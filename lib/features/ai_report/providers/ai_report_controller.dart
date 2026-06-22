import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/providers/analytics_repository.dart';
import '../models/ai_evaluation.dart';
import '../services/openrouter_service.dart';
import 'ai_report_repository.dart';

class AiReportState {
  const AiReportState({
    this.periodDays = 7,
    this.isGenerating = false,
    this.report,
    this.error,
  });

  final int periodDays;
  final bool isGenerating;
  final AiEvaluation? report;
  final String? error;

  AiReportState copyWith({
    int? periodDays,
    bool? isGenerating,
    AiEvaluation? report,
    bool clearReport = false,
    String? error,
    bool clearError = false,
  }) {
    return AiReportState(
      periodDays: periodDays ?? this.periodDays,
      isGenerating: isGenerating ?? this.isGenerating,
      report: clearReport ? null : (report ?? this.report),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AiReportController extends Notifier<AiReportState> {
  @override
  AiReportState build() => const AiReportState();

  void setPeriod(int days) {
    if (state.isGenerating) return;
    state = state.copyWith(periodDays: days);
  }

  /// Generate laporan baru untuk periode terpilih: hitung agregat → panggil AI
  /// → simpan ke Supabase → tampilkan.
  Future<void> generate() async {
    if (state.isGenerating) return;
    state = state.copyWith(
        isGenerating: true, clearError: true, clearReport: true);
    try {
      final summary = await ref
          .read(analyticsRepositoryProvider)
          .computeSummary(days: state.periodDays);

      if (summary.isEmpty) {
        state = state.copyWith(
          isGenerating: false,
          error:
              'Belum ada sesi belajar dalam ${state.periodDays} hari terakhir. '
              'Selesaikan beberapa sesi dulu, ya.',
        );
        return;
      }

      final result =
          await ref.read(openRouterServiceProvider).generateAnalysis(summary);

      final saved = await ref.read(aiReportRepositoryProvider).insertReport(
            periodDays: state.periodDays,
            summary: summary,
            result: result,
          );

      // Segarkan daftar riwayat laporan.
      ref.invalidate(aiReportsProvider);

      state = state.copyWith(isGenerating: false, report: saved);
    } on OpenRouterException catch (e) {
      state = state.copyWith(isGenerating: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: _mapError(e));
    }
  }

  /// Pesan ramah untuk error non-OpenRouter (mis. query data gagal).
  /// Hindari membocorkan exception mentah (URL/user_id) ke layar.
  String _mapError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('no address') ||
        s.contains('clientexception') ||
        s.contains('connection')) {
      return 'Tidak ada koneksi internet. Sambungkan ke internet lalu coba lagi.';
    }
    return 'Gagal menyiapkan data laporan. Coba lagi nanti.';
  }

  /// Tampilkan laporan lama (dari riwayat) tanpa generate ulang.
  void showExisting(AiEvaluation report) {
    state = state.copyWith(
      report: report,
      periodDays: report.periodDays,
      clearError: true,
      isGenerating: false,
    );
  }

  void reset() => state = const AiReportState();
}

final aiReportControllerProvider =
    NotifierProvider<AiReportController, AiReportState>(AiReportController.new);
