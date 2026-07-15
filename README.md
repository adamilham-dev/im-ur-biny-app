# I'm ur Biny - The Future of AI Waste Sorting

**Aplikasi display interaktif untuk memilah sampah berbasis AI**, dibangun dengan Flutter. Pengguna meletakkan sampah di atas papan, kamera memotretnya, lalu AI mengklasifikasikannya ke kategori sampah dan memberikan panduan pembuangan + fakta edukasi. Maskot **Biny** memandu pengguna di sepanjang alur.

Target perangkat utama: **tablet/iPad landscape (1194×834)** sebagai kios/display interaktif, namun UI responsif hingga ke layar ponsel.

> **Arsitektur AI: HYBRID (jujur).** Jalur utama saat ini memakai **Vision‑LLM Gemma via OpenRouter (cloud)** untuk mendeteksi + mengklasifikasi sampah (butuh internet). Model **on‑device TFLite** tetap di-bundle sebagai **fallback offline**. Detektor on‑device **RT‑DETR saat ini gagal dimuat** di perangkat (lihat _Catatan & Keterbatasan_). Jadi: bukan murni on‑device — ini hybrid cloud‑first dengan cadangan on‑device.

---

## Fitur Utama

- **Klasifikasi sampah via Vision‑LLM (Gemma/OpenRouter)** — satu objek (_single_) maupun banyak objek sekaligus (_mixed_) dengan pemetaan koordinat bounding box.
- **Fallback on‑device (TFLite)** — bila cloud tidak terkonfigurasi/offline, classifier on‑device mengambil alih (kategori `kaca` ditekan agar konsisten).
- **"Analisis dengan AI" (escalation)** — dari layar Tidak Dikenali, AI cloud (Gemma via OpenRouter) menganalisis ulang. **Skip cache lokal** — AI selalu jalan fresh. Jalur ini boleh return `kaca` sebagai **kategori baru** (conf ≥ 70%) → masuk ke `/conclusion-new` → `/dataset-saved` dengan chip kategori ke‑6. Confidence rendah → `/low-confidence` (PERLU DICEK).
- **Mode _mixed_ + carousel hasil** — Gemma mengembalikan daftar objek + koordinat; UI menampilkan slide _global_ (scene + semua kotak) lalu slide per‑objek (crop tiap objek).
- **Koreksi manual** — pengguna bisa membenarkan prediksi yang salah (disimpan sebagai label `human`).
- **Pengumpulan data (local‑first → Supabase)** — tiap scan terkonfirmasi disimpan lokal lalu disinkronkan ke Supabase (append‑only) untuk retraining ke depan.
- **Gamifikasi & sesi** — nama pengguna, XP, jumlah scan, riwayat (lokal via SharedPreferences).
- **Edukasi** — tiap kategori punya langkah pembuangan & fakta "Tahukah kamu?".

---

## Kategori Sampah

UI mengenali **5 kategori daur** + `lainnya` untuk item tak dikenal:

| Kategori    | Contoh                     | Pembuangan                |
| ----------- | -------------------------- | ------------------------- |
| **Kertas**  | Kardus, koran              | Tempat daur ulang kertas  |
| **Logam**   | Kaleng, tutup              | Tempat daur ulang logam   |
| **Organik** | Sisa makanan               | Tempat sampah organik     |
| **Plastik** | Botol, kemasan             | Tempat daur ulang plastik |
| **Residu**  | Popok, tisu, puntung rokok | Tempat sampah residu      |
| **Lainnya** | Tak dikenal                | Tempat sampah umum        |

