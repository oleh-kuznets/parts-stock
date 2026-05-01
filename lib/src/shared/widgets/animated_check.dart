import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

/// CleanMyMac-style animated success mark.
///
/// Draws a checkmark stroke-by-stroke on top of a soft expanding glow ring,
/// with a tiny spring overshoot when the icon settles. Designed for the
/// "done" state of the convert hero ring.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    this.size = 64,
    this.color = CupertinoColors.white,
    this.strokeWidth = 6,
    this.duration = const Duration(milliseconds: 850),
    this.showGlow = true,
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Duration duration;
  final bool showGlow;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with TickerProviderStateMixin {
  late final AnimationController _draw;
  late final AnimationController _pulse;

  late final Animation<double> _scale;
  late final Animation<double> _stroke;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _draw = AnimationController(vsync: this, duration: widget.duration);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Quick scale-up with a small overshoot, then settle.
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.45, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_draw);

    // Stroke starts a hair after the scale lands so the path looks "drawn".
    _stroke = CurvedAnimation(
      parent: _draw,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOutCubic),
    );

    // Glow ring blooms during the first half, then fades.
    _glow = CurvedAnimation(
      parent: _draw,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuad),
    );

    _draw.forward();
    if (widget.showGlow) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double box = widget.size * 1.7;
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (widget.showGlow)
            AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_pulse, _glow]),
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  size: Size.square(box),
                  painter: _GlowPainter(
                    color: widget.color,
                    progress: _glow.value,
                    pulse: _pulse.value,
                    radius: widget.size * 0.55,
                  ),
                );
              },
            ),
          AnimatedBuilder(
            animation: _draw,
            builder: (BuildContext context, Widget? child) {
              return Transform.scale(
                scale: _scale.value,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _CheckPainter(
                    color: widget.color,
                    strokeWidth: widget.strokeWidth,
                    progress: _stroke.value,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Strokes a checkmark path according to [progress] (0..1).
class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.color,
    required this.strokeWidth,
    required this.progress,
  });

  final Color color;
  final double strokeWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final Path path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.80, size.height * 0.32);

    final Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final ui.PathMetrics metrics = path.computeMetrics();
    final Path drawn = Path();
    for (final ui.PathMetric metric in metrics) {
      final double end = metric.length * progress;
      drawn.addPath(metric.extractPath(0, end), Offset.zero);
    }
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Two soft rings — one bursts out as the mark lands, one slowly pulses
/// to keep the success state feeling alive.
class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.color,
    required this.progress,
    required this.pulse,
    required this.radius,
  });

  final Color color;
  final double progress;
  final double pulse;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);

    // Burst ring — expands once during entrance and fades out.
    if (progress > 0) {
      final double burstR = radius * (0.95 + 0.55 * progress);
      final double burstAlpha = (1.0 - progress) * 0.55;
      final Paint burst = Paint()
        ..color = color.withValues(alpha: burstAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(c, burstR, burst);
    }

    // Soft heartbeat halo — keeps the success state living.
    final double t = (math.sin(pulse * math.pi * 2) + 1) / 2; // 0..1
    final double haloR = radius * (1.05 + 0.06 * t);
    final double haloAlpha = 0.10 + 0.10 * t;
    final Paint halo = Paint()
      ..color = color.withValues(alpha: haloAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, haloR, halo);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.color != color ||
      old.radius != radius;
}
