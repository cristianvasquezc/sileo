import 'dart:async';

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'options.dart';
import 'sileo_toast.dart';
import 'store.dart';

/// Base distance (px) from the screen edges to the toast stack. Any
/// [Toaster.offset] adds to this.
const double _kViewportPadding = 12;

/// The host. Mount one [Toaster] once — typically via `MaterialApp.builder` so
/// it sits below the app's [MediaQuery]/[Directionality]/theme but above all
/// routes — and call `sileo.*` from anywhere.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => Toaster(theme: SileoTheme.system, child: child),
///   home: const HomePage(),
/// );
/// ```
class Toaster extends StatefulWidget {
  const Toaster({
    super.key,
    this.child,
    this.position = SileoPosition.topRight,
    this.theme,
    this.offset,
    this.options,
  });

  /// The app content the toasts float above. When used as a `MaterialApp.builder`
  /// this is the `child` that builder receives.
  final Widget? child;

  /// Default corner for toasts that don't specify their own.
  final SileoPosition position;

  /// Enables built-in theming. When null, no theme is applied (white pill).
  final SileoTheme? theme;

  /// Extra distance from the screen edges, added to the default padding.
  final EdgeInsets? offset;

  /// Default options merged under every toast (the toast's own options win).
  final SileoOptions? options;

  @override
  State<Toaster> createState() => _ToasterState();
}

class _ToasterState extends State<Toaster> {
  final SileoStore _store = SileoStore.instance;
  final Map<String, Timer> _timers = <String, Timer>{};

  List<SileoItem> _toasts = const <SileoItem>[];
  bool _hover = false;
  String? _activeId;
  String? _latestId;

  String _timerKey(SileoItem t) => '${t.id}:${t.instanceId}';

  @override
  void initState() {
    super.initState();
    _store
      ..defaultPosition = widget.position
      ..defaultOptions = widget.options
      ..addListener(_onStore);
    _toasts = _store.toasts;
    _recomputeLatest();
  }

  @override
  void didUpdateWidget(Toaster old) {
    super.didUpdateWidget(old);
    if (widget.position != old.position) {
      _store.defaultPosition = widget.position;
    }
    if (widget.options != old.options) {
      _store.defaultOptions = widget.options;
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _clearTimers();
    super.dispose();
  }

  /* -------------------------------- Store -------------------------------- */

  void _onStore() {
    if (!mounted) return;
    setState(() => _toasts = _store.toasts);
    _recomputeLatest();
    _syncTimers();
  }

  void _recomputeLatest() {
    String? latest;
    for (final t in _toasts) {
      if (!t.exiting) latest = t.id;
    }
    _latestId = latest;
    // The newest toast becomes active on every change; a hover-enter then
    // overrides it (see _onHoverEnter), and hover-leave restores it.
    _activeId = latest;
  }

  /* ------------------------------- Timers -------------------------------- */

  void _syncTimers() {
    final live = <String>{
      for (final t in _toasts)
        if (!t.exiting) _timerKey(t),
    };
    _timers.removeWhere((key, timer) {
      if (!live.contains(key)) {
        timer.cancel();
        return true;
      }
      return false;
    });
    _schedule();
  }

  void _schedule() {
    if (_hover) return;
    for (final t in _toasts) {
      if (t.exiting) continue;
      final d = t.duration;
      if (d == null || d <= Duration.zero) continue;
      final key = _timerKey(t);
      if (_timers.containsKey(key)) continue;
      _timers[key] = Timer(d, () => _store.dismiss(t.id));
    }
  }

  void _clearTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  /* -------------------------------- Hover -------------------------------- */

  void _onHoverEnter(String id) {
    setState(() => _activeId = id);
    if (!_hover) {
      _hover = true;
      _clearTimers();
    }
  }

  void _onHoverLeave() {
    setState(() => _activeId = _latestId);
    if (_hover) {
      _hover = false;
      _schedule();
    }
  }

  /* -------------------------------- Theme -------------------------------- */

  Color? _themeFill(BuildContext context) {
    switch (widget.theme) {
      case null:
        return null;
      case SileoTheme.light:
        return kSileoLightThemeFill;
      case SileoTheme.dark:
        return kSileoDarkThemeFill;
      case SileoTheme.system:
        final brightness =
            MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
        return brightness == Brightness.light
            ? kSileoLightThemeFill
            : kSileoDarkThemeFill;
    }
  }

  /* -------------------------------- Build -------------------------------- */

  @override
  Widget build(BuildContext context) {
    final themeFill = _themeFill(context);
    // SafeArea needs a MediaQuery ancestor; skip it gracefully if absent
    // (e.g. a Toaster mounted outside a MaterialApp).
    final useSafeArea = MediaQuery.maybeOf(context) != null;

    final byPosition = <SileoPosition, List<SileoItem>>{};
    for (final t in _toasts) {
      (byPosition[t.position] ??= <SileoItem>[]).add(t);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (widget.child != null) Positioned.fill(child: widget.child!),
        for (final entry in byPosition.entries)
          _buildViewport(entry.key, entry.value, themeFill, useSafeArea),
      ],
    );
  }