> **Catatan tentang `Kaca`:** kategori `kaca` **bukan kategori "daur" pilihan user**, tetapi BISA muncul sebagai **kategori baru hasil "Analisis dengan AI"**. Jalur on‑device (TFLite/RT‑DETR) & OpenRouter jalur cepat (Gemma) menekan prediksi kaca → `lainnya` (model on‑device rentan false‑positive pada permukaan mengilap), lewat `_suppressKaca`. Sebaliknya, jalur **Analyzing escalation** (`/unknown-detected → /analyzing → /conclusion-new → /dataset-saved`, via `OpenRouterClassifierService.classifyAnalyzing`) **skip cache lokal** dan diizinkan return `kaca` sebagai kategori yang dipelajari — saat itu chip ke‑6 "Kaca" muncul di Dataset Saved ("Biny mengenali 6 jenis sampah"). Enum internal `WasteCategory` di-serialisasi memakai **string id stabil** (`WasteCategory.stableId`), bukan index, agar tahan terhadap perubahan urutan.

---

## Arsitektur

### Tumpukan Teknologi

| Area                    | Pilihan                                                                                                                                               |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Framework               | Flutter (Dart SDK `^3.12.1`)                                                                                                                          |
| State management        | **Riverpod** (`flutter_riverpod ^2.6.1`, `StateNotifier`)                                                                                             |
| Navigasi                | **GoRouter** (`go_router ^14.8.1`)                                                                                                                    |
| AI utama (cloud)        | **Gemma** (`google/gemma-4-26b-a4b-it`) via **OpenRouter** — REST `dart:io` (tanpa paket tambahan)                                                    |
| AI cadangan (on‑device) | **tflite_flutter** `^0.11.0` (classifier; RT‑DETR gagal load)                                                                                         |
| AI cloud (opsional)     | **google_generative_ai** `^0.4.6` (Gemini — **tidak dipakai sementara**, file `gemini_service.dart` orphan; semua jalur AI cloud kini via OpenRouter) |
| Pengumpulan data        | **Supabase** (Postgres + Storage via REST `dart:io`) + **hive_ce** `^2.0.0` (index lokal)                                                             |
| Konfigurasi rahasia     | **flutter_dotenv** `^5.2.1` (`.env`)                                                                                                                  |
| Hash/ID                 | **crypto** `^3.0.0` (SHA‑256, perceptual hash)                                                                                                        |
| Pemrosesan gambar       | **image** `^4.0.0`                                                                                                                                    |
| Kamera                  | **camera** `^0.11.0`                                                                                                                                  |
| Persistensi sesi        | **shared_preferences** `^2.3.0`                                                                                                                       |
| Perizinan               | **permission_handler** `^11.3.0`                                                                                                                      |
| Font & ikon             | **google_fonts** (Baloo 2 + Plus Jakarta Sans), **flutter_svg**                                                                                       |

### Struktur Direktori

```
lib/
├── main.dart                 # init dotenv (resilient) + Hive + flush sync outbox + ProviderScope
├── app.dart                  # ImUrBinyApp + GoRouter (semua rute)
├── core/
│   ├── constants/            # app_constants.dart
│   ├── models/               # waste_category (stableId), scan_result, user_session
│   ├── providers/            # scan_provider, camera_provider, session_provider,
│   │                         #   local_dataset_provider, biny_flight_controller, dll.
│   ├── services/
│   │   ├── openrouter_classifier_service.dart  # ⭐ Gemma: classify (single) + classifyMultiple (boxes)
│   │   ├── gemini_service.dart                  # jalur escalation Gemini (opsional/lama)
│   │   ├── tflite_service.dart                  # classifier on-device (fallback)
│   │   ├── rtdetr_service.dart                  # detektor on-device (GAGAL load saat ini)
│   │   ├── interpreter_factory.dart             # buat interpreter TFLite + delegate GPU + fallback CPU
│   │   ├── local_dataset_service.dart           # dataset lokal (Hive + Application Support)
│   │   ├── supabase_sync_service.dart           # sync outbox → Supabase (REST, inert tanpa key)
│   │   ├── device_id_service.dart               # id kios stabil
│   │   ├── camera_service.dart / object_validator_service.dart / session_service.dart
│   └── theme/                # app_colors, app_typography, app_responsive, app_theme
├── shared/widgets/           # biny_mascot, biny_hero, detection_box_view (overlay box), dll.
└── features/                 # satu folder per layar (presentation/<nama>_screen.dart)

assets/models/
├── waste_classifier.tflite   # classifier on-device (input 256×256) — fallback
└── rtdetr_best_fp32.tflite    # detektor (input 640×640, ~63 MB) — gagal load di device

supabase/migrations/          # skema Supabase (tabel samples + RLS + bucket)
.env                          # (gitignored) OPENROUTER_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY, GEMINI_API_KEY
```

