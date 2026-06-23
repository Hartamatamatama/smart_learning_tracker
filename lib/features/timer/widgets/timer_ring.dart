import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Signature element "Focus Ritual": cincin progress timer dengan glow.
///
/// - Pomodoro: [progress] = fraksi SISA waktu (1 penuh → 0 habis), ring
///   menyusut seiring waktu berkurang, dianimasikan halus tiap tick.
/// - Stopwatch: [isStopwatch] = true, sebuah segmen berputar terus-menerus
///   sebagai indikator "aktif" (tidak ada target).
/// - [active] (berjalan & tidak dijeda) menyalakan efek glow di sekitar ring.
class TimerRing extends StatefulWidget {
  const TimerRing({
    super.key,
    required this.size,
    required this.color,
    required this.trackColor,
    required this.child,
    this.progress,
    this.isStopwatch = false,
    this.active = true,
  });

  final double size;
  final Color color;
  final Color trackColor;
  final Widget child;
  final double? progress; // 0..1 fraksi sisa (pomodoro)
  final bool isStopwatch;
  final bool active;

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (widget.isStopwatch && widget.active) _sweep.repeat();
  }

  @override
  void didUpdateWidget(covariant TimerRing old) {
    super.didUpdateWidget(old);
    // Putar hanya saat stopwatch aktif; berhenti saat dijeda.
    if (widget.isStopwatch && widget.active) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      if (_sweep.isAnimating) _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget ring;
    if (widget.isStopwatch) {
      ring = AnimatedBuilder(
        animation: _sweep,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(
            phase: _sweep.value,
            isStopwatch: true,
            color: widget.color,
            track: widget.trackColor,
            active: widget.active,
          ),
        ),
      );
    } else {
      ring = TweenAnimationBuilder<double>(
        tween: Tween(end: (widget.progress ?? 0).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOut,
        builder: (_, v, __) => CustomPaint(
          painter: _RingPainter(
            progress: v,
            isStopwatch: false,
            color: widget.color,
            track: widget.trackColor,
            active: widget.active,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(child: ring),
          widget.child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.isStopwatch,
    required this.color,
    required this.track,
    required this.active,
    this.progress = 0,
    this.phase = 0,
  });

  final bool isStopwatch;
  final Color color;
  final Color track;
  final bool active;
  final double progress; // pomodoro
  final double phase; // stopwatch 0..1

  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - _stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    // Track penuh
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );

    final double sweepStart;
    final double sweepAngle;
    if (isStopwatch) {
      sweepStart = start + phase * 2 * math.pi;
      sweepAngle = 0.22 * 2 * math.pi; // segmen ~22%
    } else {
      sweepStart = start;
      sweepAngle = progress * 2 * math.pi;
    }
    if (sweepAngle <= 0) return;

    // Glow (saat aktif): arc blur di bawah arc utama
    if (active) {
      canvas.drawArc(
        rect,
        sweepStart,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke + 2
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Arc utama
    canvas.drawArc(
      rect,
      sweepStart,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = active ? color : color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.active != active ||
      old.color != color;
}
