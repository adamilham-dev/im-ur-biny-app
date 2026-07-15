import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/local_dataset_service.dart';
import 'core/services/supabase_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  // `.env` is optional at runtime — a missing file must not crash the kiosk.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('[main] .env not loaded — running without cloud config');
  }
  // Open the local-scan-dataset box + ensure image dir exists before UI mounts
  // so the first scan can read/write without a startup race.
  await LocalDatasetService.instance.init();
  // Flush any sample outbox left from previous sessions. Best-effort, never
  // awaited, no-op when Supabase isn't configured.
  unawaited(SupabaseSyncService.instance.syncPending());
  runApp(const ProviderScope(child: ImUrBinyApp()));
}
