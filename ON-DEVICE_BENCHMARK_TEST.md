# Laporan Pengujian Performa Model TFLite On-Device

**Aplikasi:** I'm ur Biny
**Model yang diuji:** `waste_classifier.tflite` (klasifikasi 6 kategori sampah)
**Tanggal pengujian:** 20 Juni 2026
**Perangkat uji:** Samsung Galaxy S23 (SM-S911B), Android 16 (API 36)
**Mode komputasi:** CPU, 4 threads (delegate GPU gagal diinisialisasi → fallback CPU)
**Metode inferensi:** murni on-device TFLite, **tanpa bantuan LLM/cloud**

---

## 1. Tujuan

Mengukur empat indikator performa model klasifikasi TFLite saat terintegrasi ke
dalam aplikasi:

1. **Latency** — waktu inferensi model untuk memproses satu gambar (milidetik).
2. **FPS** — jumlah frame yang dapat diproses per detik (`FPS = 1000 / latency`).
3. **Size** — ukuran file model setelah terintegrasi ke aplikasi (megabyte).
4. **Akurasi** — proporsi prediksi benar terhadap total sampel uji.

---

## 2. Metodologi

| Aspek              | Keterangan                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| Instrumen          | Harness otomatis `integration_test/classifier_benchmark_test.dart`, dijalankan langsung di perangkat fisik   |
| Pengukuran latency | `Stopwatch` mengelilingi pemanggilan `Interpreter.run()` — **murni waktu inferensi**, di luar pra-pemrosesan |
| Warm-up            | 5 inferensi pemanasan dibuang dari statistik (menghindari bias inisialisasi)                                 |
| Preprocessing      | Resize 256×256, normalisasi ImageNet, brightening adaptif untuk latar gelap                                  |
| Output             | Argmax mentah atas 6 kelas (**tanpa ambang kepercayaan, tanpa cloud**)                                       |
| Sumber sampel uji  | 32 gambar dari koleksi data Supabase (`public.samples` + bucket `waste-samples`)                             |
| Rumus akurasi      | `Akurasi = (jumlah prediksi benar / jumlah total sampel uji) × 100%`                                         |

---

## 3. Hasil

### 3.1 Ukuran Model (Size)

| Besaran           | Nilai                    |
| ----------------- | ------------------------ |
| Ukuran file       | **17,32 MB** (16,52 MiB) |
| Ukuran dalam byte | 17.321.076 bytes         |

> Model disimpan sebagai aset di dalam APK (format FlatBuffer, tidak dikompres
> ulang), sehingga ukuran di aplikasi = ukuran file.

### 3.2 Latency & FPS

| Metrik                                         | Nilai                     |
| ---------------------------------------------- | ------------------------- |
| **Latency rata-rata (inferensi murni)**        | **122,33 ms**             |
| Persentil ke-50 (p50)                          | 124,79 ms                 |
| Persentil ke-95 (p95)                          | 145,44 ms                 |
| Minimum / Maksimum                             | 96,45 ms / 146,57 ms      |
| **FPS**                                        | **8,2** (= 1000 / 122,33) |
| Latency end-to-end (preprocessing + inferensi) | 173,24 ms (≈ 5,8 FPS)     |

### 3.3 Akurasi

| Metrik            | Nilai                                  |
| ----------------- | -------------------------------------- |
| Sampel dievaluasi | 31 (dari 32; 1 gambar gagal di-decode) |
| Prediksi benar    | 10                                     |
| **Akurasi**       | **32,26 %**                            |

**Akurasi per kelas (recall):**

| Kelas   | Benar / Total | Recall           |
| ------- | ------------- | ---------------- |
| Kertas  | 5 / 7         | 71,4 %           |
| Logam   | 5 / 8         | 62,5 %           |
| Kaca    | 0 / 2         | 0,0 %            |
| Plastik | 0 / 14        | 0,0 %            |
| Organik | —             | tidak ada sampel |
| Residu  | —             | tidak ada sampel |

**Confusion Matrix** (baris = label asli, kolom = prediksi model):

| asli ＼ prediksi | Kaca | Kertas | Logam | Organik | Plastik | Residu |
| ---------------- | ---- | ------ | ----- | ------- | ------- | ------ |
| **Kaca**         | 0    | 0      | 2     | 0       | 0       | 0      |
| **Kertas**       | 0    | 5      | 1     | 1       | 0       | 0      |
| **Logam**        | 0    | 1      | 5     | 0       | 1       | 1      |
| **Plastik**      | 1    | 6      | 0     | 0       | 0       | 7      |

---

## 4. Keterbatasan & Validitas

Metrik **Size, Latency, dan FPS valid** sebagai hasil pengukuran nyata pada
perangkat target dan dapat dilaporkan apa adanya (sebutkan perangkat = Galaxy S23
dan mode = CPU).

Angka **Akurasi (32,26 %) harus dibaca dengan hati-hati** dan **belum layak**
diklaim sebagai akurasi model sebenarnya, karena:

1. **Label bukan ground-truth manusia.** Label sampel uji berasal dari prediksi
   pipeline (cloud), bukan verifikasi manual. Membandingkan model terhadap label
   ini bersifat sirkular.
2. **Input tidak konsisten.** Sebagian sampel berupa frame kamera penuh
   (1920×1080), bukan objek ter-crop seperti yang diharapkan classifier — sehingga
   prediksi menurun drastis (mis. Plastik 0/14).
3. **Dataset kecil & timpang.** Hanya 31 sampel, dominan plastik, dan dua kelas
   (Organik, Residu) tidak terwakili — sehingga tidak representatif secara statistik.

### Rekomendasi untuk akurasi yang sahih

- Gunakan **test set berlabel manusia**, seimbang antar 6 kelas.
- Gunakan input yang **sama dengan kondisi produksi** (objek ter-crop, bukan frame penuh).
- Jalankan ulang harness yang sama:
  ```bash
  flutter test integration_test/classifier_benchmark_test.dart -d <device-id>
  ```

---

## 5. Kesimpulan

| Indikator | Hasil              | Status                                        |
| --------- | ------------------ | --------------------------------------------- |
| Size      | 17,32 MB           | ✅ valid                                      |
| Latency   | 122,33 ms / gambar | ✅ valid                                      |
| FPS       | 8,2                | ✅ valid                                      |
| Akurasi   | 32,26 %            | ⚠️ indikatif, perlu test set berlabel manusia |

Model `waste_classifier.tflite` berjalan sepenuhnya on-device pada Galaxy S23
dengan latency ±122 ms (≈8 FPS) di CPU dan ukuran 17,32 MB. Pengukuran akurasi
final menunggu test set yang terverifikasi.
