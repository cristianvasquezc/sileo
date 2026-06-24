import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'options.dart';

/// Hand-drawn stroke icons as zero-dependency [CustomPaint]s. Each is authored
/// in a 24×24 viewBox with `strokeWidth: 2` and round caps/joins, then scaled to
/// the render size.

/// Returns the default badge icon for [state] at [color]. The `loading` state
/// returns a spinning loader.
Widget sileoStateIcon(SileoState state, {required Color color, double size = 16}) {
  if (state == SileoState.loading) {
    return _SileoSpinner(color: color, size: size);
  }
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _IconPainter(state, color)),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind, this.color);

  final SileoState kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case SileoState.success:
        // M20 6 9 17l-5-5
        canvas.drawPath(
          Path()
            ..moveTo(20, 6)
            ..lineTo(9, 17)
            ..lineTo(4, 12),
          p,
        );
      case SileoState.error:
        // M18 6 6 18 / m6 6 12 12
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), p);
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), p);
      case SileoState.warning:
        // circle r10 + vertical line + dot
        canvas.drawCircle(const Offset(12, 12), 10, p);
        canvas.drawLine(const Offset(12, 8), const Offset(12, 12), p);
        canvas.drawLine(const Offset(12, 16), const Offset(12.01, 16), p);
      case SileoState.info:
        // life buoy: two circles + four spokes
        canvas.drawCircle(const Offset(12, 12), 10, p);
        canvas.drawCircle(const Offset(12, 12), 4, p);
        canvas.drawLine(const Offset(4.93, 4.93), const Offset(9.17, 9.17), p);
        canvas.drawLine(const Offset(14.83, 9.17), const Offset(19.07, 4.93), p);
        canvas.drawLine(
            const Offset(14.83, 14.83), const Offset(19.07, 19.07), p);
        canvas.drawLine(const Offset(9.17, 14.83), const Offset(4.93, 19.07), p);
      case SileoState.action:
        // M5 12h14 / m12 5 7 7-7 7
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), p);
        canvas.drawPath(
          Path()
            ..moveTo(12, 5)
            ..lineTo(19, 12)
            ..lineTo(12, 19),
          p,
        );
      case SileoState.loading:
        // M21 12a9 9 0 1 1-6.219-8.56  (≈288° arc, the missing 72° is the gap)
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 9),
          0,
          math.pi * 2 * (288 / 360),
          false,
          p,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.kind != kind || old.color != color;
}

/// The `loading` badge: a partial-ring arc spinning 1s linear, forever.
class _SileoSpinner extends StatefulWidget {
  const _SileoSpinner({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_SileoSpinner> createState() => _SileoSpinnerState();
}

class _SileoSpinnerState extends State<_SileoSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour reduced-motion: hold the spinner still instead of spinning.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _IconPainter(SileoState.loading, widget.color),
        ),
      ),
    );
  }
}
