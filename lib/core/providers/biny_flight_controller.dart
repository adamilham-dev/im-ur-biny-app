import 'package:flutter/widgets.dart';

import '../../shared/widgets/biny_mascot.dart';

/// Snapshot of where Biny should be rendered on screen, plus which
/// expression to show. Reported by [BinyHero] spots and consumed by
/// [BinyFlightOverlay] to animate the mascot between screens.
class BinyFlightState {
  final Rect rect;
  final double size;
  final BinyExpression expression;

  /// Optional decoration painted ON TOP of the mascot (aligned to [rect]).
  /// Used by screens whose Biny carries a foreground badge — e.g. the
  /// onboarding steps' category badge — so the badge sits above the
  /// overlay mascot instead of behind it.
  final Widget? foreground;

  const BinyFlightState({
    required this.rect,
    required this.size,
    required this.expression,
    this.foreground,
  });

  @override
  bool operator ==(Object other) =>
      other is BinyFlightState &&
      other.rect == rect &&
      other.size == size &&
      other.expression == expression;

  @override
  int get hashCode => Object.hash(rect, size, expression);
}

/// Singleton that tracks the active Biny target across the app.
///
/// Why singleton + ChangeNotifier instead of Riverpod:
/// the flight state is purely a UI concern shared between the spot
/// reporters (deep in the route tree) and the single overlay at the
/// MaterialApp level. Riverpod would require wiring providers across
/// the navigator boundary; a ChangeNotifier with a single listener
/// (the overlay) is simpler.
class BinyFlightController extends ChangeNotifier {
  BinyFlightController._();
  static final instance = BinyFlightController._();

  BinyFlightState? _current;
  int _latestSpotId = 0;
  int _activeSpots = 0;
  int _hideCount = 0;

  BinyFlightState? get current => _current;
  bool get isHidden => _hideCount > 0;

  /// Called by [BinyHero] on mount. Returns the spot's unique id, which
  /// is used to reject stale reports from older spots that are still
  /// mounted during a page transition's exit animation.
  int registerSpot() {
    _latestSpotId += 1;
    _activeSpots += 1;
    return _latestSpotId;
  }

  /// Called by [BinyHero] on dispose. When no spot is mounted anywhere
  /// (i.e., the user navigated to a screen that intentionally has no
  /// mascot, like out-of-frame / too-large / mixed-* error screens),
  /// clear the reported rect so the overlay hides the mascot instead
  /// of leaving the previous page's Biny floating on top.
  void unregisterSpot(int id) {
    if (_activeSpots > 0) _activeSpots -= 1;
    if (_activeSpots == 0 && _current != null) {
      _current = null;
      notifyListeners();
    }
  }

  bool isActiveSpot(int id) => id == _latestSpotId;

  void report(BinyFlightState state) {
    final prev = _current;
    // Foreground is excluded from BinyFlightState.== (Widget has no stable
    // equality), so compare identity explicitly — otherwise a rebuilt
    // foreground (e.g. onboarding page change keeping the same rect) would
    // be dropped and the overlay would keep the stale badge.
    final fgChanged = !identical(state.foreground, prev?.foreground);
    if (prev == state && !fgChanged) return;
    _current = state;
    notifyListeners();
  }

  /// Hide the overlay Biny (used by screens that show their own Biny
  /// via a separate channel, e.g. [DetailItemScreen] dialog, or by
  /// screens that intentionally have no mascot like [ScanningScreen]).
  ///
  /// [notifyListeners] is synchronous, so the count MUST be updated
  /// BEFORE notifying — otherwise listeners read [isHidden] while the
  /// count is still 0 and skip the state update, leaving the overlay
  /// showing Biny even though hide() was called.
  void hide() {
    final wasHidden = _hideCount > 0;
    _hideCount += 1;
    if (!wasHidden) notifyListeners();
  }

  void show() {
    final wasHidden = _hideCount > 0;
    if (_hideCount > 0) _hideCount -= 1;
    if (wasHidden && _hideCount == 0) notifyListeners();
  }
}
