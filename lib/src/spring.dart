import 'package:flutter/animation.dart';

/// A spring-shaped easing [Curve] used for the timed transitions (entry/exit,
/// header) so they settle in lockstep with the physics-driven morph.
///
/// It is a 33-stop piecewise-linear sampling of an underdamped spring; the
/// output intentionally overshoots above `1.0` (peaking at `1.038`). Callers
/// that need a clamped value (e.g. opacity) should clamp downstream, never here.
class SileoSpringCurve extends Curve {
  const SileoSpringCurve();

  // Normalised sample times (0..1).
  static const List<double> _t = <double>[
    0.000, 0.006, 0.012, 0.018, 0.024, 0.031, 0.038, 0.053, 0.066, 0.080, //
    0.137, 0.163, 0.177, 0.191, 0.205, 0.218, 0.231, 0.245, 0.258, 0.272, //
    0.286, 0.301, 0.316, 0.331, 0.357, 0.385, 0.416, 0.450, 0.501, 0.642, //
    0.730, 0.837, 1.000,
  ];

  // Output values at each stop (may exceed 1.0 for the overshoot).
  static const List<double> _v = <double>[
    0.000, 0.002, 0.007, 0.015, 0.026, 0.041, 0.060, 0.108, 0.157, 0.214, //
    0.467, 0.577, 0.631, 0.682, 0.730, 0.771, 0.808, 0.844, 0.874, 0.903, //
    0.928, 0.952, 0.972, 0.988, 1.010, 1.025, 1.034, 1.038, 1.035, 1.012, //
    1.003, 0.999, 1.000,
  ];

  @override
  double transformInternal(double t) {
    if (t <= _t.first) return _v.first;
    if (t >= _t.last) return _v.last;

    // Binary search for the segment [lo, lo+1] that brackets t.
    var lo = 0;
    var hi = _t.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_t[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = _t[hi] - _t[lo];
    final f = span <= 0 ? 0.0 : (t - _t[lo]) / span;
    return _v[lo] + (_v[hi] - _v[lo]) * f;
  }
}

/// Shared instance of [SileoSpringCurve].
const Curve sileoSpringCurve = SileoSpringCurve();
