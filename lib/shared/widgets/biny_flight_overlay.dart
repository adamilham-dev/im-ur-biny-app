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
    with TickerProviderStateMixin {
  static const Duration _kFlightDuration = Duration(milliseconds: 380);
  static const Curve _kFlightCurve = Curves.easeOutCubic;

  late final AnimationController _ctrl;
  BinyFlightState? _from;
  BinyFlightState? _to;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kFlightDuration)
      ..addListener(() => setState(() {}));
    final c = BinyFlightController.instance;
    _hidden = c.isHidden;
    c.addListener(_onChanged);
  }

  @override
  void dispose() {
    BinyFlightController.instance.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    final c = BinyFlightController.instance;
    if (_hidden != c.isHidden) {
      setState(() => _hidden = c.isHidden);
    }
    final next = c.current;
    if (next == null) {
      // No BinyHero is mounted anywhere — the user navigated to a
      // screen that intentionally has no mascot (out-of-frame /
      // too-large / mixed-* error screens). Stop animating and hide
      // so the previous page's Biny doesn't linger on top.
      if (_to != null) {
        _ctrl.stop();
        _ctrl.value = 0;
        setState(() {
          _to = null;
          _from = null;
        });
      }
      return;
    }
    if (_to == next) return;

    setState(() {
      if (_to == null) {
        // First mount OR returning from a no-mascot page: jump to
        // position without animating.
        _from = next;
        _to = next;
        _ctrl.value = 1.0;
      } else {
        // Capture the currently displayed state so a rapid second
        // navigation mid-flight starts from where the user sees Biny.
        _from = _displayed();
        _to = next;
        _ctrl.forward(from: 0);
      }
    });
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
      // Show the destination's foreground throughout the flight so a
      // screen's badge doesn't briefly swap to the previous page's.
      foreground: to.foreground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _to;
    if (_hidden || target == null) return widget.child;

    final state =
        _ctrl.value < 1.0 ? _lerp(_from!, _to!, _kFlightCurve.transform(_ctrl.value)) : target;

    return Stack(
      children: [
        widget.child,
        Positioned.fromRect(
          rect: state.rect,
          child: IgnorePointer(
            child: RepaintBoundary(
              // The foreground (e.g. onboarding badge) is rendered ABOVE the
              // mascot so it isn't covered by the overlay Biny. It is aligned
              // to the mascot's rect and flies along with it.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  BinyMascot(
                    size: state.size,
                    expression: state.expression,
                    animate: true,
                  ),
                  if (state.foreground != null) state.foreground!,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
