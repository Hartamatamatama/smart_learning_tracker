class AppConstants {
  AppConstants._();

  static const String appName = 'Smart Learning Tracker';
  static const String appVersion = '1.0.0';

  // OpenRouter
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String openRouterModel = 'mistralai/mistral-7b-instruct:free';

  // Timer defaults (dalam detik)
  static const int defaultStudyDuration = 25 * 60; // 25 menit (Pomodoro)
  static const int defaultBreakDuration = 5 * 60;

  // Mood scale
  static const int moodMinScale = 1;
  static const int moodMaxScale = 5;
}
