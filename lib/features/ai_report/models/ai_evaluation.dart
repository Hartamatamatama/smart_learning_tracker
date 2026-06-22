import 'dart:convert';

import '../../analytics/models/study_analytics_summary.dart';

/// Satu laporan evaluasi AI tersimpan (tabel `ai_evaluations`).
class AiEvaluation {
  const AiEvaluation({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.sessionCount,
    required this.totalMinutes,
    required this.reportMarkdown,
    required this.modelUsed,
    required this.tokensUsed,
    required this.generatedAt,
    required this.summary,
  });

  factory AiEvaluation.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary_json'];
    StudyAnalyticsSummary? summary;
    if (rawSummary != null) {
      final map = rawSummary is String
          ? jsonDecode(rawSummary) as Map<String, dynamic>
          : Map<String, dynamic>.from(rawSummary as Map);
      summary = StudyAnalyticsSummary.fromJson(map);
    }
    return AiEvaluation(
      id: json['id'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      reportMarkdown: json['report_markdown'] as String?,
      modelUsed: json['model_used'] as String?,
      tokensUsed: (json['tokens_used'] as num?)?.toInt(),
      generatedAt: DateTime.parse(json['generated_at'] as String).toLocal(),
      summary: summary,
    );
  }

  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int sessionCount;
  final int totalMinutes;
  final String? reportMarkdown;
  final String? modelUsed;
  final int? tokensUsed;
  final DateTime generatedAt;

  /// Snapshot data agregat saat laporan dibuat (untuk grafik).
  final StudyAnalyticsSummary? summary;

  /// Perkiraan jumlah hari periode.
  int get periodDays => periodEnd.difference(periodStart).inDays;
}
