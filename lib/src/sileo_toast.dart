import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'constants.dart';
import 'gooey_painter.dart';
import 'icons.dart';
import 'options.dart';
import 'spring.dart';

/// One rendered toast — the visual core.
///
/// Responsible for: the spring-animated morph geometry (pill width, body
/// height/opacity), the gooey paper, the header icon+title with a blur
/// cross-fade, the expandable body, entry/exit, hover- and tap-to-expand, the
/// collapse-then-swap on content change, and swipe-to-dismiss.
class SileoToast extends StatefulWidget {
  const SileoToast({
    super.key,
    required this.id,
    required this.instanceId,
    required this.state,
    required this.fill,
    required this.roundness,
    required this.alignFactor,
    required this.expandUp,
    required this.canExpand,
    required this.width,
    this.title,
    this.description,
    this.icon,
    this.button,
    this.styles,
    this.exiting = false,
    this.autoExpandDelay,
    this.autoCollapseDelay,
    this.onMouseEnter,
    this.onMouseLeave,
    this.onTapped,
    this.onDismiss,
  });

  final String id;
  final String instanceId;
  final SileoState state;
  final Color fill;
  final double roundness;

  /// 0 = left, 0.5 = centre, 1 = right (horizontal anchoring within the canvas).
  final double alignFactor;

  /// Whether the body grows upward (bottom-of-screen positions).
  final bool expandUp;

  /// Active-toast gating — only the active toast may expand.
  final bool canExpand;

  /// Canvas width (responsive: shrinks on narrow screens).
  final double width;

  final String? title;
  final String? description;
  final Widget? icon;
  final SileoButton? button;
  final SileoStyles? styles;
  final bool exiting;
  final Duration? autoExpandDelay;
  final Duration? autoCollapseDelay;

  /// Pointer entered (hover): the host marks this the active toast and pauses
  /// every auto-dismiss timer while the pointer rests on it.
  final VoidCallback? onMouseEnter;

  /// Pointer left (hover): the host restores the newest toast and resumes.
  final VoidCallback? onMouseLeave;

  /// The toast was tapped open. Unlike [onMouseEnter] this does not pause
  /// auto-dismiss; the host makes this toast active and restarts its dismiss
  /// countdown for a fresh reading window — unless a hover is already pausing
  /// the timers, in which case the hover pause takes precedence.
  final VoidCallback? onTapped;
  final VoidCallback? onDismiss;

  @override
  State<SileoToast> createState() => _SileoToastState();
}

class _SileoToastState extends State<SileoToast> with TickerProviderStateMixin {
  // Spring-driven morph geometry.
  late final AnimationController _pillWidth = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _bodyHeight = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _bodyOpacity = AnimationController.unbounded(
    vsync: this,
  );

  // Pill neck-cover height bump when open — its own (bouncy) spring.
  late final AnimationController _pillBump = AnimationController.unbounded(
    vsync: this,
  );

