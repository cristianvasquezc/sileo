import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'constants.dart';
import 'options.dart';

/// An internal, immutable snapshot of one live toast.
@immutable
class SileoItem {
  const SileoItem({
    required this.id,
    required this.instanceId,
    required this.state,
    required this.position,
    required this.roundness,
    this.title,
    this.description,
    this.icon,
    this.fill,
    this.button,
    this.styles,
    this.duration,
    this.autoExpandDelay,
    this.autoCollapseDelay,
    this.exiting = false,
  });

  /// Dedupe key. Toasts sharing an id replace/morph into each other.
  final String id;

  /// Regenerated on every create/update — drives the morph/swap animation and
  /// the auto-dismiss timer key.
  final String instanceId;

  final SileoState state;
  final SileoPosition position;
  final double roundness;
  final String? title;
  final String? description;
  final Widget? icon;
  final Color? fill;
  final SileoButton? button;
  final SileoStyles? styles;

  /// `null` means "no auto-dismiss" (the toast persists).
  final Duration? duration;
  final Duration? autoExpandDelay;
  final Duration? autoCollapseDelay;
  final bool exiting;

  SileoItem copyWith({bool? exiting}) => SileoItem(
        id: id,
        instanceId: instanceId,
        state: state,
        position: position,
        roundness: roundness,
        title: title,
        description: description,
        icon: icon,
        fill: fill,
        button: button,
        styles: styles,
        duration: duration,
        autoExpandDelay: autoExpandDelay,
        autoCollapseDelay: autoCollapseDelay,
        exiting: exiting ?? this.exiting,
      );
}

/// The global toast store — a [ChangeNotifier] singleton holding all live
/// toasts. [Toaster] subscribes to it.
class SileoStore extends ChangeNotifier {
  SileoStore._();

  /// The single shared instance.
  static final SileoStore instance = SileoStore._();

  final List<SileoItem> _toasts = <SileoItem>[];

  /// The current toasts (unmodifiable view).
  List<SileoItem> get toasts => List<SileoItem>.unmodifiable(_toasts);

  /// Defaults set by the mounted [Toaster].
  SileoPosition defaultPosition = SileoPosition.topRight;
  SileoOptions? defaultOptions;

  int _counter = 0;
  String _nextInstance() => 'sileo-i${++_counter}';

  /// A fresh unique toast id (used by `future` so concurrent futures don't
  /// clobber each other).
  String generateId() => 'sileo-p${++_counter}';

  /* ----------------------------- Resolution ------------------------------ */

  SileoOptions _merge(SileoOptions o) {
    final d = defaultOptions;
    if (d == null) return o;
    return SileoOptions(
      id: o.id ?? d.id,
      title: o.title ?? d.title,
      description: o.description ?? d.description,
      type: o.type ?? d.type,
      position: o.position ?? d.position,
      duration: o.duration ?? d.duration,
      icon: o.icon ?? d.icon,
      styles: d.styles?.merge(o.styles) ?? o.styles,
      fill: o.fill ?? d.fill,
      roundness: o.roundness ?? d.roundness,
      autopilot: o.autopilot ?? d.autopilot,
      button: o.button ?? d.button,
    );
  }

  /// Resolves the on-screen duration. Omitted → 6s default; non-positive → null
  /// (the toast persists).
  Duration? _resolveDuration(Duration? d) {
    if (d == null) return kSileoDefaultToastDuration;
    if (d <= Duration.zero) return null;
    return d;
  }

  (Duration?, Duration?) _resolveAutopilot(
    SileoAutopilot? ap,
    Duration? duration,
  ) {
    if (ap != null && !ap.enabled) return (null, null);
    if (duration == null || duration <= Duration.zero) return (null, null);
    Duration clamp(Duration v) {
      if (v < Duration.zero) return Duration.zero;
      if (v > duration) return duration;
      return v;
    }

    return (
      clamp(ap?.expand ?? kSileoAutoExpandDelay),
      clamp(ap?.collapse ?? kSileoAutoCollapseDelay),
    );
  }

  SileoItem _build(
    SileoOptions merged,
    String id,
    SileoState state, {
    SileoPosition? fallbackPosition,
    bool persist = false,
  }) {
    final duration = persist ? null : _resolveDuration(merged.duration);
    final (expand, collapse) = _resolveAutopilot(merged.autopilot, duration);
    return SileoItem(
      id: id,
      instanceId: _nextInstance(),
      state: state,
      position: merged.position ?? fallbackPosition ?? defaultPosition,
      roundness: math.max(0, merged.roundness ?? kSileoDefaultRoundness),
      title: merged.title,
      description: merged.description,
      icon: merged.icon,
      fill: merged.fill,
      button: merged.button,
      styles: merged.styles,
      duration: duration,
      autoExpandDelay: expand,
      autoCollapseDelay: collapse,
    );
  }

  /* ------------------------------- Mutations ----------------------------- */

