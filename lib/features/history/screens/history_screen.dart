import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../timer/models/timer_enums.dart';
import '../models/history_filter.dart';
import '../models/session_history_item.dart';
import '../providers/history_controller.dart';
import '../widgets/history_filter_sheet.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final notifier = ref.read(historyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Belajar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: notifier.refresh,
          ),
          // Tombol filter dengan indikator titik jika filter aktif.
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: () async {
                  final result =
                      await showHistoryFilterSheet(context, state.filter);
                  if (result != null) notifier.applyFilter(result);
                },
              ),
              if (state.filter.isActive)
                Positioned(
                  right: 10,
                  top: 12,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.filter.isActive) _ActiveFilterBar(filter: state.filter),
          Expanded(
            child: state.page.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(message: '$e', onRetry: notifier.refresh),
              data: (page) {
                if (page.totalCount == 0) {
                  return state.filter.isActive
                      ? const _EmptyView(
                          icon: Icons.search_off,
                          title: 'Tidak ada hasil',
                          message:
                              'Tidak ada sesi yang cocok dengan filter ini.\nCoba ubah atau reset filter.',
                        )
                      : _EmptyView(
                          icon: Icons.menu_book_outlined,
                          title: 'Belum ada riwayat',
                          message:
                              'Kamu belum menyelesaikan sesi belajar.\nYuk mulai sesi pertamamu!',
                          action: FilledButton.icon(
                            onPressed: () => context.go(AppRoutes.timerSetup),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Mulai Belajar'),
                          ),
                        );
                }
                return RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SessionCard(item: page.items[i]),
                  ),
                );
              },
            ),
          ),
          // Bar pagination (hanya jika ada data).
          state.page.maybeWhen(
            data: (page) =>
                page.totalCount > 0 ? _PaginationBar(page: page) : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.filter});
  final HistoryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (filter.topicIds.isNotEmpty) {
      parts.add('${filter.topicIds.length} topik');
    }
    if (filter.from != null && filter.to != null) parts.add('rentang tanggal');
    if (filter.mode != null) parts.add(filter.mode!.label);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filter aktif: ${parts.join(", ")}',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(historyControllerProvider.notifier).resetFilter(),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item});
  final SessionHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPomodoro = item.mode == TimerMode.pomodoro;
    final completed = item.status == SessionStatus.completed;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // push (bukan go) agar muncul tombol kembali & bisa pop ke list.
        onTap: () => context.push(AppRoutes.sessionDetail, extra: item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Ikon mode
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPomodoro
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPomodoro ? Icons.timelapse : Icons.timer_outlined,
                  color: isPomodoro
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.topicName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(item.startedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          DurationFormatter.toReadable(
                              Duration(seconds: item.actualDurationSec)),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.graphic_eq,
                            size: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.ambientLabel,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge status
              Tooltip(
                message: completed ? 'Selesai' : 'Dihentikan',
                child: Icon(
                  completed ? Icons.check_circle : Icons.pause_circle_filled,
                  color: completed ? Colors.green : Colors.orange,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year} • $hh:$mm';
  }
}

class _PaginationBar extends ConsumerWidget {
  const _PaginationBar({required this.page});
  final HistoryPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(historyControllerProvider.notifier);

    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton.outlined(
              onPressed: page.hasPrev ? notifier.prevPage : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Halaman sebelumnya',
            ),
            Expanded(
              child: Text(
                'Halaman ${page.displayPage} dari ${page.totalPages}',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton.outlined(
              onPressed: page.hasNext ? notifier.nextPage : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Halaman selanjutnya',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 72,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 20),
            Text(title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Gagal memuat riwayat',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
