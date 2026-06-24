import 'package:flutter/widgets.dart';

import 'constants.dart';

/// The intent of a toast. Drives its colour and default icon.
enum SileoState { success, loading, error, warning, info, action }

/// Where a toast is anchored on screen.
enum SileoPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  /// True for the three `top*` positions.
  bool get isTop =>
      this == topLeft || this == topCenter || this == topRight;

  /// True for the three `bottom*` positions.
  bool get isBottom => !isTop;

  /// Toasts at the top expand downward; toasts at the bottom expand upward.
  bool get expandsUp => isBottom;

  /// Horizontal alignment of the pill within the 350px canvas.
  Alignment get horizontalAlignment {
    switch (this) {
      case topLeft:
      case bottomLeft:
        return Alignment.centerLeft;
      case topCenter:
      case bottomCenter:
        return Alignment.center;
      case topRight:
      case bottomRight:
        return Alignment.centerRight;
    }
  }
}

/// Built-in theming for [Toaster]. `system` follows the platform brightness.
enum SileoTheme { light, dark, system }

/// Per-toast style overrides for the title, description, badge, and button.
@immutable
class SileoStyles {
  const SileoStyles({
    this.title,
    this.description,
    this.badgeColor,
    this.buttonColor,
  });

  /// Overrides for the title text style (merged over the default).
  final TextStyle? title;

  /// Overrides for the description text style (merged over the default).
  final TextStyle? description;

  /// Overrides the badge tint (icon + background) colour.
  final Color? badgeColor;

  /// Overrides the action button tint colour.
  final Color? buttonColor;

  SileoStyles merge(SileoStyles? other) {
    if (other == null) return this;
    return SileoStyles(
      title: title?.merge(other.title) ?? other.title,
      description:
          description?.merge(other.description) ?? other.description,
      badgeColor: other.badgeColor ?? badgeColor,
      buttonColor: other.buttonColor ?? buttonColor,
    );
  }
}

/// An action button shown in the expanded body of a toast.
@immutable
class SileoButton {
  const SileoButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;
}

/// Controls the auto expand/collapse ("autopilot") behaviour:
/// * pass `null` (the default) for autopilot with default delays,
/// * [SileoAutopilot.disabled] to turn it off,
/// * `SileoAutopilot(expand: ..., collapse: ...)` to override either delay.
@immutable
class SileoAutopilot {
  const SileoAutopilot({this.expand, this.collapse}) : enabled = true;

  const SileoAutopilot.disabled()
      : enabled = false,
        expand = null,
        collapse = null;

  final bool enabled;

  /// Delay before the toast auto-expands. Defaults to [kSileoAutoExpandDelay].
  final Duration? expand;

  /// Delay before the toast auto-collapses. Defaults to [kSileoAutoCollapseDelay].
  final Duration? collapse;
}

/// Options accepted by every `sileo.*` method.
///
/// * `title`/`description` are plain strings,
/// * `duration` is a [Duration] (omit for the 6s default, pass [Duration.zero]
///   to persist),
/// * `fill` is a [Color], `icon` is a [Widget].
@immutable
class SileoOptions {
  const SileoOptions({
    this.id,
    this.title,
    this.description,
    this.type,
    this.position,
    this.duration,
    this.icon,
    this.styles,
    this.fill,
    this.roundness,
    this.autopilot,
    this.button,
  });

  /// Optional explicit id. All toasts that share an id replace/morph into each
  /// other. Omit it and every `sileo.*` call drives a single default
  /// notification that morphs in place.
  final String? id;

  /// The pill label. Defaults to the (capitalised) state name.
  final String? title;

  /// Body text shown when the toast is expanded. Its presence makes the toast
  /// expandable.
  final String? description;

  /// Only read by [SileoController.show] to choose the intent.
  final SileoState? type;

  /// Which corner the toast appears in. Defaults to the [Toaster]'s position.
  final SileoPosition? position;

  /// Auto-dismiss time. Omit for the 6-second default; pass [Duration.zero]
  /// (or any non-positive duration) to keep the toast until dismissed.
  final Duration? duration;

  /// Overrides the badge icon. `null` falls back to the state's default icon.
  final Widget? icon;

  /// Style overrides.
  final SileoStyles? styles;

  /// The pill/body fill colour. Defaults to white, or the theme fill.
  final Color? fill;

  /// Corner radius. Defaults to [kSileoDefaultRoundness].
  final double? roundness;

  /// Auto expand/collapse behaviour. See [SileoAutopilot].
  final SileoAutopilot? autopilot;

  /// An action button in the expanded body.
  final SileoButton? button;

  /// Returns a copy with the given fields replaced. (Used internally; only
  /// overrides non-null arguments, so it cannot clear a field back to null.)
  SileoOptions copyWith({
    String? id,
    String? title,
    String? description,
    SileoState? type,
    SileoPosition? position,
    Duration? duration,
    Widget? icon,
    SileoStyles? styles,
    Color? fill,
    double? roundness,
    SileoAutopilot? autopilot,
    SileoButton? button,
  }) {
    return SileoOptions(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      icon: icon ?? this.icon,
      styles: styles ?? this.styles,
      fill: fill ?? this.fill,
      roundness: roundness ?? this.roundness,
      autopilot: autopilot ?? this.autopilot,
      button: button ?? this.button,
    );
  }
}

/// Options for [SileoController.future].
///
/// Dart has no value-or-builder union, so the success/error/action branches are
/// always builders. Pass `(_) => SileoOptions(...)` for a static result.
@immutable
class SileoFutureOptions<T> {
  const SileoFutureOptions({
    required this.loading,
    required this.success,
    required this.error,
    this.action,
    this.position,
  });

  /// Shown immediately, as a non-expiring `loading` toast.
  final SileoOptions loading;

  /// Built when the future resolves (unless [action] is provided).
  final SileoOptions Function(T value) success;

  /// Built when the future rejects.
  final SileoOptions Function(Object error) error;

  /// If provided, a resolved future routes to an `action` toast instead of
  /// `success`.
  final SileoOptions Function(T value)? action;

  /// Overrides the position for the whole sequence.
  final SileoPosition? position;
}
