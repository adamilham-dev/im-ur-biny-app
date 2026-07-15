import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

class SessionService {
  static const _keyUserName = 'user_name';
  static const _keyTotalXP = 'total_xp';
  static const _keyScanCount = 'scan_count';
  static const _keyCorrectionCount = 'correction_count';

  Future<UserSession> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return UserSession(
      userName: prefs.getString(_keyUserName) ?? '',
      totalXP: prefs.getInt(_keyTotalXP) ?? 0,
      scanCount: prefs.getInt(_keyScanCount) ?? 0,
      correctionCount: prefs.getInt(_keyCorrectionCount) ?? 0,
    );
  }

  Future<void> saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, session.userName);
    await prefs.setInt(_keyTotalXP, session.totalXP);
    await prefs.setInt(_keyScanCount, session.scanCount);
    await prefs.setInt(_keyCorrectionCount, session.correctionCount);
  }

  Future<void> resetSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyTotalXP);
    await prefs.remove(_keyScanCount);
    await prefs.remove(_keyCorrectionCount);
  }

  // XP rewards
  static const int xpNewCategory = 25;
  static const int xpExistingCategory = 10;
  static const int xpCorrection = 2;
}