### Pola State Management

Riverpod (`ProviderScope` di `main.dart`). Provider kunci:

- **`scanProvider`** (`StateNotifier<AsyncValue<ScanResult?>>`) — orkestrasi klasifikasi: `classifyImage` (single), `classifyMultipleImages` (mixed), `correctResult`, dll.
- **`cameraProvider`**, **`sessionProvider`** (XP/riwayat, persisten), **`localDatasetProvider`**.
- App state: `scanModeProvider` (`single`/`mixed`), `capturedImageProvider`, dll.

Data antar‑layar lewat provider (bukan argumen rute) → rute GoRouter tetap tanpa argumen.

### Pipeline Inferensi ML — Hybrid

**Jalur utama (cloud, butuh internet):**

1. Foto di‑crop ke **kotak persegi** (sesuai frame square di preview).
2. **`OpenRouterClassifierService`** mengirim gambar (di‑resize 512/1024px) + prompt ke **Gemma**:
   - **single** → `classify()` → `{kategori, yakin}`.
   - **mixed** → `classifyMultiple()` → array `{kategori, yakin, box}`; box dalam koordinat **0..1000** dikonversi ke 0..1 lalu ke piksel untuk **meng-crop tiap objek**.
3. Hasil dipetakan ke `ScanResult` (kategori + confidence + bounding box + crop). `kaca` tidak pernah muncul (di luar daftar prompt).

**Jalur cadangan (on‑device, saat cloud tak terkonfigurasi/offline/gagal):**

- `RTDETRService` dicoba dulu sebagai detektor, **tetapi saat ini gagal load** (`Bad state: failed precondition`) → langsung fallback.
- `TFLiteService.classifyImage()` mengklasifikasi gambar (atau center‑crop) on‑device; output `kaca` → `lainnya` (`_suppressKaca`).
- `InterpreterFactory` mencoba delegate GPU lalu fallback CPU saat memuat model.

> Konsekuensi: kualitas/akurasi yang terlihat sekarang berasal dari **Gemma cloud**, bukan TFLite. Box dari Gemma "cukup baik" namun **bukan presisi detektor khusus** (Gemma = LLM, bukan YOLO/RT‑DETR).

---

## Alur Teknis End‑to‑End (Capture → Hasil)

```
[Kamera live preview]  (preview = container SQUARE, BoxFit.cover)
        │  user potret / countdown selesai
        ▼
[takePicture() → JPEG]  → CROP ke center-square (cocok dgn frame)  (scanning_screen.dart)
        │  user "Gunakan Foto Ini"
        ▼
[_runClassification(bytes)]  ── animasi scanning UX ──┐
        ├── single ─► scanProvider.classifyImage()    │
        └── mixed  ─► scanProvider.classifyMultipleImages()
        ▼
┌──────────── single ────────────┐     ┌──────────── mixed ────────────┐
│ cek dataset lokal (cache)       │     │ RT-DETR (gagal load)           │
│ RT-DETR (gagal) → fallback      │     │   → Gemma classifyMultiple()   │
│ Gemma classify(crop) →override  │     │   → array {kategori,yakin,box} │
│ (cloud off → TFLite center-crop)│     │   → crop tiap objek dari box   │
└─────────────────────────────────┘     └────────────────────────────────┘
        ▼
[ScanResult: kategori, confidence, boundingBox, croppedImage, allProbabilities]
        ▼
[Simpan lokal + sync ke Supabase (best-effort, non-blocking)]
        ▼
[Routing]  single: <0.50 → /unknown ; <0.70 → /low-confidence ; else /result
           mixed : ada objek confident → /multi-result (carousel) ; else /unknown
        ▼
[multi_result: carousel] slide 0 = scene + semua kotak ; slide 1..N = crop tiap objek
        ▼
[Koreksi manual] correctResult() → label 'human' → re-sync ke Supabase
```

