import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode_provider.dart';
import '../models/reminder_time.dart';
import '../providers/reminder_provider.dart';

/// Layar Pengaturan: tema + Pengingat Belajar (jadwal notifikasi harian).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final reminders = ref.watch(reminderControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Tampilan'),
          SwitchListTile(
            secondary: Icon(isDark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined),
            title: const Text('Mode gelap'),
            subtitle: const Text('Konsep "Focus Ritual" mengutamakan gelap'),
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const Divider(height: 24),

          _SectionHeader('Pengingat Belajar'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Atur jam pengingat untuk mulai belajar. Pengingat hari ini '
              'otomatis dibatalkan setelah kamu menyelesaikan satu sesi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          reminders.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Gagal memuat pengingat: $e',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
            data: (times) => _ReminderList(times: times),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: OutlinedButton.icon(
              onPressed: () => _addReminder(context, ref),
              icon: const Icon(Icons.add_alarm_outlined),
              label: const Text('Tambah waktu pengingat'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addReminder(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      helpText: 'Pilih jam pengingat',
    );
    if (picked == null) return;
    await ref
        .read(reminderControllerProvider.notifier)
        .addTime(ReminderTime.fromTimeOfDay(picked));
  }
}

class _ReminderList extends ConsumerWidget {
  const _ReminderList({required this.times});
  final List<ReminderTime> times;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (times.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Text('Belum ada pengingat.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      );
    }
    return Column(
      children: [
        for (final t in times)
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(
              t.label(context),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
              onPressed: () =>
                  ref.read(reminderControllerProvider.notifier).removeTime(t),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
