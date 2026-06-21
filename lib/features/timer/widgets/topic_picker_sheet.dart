import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/topic.dart';
import '../providers/topic_provider.dart';

/// Bottom sheet pemilihan topik. Mengembalikan [Topic] terpilih, atau null.
Future<Topic?> showTopicPickerSheet(BuildContext context) {
  return showModalBottomSheet<Topic>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _TopicPickerSheet(),
  );
}

class _TopicPickerSheet extends ConsumerStatefulWidget {
  const _TopicPickerSheet();

  @override
  ConsumerState<_TopicPickerSheet> createState() => _TopicPickerSheetState();
}

class _TopicPickerSheetState extends ConsumerState<_TopicPickerSheet> {
  final _newTopicCtrl = TextEditingController();
  bool _creating = false;
  bool _showCreateField = false;

  @override
  void dispose() {
    _newTopicCtrl.dispose();
    super.dispose();
  }

  Future<void> _createTopic() async {
    final name = _newTopicCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final topic = await ref.read(topicRepositoryProvider).createTopic(name);
      ref.invalidate(topicsProvider);
      if (mounted) Navigator.of(context).pop(topic);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat topik: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topicsAsync = ref.watch(topicsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pilih Topik Belajar',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Topik wajib dipilih sebelum memulai sesi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),

          // Daftar topik
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: topicsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Gagal memuat topik: $e'),
              ),
              data: (topics) {
                if (topics.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Belum ada topik. Buat topik baru di bawah.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: topics.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final topic = topics[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _parseColor(topic.colorHex)
                            .withValues(alpha: 0.18),
                        child: Icon(Icons.book_outlined,
                            color: _parseColor(topic.colorHex)),
                      ),
                      title: Text(topic.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(topic),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Buat topik baru
          if (_showCreateField) ...[
            TextField(
              controller: _newTopicCtrl,
              autofocus: true,
              enabled: !_creating,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nama topik baru',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _createTopic(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _creating ? null : _createTopic,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Simpan & Pilih'),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: () => setState(() => _showCreateField = true),
              icon: const Icon(Icons.add),
              label: const Text('Buat topik baru'),
            ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF4A90D9;
    return Color(value);
  }
}