**Konstanta nyata (dari kode):**

| Parameter                       | Nilai                                  | Lokasi                                 |
| ------------------------------- | -------------------------------------- | -------------------------------------- |
| Model Gemma                     | `google/gemma-4-26b-a4b-it`            | `openrouter_classifier_service.dart`   |
| Resolusi kirim ke Gemma         | 512px (single) / 1024px (mixed)        | `_downscaledJpegBase64`                |
| Konvensi box Gemma              | 0..1000 (dikonversi ke 0..1)           | `_parseMulti`                          |
| RT-DETR conf threshold          | 0.35                                   | `rtdetr_service.dart` (model tak load) |
| Classifier input                | 256×256, norm ImageNet                 | `tflite_service.dart`                  |
| Routing low-confidence (single) | < 0.70                                 | `scanning_screen.dart`                 |
| Durasi animasi scanning minimal | ~6 detik (UX, **bukan** latensi model) | `scanning_screen.dart`                 |

---

## Pengumpulan Data (Local‑First → Supabase)

Tiap scan terkonfirmasi dikumpulkan untuk retraining model ke depan, **tanpa memblok scan**:

```
[scan] → simpan LOKAL (Hive index + JPEG di <AppSupport>/ml_dataset/v1/)
       → SupabaseSyncService (best-effort, saat online)
       → upload gambar ke bucket privat 'waste-samples'
       → INSERT baris ke tabel public.samples
```

- **Append‑only**: tiap scan/koreksi = baris baru. Koreksi manual = baris `label_source='human'`. Dedup/"ambil terbaru" dilakukan saat training, bukan di DB.
- **RLS insert‑only**: kios hanya boleh INSERT (tidak baca/ubah) → anon key yang bocor pun tak bisa menarik/mengubah data.
- Skema lengkap: `supabase/migrations/20260617000001_samples_collection.sql`.
- `SupabaseSyncService` **inert tanpa key** — bila `.env` kosong, app tetap jalan lokal saja.

---

## Validasi & "Checker"

Mekanisme quality control terhadap output:

1. **Crop berbasis koordinat** — Gemma hanya menerima **crop objek** (dari box‑nya), bukan seluruh frame → background (mis. pakaian) tidak ikut mengganggu klasifikasi.
2. **Gerbang detektor (single)** — Gemma override kategori on‑device; bila tak ada objek terdeteksi → fallback center‑crop (drop tepi frame), bukan menebak frame penuh.
3. **Ambang confidence** — single < 0.50 → `/unknown-detected`; < 0.70 → `/low-confidence`.
4. **Human‑in‑the‑loop** — `correctResult()` menyimpan koreksi (label `human`) yang re‑sync ke Supabase sebagai data berbobot tinggi untuk retraining.

> **Penting (untuk paper):** Vision‑LLM (Gemma) **adalah** komponen AI cloud yang sekarang dipakai — jadi jangan klaim "murni on‑device / tanpa cloud / tanpa LLM". Deskripsi jujur: _hybrid_ (cloud‑first Vision‑LLM + cadangan TFLite on‑device).

---

## Metrik Model

> **Status: BELUM ADA angka akurasi.** Repo tidak berisi notebook training, skrip evaluasi, test set, maupun benchmark. **Jangan mengarang** angka akurasi/presisi/kecepatan untuk paper. Tambahan: jalur utama sekarang adalah **Gemma cloud**, sehingga "akurasi on‑device TFLite" bukan representasi mode utama. Proxy akurasi lapangan paling jujur = **correction rate** (seberapa sering pengguna mengoreksi).

