import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scan_result.dart';
import '../models/user_session.dart';
import '../services/session_service.dart';

class SessionNotifier extends StateNotifier<UserSession> {
  final SessionService _service;

  SessionNotifier(this._service) : super(const UserSession()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await _service.loadSession();
    if (mounted) state = session;
  }

  Future<void> setName(String name) async {
    state = state.copyWith(userName: name);
    await _service.saveSession(state);
  }

  Future<void> addXP(int xp) async {
    state = state.copyWith(totalXP: state.totalXP + xp);
    await _service.saveSession(state);
  }

  Future<void> addScan() async {
    state = state.copyWith(scanCount: state.scanCount + 1);
    await _service.saveSession(state);
  }

  Future<void> addCorrection() async {
    state = state.copyWith(correctionCount: state.correctionCount + 1);
    await _service.saveSession(state);
  }

  /// Append a list of scan results to the session history.
  Future<void> addToHistory(List<ScanResult> results) async {
    state = state.copyWith(scanHistory: [...state.scanHistory, ...results]);
    await _service.saveSession(state);
  }

  Future<void> resetSession() async {
    await _service.resetSession();
    state = const UserSession();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, UserSession>((ref) {
  return SessionNotifier(SessionService());
});

final userNameProvider = Provider<String>((ref) {
  return ref.watch(sessionProvider).userName;
});

final xpProvider = Provider<int>((ref) {
  return ref.watch(sessionProvider).totalXP;
});

final scanCountProvider = Provider<int>((ref) {
  return ref.watch(sessionProvider).scanCount;
});
