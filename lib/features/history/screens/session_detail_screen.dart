import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_formatter.dart';
import '../../timer/models/timer_enums.dart';
import '../models/session_history_item.dart';
import '../providers/history_controller.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.item});

  final SessionHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPomodoro = item.mode == TimerMode.pomodoro;
    final completed = item.status == SessionStatus.completed;
    final moodAsync = ref.watch(sessionMoodProvider(item.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Sesi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header topik + status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPomodoro
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPomodoro ? Icons.timelapse : Icons.timer_outlined,
                  size: 28,
                  color: isPomodoro
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.topicName,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          completed
                              ? Icons.check_circle
                              : Icons.pause_circle_filled,
                          size: 16,
                          color: completed ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(item.status.label,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info sesi
          _InfoCard(rows: [
            _InfoRow(Icons.event, 'Tanggal', _formatDate(item.startedAt)),
            _InfoRow(Icons.login, 'Mulai', _formatTime(item.startedAt)),
            _InfoRow(
                Icons.logout,
                'Selesai',
                item.endedAt != null ? _formatTime(item.endedAt!) : '-'),
            _InfoRow(
                Icons.schedule,
                'Durasi',
                DurationFormatter.toReadable(
                    Duration(seconds: item.actualDurationSec))),
            _InfoRow(Icons.tune, 'Mode', item.mode.label),
            _InfoRow(Icons.graphic_eq, 'Ambient', item.ambientLabel),
          ]),
          const SizedBox(height: 24),

          Text('Jurnal Mood',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          moodAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Gagal memuat mood: $e',
                style: TextStyle(color: theme.colorScheme.error)),
            data: (mood) {
              if (mood.isEmpty) {
                return Text('Tidak ada data mood untuk sesi ini.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ));
              }
              return Column(
                children: [
                  ...mood.scores.map((s) => _MoodRow(
                        label: s.displayLabel,
                        score: s.score,
                      )),
                  if (mood.note != null && mood.note!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Catatan',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              )),
                          const SizedBox(height: 4),
                          Text(mood.note!, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _InfoRow {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(rows[i].icon,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(rows[i].label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      )),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.label, required this.score});
  final String label;
  final int score;

  static const _icons = [
    Icons.sentiment_very_dissatisfied,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
    Icons.sentiment_very_satisfied,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = (score.clamp(1, 5)) - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(_icons[idx], color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          // Lima titik skor
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final filled = i < score;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  filled ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: filled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