  /// Creates (or replaces, by id) a toast. Returns its id.
  String create(
    SileoOptions options,
    SileoState state, {
    String? forceId,
    bool persist = false,
  }) {
    final merged = _merge(options);
    final id = forceId ?? merged.id ?? 'sileo-default';
    // A new toast always appears at the currently-selected position.
    final position = merged.position ?? defaultPosition;

    // The toast currently "owning" this id (the live, non-exiting one).
    SileoItem? live;
    for (final t in _toasts) {
      if (t.id == id && !t.exiting) {
        live = t;
        break;
      }
    }

    // If the live toast is at a different position, it stays put and animates
    // out where it is — it does not jump to the new position.
    if (live != null && live.position != position) {
      _beginExit(live);
    }

    final item = _build(
      merged,
      id,
      state,
      fallbackPosition: position,
      persist: persist,
    );

    // Replace any toast sharing this id at this position (the in-place morph,
    // plus any stale same-slot leftover), then add the new one.
    _toasts.removeWhere((t) => t.id == id && t.position == position);
    _toasts.add(item);
    notifyListeners();
    return id;
  }

  /// Updates an existing toast in place (new instanceId → triggers the morph).
  void update(String id, SileoOptions options, SileoState state) {
    // Prefer the live owner of the id; only fall back to an exiting one.
    var idx = _toasts.indexWhere((t) => t.id == id && !t.exiting);
    if (idx < 0) idx = _toasts.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final existing = _toasts[idx];
    _toasts[idx] = _build(
      _merge(options),
      id,
      state,
      fallbackPosition: existing.position,
    );
    notifyListeners();
  }

  /// Begins the exit animation, then removes the toast after the exit window.
  void dismiss(String id) {
    for (final t in _toasts) {
      if (t.id == id && !t.exiting) {
        _beginExit(t);
        notifyListeners();
        return;
      }
    }
  }

  /// Marks [item] as exiting (animating out in place) and schedules its removal
  /// after the exit window. Does not notify; the caller does.
  void _beginExit(SileoItem item) {
    final idx = _toasts.indexOf(item);
    if (idx < 0 || _toasts[idx].exiting) return;
    final instanceId = item.instanceId;
    _toasts[idx] = _toasts[idx].copyWith(exiting: true);
    Future<void>.delayed(kSileoExitDuration, () {
      final before = _toasts.length;
      _toasts.removeWhere((t) => t.instanceId == instanceId);
      if (_toasts.length != before) notifyListeners();
    });
  }

  /// Removes all toasts immediately, or only those at [position].
  void clear([SileoPosition? position]) {
    if (_toasts.isEmpty) return;
    if (position == null) {
      _toasts.clear();
    } else {
      _toasts.removeWhere((t) => t.position == position);
    }
    notifyListeners();
  }
}

/// The imperative toast API. The public entry point is the [sileo] instance:
/// `sileo.success(...)`, `sileo.future(...)`, `sileo.dismiss(id)`, etc.
class SileoController {
  SileoController._();

  final SileoStore _store = SileoStore.instance;

  /// Generic toast; uses [SileoOptions.type] (default `success`) to pick the
  /// intent.
  String show(SileoOptions options) =>
      _store.create(options, options.type ?? SileoState.success);

  String success(SileoOptions options) =>
      _store.create(options, SileoState.success);

  String error(SileoOptions options) =>
      _store.create(options, SileoState.error);

  String warning(SileoOptions options) =>
      _store.create(options, SileoState.warning);

  String info(SileoOptions options) => _store.create(options, SileoState.info);

  String action(SileoOptions options) =>
      _store.create(options, SileoState.action);

  /// Shows a non-expiring `loading` toast, then morphs it to
  /// `success`/`action` on resolve or `error` on reject. Returns [future] so
  /// you can keep chaining/awaiting.
  ///
  /// Each call gets its own toast id so concurrent futures don't clobber each
  /// other; pass an explicit [SileoOptions.id] on `loading` to override.
  Future<T> future<T>(Future<T> future, SileoFutureOptions<T> options) {
    final id = _store.create(
      options.loading.copyWith(position: options.position),
      SileoState.loading,
      forceId: options.loading.id ?? _store.generateId(),
      persist: true,
    );

    future.then((T value) {
      if (options.action != null) {
        _store.update(id, options.action!(value), SileoState.action);
      } else {
        _store.update(id, options.success(value), SileoState.success);
      }
    }).catchError((Object e) {
      _store.update(id, options.error(e), SileoState.error);
    });

    return future;
  }

  /// Dismisses the toast with [id] (begins its exit animation).
  void dismiss(String id) => _store.dismiss(id);

  /// Removes all toasts, or only those at [position].
  void clear([SileoPosition? position]) => _store.clear(position);
}

/// The global Sileo API. Call `sileo.success(...)`, `sileo.future(...)`, etc.
/// from anywhere — no [BuildContext] required.
final SileoController sileo = SileoController._();
