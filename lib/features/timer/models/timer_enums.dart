/// Mode timer belajar.
enum TimerMode {
  pomodoro,
  stopwatch;

  String get dbValue => switch (this) {
        TimerMode.pomodoro => 'pomodoro',
        TimerMode.stopwatch => 'stopwatch',
      };

  String get label => switch (this) {
        TimerMode.pomodoro => 'Pomodoro',
        TimerMode.stopwatch => 'Stopwatch',
      };

  static TimerMode fromDb(String value) =>
      value == 'stopwatch' ? TimerMode.stopwatch : TimerMode.pomodoro;
}

/// Fase dalam siklus Pomodoro. Stopwatch selalu [focus].
/// Catatan: hanya fase [focus] yang dicatat sebagai study_session +
/// memicu jurnal mood. Fase [breakTime] murni UX (tidak disimpan).
enum TimerPhase {
  focus,
  breakTime;

  String get label => switch (this) {
        TimerPhase.focus => 'Fokus',
        TimerPhase.breakTime => 'Istirahat',
      };
}

/// Status akhir sebuah sesi belajar (disimpan ke study_sessions.status).
enum SessionStatus {
  /// Sesi selesai penuh sesuai rencana (atau stopwatch dihentikan normal).
  completed,

  /// Sesi dihentikan paksa sebelum target durasi tercapai.
  stoppedEarly;

  String get dbValue => switch (this) {
        SessionStatus.completed => 'completed',
        SessionStatus.stoppedEarly => 'stopped_early',
      };
}
