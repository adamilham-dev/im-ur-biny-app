# Test set benchmark classifier (TFLite, tanpa LLM)

Dipakai oleh `integration_test/classifier_benchmark_test.dart` untuk mengukur
**latency, FPS, akurasi, dan confusion matrix** dari `waste_classifier.tflite`
secara on-device — murni TFLite, tanpa cloud/LLM.

## Cara pakai

1. Taruh gambar uji **berlabel** ke subfolder kategori (nama folder = ground-truth):

   ```
   assets/benchmark/Kaca/*.jpg
   assets/benchmark/Kertas/*.jpg
   assets/benchmark/Logam/*.jpg
   assets/benchmark/Organik/*.jpg
   assets/benchmark/Plastik/*.jpg
   assets/benchmark/Residu/*.jpg
   ```

   Format: `.jpg`, `.jpeg`, atau `.png`. Nama file bebas.

2. Pastikan label benar-benar diverifikasi manusia (ground-truth), bukan hasil
   prediksi model — kalau pakai label prediksi, angka akurasi jadi sirkular/tidak valid.

3. Jalankan di device fisik (latency hanya valid di device target):

   ```bash
   flutter test integration_test/classifier_benchmark_test.dart -d <device-id>
   ```

4. Baca laporan di output test: ukuran model, latency rata-rata/p50/p95, FPS,
   akurasi keseluruhan & per-kelas, dan confusion matrix.

## Catatan

- File `.gitkeep` hanya placeholder agar folder ada; diabaikan harness.
- Tambah lebih banyak sampel per kelas (idealnya seimbang antar kelas) agar
  angka akurasi kredibel untuk paper.
