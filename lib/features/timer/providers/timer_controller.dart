import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../ambient_sound/models/ambient_sound.dart';
import '../../ambient_sound/providers/ambient_player_controller.dart';
import '../../history/providers/history_controller.dart';
import '../../reminders/providers/reminder_provider.dart';
import '../models/study_session.dart';
import '../models/timer_clock.dart';
import '../models/timer_enums.dart';
import '../models/topic.dart';
import '../services/timer_foreground_task.dart';
import 'session_repository.dart';
import 'timer_state.dart';

/// Controller utama timer. Mengatur start/pause/resume/stop, jembatan ke
/// foreground service (Android) atau ticker internal (Web), dan menyimpan
/// sesi ke Supabase saat berakhir.
class TimerController extends Notifier<TimerState> {
  Timer? _webTimer;
  TimerClock? _webClock;
  DateTime? _startedAt;
  bool _ending = false;
  bool _callbackRegistered = false;

  bool get _useService => !kIsWeb;

  @override
  TimerState build() {
    if (_useService && !_callbackRegistered) {
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      _callbackRegistered = true;
      ref.onDispose(() {
        FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
        _callbackRegistered = false;
      });
    }
    ref.onDispose(() => _webTimer?.cancel());
    return const TimerState();
  }

  // ---------------------------------------------------------------------------
  // Start
  // ---------------------------------------------------------------------------

  Future<void> startFocus({
    required TimerMode mode,
    required Topic topic,
    required int focusMinutes,
    required int breakMinutes,
    AmbientSound? ambientSound,
  }) async {
    final target = mode == TimerMode.pomodoro ? focusMinutes * 60 : null;
    await _start(
      mode: mode,
      topic: topic,
      phase: TimerPhase.focus,
      targetSeconds: target,
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      ambientSound: ambientSound,
    );
  }

  /// Mulai fase istirahat (hanya Pomodoro). Tidak dicatat ke DB.
  Future<void> startBreak() async {
    final topic = state.topic;
    if (topic == null) return;
    await _start(
      mode: TimerMode.pomodoro,
      topic: topic,
      phase: TimerPhase.breakTime,
      targetSeconds: state.breakMinutes * 60,
      focusMinutes: state.focusMinutes,
      breakMinutes: state.breakMinutes,
    );
  }

  Future<void> _start({
    required TimerMode mode,
    required Topic topic,
    required TimerPhase phase,
    required int? targetSeconds,
    required int focusMinutes,
    required int breakMinutes,
    AmbientSound? ambientSound,
  }) async {
    _ending = false;
    final now = DateTime.now();
    _startedAt = now;
    final clock = TimerClock(startedAtMs: now.millisecondsSinceEpoch);

    state = TimerState(
      status: TimerRunStatus.running,
      mode: mode,
      phase: phase,
      topic: topic,
      elapsedSeconds: 0,
      targetSeconds: targetSeconds,
      isPaused: false,
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      ambientSound: ambientSound,
    );

    if (_useService) {
      await _startService(clock, mode, phase, targetSeconds, topic.name);
    } else {
      _startWeb(clock, targetSeconds);
    }

    // Ambient sound opsional — mulai memutar (loop) bila dipilih.
    if (ambientSound != null) {
      await ref
          .read(ambientPlayerControllerProvider.notifier)
          .start(ambientSound);
    }
  }

