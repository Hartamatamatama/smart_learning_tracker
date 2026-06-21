import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/duration_formatter.dart';
import '../models/timer_clock.dart';

/// Kunci penyimpanan bersama (saveData/getData) antara isolate UI & service.
/// Clock disimpan sebagai 3 int agar tidak perlu codec string yang rawan beda
/// antar-isolate. [clockPauseStartedAtMs] = -1 berarti tidak sedang jeda.
class TimerTaskKeys {
  TimerTaskKeys._();
  static const clockStartedAtMs = 'tk_clock_started';
  static const clockAccumPauseMs = 'tk_clock_accum';
  static const clockPauseStartedAtMs = 'tk_clock_pause';
  static const mode = 'tk_mode'; // 'pomodoro' | 'stopwatch'
  static const phase = 'tk_phase'; // 'focus' | 'break'
  static const targetSeconds = 'tk_target'; // int, -1 jika stopwatch
  static const topicName = 'tk_topic';
  static const reminderInterval = 'tk_reminder';

  static const int noPause = -1;

  /// Simpan seluruh state clock + sesi. Dipanggil dari isolate UI sebelum start
  /// dan dari handler tiap pause/resume.
  static Future<void> saveClock(TimerClock clock) async {
    await FlutterForegroundTask.saveData(
        key: clockStartedAtMs, value: clock.startedAtMs);
    await FlutterForegroundTask.saveData(
        key: clockAccumPauseMs, value: clock.accumulatedPauseMs);
    await FlutterForegroundTask.saveData(
        key: clockPauseStartedAtMs, value: clock.pauseStartedAtMs ?? noPause);
  }

  static Future<TimerClock> readClock() async {
    final started =
        await FlutterForegroundTask.getData<int>(key: clockStartedAtMs) ??
            DateTime.now().millisecondsSinceEpoch;
    final accum =
        await FlutterForegroundTask.getData<int>(key: clockAccumPauseMs) ?? 0;
    final pause =
        await FlutterForegroundTask.getData<int>(key: clockPauseStartedAtMs) ??
            noPause;
    return TimerClock(
      startedAtMs: started,
      accumulatedPauseMs: accum,
      pauseStartedAtMs: pause == noPause ? null : pause,
    );
  }
}

/// Perintah dari UI ke handler (lewat sendDataToTask).
class TimerCommands {
  TimerCommands._();
  static const pause = 'pause';
  static const resume = 'resume';
  static const stop = 'stop';
}

/// Id tombol di notifikasi.
class TimerButtons {
  TimerButtons._();
  static const pauseResume = 'btn_pause_resume';
  static const stop = 'btn_stop';
}

/// Key payload tick dari handler ke UI (lewat sendDataToMain).
class TimerTickKeys {
  TimerTickKeys._();
  static const type = 'type';
  static const tick = 'tick';
  static const stopRequested = 'stopRequested';
  static const elapsed = 'elapsed';
  static const isPaused = 'isPaused';
  static const finished = 'finished';
}

/// Entry-point isolate foreground service. Harus top-level + vm:entry-point.
@pragma('vm:entry-point')
void startTimerCallback() {
  FlutterForegroundTask.setTaskHandler(_TimerTaskHandler());
}

/// Handler yang menjadi SUMBER KEBENARAN waktu timer.
///
/// Tetap hidup saat app di-background / layar dikunci. Tiap detik:
/// hitung elapsed dari timestamp, perbarui notifikasi, kirim tick ke UI.
class _TimerTaskHandler extends TaskHandler {
  TimerClock _clock = TimerClock(startedAtMs: 0);
  String _phase = 'focus';
  int _targetSeconds = -1; // -1 = stopwatch (tanpa target)
  String _topicName = '';
  int _reminderInterval = AppConstants.reminderIntervalSeconds;
  bool _finished = false;

