import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../../analytics/models/study_analytics_summary.dart';
import '../models/ai_evaluation.dart';
import '../services/openrouter_service.dart';

/// CRUD laporan evaluasi AI ke tabel `ai_evaluations`.
class AiReportRepository {
  const AiReportRepository();

  String get _userId {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw StateError('Tidak ada user yang login.');
    return user.id;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Simpan laporan baru, kembalikan baris hasil (termasuk id & summary).
  Future<AiEvaluation> insertReport({
    required int periodDays,
    required StudyAnalyticsSummary summary,
    required AiGenerationResult result,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: periodDays));
    final inserted = await SupabaseConfig.client
        .from('ai_evaluations')
        .insert({
          'user_id': _userId,
          'period_start': _dateOnly(start),
          'period_end': _dateOnly(now),
          'session_count': summary.sessionCount,
          'total_minutes': summary.totalMinutes,
          'prompt_used': result.promptUsed,
          'report_markdown': result.text,
          'model_used': result.model,
          'tokens_used': result.totalTokens,
          'summary_json': summary.toJson(),
        })
        .select()
        .single();
    return AiEvaluation.fromJson(inserted);
  }

  /// Daftar laporan, urut terbaru.
  Future<List<AiEvaluation>> fetchReports() async {
    final rows = await SupabaseConfig.client
        .from('ai_evaluations')
        .select()
        .eq('user_id', _userId)
        .order('generated_at', ascending: false);
    return (rows as List)
        .map((e) => AiEvaluation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Waktu laporan terbaru (untuk reminder mingguan). Null jika belum ada.
  Future<DateTime?> latestGeneratedAt() async {
    final rows = await SupabaseConfig.client
        .from('ai_evaluations')
        .select('generated_at')
        .eq('user_id', _userId)
        .order('generated_at', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return DateTime.parse(rows.first['generated_at'] as String).toLocal();
  }
}

final aiReportRepositoryProvider =
    Provider<AiReportRepository>((ref) => const AiReportRepository());

/// Daftar laporan AI (untuk layar riwayat laporan).
final aiReportsProvider = FutureProvider<List<AiEvaluation>>((ref) {
  return ref.watch(aiReportRepositoryProvider).fetchReports();
});
