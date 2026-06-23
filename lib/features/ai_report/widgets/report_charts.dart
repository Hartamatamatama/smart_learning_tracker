import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../analytics/models/study_analytics_summary.dart';

/// Tiga grafik ringkasan untuk laporan: menit/topik (bar), tren fokus (line),
/// proporsi selesai vs dihentikan (pie).
class ReportCharts extends StatelessWidget {
  const ReportCharts({super.key, required this.summary});

  final StudyAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: 'Menit Belajar per Topik',
          child: _MinutesByTopicChart(summary: summary),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Tren Fokus',
          subtitle: 'Rata-rata skor fokus (1–5) sepanjang periode',
          child: _FokusTrendChart(summary: summary),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Sesi Selesai vs Dihentikan',
          child: _CompletionChart(summary: summary),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                )),
          ],
          const SizedBox(height: 16),
          SizedBox(height: 170, child: child),
        ],
      ),
    );
  }
}

String _short(String s, [int max = 8]) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';

class _MinutesByTopicChart extends StatelessWidget {
  const _MinutesByTopicChart({required this.summary});
  final StudyAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ambil maksimal 6 topik dengan menit terbanyak agar tidak penuh.
    final entries = summary.minutesByTopic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    if (top.isEmpty) return const _NoData();

    final maxMinutes =
        top.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxMinutes * 1.25 + 1,
        barTouchData: BarTouchData(enabled: true),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: theme.textTheme.labelSmall),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= top.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_short(top[i].key),
                      style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < top.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: top[i].value.toDouble(),
                color: theme.colorScheme.primary,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      ),
    );
  }
}

class _FokusTrendChart extends StatelessWidget {
  const _FokusTrendChart({required this.summary});
  final StudyAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = summary.moodTrend;
    if (points.isEmpty) return const _NoData();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 5,
        lineTouchData: const LineTouchData(enabled: true),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (v, _) =>
                  Text(v.toInt().toString(), style: theme.textTheme.labelSmall),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                // Hindari label terlalu rapat jika banyak titik.
                if (points.length > 7 && i % 2 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(points[i].label,
                      style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].fokus),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionChart extends StatelessWidget {
  const _CompletionChart({required this.summary});
  final StudyAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = summary.completedCount;
    final s = summary.stoppedEarlyCount;
    final total = c + s;
    if (total == 0) return const _NoData();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                PieChartSectionData(
                  value: c.toDouble(),
                  title: '${(c / total * 100).round()}%',
                  color: AppColors.success,
                  radius: 46,
                  titleStyle: const TextStyle(
                      color: AppColors.onLime,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                PieChartSectionData(
                  value: s.toDouble(),
                  title: '${(s / total * 100).round()}%',
                  color: AppColors.warning,
                  radius: 46,
                  titleStyle: const TextStyle(
                      color: AppColors.onLime,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Legend(color: AppColors.success, label: 'Selesai', value: c),
            const SizedBox(height: 10),
            _Legend(color: AppColors.warning, label: 'Dihentikan', value: s),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text('$label  ', style: theme.textTheme.bodyMedium),
        Text('$value',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Data belum cukup',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              )),
    );
  }
}
