import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/constants/app_constants.dart';
import 'ai_report_repository.dart';

const _dismissKey = 'ai_reminder_dismissed_date';

String _todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month}-${n.day}';
}

/// Apakah banner reminder laporan mingguan perlu ditampilkan di Home?
///
/// Tampil jika belum di-dismiss hari ini DAN:
/// - belum pernah ada laporan, tapi user sudah punya >= [aiReportMinSessions]
///   sesi belajar, ATAU
/// - laporan terakhir sudah lebih lama dari [aiReportReminderDays].
final weeklyReminderProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_dismissKey) == _todayKey()) return false;

  final repo = ref.read(aiReportRepositoryProvider);
  final latest = await repo.latestGeneratedAt();

  if (latest == null) {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return false;
    final res = await SupabaseConfig.client
        .from('study_sessions')
        .select('id')
        .eq('user_id', user.id)
        .count(CountOption.exact);
    return res.count >= AppConstants.aiReportMinSessions;
  }

  return DateTime.now().difference(latest).inDays >=
      AppConstants.aiReportReminderDays;
});

/// Sembunyikan banner untuk hari ini (disimpan lokal).
Future<void> dismissAiReminderToday(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_dismissKey, _todayKey());
  ref.invalidate(weeklyReminderProvider);
}