  // Entry/exit timing on the spring-easing curve.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: kSileoEntryDuration,
  );
  late final CurvedAnimation _entryCurve = CurvedAnimation(
    parent: _entry,
    curve: sileoSpringCurve,
  );

  // Header cross-fade: the incoming title/icon blurs in on the spring curve; the
  // outgoing (prev) layer blurs out on ease, then is dropped. The prev layer is
  // overlaid (never laid out), so a swap never resizes the header — keeping the
  // tuck-scale pivot and the title position stable.
  late final AnimationController _headerEnter = AnimationController(
    vsync: this,
    duration: kSileoDuration,
  );
  late final AnimationController _headerExit = AnimationController(
    vsync: this,
    duration: kSileoHeaderExit,
  );
  late final CurvedAnimation _headerEnterCurve = CurvedAnimation(
    parent: _headerEnter,
    curve: sileoSpringCurve,
  );
  late final CurvedAnimation _headerExitCurve = CurvedAnimation(
    parent: _headerExit,
    curve: Curves.ease,
  );
  Widget? _prevHeaderInner;
  String? _headerKey;
  Timer? _headerExitTimer;

  // The currently displayed content (the "view"); updated by the swap logic.
  late SileoState _vState;
  late String? _vTitle;
  late String? _vDescription;
  late Widget? _vIcon;
  late SileoButton? _vButton;
  late SileoStyles? _vStyles;
  late Color _vFill;

  bool _isExpanded = false;
  bool _ready = false;
  bool _reduceMotion = false;
  double _contentHeight = 0;

  // Swipe.
  double _dragRaw = 0;
  double _dragShown = 0;

  Timer? _expandTimer;
  Timer? _collapseTimer;
  Timer? _swapTimer;

  final GlobalKey _contentKey = GlobalKey();
  TextScaler _textScaler = TextScaler.noScaling;
  TextDirection _textDirection = TextDirection.ltr;

  bool get _hasDesc => _vDescription != null || _vButton != null;

  bool get _isLoading => _vState == SileoState.loading;

  bool get _open => _hasDesc && _isExpanded && !_isLoading;

  bool get _allowExpand => !_isLoading && widget.canExpand;

  double get _blur => widget.roundness * kSileoBlurRatio;

  @override
  void initState() {
    super.initState();
    _adoptView();
    _headerKey = _headerKeyString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureContent();
      _runAutopilot();
      if (!widget.exiting) {
        if (_reduceMotion) {
          _entry.value = 1;
          _headerEnter.value = 1;
        } else {
          _entry.forward();
          _headerEnter.forward(from: 0); // header blurs in on first appear
        }
      } else {
        _headerEnter.value = 1;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.maybeOf(context);
    _reduceMotion = mq?.disableAnimations ?? false;
    _textScaler = mq?.textScaler ?? TextScaler.noScaling;
    _textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;

    // Measure the pill synchronously (TextPainter needs no layout pass). The
    // first measurement snaps; later ones spring (mirrors `ready ? SPRING : 0`).
    _measurePill(snap: !_ready);
    // Re-measure the body too — text scale / directionality may have reflowed it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureContent();
    });
  }

  @override
  void didUpdateWidget(SileoToast old) {
    super.didUpdateWidget(old);

    if (widget.fill != old.fill) {
      setState(() => _vFill = widget.fill);
    }

    if (widget.instanceId != old.instanceId) {
      _handleRefresh();
    } else if (widget.canExpand != old.canExpand ||
        widget.autoExpandDelay != old.autoExpandDelay ||
        widget.autoCollapseDelay != old.autoCollapseDelay) {
      _runAutopilot();
    }

    if (widget.exiting && !old.exiting) {
      _expandTimer?.cancel();
      _collapseTimer?.cancel();
      _swapTimer?.cancel();
      _setExpanded(false);
      if (_reduceMotion) {
        _entry.value = 0;
      } else {
        _entry.reverse();
      }
    } else if (!widget.exiting && old.exiting) {
      // This State was reused for a fresh toast (a same-slot re-create can
      // recycle an exiting element by key) — replay the entry so it's visible.
      if (_reduceMotion) {
        _entry.value = 1;
      } else {
        _entry.forward();
      }
      _runAutopilot();
    }
  }

  @override
  void dispose() {
    _expandTimer?.cancel();
    _collapseTimer?.cancel();
    _swapTimer?.cancel();
    _headerExitTimer?.cancel();
    _entryCurve.dispose();
    _headerEnterCurve.dispose();
    _headerExitCurve.dispose();
    _pillWidth.dispose();
    _bodyHeight.dispose();
    _bodyOpacity.dispose();
    _pillBump.dispose();
    _entry.dispose();
    _headerEnter.dispose();
    _headerExit.dispose();
    super.dispose();
  }

  /* ------------------------------- View / swap --------------------------- */

  void _adoptView() {
    _vState = widget.state;
    _vTitle = widget.title;
    _vDescription = widget.description;
    _vIcon = widget.icon;
    _vButton = widget.button;
    _vStyles = widget.styles;
    _vFill = widget.fill;
  }

  void _handleRefresh() {
    _swapTimer?.cancel();
    if (_open) {
      // Collapse first, then swap the content while closed, then let autopilot
      // / hover re-expand — the swap morph.
      _setExpanded(false);
      _swapTimer = Timer(kSileoSwapCollapse, () {
        if (mounted) _applySwap();
      });
    } else {
      _applySwap();
    }
  }

  void _applySwap() {
    setState(() {
      _maybeCrossfadeHeader(); // snapshot the OLD header before adopting
      _adoptView();
    });
    _measurePill();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureContent();
    });
    _runAutopilot();
  }

  /* ------------------------------ Measurement ---------------------------- */

  void _measurePill({bool snap = false}) {
    final tp = TextPainter(
      text: TextSpan(text: _resolvedTitle(), style: _titleStyle()),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: 1,
    )..layout();
    // header inner = badge(24) + gap(8) + title; pill = inner + headerPad*2 +
    // PILL_PADDING.
    final inner = 24 + 8 + tp.width;
    final target = math.max(
      inner + kSileoHeaderPadding * 2 + kSileoPillPadding,
      kSileoHeight,
    );
    if (snap || !_ready) {
      _pillWidth.stop();
      _pillWidth.value = target;
      _ready = true;
    } else {
      _spring(_pillWidth, target);
    }
  }

  void _measureContent() {
    final size = _contentKey.currentContext?.size;
    if (size == null) return;
    if ((size.height - _contentHeight).abs() < 0.5) return;
    _contentHeight = size.height;
    if (_open) _applyOpen();
  }

  /* ------------------------------- Springs ------------------------------- */

  void _spring(
    AnimationController c,
    double target, {
    SpringDescription? with_,
  }) {
    if (_reduceMotion) {
      c
        ..stop()
        ..value = target;
      return;
    }
    c.animateWith(
      SpringSimulation(with_ ?? kSileoSpringOpen, c.value, target, c.velocity),
    );
  }

  void _applyOpen() {
    if (_open) {
      final expanded = math.max(
        kSileoHeight * kSileoMinExpandRatio,
        kSileoHeight + _contentHeight,
      );
      _spring(_bodyHeight, expanded - kSileoHeight);
      _spring(_bodyOpacity, 1);
      _spring(_pillBump, _blur * 3); // pill always springs bouncy, both ways
    } else {
      _spring(_bodyHeight, 0, with_: kSileoSpringClose);
      _spring(_bodyOpacity, 0, with_: kSileoSpringClose);
      _spring(_pillBump, 0);
    }
  }

  void _setExpanded(bool value) {
    if (_isExpanded == value) return;
    _isExpanded = value;
    _applyOpen();
  }

  /// Tap toggles the body open/closed. Opening reveals the description and —
  /// unlike a hover — does *not* pause auto-dismiss: it restarts the collapse
  /// countdown here and the dismiss countdown in the host (via [onTapped]), so
  /// the toast still closes and hides itself after a fresh reading window.
  void _handleTap() {
    if (widget.exiting || !_hasDesc || _isLoading) return;
    if (_isExpanded) {
      _collapseTimer?.cancel();
      _setExpanded(false);
    } else {
      widget.onTapped?.call();
      _setExpanded(true);
      _restartAutoCollapse();
    }
  }

  /// Restarts the auto-collapse countdown so a tapped-open toast closes its
  /// body after [autoCollapseDelay]. A no-op when autopilot is off (the toast
  /// then stays open until it's tapped closed, dismissed, or swiped away).
  void _restartAutoCollapse() {
    _collapseTimer?.cancel();
    final collapse = widget.autoCollapseDelay;
    if (collapse != null && collapse > Duration.zero) {
      _collapseTimer = Timer(collapse, () {
        if (mounted) _setExpanded(false);
      });
    }
  }

  void _runAutopilot() {
    _expandTimer?.cancel();
    _collapseTimer?.cancel();
    if (!_hasDesc) return;
    if (widget.exiting || !_allowExpand) {
      _setExpanded(false);
      return;
    }
    final expand = widget.autoExpandDelay;
    final collapse = widget.autoCollapseDelay;
    if (expand == null && collapse == null) return; // manual (hover) only

    if (expand != null && expand > Duration.zero) {
      _expandTimer = Timer(expand, () {
        if (mounted) _setExpanded(true);
      });
    } else {
      _setExpanded(true);
    }
    if (collapse != null && collapse > Duration.zero) {
      _collapseTimer = Timer(collapse, () {
        if (mounted) _setExpanded(false);
      });
    }
  }

  /* ------------------------------- Content ------------------------------- */

  String _resolvedTitle() => _capitalize(_vTitle ?? _vState.name);

  static String _capitalize(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  TextStyle _titleStyle() => TextStyle(
    fontSize: 13.2,
    height: 16 / 13.2,
    fontWeight: FontWeight.w500,
    color: sileoToneColor(_vState),
  ).merge(_vStyles?.title);

  String _headerKeyString() => '${_vState.name}-${_resolvedTitle()}';

  /// Called from [_applySwap] just before [_adoptView] — `_v*` still hold the
  /// OLD content. If the header (state + title) actually changes, snapshots the
  /// old header as the outgoing layer and (re)starts the cross-fade.
  void _maybeCrossfadeHeader() {
    final nextKey =
        '${widget.state.name}-${_capitalize(widget.title ?? widget.state.name)}';
    if (nextKey == _headerKey) return;
    _prevHeaderInner = _buildHeaderInner(); // built from the OLD _v*
    _headerKey = nextKey;
    _headerExitTimer?.cancel();
    if (_reduceMotion) {
      _headerEnter.value = 1;
      _headerExit.value = 1;
      _prevHeaderInner = null;
      return;
    }
    _headerEnter.forward(from: 0);
    _headerExit.forward(from: 0);
    _headerExitTimer = Timer(kSileoHeaderExit, () {
      if (mounted) setState(() => _prevHeaderInner = null);
    });
  }

  /// One cross-fade layer: the icon badge + title row (no key, no transforms).
  Widget _buildHeaderInner() {
    final tone = sileoToneColor(_vState, _vStyles?.badgeColor);
    final badge = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: sileoBadgeBackground(tone),
        shape: BoxShape.circle,
      ),
      child: _vIcon != null
          ? IconTheme.merge(
              data: IconThemeData(color: tone, size: 16),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: tone),
                child: _vIcon!,
              ),
            )
          : sileoStateIcon(_vState, color: tone),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        badge,
        const SizedBox(width: 8),
        Text(
          _resolvedTitle(),
          style: _titleStyle(),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ],
    );
  }

  /// Applies the cross-fade blur + opacity to one header layer.
  Widget _headerFx({
    required double blur,
    required double opacity,
    required Widget child,
  }) {
    var w = child;
    if (blur >= 0.05) {
      w = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: w,
      );
    }
    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: w);
  }

  /* -------------------------------- Build -------------------------------- */

  String _semanticsLabel() {
    final t = _resolvedTitle();
    final d = _vDescription;
    return d == null || d.isEmpty ? t : '$t. $d';
  }

  @override
  Widget build(BuildContext context) {
    final canSwipe = widget.onDismiss != null && !widget.exiting;
    // Toasts render in the overlay, outside any Material/Scaffold, so give them
    // a clean base text style (no yellow "missing style" underline). Each text
    // sets its own colour/size on top of this.
    return DefaultTextStyle(
      style: const TextStyle(
        decoration: TextDecoration.none,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF000000),
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: _semanticsLabel(),
        child: MouseRegion(
          opaque: false,
          onEnter: (_) {
            if (widget.exiting) return;
            widget.onMouseEnter?.call();
            if (_hasDesc) _setExpanded(true);
          },
          onExit: (_) {
            if (widget.exiting) return;
            widget.onMouseLeave?.call();
            _setExpanded(false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: _hasDesc && !widget.exiting && !_isLoading
                ? _handleTap
                : null,
            onVerticalDragUpdate: canSwipe
                ? (d) {
                    _dragRaw += d.delta.dy;
                    setState(() {
                      _dragShown = _dragRaw.clamp(
                        -kSileoSwipeMax,
                        kSileoSwipeMax,
                      );
                    });
                  }
                : null,
            onVerticalDragEnd: canSwipe
                ? (_) {
                    final dismiss = _dragRaw.abs() > kSileoSwipeDismiss;
                    _dragRaw = 0;
                    setState(() => _dragShown = 0);
                    if (dismiss) widget.onDismiss?.call();
                  }
                : null,
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _pillWidth,
                _bodyHeight,
                _bodyOpacity,
                _pillBump,
                _entryCurve,
              ]),
              builder: (context, _) => _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Clamp the (title-driven) pill to the canvas so a long title on a narrow
    // screen is cropped by the header's ClipRect instead of overflowing — this
    // also keeps pillX (below) >= 0.
    final pillW = math.min(
      math.max(_pillWidth.value, kSileoHeight),
      widget.width,
    );
    final bodyH = math.max(0.0, _bodyHeight.value);
    final bodyO = _bodyOpacity.value.clamp(0.0, 1.0);
    final total = kSileoHeight + bodyH;

    final pillX = (widget.width - pillW) * widget.alignFactor;
    final pillHeight = kSileoHeight + math.max(0.0, _pillBump.value);

    final e = _entryCurve.value;
    final start = widget.expandUp ? kSileoEntryOffset : -kSileoEntryOffset;
    final translateY = ui.lerpDouble(start, 0, e)! + _dragShown;

    final paper = RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, total),
        painter: SileoGooeyPainter(
          pill: Rect.fromLTWH(pillX, 0, pillW, pillHeight),
          body: Rect.fromLTWH(0, kSileoHeight, widget.width, bodyH),
          radius: widget.roundness,
          blur: _blur,
          fill: _vFill,
        ),
      ),
    );

    return Opacity(
      opacity: e.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: ui.lerpDouble(0.95, 1.0, e)!,
          child: SizedBox(
            width: widget.width,
            height: total,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: widget.expandUp
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(1, -1, 1),
                          child: paper,
                        )
                      : paper,
                ),
                if (_hasDesc) _buildContent(bodyH, bodyO),
                _buildHeader(pillX, pillW, bodyO),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double pillX, double pillW, double openT) {
    // As the toast opens, the header tucks toward the body (scale 0.9, nudge
    // 3px toward the expand edge). The cross-fade layers sit below this scale,
    // and the box is sized only by the current layer, so the pivot stays put.
    final t = openT.clamp(0.0, 1.0);
    final headerScale = ui.lerpDouble(1.0, 0.9, t)!;
    final headerNudge = (widget.expandUp ? -3.0 : 3.0) * t;

    final layers = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _headerEnterCurve,
        _headerExitCurve,
      ]),
      builder: (context, _) {
        final enter = _headerEnterCurve.value.clamp(0.0, 1.0);
        final exit = _headerExitCurve.value.clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: <Widget>[
            // Current layer — the only one that sizes the header; blurs in.
            _headerFx(
              blur: (1 - enter) * 6,
              opacity: enter,
              child: _buildHeaderInner(),
            ),
            // Outgoing layer — overlaid with no layout effect; blurs out.
            if (_prevHeaderInner != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _headerFx(
                  blur: exit * 6,
                  opacity: 1 - exit,
                  child: _prevHeaderInner!,
                ),
              ),
          ],
        );
      },
    );

    return Positioned(
      left: pillX,
      width: pillW,
      // clip the header to the pill (a longer outgoing title is cropped)
      top: widget.expandUp ? null : 0,
      bottom: widget.expandUp ? 0 : null,
      height: kSileoHeight,
      child: ClipRect(
        // OverflowBox lets the title row lay out at its natural width (so it is
        // never constrained/overflowed); the ClipRect crops the painted result
        // to the pill width instead.
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: kSileoHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSileoHeaderPadding,
            ),
            child: Transform.translate(
              offset: Offset(0, headerNudge),
              child: Transform.scale(scale: headerScale, child: layers),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double bodyH, double bodyO) {
    return Positioned(
      left: 0,
      width: widget.width,
      top: widget.expandUp ? null : kSileoHeight,
      bottom: widget.expandUp ? kSileoHeight : null,
      child: SizedBox(
        width: widget.width,
        height: bodyH,
        child: ClipRect(
          child: OverflowBox(
            alignment: widget.expandUp
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Opacity(opacity: bodyO, child: _contentChild()),
          ),
        ),
      ),
    );
  }

  Widget _contentChild() {
    final descColor = sileoDescriptionColor(_vFill);
    final descStyle = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: descColor,
    ).merge(_vStyles?.description);

    return Padding(
      key: _contentKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_vDescription != null) Text(_vDescription!, style: descStyle),
          if (_vButton != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _SileoActionButton(
                button: _vButton!,
                tone: sileoToneColor(_vState, _vStyles?.buttonColor),
              ),
            ),
        ],
      ),
    );
  }
}

/// The expanded body's action button — a pill that tints darker on hover.
class _SileoActionButton extends StatefulWidget {
  const _SileoActionButton({required this.button, required this.tone});

  final SileoButton button;
  final Color tone;

  @override
  State<_SileoActionButton> createState() => _SileoActionButtonState();
}

class _SileoActionButtonState extends State<_SileoActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.button.onPressed,
        // Claim vertical drags so a drag starting on the button doesn't bubble
        // up and dismiss the toast.
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (_) {},
        onVerticalDragEnd: (_) {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 28,
          // Stretch to the full content width; an alignment makes the container
          // expand to the available width instead of hugging the label.
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover
                ? sileoButtonHoverBackground(widget.tone)
                : sileoButtonBackground(widget.tone),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            widget.button.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: widget.tone,
            ),
          ),
        ),
      ),
    );
  }
}