Yang dapat diverifikasi dari repo:

| Properti         | RT‑DETR (TFLite)          | Classifier (TFLite)              |
| ---------------- | ------------------------- | -------------------------------- |
| File             | `rtdetr_best_fp32.tflite` | `waste_classifier.tflite`        |
| Ukuran           | ~63,2 MB                  | ~16,5 MB                         |
| Presisi          | FP32                      | FP32                             |
| Input            | 640×640×3                 | 256×256×3                        |
| Status di device | **gagal load**            | load (CPU), dipakai sbg fallback |

---

## Alur Pengguna

```
/ (idle) → /welcome (nama) → /onboarding → /mode-select (single/mixed)
  → /camera-guide → /countdown → /scanning (preview → potret → analisis)
  → /result (single) atau /multi-result (mixed, carousel)
  → /continue-session → (lagi → /scanning | selesai → /thank-you)
```

Edge‑case: `/out-of-frame`, `/too-large`, `/low-confidence`, `/unknown-detected`, `/manual-correction`, `/mixed-*`, dll. Definisi lengkap di `lib/app.dart`.

---

## Sistem Desain

- **Warna** — primary ungu `#7C5CFC`; tiap kategori punya warna khas.
- **Tipografi** — heading **Baloo 2 ExtraBold**, body **Plus Jakarta Sans**.
- **Responsif** (`app_responsive.dart`) — target 1194×834; helper `sp/rs/wp/hp`; breakpoint `isPhone (<600)`, `isTablet (≥600)`.

---

## Konfigurasi (`.env`)

`.env` (gitignored, **tidak** di-commit) di root proyek:

```bash
# AI cloud utama (OpenRouter / Gemma)
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxx

# Pengumpulan data (Supabase)
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=sb_publishable_xxxx     # publishable/anon saja, JANGAN service_role

# Opsional (jalur Gemini lama)
GEMINI_API_KEY=...
```

> ⚠️ `.env` di-bundle sebagai asset → **key ikut masuk ke APK**. Siapa pun yang memakai APK akan memakai **saldo OpenRouter Anda**. Untuk produksi, proxy lewat backend.

Setup Supabase: jalankan `supabase/migrations/20260617000001_samples_collection.sql` di SQL Editor project Anda (membuat tabel `samples`, RLS, bucket `waste-samples`).

---

## Memulai

**Prasyarat:** Flutter SDK (Dart `^3.12.1`), Android/iOS device, kamera, **internet** (untuk jalur Gemma), `.env` terisi.

```bash
flutter pub get
flutter run
flutter analyze
flutter build apk --release                # universal (besar, ~360MB)
flutter build apk --release --split-per-abi # per-ABI (arm64 ~182MB)
```

**Perizinan:** kamera (via `permission_handler`); konfigurasi di `android/app/src/main/AndroidManifest.xml` & `ios/Runner/Info.plist`.

> Catatan ukuran: APK besar karena model `fp32` ~80MB + native lib **TF Flex delegate** (~65MB/ABI). Kuantisasi int8 + hilangkan Flex = PR performa ke depan.

---

## Catatan & Keterbatasan (jujur)

- **RT‑DETR on‑device gagal load** (`failed precondition`, kemungkinan butuh TF Select/Flex ops). Deteksi multi‑objek kini ditangani **Gemma cloud**, bukan RT‑DETR.
- **Butuh internet** untuk jalur utama (Gemma). Offline → fallback classifier on‑device (akurasi/format berbeda, tanpa box).
- **Box dari Gemma** = Vision‑LLM grounding (cukup baik, **bukan** presisi detektor khusus).
- **Nol metrik akurasi** terukur — jangan difabrikasi.
- **Key di `.env` ter‑bundle** ke APK (risiko biaya/keamanan) — gunakan key terbatas saat berbagi.

---

## Lisensi

Belum ditentukan.
