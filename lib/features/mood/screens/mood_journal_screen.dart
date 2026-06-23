import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../timer/models/timer_enums.dart';
import '../../timer/providers/session_repository.dart';
import '../../timer/providers/timer_controller.dart';
import '../../timer/providers/timer_state.dart';
import '../models/mood_parameter.dart';
import '../providers/mood_provider.dart';

/// Jurnal Mood lengkap (Fase 3).
///
/// 4 parameter (mood_umum, fokus, kelelahan, motivasi) wajib diisi 1-5,
/// plus catatan teks opsional. Disimpan 1 baris per parameter ke
/// `mood_journals`. Setelah submit, tampilkan ringkasan sesi + pesan
/// motivasional, lalu tawarkan istirahat (pomodoro) atau kembali ke Home.
///
/// Wajib dilewati: user tidak bisa kembali ke Home tanpa menyimpan.
class MoodJournalScreen extends ConsumerStatefulWidget {
  const MoodJournalScreen({super.key, required this.request});

  final MoodNavRequest request;

  @override
  ConsumerState<MoodJournalScreen> createState() => _MoodJournalScreenState();
}

class _MoodJournalScreenState extends ConsumerState<MoodJournalScreen> {
  final Map<String, int> _scores = {};
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  bool _showSummary = false;

  // Disimpan untuk ringkasan setelah submit.
  List<MoodParameter> _savedParams = const [];
  double _avgScore = 0;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _allFilled(List<MoodParameter> params) =>
      params.isNotEmpty && params.every((p) => _scores.containsKey(p.id));

  Future<void> _save(List<MoodParameter> params) async {
    if (!_allFilled(params) || _saving) return;
    setState(() => _saving = true);

    // Catatan hanya ditempel ke parameter 'mood_umum' agar tidak duplikat.
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    String? moodUmumId;
    for (final p in params) {
      if (p.name == 'mood_umum') moodUmumId = p.id;
    }

    final entries = params
        .map((p) => MoodEntry(
              parameterId: p.id,
              score: _scores[p.id]!,
              note: p.id == moodUmumId ? note : null,
            ))
        .toList();

    try {
      await ref.read(sessionRepositoryProvider).insertMoodJournals(
            sessionId: widget.request.sessionId,
            entries: entries,
          );
      if (!mounted) return;
      final total = params.fold<int>(0, (sum, p) => sum + _scores[p.id]!);
      setState(() {
        _savedParams = params;
        _avgScore = total / params.length;
        _showSummary = true;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan mood: $e')),
      );
    }
  }

  /// Setelah ringkasan: tawarkan istirahat (jika pomodoro completed)
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
          content:
              Text('Ambil jeda $breakMinutes menit sebelum sesi berikutnya.'),
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
    return PopScope(
      // Wajib: tidak bisa keluar tanpa menyelesaikan alur.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_showSummary ? 'Ringkasan Sesi' : 'Jurnal Mood'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: _showSummary ? _buildSummary() : _buildForm(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form
  // ---------------------------------------------------------------------------

  Widget _buildForm() {
    final theme = Theme.of(context);
    final req = widget.request;
    final statusLabel = req.status == SessionStatus.completed
        ? 'Sesi selesai penuh 🎉'
        : 'Sesi dihentikan lebih awal';

    final async = ref.watch(moodParametersProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Gagal memuat parameter mood.\n$e',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
      data: (params) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 4),
          Icon(Icons.favorite_outline, size: 44, color: theme.colorScheme.secondary),
          const SizedBox(height: 14),
          Text(
            'Bagaimana sesi belajar "${req.topicName}"?',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            statusLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),

          for (final p in params) ...[
            _ParameterCard(
              parameter: p,
              value: _scores[p.id],
              onSelected: _saving
                  ? null
                  : (v) => setState(() => _scores[p.id] = v),
            ),
            const SizedBox(height: 16),
          ],

          // Catatan opsional
          TextField(
            controller: _noteCtrl,
            enabled: !_saving,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Apa yang membuat sesi ini terasa begitu?',
              alignLabelWithHint: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),

          FilledButton(
            onPressed:
                (!_allFilled(params) || _saving) ? null : () => _save(params),
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
                : const Text('Simpan', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          if (!_allFilled(params))
            Text(
              'Isi keempat parameter untuk melanjutkan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ringkasan setelah submit
  // ---------------------------------------------------------------------------

  String get _motivational {
    if (_avgScore >= 4.5) return 'Luar biasa! Sesi yang sangat produktif. 🌟';
    if (_avgScore >= 3.5) return 'Kerja bagus! Pertahankan ritme ini. 💪';
    if (_avgScore >= 2.5) return 'Lumayan — setiap langkah kecil tetap berarti. 🙂';
    return 'Tidak apa-apa. Istirahat yang cukup, besok lebih baik. 🌱';
  }

  Widget _buildSummary() {
    final theme = Theme.of(context);
    final req = widget.request;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        Icon(Icons.celebration_outlined,
            size: 56, color: theme.colorScheme.secondary),
        const SizedBox(height: 16),
        Text(
          _motivational,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        // Kartu ringkasan sesi
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _summaryRow(Icons.book_outlined, 'Topik', req.topicName),
              const Divider(height: 22),
              _summaryRow(
                Icons.timer_outlined,
                'Durasi',
                DurationFormatter.fromSeconds(req.durationSeconds),
              ),
              const Divider(height: 22),
              _summaryRow(
                req.mode == TimerMode.pomodoro
                    ? Icons.timelapse
                    : Icons.timer_outlined,
                'Mode',
                req.mode.label,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('Mood kamu', style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 10),
        ..._savedParams.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(p.displayLabel)),
                  _ScoreDots(score: _scores[p.id] ?? 0),
                ],
              ),
            )),
        const SizedBox(height: 28),

        FilledButton(
          onPressed: _proceed,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(
            widget.request.allowBreak ? 'Lanjut' : 'Kembali ke Home',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.secondary),
        const SizedBox(width: 12),
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            )),
        const Spacer(),
        Text(value,
            style:
                theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Satu kartu parameter mood dengan baris 5 wajah.
class _ParameterCard extends StatelessWidget {
  const _ParameterCard({
    required this.parameter,
    required this.value,
    required this.onSelected,
  });

  final MoodParameter parameter;
  final int? value;
  final ValueChanged<int>? onSelected;

  static const _faces = [
    (1, Icons.sentiment_very_dissatisfied, 'Buruk'),
    (2, Icons.sentiment_dissatisfied, 'Kurang'),
    (3, Icons.sentiment_neutral, 'Biasa'),
    (4, Icons.sentiment_satisfied, 'Baik'),
    (5, Icons.sentiment_very_satisfied, 'Bagus'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value == null
              ? theme.colorScheme.outline.withValues(alpha: 0.3)
              : theme.colorScheme.secondary.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parameter.displayLabel,
              style:
                  theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (parameter.description != null) ...[
            const SizedBox(height: 2),
            Text(
              parameter.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _faces.map((f) {
              final (val, icon, label) = f;
              final selected = value == val;
              return Expanded(
                child: GestureDetector(
                  onTap: onSelected == null ? null : () => onSelected!(val),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 30,
                          color: selected
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selected
                              ? theme.colorScheme.secondary
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
        ],
      ),
    );
  }
}

/// Lima titik untuk merepresentasikan skor 1-5 di ringkasan.
class _ScoreDots extends StatelessWidget {
  const _ScoreDots({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < score;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            filled ? Icons.circle : Icons.circle_outlined,
            size: 12,
            color: filled
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}
