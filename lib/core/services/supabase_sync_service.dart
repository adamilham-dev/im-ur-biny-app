import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'device_id_service.dart';
import 'local_dataset_service.dart';

/// Best-effort uploader for the local sample outbox → Supabase.
///
/// Talks to Supabase via its REST endpoints (PostgREST + Storage) using a plain
/// [HttpClient], so it needs NO `supabase_flutter` dependency and no platform
/// setup. It is **inert** until `SUPABASE_URL` + `SUPABASE_ANON_KEY` are present
/// in `.env`: with no config it logs once and does nothing, so the app keeps
/// working fully offline.
///
/// Design contract:
/// - Never throws to callers — every failure is swallowed and the entry simply
///   stays `synced=false` for a later retry.
/// - Never blocks a scan. Call [syncPending] fire-and-forget.
/// - Uploads the JPEG to the private `waste-samples` bucket, then INSERTS a row
///   in `public.samples`, then marks the local entry synced and DELETES the
///   local JPEG (disk reclaim — the Hive pHash row stays so [findMatch] keeps
///   matching; the bucket now holds the only copy of the bytes).
///
/// Append-only model: the table RLS is pure insert-only (most secure — the
/// bundled anon key can't read or modify rows). A correction re-syncs as a NEW
/// row (`label_source='human'`, later `captured_at`); dedup / latest-label is
/// resolved at training time, not in the DB. No upsert, so no SELECT policy is
/// needed and the key stays write-only.
class SupabaseSyncService {
  SupabaseSyncService._();
  static final SupabaseSyncService instance = SupabaseSyncService._();

  static const String _bucket = 'waste-samples';

  bool _syncing = false;

  String get _url => dotenv.maybeGet('SUPABASE_URL') ?? '';
  String get _anonKey => dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

  /// True once `.env` carries a usable Supabase config.
  bool get isConfigured =>
      _url.isNotEmpty &&
      !_url.contains('YOUR_PROJECT_REF') &&
      _anonKey.isNotEmpty &&
      !_anonKey.contains('YOUR_');

  /// Upload every pending local entry. Safe to call often; re-entrant calls
  /// while a sync is in flight are ignored. Returns the number of entries
  /// successfully synced this run.
  Future<int> syncPending() async {
    if (!isConfigured) {
      debugPrint('[Sync] Supabase not configured — staying local-only');
      return 0;
    }
    if (_syncing) return 0;
    _syncing = true;
    var ok = 0;
    try {
      final deviceId = await DeviceIdService.instance.get();
      final pending = LocalDatasetService.instance.unsyncedEntries();
      if (pending.isEmpty) return 0;
      debugPrint('[Sync] uploading ${pending.length} pending sample(s)');

      for (final entry in pending) {
        final bytes = await LocalDatasetService.instance.imageBytesFor(entry);
        final path = '$deviceId/${entry.imageFileName}';

        // Missing file ≠ error: JPEGs are deleted after a successful sync,
        // and a human correction re-enters the outbox (synced=false) WITHOUT
        // its image. The identical bytes already sit at [path] in the bucket
        // (SHA-derived name, append-only), so skip the upload and just insert
        // the corrected metadata row.
        if (bytes != null) {
          final uploaded = await _uploadImage(path, bytes);
          if (!uploaded) continue;
        }

        final inserted = await _insertRow(entry, deviceId: deviceId, imagePath: path);
        if (!inserted) continue;

        await LocalDatasetService.instance.markSynced(entry.sha256Hex);
        // Bytes are safe in the bucket — reclaim the local JPEG. findMatch
        // only needs the Hive pHash row, so matching keeps working.
        await LocalDatasetService.instance.deleteImageFile(entry);
        ok++;
      }
      debugPrint('[Sync] done — $ok/${pending.length} synced');
    } catch (e) {
      debugPrint('[Sync] aborted: $e');
    } finally {
      _syncing = false;
    }
    return ok;
  }

  Future<bool> _uploadImage(String path, List<int> bytes) async {
    try {
      final uri = Uri.parse('$_url/storage/v1/object/$_bucket/$path');
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set('apikey', _anonKey);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey');
      req.headers.set(HttpHeaders.contentTypeHeader, 'image/jpeg');
      req.add(bytes);
      final resp = await req.close();
      await resp.drain<void>();
      client.close();
      // 2xx = uploaded. 409 = object already exists (same image bytes from a
      // prior sync / correction re-send) — treat as success and proceed to
      // insert the metadata row. The bucket is insert-only, so we don't
      // overwrite, and that's fine: identical bytes need no re-upload.
      final okStatus =
          (resp.statusCode >= 200 && resp.statusCode < 300) ||
              resp.statusCode == 409;
      if (!okStatus) {
        debugPrint('[Sync] image upload HTTP ${resp.statusCode} for $path');
      }
      return okStatus;
    } catch (e) {
      debugPrint('[Sync] image upload error: $e');
      return false;
    }
  }

  Future<bool> _insertRow(
    LocalDatasetEntry entry, {
    required String deviceId,
    required String imagePath,
  }) async {
    try {
      // Append-only insert (no upsert — see class doc).
      final uri = Uri.parse('$_url/rest/v1/samples');
      final body = jsonEncode({
        'sha256': entry.sha256Hex,
        'phash': entry.pHash,
        'label': entry.category.stableId,
        'label_source': entry.labelSource,
        'item_name': entry.itemName,
        'confidence': entry.confidence,
        'device_id': deviceId,
        'image_path': imagePath,
        'captured_at': entry.capturedAt.toUtc().toIso8601String(),
      });

      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set('apikey', _anonKey);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('Prefer', 'return=minimal');
      req.add(utf8.encode(body));
      final resp = await req.close();
      await resp.drain<void>();
      client.close();
      final okStatus = resp.statusCode >= 200 && resp.statusCode < 300;
      if (!okStatus) {
        debugPrint('[Sync] row insert HTTP ${resp.statusCode}');
      }
      return okStatus;
    } catch (e) {
      debugPrint('[Sync] row insert error: $e');
      return false;
    }
  }
}