  Future<void> _startService(
    TimerClock clock,
    TimerMode mode,
    TimerPhase phase,
    int? targetSeconds,
    String topicName,
  ) async {
    await TimerTaskKeys.saveClock(clock);
    await FlutterForegroundTask.saveData(
        key: TimerTaskKeys.mode, value: mode.dbValue);
    await FlutterForegroundTask.saveData(
        key: TimerTaskKeys.phase,
        value: phase == TimerPhase.breakTime ? 'break' : 'focus');
    await FlutterForegroundTask.saveData(
        key: TimerTaskKeys.targetSeconds, value: targetSeconds ?? -1);
    await FlutterForegroundTask.saveData(
        key: TimerTaskKeys.topicName, value: topicName);
    await FlutterForegroundTask.saveData(
        key: TimerTaskKeys.reminderInterval,
        value: AppConstants.reminderIntervalSeconds);

    await _requestPermissions();
    _initService();

    final initialText = targetSeconds != null
        ? '⏳ Sisa ${_fmt(targetSeconds)}'
        : '⏱️ Berjalan 00:00';

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: AppConstants.foregroundServiceId,
        notificationTitle:
            '${phase == TimerPhase.breakTime ? "Istirahat" : "Fokus"}: $topicName',
        notificationText: initialText,
        notificationButtons: const [
          NotificationButton(id: TimerButtons.pauseResume, text: 'Jeda'),
          NotificationButton(id: TimerButtons.stop, text: 'Stop'),
        ],
        callback: startTimerCallback,
      );
    }
  }

  void _startWeb(TimerClock clock, int? targetSeconds) {
    _webClock = clock;
    _webTimer?.cancel();
    _webTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final c = _webClock;
      if (c == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      var elapsed = c.elapsedSeconds(now);
      var finished = false;
      if (targetSeconds != null && elapsed >= targetSeconds) {
        elapsed = targetSeconds;
        finished = true;
      }
      state = state.copyWith(elapsedSeconds: elapsed, isPaused: c.isPaused);
      if (finished && !_ending) {
        _webTimer?.cancel();
        _handleFinish();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Pause / Resume / Stop
  // ---------------------------------------------------------------------------

  void pause() {
    if (state.status != TimerRunStatus.running || state.isPaused) return;
    if (_useService) {
      FlutterForegroundTask.sendDataToTask(TimerCommands.pause);
    } else {
      _webClock?.pause(DateTime.now().millisecondsSinceEpoch);
    }
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    if (state.status != TimerRunStatus.running || !state.isPaused) return;
    if (_useService) {
      FlutterForegroundTask.sendDataToTask(TimerCommands.resume);
    } else {
      _webClock?.resume(DateTime.now().millisecondsSinceEpoch);
    }
    state = state.copyWith(isPaused: false);
  }

  /// Stop manual (tombol UI atau notifikasi).
  Future<void> stop() async {
    if (state.status != TimerRunStatus.running) return;
    if (state.phase == TimerPhase.breakTime) {
      await _endBreak();
    } else {
      final status = state.mode == TimerMode.stopwatch
          ? SessionStatus.completed // stopwatch: stop = selesai normal
          : SessionStatus.stoppedEarly; // pomodoro fokus dihentikan di tengah
      await _endSession(status);
    }
  }

  // ---------------------------------------------------------------------------
  // Akhir sesi
  // ---------------------------------------------------------------------------

  void _handleFinish() {
    if (state.phase == TimerPhase.breakTime) {
      _endBreak();
    } else {
      _endSession(SessionStatus.completed);
    }
  }

  Future<void> _endSession(SessionStatus status) async {
    if (_ending) return;
    _ending = true;

    await _stopRuntime();

    final elapsed = state.targetSeconds != null && status == SessionStatus.completed
        ? state.targetSeconds!
        : state.elapsedSeconds;
    final topic = state.topic;
    final user = SupabaseConfig.client.auth.currentUser;

    if (topic == null || user == null) {
      state = state.copyWith(
        status: TimerRunStatus.finished,
        errorMessage: 'Sesi tidak dapat disimpan (data tidak lengkap).',
      );
      return;
    }

    final session = StudySession(
      userId: user.id,
      topicId: topic.id,
      mode: state.mode,
      startedAt: _startedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      plannedDurationSec:
          state.mode == TimerMode.pomodoro ? state.targetSeconds : null,
      actualDurationSec: elapsed,
      status: status,
      ambientSoundId: state.ambientSound?.id,
    );

    try {
      final sessionId =
          await ref.read(sessionRepositoryProvider).insertSession(session);
      // Sesi baru masuk ke study_sessions → segarkan Riwayat agar saat dibuka
      // menampilkan data terbaru (reset ke halaman 1 & filter kosong).
      ref.invalidate(historyControllerProvider);
      // Sudah belajar hari ini → batalkan pengingat belajar sisa hari ini
      // langsung (tanpa harus tutup-buka app). Fire-and-forget.
      unawaited(
          ref.read(reminderControllerProvider.notifier).reconcileToday());
      state = state.copyWith(
        status: TimerRunStatus.finished,
        elapsedSeconds: elapsed,
        moodNav: MoodNavRequest(
          sessionId: sessionId,
          status: status,
          topicName: topic.name,
          allowBreak: state.mode == TimerMode.pomodoro &&
              status == SessionStatus.completed,
          mode: state.mode,
          durationSeconds: elapsed,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status: TimerRunStatus.finished,
        elapsedSeconds: elapsed,
        errorMessage: 'Gagal menyimpan sesi: $e',
      );
    }
  }

  Future<void> _endBreak() async {
    if (_ending) return;
    _ending = true;
    await _stopRuntime();
    state = state.copyWith(
      status: TimerRunStatus.finished,
      breakFinished: true,
    );
  }

  Future<void> _stopRuntime() async {
    _webTimer?.cancel();
    _webTimer = null;
    _webClock = null;
    // Hentikan ambient sound bila ada (sesi berakhir → suara berhenti).
    await ref.read(ambientPlayerControllerProvider.notifier).stop();
    if (_useService && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle / reconciliation
  // ---------------------------------------------------------------------------

  /// Dipanggil saat app kembali ke foreground. Hitung ulang dari timestamp
  /// tersimpan agar UI langsung sinkron tanpa menunggu tick berikutnya.
  Future<void> reconcile() async {
    if (!_useService || state.status != TimerRunStatus.running) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    final clock = await TimerTaskKeys.readClock();
    final target = await FlutterForegroundTask.getData<int>(
            key: TimerTaskKeys.targetSeconds) ??
        -1;
    final now = DateTime.now().millisecondsSinceEpoch;
    var elapsed = clock.elapsedSeconds(now);
    var finished = false;
    if (target > 0 && elapsed >= target) {
      elapsed = target;
      finished = true;
    }
    state = state.copyWith(elapsedSeconds: elapsed, isPaused: clock.isPaused);
    if (finished && !_ending) _handleFinish();
  }

  // ---------------------------------------------------------------------------
  // Konsumsi sinyal transient & reset
  // ---------------------------------------------------------------------------

  void consumeMoodNav() => state = state.copyWith(clearMoodNav: true);

  void acknowledgeBreakFinished() =>
      state = state.copyWith(breakFinished: false, status: TimerRunStatus.idle);

  void reset() => state = const TimerState();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final type = data[TimerTickKeys.type];
    if (type == TimerTickKeys.stopRequested) {
      stop();
      return;
    }
    if (type == TimerTickKeys.tick) {
      final elapsed = (data[TimerTickKeys.elapsed] as num?)?.toInt() ?? 0;
      final isPaused = data[TimerTickKeys.isPaused] == true;
      final finished = data[TimerTickKeys.finished] == true;
      if (state.status == TimerRunStatus.running) {
        state = state.copyWith(elapsedSeconds: elapsed, isPaused: isPaused);
        if (finished && !_ending) _handleFinish();
      }
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.timerChannelId,
        channelName: AppConstants.timerChannelName,
        channelDescription: AppConstants.timerChannelDesc,
        // FIX Fase 8: tanpa ini, default channelImportance = LOW → notifikasi
        // tidak tampil di status bar / lock screen. HIGH = tampil di mana-mana
        // (status bar, lock screen, sekali peek). priority HIGH untuk Android
        // 7.1 ke bawah. visibility PUBLIC (default) agar terlihat di lock screen.
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        // onlyAlertOnce: HIGH membuat heads-up sekali saat sesi mulai, lalu
        // update tiap detik tidak bunyi/bergetar lagi (tetap persisten).
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    // FIX Fase 8: minta pengecualian battery optimization. Tanpa ini, Doze /
    // manajemen baterai OEM (mis. Transsion/Infinix XOS) bisa membekukan
    // foreground service & menyembunyikan notifikasi. Dialog sistem hanya
    // muncul sekali bila app belum di-whitelist; jika sudah, langsung lewat.
    // CATATAN: ini hanya menangani Doze standar Android — pengaturan baterai
    // KHUSUS OEM (Autostart dll) tidak bisa diminta via API; lihat
    // TROUBLESHOOTING_NOTIFICATIONS.md untuk langkah manual.
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

final timerControllerProvider =
    NotifierProvider<TimerController, TimerState>(TimerController.new);
