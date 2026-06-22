import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../timer/models/timer_enums.dart';
import '../../timer/providers/topic_provider.dart';
import '../models/history_filter.dart';

/// Bottom-sheet pemilih filter riwayat. Mengembalikan [HistoryFilter] baru
/// saat "Terapkan", atau null jika dibatalkan. "Reset" mengembalikan filter kosong.
Future<HistoryFilter?> showHistoryFilterSheet(
  BuildContext context,
  HistoryFilter current,
) {
  return showModalBottomSheet<HistoryFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HistoryFilterSheet(initial: current),
  );
}

class _HistoryFilterSheet extends ConsumerStatefulWidget {
  const _HistoryFilterSheet({required this.initial});
  final HistoryFilter initial;

  @override
  ConsumerState<_HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends ConsumerState<_HistoryFilterSheet> {
  late Set<String> _topicIds;
  DateTime? _from;
  DateTime? _to;
  TimerMode? _mode;

  @override
  void initState() {
    super.initState();
    _topicIds = {...widget.initial.topicIds};
    _from = widget.initial.from;
    _to = widget.initial.to;
    _mode = widget.initial.mode;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (range != null) {
      setState(() {
        // Inklusif: dari awal hari start s/d akhir hari end.
        _from = DateTime(range.start.year, range.start.month, range.start.day);
        _to = DateTime(
            range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topicsAsync = ref.watch(topicsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Riwayat',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Topik
            Text('Topik', style: _label(theme)),
            const SizedBox(height: 8),
            topicsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Gagal memuat topik',
                  style: TextStyle(color: theme.colorScheme.error)),
              data: (topics) => topics.isEmpty
                  ? Text('Belum ada topik.', style: theme.textTheme.bodySmall)
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topics.map((t) {
                        final sel = _topicIds.contains(t.id);
                        return FilterChip(
                          label: Text(t.name),
                          selected: sel,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _topicIds.add(t.id);
                            } else {
                              _topicIds.remove(t.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),

            // Rentang tanggal
            Text('Rentang Tanggal', style: _label(theme)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      (_from != null && _to != null)
                          ? '${_fmtDate(_from!)} – ${_fmtDate(_to!)}'
                          : 'Pilih rentang',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _pickRange,
                  ),
                ),
                if (_from != null || _to != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Hapus tanggal',
                    onPressed: () => setState(() {
                      _from = null;
                      _to = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Mode
            Text('Mode', style: _label(theme)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _mode == null,
                  onSelected: (_) => setState(() => _mode = null),
                ),
                ChoiceChip(
                  label: const Text('Pomodoro'),
                  selected: _mode == TimerMode.pomodoro,
                  onSelected: (_) => setState(() => _mode = TimerMode.pomodoro),
                ),
                ChoiceChip(
                  label: const Text('Stopwatch'),
                  selected: _mode == TimerMode.stopwatch,
                  onSelected: (_) => setState(() => _mode = TimerMode.stopwatch),
                ),
              ],
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const HistoryFilter()),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      HistoryFilter(
                        topicIds: _topicIds,
                        from: _from,
                        to: _to,
                        mode: _mode,
                      ),
                    ),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _label(ThemeData theme) =>
      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
}
