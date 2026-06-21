import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../timer/models/timer_enums.dart';
import '../../timer/providers/session_repository.dart';
import '../../timer/providers/timer_controller.dart';
import '../../timer/providers/timer_state.dart';

/// Placeholder Jurnal Mood (Fase 2).
///
/// Minimal 1 input (rating mood 1-5) yang disimpan ke `mood_journals`
/// dengan relasi ke session_id yang baru dibuat. Detail multi-parameter +
/// catatan lengkap dikerjakan di Fase 3.
///
/// Wajib dilewati: user tidak bisa kembali ke Home tanpa menyimpan.
class MoodJournalScreen extends ConsumerStatefulWidget {
  const MoodJournalScreen({super.key, required this.request});

  final MoodNavRequest request;

  @override
  ConsumerState<MoodJournalScreen> createState() => _MoodJournalScreenState();
}

class _MoodJournalScreenState extends ConsumerState<MoodJournalScreen> {
  int? _rating;
  bool _saving = false;

  static const _faces = [
    (1, Icons.sentiment_very_dissatisfied, 'Buruk'),
    (2, Icons.sentiment_dissatisfied, 'Kurang'),
    (3, Icons.sentiment_neutral, 'Biasa'),
    (4, Icons.sentiment_satisfied, 'Baik'),
    (5, Icons.sentiment_very_satisfied, 'Bagus'),
  ];

  Future<void> _save() async {
    final rating = _rating;
    if (rating == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(sessionRepositoryProvider).insertMoodJournal(
            sessionId: widget.request.sessionId,
            score: rating,
          );
      if (!mounted) return;
      await _proceed();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan mood: $e')),
      );
    }
  }

  /// Setelah mood tersimpan: tawarkan istirahat (jika pomodoro completed)
  /// atau langsung kembali ke Home.
  Future<void> _proceed() async {
    if (widget.request.allowBreak) {
      final breakMinutes = ref.read(timerControllerProvider).breakMinutes;
      final startBreak = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.coffee_outlined, size: 36),
          title: const Text('Waktunya istirahat?'),
          content: Text('Ambil jeda $breakMinutes menit sebelum sesi berikutnya.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Lewati'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mulai Istirahat'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (startBreak == true) {
        await ref.read(timerControllerProvider.notifier).startBreak();
        if (mounted) context.go(AppRoutes.timerRun);
        return;
      }
    }
    ref.read(timerControllerProvider.notifier).reset();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;
    final statusLabel = req.status == SessionStatus.completed
        ? 'Sesi selesai penuh 🎉'
        : 'Sesi dihentikan lebih awal';

    return PopScope(
      // Wajib: tidak bisa keluar tanpa mengisi & menyimpan.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jurnal Mood'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 8),
              Icon(Icons.favorite_outline,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Bagaimana perasaanmu setelah belajar\n"${req.topicName}"?',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                statusLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 36),

              // Rating wajah 1-5
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _faces.map((f) {
                  final (value, icon, label) = f;
                  final selected = _rating == value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () => setState(() => _rating = value),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.18)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 36,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),
              FilledButton(
                onPressed: (_rating == null || _saving) ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan & Lanjut',
                        style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              Text(
                'Jurnal lengkap (fokus, kelelahan, motivasi) hadir di tahap berikutnya.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
