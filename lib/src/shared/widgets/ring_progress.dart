import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// Circular gradient progress ring inspired by CleanMyMac's hero gauge.
///
/// Pass [value] in `0..1` for a determinate ring; pass `null` for an
/// indeterminate sweeping arc. Plays nicely on top of dark hero panels.
class RingProgress extends StatefulWidget {
  const RingProgress({
    super.key,
    this.value,
    required this.size,
    required this.gradientColors,
    required this.trackColor,
    this.strokeWidth = 12,
    this.center,
  });

  final double? value;
  final double size;
  final List<Color> gradientColors;
  final Color trackColor;
  final double strokeWidth;
  final Widget? center;

  @override
  State<RingProgress> createState() => _RingProgressState();
}

class _RingProgressState extends State<RingProgress>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _morph;

  // Animated value transition state — kept on `this` so we don't re-attach
  // a fresh listener (and leak it!) every time the parent rebuilds with a
  // new `value`.
  double _displayedValue = 0;
  double _morphFrom = 0;
  double _morphTo = 0;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_onMorphTick);

    _displayedValue = widget.value ?? 0;
    _morphFrom = _displayedValue;
    _morphTo = _displayedValue;

    // Spin only when there's no determinate value (otherwise the ring just
    // burns CPU/GPU at 60 Hz redrawing the same arc).
    if (widget.value == null) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant RingProgress oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool wasIndeterminate = oldWidget.value == null;
    final bool nowIndeterminate = widget.value == null;
    if (wasIndeterminate != nowIndeterminate) {
      if (nowIndeterminate) {
        if (!_spin.isAnimating) _spin.repeat();
      } else {
        _spin.stop();
      }
    }

    final double? next = widget.value;
    if (next != null && next != _morphTo) {
      _morphFrom = _displayedValue;
      _morphTo = next;
      _morph
        ..stop()
        ..reset()
        ..forward();
    }
  }

  void _onMorphTick() {
    if (!mounted) return;
    setState(() {
      _displayedValue = _morphFrom +
          (_morphTo - _morphFrom) * Curves.easeOut.transform(_morph.value);
    });
  }

  @override
  void dispose() {
    _morph.removeListener(_onMorphTick);
    _spin.dispose();
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (BuildContext _, Widget? child) {
          return CustomPaint(
            painter: _RingPainter(
              value: widget.value == null ? null : _displayedValue,
              spin: _spin.value,
              gradient: widget.gradientColors,
              trackColor: widget.trackColor,
              strokeWidth: widget.strokeWidth,
            ),
            child: Center(child: widget.center),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.spin,
    required this.gradient,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double? value;
  final double spin;
  final List<Color> gradient;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: <Color>[...gradient, gradient.first],
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(-math.pi / 2 + spin * math.pi * 2),
      ).createShader(rect);

    if (value != null) {
      final double v = value!.clamp(0.0, 1.0);
      // Always start the arc at 12 o'clock for visual consistency.
      const double start = -math.pi / 2;
      canvas.drawArc(rect, start, math.pi * 2 * v, false, arc);
    } else {
      // Indeterminate sweep — a 70-degree leading edge orbits the ring.
      const double sweep = math.pi * 0.6;
      final double start = -math.pi / 2 + spin * math.pi * 2;
      canvas.drawArc(rect, start, sweep, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.spin != spin ||
        oldDelegate.gradient != gradient;
  }
}

/// Slim linear progress bar with a gradient fill — used inline on queue rows
/// and other compact surfaces.
class LineProgress extends StatelessWidget {
  const LineProgress({
    super.key,
    this.value,
    required this.gradientColors,
    required this.trackColor,
    this.height = 6,
  });

  final double? value;
  final List<Color> gradientColors;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: trackColor),
            if (value != null)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value!.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                  ),
                ),
              )
            else
              const _IndeterminateLine(),
          ],
        ),
      ),
    );
  }
}

class _IndeterminateLine extends StatefulWidget {
  const _IndeterminateLine();

  @override
  State<_IndeterminateLine> createState() => _IndeterminateLineState();
}

class _IndeterminateLineState extends State<_IndeterminateLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return AnimatedBuilder(
          animation: _c,
          builder: (BuildContext _, Widget? child) {
            final double width = box.maxWidth * 0.35;
            final double t = _c.value;
            final double x = -width + (box.maxWidth + width) * t;
            return Stack(
              children: <Widget>[
                Positioned(
                  left: x,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: width,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Color(0x00FFFFFF),
                          Color(0xFFFFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