  bool get _hasTarget => _targetSeconds > 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _clock = await TimerTaskKeys.readClock();
    _phase =
        await FlutterForegroundTask.getData<String>(key: TimerTaskKeys.phase) ??
            'focus';
    _targetSeconds = await FlutterForegroundTask.getData<int>(
            key: TimerTaskKeys.targetSeconds) ??
        -1;
    _topicName = await FlutterForegroundTask.getData<String>(
            key: TimerTaskKeys.topicName) ??
        '';
    _reminderInterval = await FlutterForegroundTask.getData<int>(
            key: TimerTaskKeys.reminderInterval) ??
        AppConstants.reminderIntervalSeconds;
    _finished = false;
    _emit();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _emit();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! String) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (data) {
      case TimerCommands.pause:
        _clock.pause(now);
        TimerTaskKeys.saveClock(_clock);
      case TimerCommands.resume:
        _clock.resume(now);
        TimerTaskKeys.saveClock(_clock);
      case TimerCommands.stop:
        FlutterForegroundTask.sendDataToMain({
          TimerTickKeys.type: TimerTickKeys.stopRequested,
        });
    }
    _emit();
  }

  @override
  void onNotificationButtonPressed(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == TimerButtons.pauseResume) {
      if (_clock.isPaused) {
        _clock.resume(now);
      } else {
        _clock.pause(now);
      }
      TimerTaskKeys.saveClock(_clock);
      _emit();
    } else if (id == TimerButtons.stop) {
      FlutterForegroundTask.sendDataToMain({
        TimerTickKeys.type: TimerTickKeys.stopRequested,
      });
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  // -------------------------------------------------------------------------

  /// Hitung waktu, perbarui notifikasi, kirim tick ke UI.
  void _emit() {
    final now = DateTime.now().millisecondsSinceEpoch;
    var elapsed = _clock.elapsedSeconds(now);

    if (_hasTarget && elapsed >= _targetSeconds) {
      elapsed = _targetSeconds;
      _finished = true;
    }

    _updateNotification(elapsed);

    FlutterForegroundTask.sendDataToMain({
      TimerTickKeys.type: TimerTickKeys.tick,
      TimerTickKeys.elapsed: elapsed,
      TimerTickKeys.isPaused: _clock.isPaused,
      TimerTickKeys.finished: _finished,
    });
  }

  void _updateNotification(int elapsed) {
    final String title;
    final String text;

    if (_finished) {
      title = 'Sesi ${_phaseLabel()} selesai 🎉';
      text = 'Buka aplikasi untuk melanjutkan.';
    } else {
      title = '${_phaseLabel()}: ${_topicName.isEmpty ? "Belajar" : _topicName}';
      final reminder = _reminderMessage(elapsed);
      if (reminder != null) {
        text = reminder;
      } else if (_hasTarget) {
        final remaining = (_targetSeconds - elapsed).clamp(0, _targetSeconds);
        text = '⏳ Sisa ${DurationFormatter.fromSeconds(remaining)}'
            '${_clock.isPaused ? "  (jeda)" : ""}';
      } else {
        text = '⏱️ Berjalan ${DurationFormatter.fromSeconds(elapsed)}'
            '${_clock.isPaused ? "  (jeda)" : ""}';
      }
    }

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationButtons: _finished
          ? const []
          : [
              NotificationButton(
                id: TimerButtons.pauseResume,
                text: _clock.isPaused ? 'Lanjut' : 'Jeda',
              ),
              const NotificationButton(id: TimerButtons.stop, text: 'Stop'),
            ],
    );
  }

  /// Reminder berkala digabung ke notifikasi yang sama.
  /// Tiap [_reminderInterval] detik, tampilkan pesan motivasional selama
  /// [AppConstants.reminderDisplaySeconds] detik.
  String? _reminderMessage(int elapsed) {
    if (_reminderInterval <= 0 || elapsed < _reminderInterval) return null;
    if (_clock.isPaused) return null;
    final index = elapsed ~/ _reminderInterval;
    final intoWindow = elapsed - (index * _reminderInterval);
    if (intoWindow >= AppConstants.reminderDisplaySeconds) return null;
    final minutes = elapsed ~/ 60;
    final msg = AppConstants.motivationalMessages[
        (index - 1) % AppConstants.motivationalMessages.length];
    return '🔥 $minutes menit di ${_topicName.isEmpty ? "topik ini" : _topicName}. $msg';
  }

  String _phaseLabel() => _phase == 'break' ? 'Istirahat' : 'Fokus';
}
