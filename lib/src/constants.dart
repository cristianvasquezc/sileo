import 'package:flutter/physics.dart';

/// Tuning constants for layout, timing, and rendering.
///
/// Everything here is intentionally `const`/`final` so the whole library shares
/// a single source of truth.

/* --------------------------------- Layout --------------------------------- */

/// Pill (collapsed toast) height.
const double kSileoHeight = 40;

/// Fixed toast canvas width.
const double kSileoWidth = 350;

/// Default corner radius of the pill/body. Also scales the gooey blur
/// (`blur = roundness * kSileoBlurRatio`).
const double kSileoDefaultRoundness = 16;

/// Horizontal padding inside the header (8px each side).
const double kSileoHeaderPadding = 8;

/* --------------------------------- Timing --------------------------------- */

/// Core animation duration — the perceptual spring duration and the length of
/// the entry/header transitions.
const Duration kSileoDuration = Duration(milliseconds: 600);

/// Default auto-dismiss time for a toast.
const Duration kSileoDefaultToastDuration = Duration(milliseconds: 6000);

/// How long the exit animation runs before the item is removed.
const Duration kSileoExitDuration = Duration(milliseconds: 600);

/// Autopilot expand delay, clamped to the toast's real duration in the store.
const Duration kSileoAutoExpandDelay = Duration(milliseconds: 150);

/// Autopilot collapse delay, clamped to the toast's real duration in the store.
const Duration kSileoAutoCollapseDelay = Duration(milliseconds: 4000);

/// Entry/exit transition length — drives the toast's scale, opacity, and slide
/// offset.
const Duration kSileoEntryDuration = Duration(milliseconds: 396);

/// Vertical offset (px) a toast slides from on entry / to on exit. Toasts at the
/// top slide from `-6`, at the bottom from `+6`.
const double kSileoEntryOffset = 6;

/// Header cross-fade exit length.
const Duration kSileoHeaderExit = Duration(milliseconds: 420);

/// Collapse-before-content-swap gate: how long a toast collapses before its
/// content is swapped on an in-place update.
const Duration kSileoSwapCollapse = Duration(milliseconds: 200);

/* --------------------------------- Render --------------------------------- */

/// `blur = roundness * kSileoBlurRatio` — the Gaussian blur sigma that fuses the
/// pill and body into one gooey shape.
const double kSileoBlurRatio = 0.5;

/// Extra px added to the measured header width to get the pill width.
const double kSileoPillPadding = 10;

/// Minimum expanded height = `kSileoHeight * kSileoMinExpandRatio` (= 90).
const double kSileoMinExpandRatio = 2.25;

/* --------------------------------- Swipe ---------------------------------- */

/// Drag distance (px), in the dismiss direction, past which releasing the toast
/// dismisses it. Below this, a slow release springs the toast back to rest.
const double kSileoSwipeDismiss = 36;

/// Flick speed (px/s), in the dismiss direction, past which releasing dismisses
/// the toast regardless of how far it was dragged — a quick flick throws it off.
const double kSileoSwipeVelocity = 340;

/// Distance (px) over which the toast fades from fully opaque to transparent as
/// it is dragged toward dismissal. Tuned so a drag to [kSileoSwipeDismiss] only
/// dims it slightly, while a fling carries it past this and fully out.
const double kSileoSwipeFadeDistance = 180;

/// Soft asymptote (px) for dragging *against* the dismiss direction: the toast
/// rubber-bands toward this limit instead of following the finger, so it never
/// dismisses the wrong way and there is no hard wall.
const double kSileoSwipeResist = 24;

/* -------------------------------- Springs --------------------------------- */

/// The morph geometry (pill x/width/height, body height/opacity) uses an
/// underdamped spring: a lively settle with a little overshoot (stiffness
/// ≈ 244.29, damping ratio 0.75).
///
/// Built with [SpringDescription.withDampingRatio] rather than
/// `withDurationAndBounce`, whose perceptual-duration mapping is noticeably
/// softer for the same numbers.
final SpringDescription kSileoSpringOpen = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 244.291,
  ratio: 0.75,
);

/// Body collapse is critically damped (ratio 1.0) so it settles closed without
/// any overshoot.
final SpringDescription kSileoSpringClose = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 236.822,
  ratio: 1.0,
);

/// Drives the swipe offset both ways: the snap-back when a drag is released
/// below threshold (a lively, barely-overshooting settle to rest) and the
/// throw-off when a swipe dismisses (the same spring pulling toward a far
/// off-screen target, carrying the release velocity). Slightly under-damped so
/// the snap-back feels rubbery rather than mechanical.
final SpringDescription kSileoSpringSwipe = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 260,
  ratio: 0.82,
);
