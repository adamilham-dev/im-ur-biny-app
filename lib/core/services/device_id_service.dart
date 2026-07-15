import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable per-device (per-kiosk) identifier, persisted in SharedPreferences.
///
/// Used to tag synced samples so the central dataset knows which kiosk a sample
/// came from, and so the `unique(device_id, sha256)` dedup in Supabase works.
///
/// Generated once on first run as a random 128-bit hex string (UUID-v4-ish).
/// We avoid the `uuid` package — `Random.secure()` is enough for a non-crypto
/// device tag and keeps the dependency list lean.
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  static const String _prefsKey = 'kiosk_device_id';

  String? _cached;

  /// Returns the stable device id, creating and persisting one on first call.
  Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id = _generate();
      await prefs.setString(_prefsKey, id);
      debugPrint('[DeviceId] generated new kiosk id: $id');
    }
    _cached = id;
    return id;
  }

  String _generate() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
