import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Paints the liquid "paper" — the pill and (optional) body fused into one
/// gooey shape.
///
/// The two rounded rects are blurred together so their edges smear, then a
/// steep alpha-threshold matrix snaps that smear back to a crisp, fused contour
/// with a rounded neck where they meet. Only the coloured paper is rendered
/// here; text and icons are stacked above by [SileoToast].
class SileoGooeyPainter extends CustomPainter {
  const SileoGooeyPainter({
    required this.pill,
    required this.body,
    required this.radius,
    required this.blur,
    required this.fill,
  });

  /// Pill rect (the collapsed-toast shape), in local paint coordinates.
  final Rect pill;

  /// Body rect (the expanded panel). A zero/near-zero height means "no body".
  final Rect body;

  /// Corner radius for both rects.
  final double radius;

  /// Gaussian blur sigma (`roundness * 0.5`). When ~0, the gooey pass is skipped.
  final double blur;

  /// The paper fill colour.
  final Color fill;

  /// Alpha-threshold matrix. RGB pass through unchanged; alpha becomes
  /// `A' = 20·A − 10` (in 0..1), i.e. `20·A − 2550` in dart:ui's 0..255 space —
  /// a steep ramp centred at 0.5 that re-crisps the blurred edges.
  static const List<double> _threshold = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 20, -2550, //
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final fillPaint = Paint()
      ..color = fill
      ..isAntiAlias = true;

    final hasBody = body.height > 0.5;

    // No meaningful blur (roundness ~0): draw the rects directly, crisp.
    if (blur < 0.5) {
      canvas.drawRRect(RRect.fromRectAndRadius(pill, r), fillPaint);
      if (hasBody) {
        canvas.drawRRect(RRect.fromRectAndRadius(body, r), fillPaint);
      }
      return;
    }

    // Give the blur room beyond the canvas so top/bottom edges blur
    // symmetrically; the threshold then crops the halo back to the true edges.
    final pad = blur * 3 + 2;
    final bounds = (Offset.zero & size).inflate(pad);

    // Outer layer: alpha threshold. Inner layer: Gaussian blur. Contents: the
    // two opaque rounded rects. (blur first, then threshold.)
    canvas.saveLayer(
      bounds,
      Paint()..colorFilter = const ColorFilter.matrix(_threshold),
    );
    canvas.saveLayer(
      bounds,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
    );

    canvas.drawRRect(RRect.fromRectAndRadius(pill, r), fillPaint);
    if (hasBody) canvas.drawRRect(RRect.fromRectAndRadius(body, r), fillPaint);

    canvas.restore(); // blur
    canvas.restore(); // threshold
  }

  @override
  bool hitTest(Offset position) =>
      pill.contains(position) || (body.height > 0.5 && body.contains(position));

  @override
  bool shouldRepaint(SileoGooeyPainter old) =>
      old.pill != pill ||
      old.body != body ||
      old.radius != radius ||
      old.blur != blur ||
      old.fill != fill;
}
