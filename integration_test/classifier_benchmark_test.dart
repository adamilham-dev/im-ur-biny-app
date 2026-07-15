// Benchmark on-device untuk classifier TFLite (waste_classifier.tflite).
//
// Mengukur — MURNI TFLite, tanpa cloud/LLM:
//   • Size model (MB)
//   • Latency inferensi per gambar (ms): mean / p50 / p95 / min / max
//   • FPS = 1000 / latency
//   • Akurasi = deteksi benar / total sampel uji × 100%
//   • Confusion matrix 6 kelas
//
// Test set: assets/benchmark/<Kategori>/*.jpg  (nama folder = ground-truth).
//
// Jalankan di DEVICE FISIK (latency hanya valid di device target):
//   flutter test integration_test/classifier_benchmark_test.dart -d <device-id>

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imurbiny/core/services/tflite_service.dart';

const int _warmupRuns = 5; // inferensi pemanasan (dibuang dari statistik)

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('Classifier TFLite — benchmark latency / FPS / akurasi', () async {
    final out = StringBuffer();
    void log(String s) {
      out.writeln(s);
      // ignore: avoid_print
      print(s);
    }

    // ── 1. Size model ──
    final modelData = await rootBundle.load(TFLiteService.modelAssetPath);
    final modelBytes = modelData.lengthInBytes;
    final modelMiB = modelBytes / (1024 * 1024);
    final modelMB = modelBytes / 1000000;

    // ── 2. Load model ──
    final svc = TFLiteService();
    await svc.loadModel();
    expect(svc.isLoaded, isTrue,
        reason: 'Model classifier gagal di-load — cek log TFLite native.');

    final classes = TFLiteService.classNames;

    // ── 3. Kumpulkan test set dari assets/benchmark/<Kategori>/ ──
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetKeys = manifest.listAssets();
    final samples = <({String path, String label})>[];
    for (final key in assetKeys) {
      if (!key.startsWith('assets/benchmark/')) continue;
      final lower = key.toLowerCase();
      if (!(lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png'))) {
        continue;
      }
      final parts = key.split('/'); // assets/benchmark/<Kategori>/<file>
      if (parts.length < 4) continue;
      samples.add((path: key, label: parts[2]));
    }

    log('═══════════════════════════════════════════════════════════');
    log(' BENCHMARK CLASSIFIER TFLITE (tanpa LLM)');
    log('═══════════════════════════════════════════════════════════');
    log(' Model   : ${TFLiteService.modelAssetPath}');
    log(' Size    : ${modelMiB.toStringAsFixed(2)} MiB '
        '(${modelMB.toStringAsFixed(2)} MB) — $modelBytes bytes');
    log(' Kelas   : ${classes.join(', ')}');
    log(' Sampel  : ${samples.length} gambar uji');
    log('───────────────────────────────────────────────────────────');

    if (samples.isEmpty) {
      log(' ⚠️  Tidak ada gambar di assets/benchmark/<Kategori>/.');
      log('    Isi dulu test set-nya (lihat assets/benchmark/README.md),');
      log('    lalu `flutter pub get` & jalankan ulang.');
      log('═══════════════════════════════════════════════════════════');
      return;
    }

    // Baca byte aset dengan slice yang benar (offset+length), kalau pakai
    // .buffer.asUint8List() polos bisa ikut byte buffer lain → decode error.
    Future<Uint8List> readAsset(String path) async {
      final d = await rootBundle.load(path);
      return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    }

    // ── 4. Warm-up (buang efek init/lazy-alloc dari statistik) ──
    // Pilih gambar pertama yang bisa di-decode sebagai pemanasan.
    for (final s in samples) {
      try {
        final b = await readAsset(s.path);
        for (var i = 0; i < _warmupRuns; i++) {
          svc.benchmarkClassify(b);
        }
        break;
      } catch (_) {
        continue;
      }
    }

    // ── 5. Loop terukur: latency + prediksi ──
    final latencies = <double>[]; // inferensi murni (ms)
    final totals = <double>[]; // preprocess + inferensi (ms)
    var correct = 0;
    var counted = 0; // sampel yang label-nya termasuk 6 kelas
    var decodeFail = 0; // gambar yang gagal di-decode (dilewati)
    // confusion[trueLabel][predLabel] = jumlah
    final confusion = <String, Map<String, int>>{
      for (final c in classes) c: {for (final p in classes) p: 0},
    };
    final perClassTotal = <String, int>{for (final c in classes) c: 0};
    final unknownLabels = <String, int>{};

    for (final s in samples) {
      final bytes = await readAsset(s.path);
      final ({
        int index,
        String name,
        double confidence,
        double preprocessMs,
        double inferenceMs,
      }) r;
      try {
        r = svc.benchmarkClassify(bytes);
      } catch (e) {
        decodeFail++;
        log('   ⚠️  gagal proses ${s.path}: $e');
        continue;
      }
      latencies.add(r.inferenceMs);
      totals.add(r.preprocessMs + r.inferenceMs);

      final trueLabel = _canonical(classes, s.label);
      if (trueLabel == null) {
        unknownLabels[s.label] = (unknownLabels[s.label] ?? 0) + 1;
        continue;
      }
      counted++;
      perClassTotal[trueLabel] = perClassTotal[trueLabel]! + 1;
      confusion[trueLabel]![r.name] = confusion[trueLabel]![r.name]! + 1;
      if (r.name == trueLabel) correct++;
    }
    if (decodeFail > 0) {
      log(' (Catatan: $decodeFail gambar gagal di-decode & dilewati)');
    }

    // ── 6. Statistik latency ──
    latencies.sort();
    final meanLat = _mean(latencies);
    final meanTot = _mean(totals);
    log(' LATENCY (inferensi murni _interpreter.run):');
    log('   mean   : ${meanLat.toStringAsFixed(2)} ms  '
        '→ FPS = ${(1000.0 / meanLat).toStringAsFixed(1)}');
    log('   p50    : ${_pct(latencies, 50).toStringAsFixed(2)} ms');
    log('   p95    : ${_pct(latencies, 95).toStringAsFixed(2)} ms');
    log('   min/max: ${latencies.first.toStringAsFixed(2)} / '
        '${latencies.last.toStringAsFixed(2)} ms');
    log('   (preprocess+inferensi mean: ${meanTot.toStringAsFixed(2)} ms '
        '→ FPS end-to-end ${(1000.0 / meanTot).toStringAsFixed(1)})');
    log('───────────────────────────────────────────────────────────');

    // ── 7. Akurasi ──
    if (counted == 0) {
      log(' AKURASI: tidak bisa dihitung — tidak ada label yang cocok '
          'dengan 6 kelas.');
    } else {
      final acc = correct / counted * 100;
      log(' AKURASI: $correct / $counted = ${acc.toStringAsFixed(2)} %');
      log('   (formula: deteksi benar / total sampel uji × 100%)');
      log('');
      log('   Akurasi per kelas (recall):');
      for (final c in classes) {
        final tot = perClassTotal[c]!;
        if (tot == 0) {
          log('     $c : (tidak ada sampel)');
          continue;
        }
        final tp = confusion[c]![c]!;
        log('     ${c.padRight(8)}: $tp / $tot = '
            '${(tp / tot * 100).toStringAsFixed(1)} %');
      }
    }
    if (unknownLabels.isNotEmpty) {
      log('   ⚠️  Folder label di luar 6 kelas (diabaikan utk akurasi): '
          '$unknownLabels');
    }
    log('───────────────────────────────────────────────────────────');

    // ── 8. Confusion matrix (baris = ground-truth, kolom = prediksi) ──
    if (counted > 0) {
      log(' CONFUSION MATRIX (baris=asli, kolom=prediksi):');
      final header = ['true\\pred', ...classes.map((c) => c.substring(0, 3))];
      log('   ${header.map((h) => h.padLeft(8)).join()}');
      for (final t in classes) {
        final row = [
          t.substring(0, 3),
          ...classes.map((p) => confusion[t]![p].toString()),
        ];
        log('   ${row.map((v) => v.padLeft(8)).join()}');
      }
    }
    log('═══════════════════════════════════════════════════════════');

    // Pastikan benchmark benar-benar jalan.
    expect(latencies, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// Cocokkan nama folder ke salah satu nama kelas (case-insensitive).
String? _canonical(List<String> classes, String label) {
  final l = label.toLowerCase().trim();
  for (final c in classes) {
    if (c.toLowerCase() == l) return c;
  }
  return null;
}

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

/// Persentil sederhana (xs harus sudah terurut menaik).
double _pct(List<double> sorted, int p) {
  if (sorted.isEmpty) return 0;
  final idx = ((p / 100) * (sorted.length - 1)).round();
  return sorted[idx];
}
