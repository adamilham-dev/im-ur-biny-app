import 'package:flutter/material.dart';

import '../../core/providers/biny_flight_controller.dart';
import 'biny_mascot.dart';

/// Mounts a single [BinyMascot] above the Navigator that smoothly flies
/// between the rects reported by [BinyHero] spots as the user navigates.
///
/// This avoids [Hero] entirely because Hero flights don't fire reliably
/// with GoRouter's `context.go()` (see flutter/flutter#112095). The
/// overlay reads from [BinyFlightController] and animates between the
/// previously displayed state and the newly reported one.
class BinyFlightOverlay extends StatefulWidget {
  final Widget child;

  const BinyFlightOverlay({super.key, required this.child});

  @override
  State<BinyFlightOverlay> createState() => _BinyFlightOverlayState();
}

class _BinyFlightOverlayState extends State<BinyFlightOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _kFlightDuration = Duration(milliseconds: 380);
  static const Curve _kFlightCurve = Curves.easeOutCubic;

  late final AnimationController _ctrl;
  BinyFlightState? _from;
  BinyFlightState? _to;
  bool _hidden = false;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kFlightDuration);
    final c = BinyFlightController.instance;
    _hidden = c.isHidden;
    c.addListener(_scheduleUpdate);
  }

  @override
  void dispose() {
    BinyFlightController.instance.removeListener(_scheduleUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  /// Defer controller reactions to the next frame. [BinyFlightController]
  /// can notify while a [BinyHero] is disposing (tree locked), and driving
  /// [_ctrl] inside [setState] ticks the animation listener synchronously.
  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      _applyUpdate();
    });
  }

  void _applyUpdate() {
    final c = BinyFlightController.instance;
    final next = c.current;
    final newHidden = c.isHidden;

    if (next == null) {
      // No BinyHero is mounted anywhere — the user navigated to a
      // screen that intentionally has no mascot (out-of-frame /
      // too-large / mixed-* error screens). Stop animating and hide
      // so the previous page's Biny doesn't linger on top.
      if (_to != null || _hidden != newHidden) {
        _ctrl.stop();
        if (_to != null) _ctrl.value = 0;
        setState(() {
          _to = null;
          _from = null;
          _hidden = newHidden;
        });
      }
      return;
    }

    if (_to == next) {
      if (_hidden != newHidden) {
        setState(() => _hidden = newHidden);
      }
      return;
    }

    final BinyFlightState from;
    final BinyFlightState to = next;
    final bool animate;

    if (_to == null) {
      // First mount OR returning from a no-mascot page: jump to
      // position without animating.
      from = next;
      animate = false;
    } else {
      // Capture the currently displayed state so a rapid second
      // navigation mid-flight starts from where the user sees Biny.
      from = _displayed();
      animate = true;
    }

    setState(() {
      _from = from;
      _to = to;
      _hidden = newHidden;
    });

    // Drive the controller after setState — forward()/value notify
    // listeners synchronously and must not run inside setState.
    if (animate) {
      _ctrl.forward(from: 0);
    } else {
      _ctrl.value = 1.0;
    }
  }

  BinyFlightState _displayed() {
    if (_from == null || _to == null) return _to!;
    if (_ctrl.value >= 1.0) return _to!;
    return _lerp(_from!, _to!, _kFlightCurve.transform(_ctrl.value));
  }

  BinyFlightState _lerp(BinyFlightState from, BinyFlightState to, double t) {
    return BinyFlightState(
      rect: Rect.lerp(from.rect, to.rect, t)!,
      size: from.size + (to.size - from.size) * t,
      expression: to.expression,
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _to;
    if (_hidden || target == null) return widget.child;

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final from = _from;
            final to = _to;
            if (from == null || to == null) return const SizedBox.shrink();

            final state = _ctrl.value < 1.0
                ? _lerp(from, to, _kFlightCurve.transform(_ctrl.value))
                : to;

            return Positioned.fromRect(
              rect: state.rect,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: BinyMascot(
                    size: state.size,
                    expression: state.expression,
                    animate: true,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
