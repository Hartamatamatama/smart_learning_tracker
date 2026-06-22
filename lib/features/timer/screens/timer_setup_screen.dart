import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../ambient_sound/models/ambient_sound.dart';
import '../../ambient_sound/providers/ambient_sound_provider.dart';
import '../models/timer_enums.dart';
import '../models/topic.dart';
import '../providers/timer_controller.dart';
import '../widgets/topic_picker_sheet.dart';

class TimerSetupScreen extends ConsumerStatefulWidget {
  const TimerSetupScreen({super.key});

  @override
  ConsumerState<TimerSetupScreen> createState() => _TimerSetupScreenState();
}

class _TimerSetupScreenState extends ConsumerState<TimerSetupScreen> {
  TimerMode _mode = TimerMode.pomodoro;
  Topic? _topic;
  AmbientSound? _ambient; // null = Tanpa suara
  final _focusCtrl =
      TextEditingController(text: '${AppConstants.defaultFocusMinutes}');
  final _breakCtrl =
      TextEditingController(text: '${AppConstants.defaultBreakMinutes}');

  @override
  void dispose() {
    _focusCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  int? _parseMinutes(String text) {
    final v = int.tryParse(text.trim());
    if (v == null) return null;
    if (v < AppConstants.minDurationMinutes ||
        v > AppConstants.maxDurationMinutes) {
      return null;
    }
    return v;
  }

  bool get _canStart {
    if (_topic == null) return false;
    if (_mode == TimerMode.pomodoro) {
      return _parseMinutes(_focusCtrl.text) != null &&
          _parseMinutes(_breakCtrl.text) != null;
    }
    return true;
  }

  Future<void> _pickTopic() async {
    final topic = await showTopicPickerSheet(context);
    if (topic != null) setState(() => _topic = topic);
  }

  Future<void> _start() async {
    final topic = _topic;
    if (topic == null) return;
    final focus = _parseMinutes(_focusCtrl.text) ??
        AppConstants.defaultFocusMinutes;
    final brk = _parseMinutes(_breakCtrl.text) ??
        AppConstants.defaultBreakMinutes;

    await ref.read(timerControllerProvider.notifier).startFocus(
          mode: _mode,
          topic: topic,
          focusMinutes: focus,
          breakMinutes: brk,
          ambientSound: _ambient,
        );
    if (mounted) context.go(AppRoutes.timerRun);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mulai Belajar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Mode
            Text('Mode Timer', style: _label(theme)),
            const SizedBox(height: 10),
            SegmentedButton<TimerMode>(
              segments: const [
                ButtonSegment(
                  value: TimerMode.pomodoro,
                  label: Text('Pomodoro'),
                  icon: Icon(Icons.timelapse),
                ),
                ButtonSegment(
                  value: TimerMode.stopwatch,
                  label: Text('Stopwatch'),
                  icon: Icon(Icons.timer_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _mode == TimerMode.pomodoro
                  ? 'Hitung mundur dengan target durasi & istirahat otomatis.'
                  : 'Hitung naik tanpa batas — hentikan kapan pun kamu mau.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            // Topik
            Text('Topik', style: _label(theme)),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: _topic == null
                      ? theme.colorScheme.outline.withValues(alpha: 0.4)
                      : theme.colorScheme.primary,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  _topic == null ? Icons.add_circle_outline : Icons.book,
                  color: theme.colorScheme.primary,
                ),
                title: Text(_topic?.name ?? 'Pilih topik belajar'),
                subtitle: _topic == null
                    ? const Text('Wajib dipilih')
                    : const Text('Ketuk untuk mengganti'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickTopic,
              ),
            ),
            const SizedBox(height: 24),

            // Ambient sound (opsional)
            Row(
              children: [
                Text('Suara Latar', style: _label(theme)),
                const SizedBox(width: 8),
                Text(
                  '(opsional)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AmbientPicker(
              selected: _ambient,
              onSelected: (s) => setState(() => _ambient = s),
            ),
            const SizedBox(height: 24),

            // Durasi (Pomodoro)
            if (_mode == TimerMode.pomodoro) ...[
              Text('Durasi (menit)', style: _label(theme)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MinuteField(
                      controller: _focusCtrl,
                      label: 'Fokus',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MinuteField(
                      controller: _breakCtrl,
                      label: 'Istirahat',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Rentang ${AppConstants.minDurationMinutes}–'
                '${AppConstants.maxDurationMinutes} menit.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 24),
            ],

            FilledButton.icon(
              onPressed: _canStart ? _start : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mulai Sesi', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _label(ThemeData theme) => theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      );
}

class _MinuteField extends StatelessWidget {
  const _MinuteField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Pemilih ambient sound: chip "Tanpa suara" + satu chip per sound.
class _AmbientPicker extends ConsumerWidget {
  const _AmbientPicker({required this.selected, required this.onSelected});

  final AmbientSound? selected;
  final ValueChanged<AmbientSound?> onSelected;

  IconData _iconFor(String category) => switch (category) {
        'cafe' => Icons.local_cafe_outlined,
        'white_noise' => Icons.blur_on,
        'music' => Icons.music_note_outlined,
        _ => Icons.nature_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(ambientSoundsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        'Gagal memuat daftar suara.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
      data: (sounds) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Tanpa suara'),
            avatar: const Icon(Icons.volume_off_outlined, size: 18),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final s in sounds)
            ChoiceChip(
              label: Text(s.name),
              avatar: Icon(_iconFor(s.category), size: 18),
              selected: selected?.id == s.id,
              onSelected: (_) => onSelected(s),
            ),
        ],
      ),
    );
  }
}
