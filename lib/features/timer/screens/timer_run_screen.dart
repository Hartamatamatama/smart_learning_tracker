import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../ambient_sound/models/ambient_sound.dart';
import '../../ambient_sound/providers/ambient_player_controller.dart';
import '../models/timer_enums.dart';
import '../providers/timer_controller.dart';
import '../providers/timer_state.dart';
import '../widgets/timer_ring.dart';

class TimerRunScreen extends ConsumerStatefulWidget {
  const TimerRunScreen({super.key});

  @override
  ConsumerState<TimerRunScreen> createState() => _TimerRunScreenState();
}

class _TimerRunScreenState extends ConsumerState<TimerRunScreen>
    with WidgetsBindingObserver {
  bool _handlingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sinkronkan UI dengan waktu nyata begitu app kembali ke depan.
      ref.read(timerControllerProvider.notifier).reconcile();
    }
  }

  void _onStateChanged(TimerState? prev, TimerState next) {
    // 1) Wajib ke Jurnal Mood setelah sesi (fokus/stopwatch) berakhir.
    final nav = next.moodNav;
    if (nav != null) {
      ref.read(timerControllerProvider.notifier).consumeMoodNav();
      context.go(AppRoutes.moodJournal, extra: nav);
      return;
    }

    // 2) Istirahat selesai → tawarkan siklus baru atau selesai.
    if (next.breakFinished && !_handlingDialog) {
      _handlingDialog = true;
      _showBreakDoneDialog();
      return;
    }

    // 3) Sesi berakhir tapi gagal disimpan (mis. migrasi DB belum dijalankan).
    if (next.status == TimerRunStatus.finished &&
        next.errorMessage != null &&
        !next.breakFinished &&
        !_handlingDialog) {
      _handlingDialog = true;
      _showErrorDialog(next.errorMessage!);
    }
  }

  Future<void> _showBreakDoneDialog() async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, size: 40),
        title: const Text('Istirahat selesai'),
        content: const Text('Mau lanjut sesi baru atau sudahi dulu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('done'),
            child: const Text('Selesai'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('new'),
            child: const Text('Sesi Baru'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ref.read(timerControllerProvider.notifier).acknowledgeBreakFinished();
    if (choice == 'new') {
      context.go(AppRoutes.timerSetup);
    } else {
      ref.read(timerControllerProvider.notifier).reset();
      context.go(AppRoutes.home);
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.error_outline, size: 40),
        title: const Text('Gagal menyimpan sesi'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kembali ke Home'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ref.read(timerControllerProvider.notifier).reset();
    context.go(AppRoutes.home);
  }

  Future<void> _confirmStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hentikan sesi?'),
        content: const Text(
            'Sesi akan diakhiri dan kamu diarahkan ke jurnal mood.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hentikan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(timerControllerProvider.notifier).stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TimerState>(timerControllerProvider, _onStateChanged);

    final theme = Theme.of(context);
    final state = ref.watch(timerControllerProvider);
    final isBreak = state.phase == TimerPhase.breakTime;
    final isStopwatch = state.mode == TimerMode.stopwatch;

    final displaySeconds = isStopwatch
        ? state.elapsedSeconds
        : (state.remainingSeconds ?? 0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.status == TimerRunStatus.running) {
          _confirmStop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                // Label fase + topik
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isBreak
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.primary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isBreak ? '☕ Istirahat' : '🎯 Fokus',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isBreak
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.topic?.name ?? 'Belajar',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Signature: cincin timer dengan glow
                TimerRing(
                  size: 272,
                  color: isBreak
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                  trackColor:
                      theme.colorScheme.outline.withValues(alpha: 0.6),
                  // Pomodoro: fraksi SISA (ring menyusut saat waktu berkurang).
                  progress: isStopwatch ? null : (1 - state.progress),
                  isStopwatch: isStopwatch,
                  active: state.status == TimerRunStatus.running &&
                      !state.isPaused,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DurationFormatter.fromSeconds(displaySeconds),
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.isPaused
                            ? 'DIJEDA'
                            : (isStopwatch ? 'BERJALAN' : 'TERSISA'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: state.isPaused
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Kontrol ambient sound (opsional, hanya fase fokus).
                if (state.ambientSound != null &&
                    state.phase == TimerPhase.focus)
                  _AmbientControls(sound: state.ambientSound!),

                const Spacer(),

                // Tombol kontrol
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.isPaused)
                      _ControlButton(
                        icon: Icons.play_arrow,
                        label: 'Lanjut',
                        color: theme.colorScheme.primary,
                        onTap: () =>
                            ref.read(timerControllerProvider.notifier).resume(),
                      )
                    else
                      _ControlButton(
                        icon: Icons.pause,
                        label: 'Jeda',
                        color: theme.colorScheme.onSurfaceVariant,
                        onTap: () =>
                            ref.read(timerControllerProvider.notifier).pause(),
                      ),
                    const SizedBox(width: 28),
                    _ControlButton(
                      icon: Icons.stop,
                      label: 'Stop',
                      color: theme.colorScheme.error,
                      onTap: _confirmStop,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Timer tetap berjalan walau layar dikunci atau pindah aplikasi.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withValues(alpha: 0.15),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: color, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// Kontrol ambient sound terpisah dari timer: play/pause & mute.
/// Mengubah ini TIDAK memengaruhi jalannya timer.
class _AmbientControls extends ConsumerWidget {
  const _AmbientControls({required this.sound});

  final AmbientSound sound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final player = ref.watch(ambientPlayerControllerProvider);
    final notifier = ref.read(ambientPlayerControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              sound.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: player.isPlaying ? 'Jeda suara' : 'Putar suara',
            icon: Icon(player.isPlaying
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline),
            color: theme.colorScheme.primary,
            onPressed: notifier.togglePlayPause,
          ),
          IconButton(
            tooltip: player.isMuted ? 'Bunyikan' : 'Bisukan',
            icon: Icon(player.isMuted
                ? Icons.volume_off_outlined
                : Icons.volume_up_outlined),
            color: player.isMuted
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface,
            onPressed: notifier.toggleMute,
          ),
        ],
      ),
    );
  }
}
