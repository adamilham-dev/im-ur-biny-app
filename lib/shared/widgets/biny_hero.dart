import 'package:flutter/material.dart';

import '../../core/providers/biny_flight_controller.dart';
import 'biny_mascot.dart';

// Re-export BinyExpression so screens can keep importing only this file
// after swapping `biny_mascot.dart` for `biny_hero.dart`.
export 'biny_mascot.dart' show BinyExpression;

const double _kBinyViewBoxW = 240;
const double _kBinyViewBoxH = 252;

// MUST match `_kSlideFractionX` in lib/app.dart. Used to compensate
// the entering page's horizontal slide so BinyHero reports the
// AT-REST rect even when measured mid-transition — this lets the
// flight overlay start the fly during the page transition rather
// than after it completes.
const double _kPageSlideFractionX = 0.05;

/// Invisible placeholder that reserves the mascot's slot in the layout
/// and reports its on-screen rect to [BinyFlightController]. The actual
/// mascot is rendered once at the top of the tree by [BinyFlightOverlay]
/// so it can fly between screens.
///
/// Why not [Hero]: Hero flights do not fire reliably with GoRouter's
/// `context.go()` (flutter/flutter#112095). Since TrashScan is a kiosk
/// app whose flow is built around `context.go()` (stack-less forward
/// navigation), we drive the flight ourselves via the controller + overlay.
class BinyHero extends StatefulWidget {
  final double size;
  final BinyExpression expression;

  /// Kept for API compatibility with the previous BinyHero/BinyMascot
  /// signature. The overlay always animates the mascot, so this is
  /// effectively ignored.
  final bool animate;

  /// Optional widget rendered by [BinyFlightOverlay] ON TOP of the mascot,
  /// aligned to the same rect and flying along with it. Use this for
  /// decorations that must appear in front of Biny (e.g. the onboarding
  /// badge), since the overlay mascot otherwise paints over anything drawn
  /// inside the route.
  final Widget? foreground;

  const BinyHero({
    super.key,
    required this.size,
    required this.expression,
    this.animate = true,
    this.foreground,
  });

  @override
  State<BinyHero> createState() => _BinyHeroState();
}

class _BinyHeroState extends State<BinyHero> {
  final GlobalKey _key = GlobalKey();
  late final int _id;

  // Track the pending route-animation listener so we can remove it if
  // the widget unmounts before the transition completes.
  Animation<double>? _watchedAnimation;
  void Function(AnimationStatus)? _statusListener;

  // Settle-follow state: layout around the slot can keep moving AFTER the
  // one-shot post-frame measure (keyboard inset animation, an AnimatedSize
  // ancestor expanding, scroll settling). None of those fire
  // didChangeDependencies/didUpdateWidget, so a single measurement parks the
  // overlay mascot at a stale rect. After every trigger we keep re-measuring
  // each frame until the rect stops moving for a few consecutive frames.
  Rect? _lastRect;
  int _stableFrames = 0;
  int _followBudget = 0;
  static const int _kStableFramesNeeded = 5;
  static const int _kMaxFollowFrames = 240; // hard cap ≈ 4s @60fps

  @override
  void initState() {
    super.initState();
    _id = BinyFlightController.instance.registerSpot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant BinyHero old) {
    super.didUpdateWidget(old);
    if (old.size != widget.size ||
        old.expression != widget.expression ||
        !identical(old.foreground, widget.foreground)) {
      _scheduleMeasure();
    }
  }

  @override
  void dispose() {
    // Tell the controller this spot is gone so it can clear state
    // when no spots remain (hides the mascot on mascot-less pages).
    BinyFlightController.instance.unregisterSpot(_id);
    _clearStatusListener();
    super.dispose();
  }

  void _clearStatusListener() {
    if (_statusListener != null && _watchedAnimation != null) {
      _watchedAnimation!.removeStatusListener(_statusListener!);
    }
    _statusListener = null;
    _watchedAnimation = null;
  }

  void _scheduleMeasure() {
    _clearStatusListener();
    _lastRect = null;
    _stableFrames = 0;
    _followBudget = _kMaxFollowFrames;

    final anim = ModalRoute.of(context)?.animation;
    // Measure as soon as layout settles — even if the route animation
    // is still in progress. `_measure()` compensates for the active
    // slide so we report the AT-REST rect, which lets the flight
    // overlay start the fly DURING the page transition rather than
    // after it completes (otherwise the user sees the page arrive,
    // then Biny fly afterwards — total ~760ms instead of ~380ms).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(anim));

    if (anim == null || anim.isCompleted) return;

    // Safety net: re-measure once the transition completes. The
    // compensated first measurement should already be correct, but
    // this guards against the post-frame firing very early (before
    // layout fully settled) or the layout shifting mid-transition.
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _clearStatusListener();
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure(null));
      }
    }
    _statusListener = listener;
    _watchedAnimation = anim;
    anim.addStatusListener(listener);
  }

  void _measure(Animation<double>? routeAnim) {
    if (!mounted) return;
    if (!BinyFlightController.instance.isActiveSpot(_id)) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    var rect = ro.localToGlobal(Offset.zero) & ro.size;

    // Compensate for the entering page's horizontal slide. The page
    // slides from +_kPageSlideFractionX (at anim.value = 0) to 0 (at
    // anim.value = 1) following easeOutCubic — see
    // `_appPageTransitionBuilder` in lib/app.dart. Without this, the
    // measured rect would be offset by the slide and the fly target
    // would be wrong until the transition completes.
    if (routeAnim != null && routeAnim.value < 1.0) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final eased = Curves.easeOutCubic.transform(routeAnim.value);
      final dx = (1.0 - eased) * _kPageSlideFractionX * screenWidth;
      rect = rect.translate(-dx, 0);
    }

    BinyFlightController.instance.report(
      BinyFlightState(
        rect: rect,
        size: widget.size,
        expression: widget.expression,
        foreground: widget.foreground,
      ),
    );

    // Follow the slot while layout is still settling (see field docs).
    // report() dedupes identical states, so repeated identical measures
    // are free; we stop once the rect holds still for a few frames.
    if (_lastRect != rect) {
      _lastRect = rect;
      _stableFrames = 0;
    } else {
      _stableFrames += 1;
    }
    if (_stableFrames < _kStableFramesNeeded && _followBudget > 0) {
      _followBudget -= 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(null));
      // Layout animations normally keep frames coming, but make sure the
      // follow-up measure actually gets a frame even if nothing else is
      // animating.
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _key,
      width: widget.size * _kBinyViewBoxW / _kBinyViewBoxH,
      height: widget.size,
    );
  }
}