  Widget _buildViewport(
    SileoPosition pos,
    List<SileoItem> items,
    Color? themeFill,
    bool useSafeArea,
  ) {
    // Newest closest to its edge (top: reversed; bottom: natural order).
    final ordered = pos.isTop ? items.reversed.toList() : items;
    final offset = widget.offset ?? EdgeInsets.zero;

    final content = Align(
      alignment: _alignmentFor(pos),
      child: Padding(
        padding: EdgeInsets.only(
          top: _kViewportPadding + offset.top,
          bottom: _kViewportPadding + offset.bottom,
          left: _kViewportPadding + offset.left,
          right: _kViewportPadding + offset.right,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12,
          children: <Widget>[
            for (final item in ordered) _buildToast(item, themeFill),
          ],
        ),
      ),
    );

    return Positioned.fill(
      key: ValueKey<SileoPosition>(pos),
      child: useSafeArea ? SafeArea(child: content) : content,
    );
  }

  Widget _buildToast(SileoItem item, Color? themeFill) {
    final pos = item.position;
    return SileoToast(
      // Keyed by id + position so the widget persists across in-place updates
      // (morph) but a repositioned toast becomes a distinct widget (the old one
      // exits at its old position, the new one enters at the new position).
      key: ValueKey<String>('${item.id}|${item.position.name}'),
      id: item.id,
      instanceId: item.instanceId,
      state: item.state,
      title: item.title,
      description: item.description,
      icon: item.icon,
      fill: item.fill ?? themeFill ?? kSileoDefaultFill,
      roundness: item.roundness,
      alignFactor: (pos.horizontalAlignment.x + 1) / 2,
      expandUp: pos.expandsUp,
      canExpand: _activeId == null || _activeId == item.id,
      button: item.button,
      styles: item.styles,
      exiting: item.exiting,
      autoExpandDelay: item.autoExpandDelay,
      autoCollapseDelay: item.autoCollapseDelay,
      onMouseEnter: () => _onHoverEnter(item.id),
      onMouseLeave: _onHoverLeave,
      onDismiss: () => _store.dismiss(item.id),
    );
  }

  Alignment _alignmentFor(SileoPosition pos) {
    switch (pos) {
      case SileoPosition.topLeft:
        return Alignment.topLeft;
      case SileoPosition.topCenter:
        return Alignment.topCenter;
      case SileoPosition.topRight:
        return Alignment.topRight;
      case SileoPosition.bottomLeft:
        return Alignment.bottomLeft;
      case SileoPosition.bottomCenter:
        return Alignment.bottomCenter;
      case SileoPosition.bottomRight:
        return Alignment.bottomRight;
    }
  }
}
