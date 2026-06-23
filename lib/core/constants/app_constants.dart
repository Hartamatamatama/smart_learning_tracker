class AppConstants {
  AppConstants._();

  static const String appName = 'Smart Learning Tracker';
  static const String appVersion = '1.0.0';

  // OpenRouter
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  // Pakai router otomatis 'openrouter/free' (bukan model spesifik) karena
  // daftar model gratis OpenRouter sering berubah; router ini memilih sendiri
  // model gratis yang tersedia saat request, jadi lebih tahan perubahan.
  static const String openRouterModel = 'openrouter/free';

  // Reminder laporan AI mingguan (hari). Banner muncul jika laporan terakhir
  // sudah lebih lama dari ini (atau belum pernah ada).
  static const int aiReportReminderDays = 7;
  // Minimal sesi sebelum reminder pertama ditawarkan.
  static const int aiReportMinSessions = 3;

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
  // PENTING: importance sebuah notification channel di Android BERSIFAT IMMUTABLE
  // setelah channel pertama kali dibuat — ganti importance di kode TIDAK akan
  // mengubah channel lama. Channel 'study_timer_channel' (v1) terlanjur dibuat
  // dengan importance LOW (bug Fase 2: channelImportance tidak di-set), sehingga
  // notifikasi tidak muncul di status bar / lock screen. Maka id di-bump ke v2
  // agar channel BARU dibuat dengan importance HIGH.
  static const String timerChannelId = 'study_timer_channel_v2';
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
