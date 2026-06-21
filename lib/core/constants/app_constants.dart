class AppConstants {
  AppConstants._();

  static const String appName = 'Smart Learning Tracker';
  static const String appVersion = '1.0.0';

  // OpenRouter
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openRouterModel = 'mistralai/mistral-7b-instruct:free';

  // Timer defaults (dalam menit)
  static const int defaultFocusMinutes = 25; // Pomodoro fokus
  static const int defaultBreakMinutes = 5; // Pomodoro istirahat
  static const int minDurationMinutes = 1;
  static const int maxDurationMinutes = 180;

  // Reminder berkala saat sesi aktif (detik). Digabung ke notifikasi
  // persisten: tiap interval ini, pesan notifikasi berganti motivasional
  // selama [reminderDisplaySeconds] detik, lalu kembali menampilkan waktu.
  static const int reminderIntervalSeconds = 10 * 60; // 10 menit
  static const int reminderDisplaySeconds = 30;

  // Foreground service / notifikasi
  static const int foregroundServiceId = 500;
  static const String timerChannelId = 'study_timer_channel';
  static const String timerChannelName = 'Timer Belajar';
  static const String timerChannelDesc =
      'Notifikasi persisten selama sesi belajar berlangsung.';

  // Mood scale
  static const int moodMinScale = 1;
  static const int moodMaxScale = 5;

  // Parameter mood default yang dipakai placeholder Jurnal Mood (Fase 2).
  // Detail lengkap multi-parameter dikerjakan di Fase 3.
  static const String defaultMoodParameter = 'mood_umum';

  // Pesan motivasional reminder (dipilih bergiliran).
  static const List<String> motivationalMessages = [
    'Tetap fokus, kamu sedang membangun kebiasaan baik!',
    'Sedikit lagi, jaga konsentrasimu!',
    'Kerja bagus, terus pertahankan ritmenya!',
    'Napas sejenak, lalu lanjut fokus ya!',
  ];
}
