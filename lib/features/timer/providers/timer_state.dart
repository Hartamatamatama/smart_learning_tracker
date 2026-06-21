import '../models/timer_enums.dart';
import '../models/topic.dart';

enum TimerRunStatus { idle, running, finished }

/// Permintaan navigasi wajib ke Jurnal Mood setelah sesi (fokus/stopwatch)
/// berakhir. Bersifat transient — di-clear setelah dikonsumsi UI.
class MoodNavRequest {
  const MoodNavRequest({
    required this.sessionId,
    required this.status,
    required this.topicName,
    required this.allowBreak,
  });

  final String sessionId;
  final SessionStatus status;
  final String topicName;

  /// True jika setelah jurnal boleh ditawari istirahat (pomodoro completed).
  final bool allowBreak;
}

/// State runtime timer yang dirender UI.
class TimerState {
  const TimerState({
    this.status = TimerRunStatus.idle,
    this.mode = TimerMode.pomodoro,
    this.phase = TimerPhase.focus,
    this.topic,
    this.elapsedSeconds = 0,
    this.targetSeconds,
    this.isPaused = false,
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.moodNav,
    this.breakFinished = false,
    this.errorMessage,
  });

  final TimerRunStatus status;
  final TimerMode mode;
  final TimerPhase phase;
  final Topic? topic;
  final int elapsedSeconds;

  /// Null untuk stopwatch (tanpa target).
  final int? targetSeconds;
  final bool isPaused;
  final int focusMinutes;
  final int breakMinutes;

  final MoodNavRequest? moodNav;
  final bool breakFinished;
  final String? errorMessage;

  int? get remainingSeconds =>
      targetSeconds == null ? null : (targetSeconds! - elapsedSeconds).clamp(0, targetSeconds!);

  double get progress {
    final target = targetSeconds;
    if (target == null || target == 0) return 0;
    return (elapsedSeconds / target).clamp(0.0, 1.0);
  }

  TimerState copyWith({
    TimerRunStatus? status,
    TimerMode? mode,
    TimerPhase? phase,
    Topic? topic,
    int? elapsedSeconds,
    int? targetSeconds,
    bool clearTarget = false,
    bool? isPaused,
    int? focusMinutes,
    int? breakMinutes,
    MoodNavRequest? moodNav,
    bool clearMoodNav = false,
    bool? breakFinished,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TimerState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      topic: topic ?? this.topic,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      targetSeconds: clearTarget ? null : (targetSeconds ?? this.targetSeconds),
      isPaused: isPaused ?? this.isPaused,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      moodNav: clearMoodNav ? null : (moodNav ?? this.moodNav),
      breakFinished: breakFinished ?? this.breakFinished,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
