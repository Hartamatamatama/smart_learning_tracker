import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../models/ai_evaluation.dart';
import '../providers/ai_report_controller.dart';
import '../widgets/markdown_text.dart';
import '../widgets/report_charts.dart';

class AiReportScreen extends ConsumerStatefulWidget {
  const AiReportScreen({super.key, this.autoGenerate = false});

  /// True jika dibuka dari banner reminder (langsung generate).
  final bool autoGenerate;

  @override
  ConsumerState<AiReportScreen> createState() => _AiReportScreenState();
}

class _AiReportScreenState extends ConsumerState<AiReportScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoGenerate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final s = ref.read(aiReportControllerProvider);
        if (!s.isGenerating && s.report == null) {
          ref.read(aiReportControllerProvider.notifier).generate();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiReportControllerProvider);
    final notifier = ref.read(aiReportControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyze Ourself'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat laporan',
            onPressed: () => context.push(AppRoutes.aiReportHistory),
          ),
        ],
      ),
      body: SafeArea(
        child: state.isGenerating
            ? const _GeneratingView()
            : state.report != null
                ? _ResultView(
                    report: state.report!,
                    onNew: notifier.reset,
                  )
                : _IntroView(
                    periodDays: state.periodDays,
                    error: state.error,
                    onPeriod: notifier.setPeriod,
                    onGenerate: notifier.generate,
                  ),
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({
    required this.periodDays,
    required this.error,
    required this.onPeriod,
    required this.onGenerate,
  });

  final int periodDays;
  final String? error;
  final ValueChanged<int> onPeriod;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        Icon(Icons.insights_rounded, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Analisis Performa Belajarmu',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'AI akan merangkum data sesi & mood-mu menjadi insight dan '
          'rekomendasi yang bisa kamu terapkan.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 28),

        Text('Periode analisis', style: _label(theme)),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 hari terakhir')),
            ButtonSegment(value: 30, label: Text('30 hari terakhir')),
          ],
          selected: {periodDays},
          onSelectionChanged: (s) => onPeriod(s.first),
        ),
        const SizedBox(height: 24),

        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(error!,
                      style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        FilledButton.icon(
          onPressed: onGenerate,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Analisis Sekarang', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 12),
        Text(
          'Membutuhkan koneksi internet. Proses memakan beberapa detik.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  TextStyle? _label(ThemeData theme) =>
      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 56, height: 56, child: CircularProgressIndicator()),
            const SizedBox(height: 28),
            Text('Menganalisis data belajarmu…',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'AI sedang membaca pola sesi & mood-mu lalu menyusun laporan. '
              'Mohon tunggu sebentar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.report, required this.onNew});

  final AiEvaluation report;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = report.summary;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header laporan
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Laporan ${report.periodDays} Hari Terakhir',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Dibuat ${_fmt(report.generatedAt)} • '
                '${report.sessionCount} sesi • ${report.totalMinutes} menit',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 1) Analisis AI (deliverable utama "Analyze Ourself")
        Text('Analisis AI',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (report.reportMarkdown != null)
          MarkdownText(report.reportMarkdown!)
        else
          const Text('(Tidak ada teks analisis.)'),
        const SizedBox(height: 28),

        // 2) Ringkasan visual sebagai bukti pendukung
        Text('Ringkasan Visual',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (summary != null)
          ReportCharts(summary: summary)
        else
          Text('Grafik tidak tersedia untuk laporan ini.',
              style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),

        if (report.modelUsed != null)
          Text(
            'Model: ${report.modelUsed}'
            '${report.tokensUsed != null ? " • ${report.tokensUsed} token" : ""}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.refresh),
          label: const Text('Buat Laporan Baru'),
        ),
      ],
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
  }
}
