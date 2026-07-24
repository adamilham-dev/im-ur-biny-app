# I'm Ur Biny — Technical Documentation

> **"I'm ur Biny"** — AI Waste Sorting Interactive Display

---

## Daftar Isi

1. [Gambaran Umum](#1-gambaran-umum)
2. [Fitur Utama](#2-fitur-utama)
3. [Arsitektur & Tech Stack](#3-arsitektur--tech-stack)
4. [Struktur Direktori](#4-struktur-direktori)
5. [Alur Aplikasi (User Flow)](#5-alur-aplikasi-user-flow)
6. [Daftar Screen & Deskripsi](#6-daftar-screen--deskripsi)
7. [Data Model](#7-data-model)
8. [State Management (Providers)](#8-state-management-providers)
9. [Service Layer](#9-service-layer)
10. [AI / Machine Learning](#10-ai--machine-learning)
11. [Tema & UI](#11-tema--ui)
12. [Shared Widgets](#12-shared-widgets)
13. [Assets](#13-assets)
14. [Konfigurasi & Build](#14-konfigurasi--build)

---

## 1. Gambaran Umum

**ImUrBiny** adalah aplikasi Flutter berbasis AI untuk klasifikasi sampah secara real-time menggunakan kamera perangkat. Aplikasi ini dirancang sebagai **interactive display** (layar interaktif) yang ditempatkan di area pengelolaan sampah, membantu pengguna mengidentifikasi jenis sampah dan cara pembuangannya yang benar.

Mascot resmi aplikasi ini adalah **Biny** — karakter animasi yang mendampingi pengguna di setiap tahap proses scan.

### Tujuan Aplikasi

- Mengklasifikasikan sampah ke dalam 6 kategori (Plastik, Kertas, Organik, Logam, Kaca, Residu)
- Memberikan panduan cara membuang sampah yang benar
- Mendukung scan **single item** (satu objek) dan **mixed waste** (campuran beberapa objek)
- Mengedukasi pengguna dengan fakta menarik tentang pengelolaan sampah
- Mengumpulkan data koreksi pengguna untuk meningkatkan akurasi model AI

---

## 2. Fitur Utama

| Fitur                          | Deskripsi                                                                          |
| ------------------------------ | ---------------------------------------------------------------------------------- |
| **AI Classification**          | Klasifikasi real-time menggunakan TensorFlow Lite (EfficientNet-B0)                |
| **Real-time Object Detection** | Deteksi objek via analisis luminance piksel pada camera preview                    |
| **Bounding Box**               | Kotak pembatas real-time di sekeliling objek yang terdeteksi dengan label kategori |
| **Mixed Waste Mode**           | Scan beberapa sampah sekaligus (maksimal 5 objek)                                  |
| **Camera Guide**               | Panduan penempatan objek dengan boundary box dan status validasi                   |
| **Manual Correction**          | Pengguna bisa mengoreksi prediksi AI                                               |
| **Gamification (XP)**          | Sistem poin untuk mendorong penggunaan                                             |
| **Responsive Design**          | Mendukung portrait (handphone) dan landscape (tablet)                              |
| **Mascot Animasi (Biny)**      | 21 ekspresi animasi di setiap screen                                               |
| **Educational Content**        | Fakta menarik dan panduan pembuangan per kategori                                  |
| **Data Collection**            | Menyimpan hasil koreksi untuk training ulang model                                 |

---

## 3. Arsitektur & Tech Stack

### Arsitektur

```
┌─────────────────────────────────────────────┐
│                  Flutter UI                  │
│         (Screens + Shared Widgets)           │
├─────────────────────────────────────────────┤
│            Riverpod Providers                │
│    (StateNotifier + StateProvider)           │
├──────────┬──────────┬───────────────────────┤
│  Camera   │  TFLite  │  Object Validator     │
│  Service  │  Service │  Service               │
├──────────┴──────────┴───────────────────────┤
│         SharedPreferences (Storage)          │
│         Assets (Models, Images, Icons)       │
└─────────────────────────────────────────────┘
```

### Tech Stack

| Komponen         | Teknologi                                 |
| ---------------- | ----------------------------------------- |
| Framework        | Flutter 3.x (Dart)                        |
| State Management | Riverpod (flutter_riverpod)               |
| Routing          | GoRouter                                  |
| AI/ML            | TensorFlow Lite (tflite_flutter)          |
| Kamera           | camera (CameraX)                          |
| Font             | Google Fonts (Plus Jakarta Sans, Baloo 2) |
| SVG              | flutter_svg                               |
| Storage          | SharedPreferences                         |
| Image Processing | image package                             |
| Model Training   | PyTorch → ONNX → TFLite                   |

### Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter_riverpod: ^2.6.1
  go_router: ^14.8.1
  google_fonts: ^6.2.1
  flutter_svg: ^2.1.0
  camera: ^0.11.0
  shared_preferences: ^2.3.0
  path_provider: ^2.1.0
  permission_handler: ^11.3.0
  tflite_flutter: ^0.11.0
  image: ^4.0.0
```

---

## 4. Struktur Direktori

```
imurbiny/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── app.dart                           # GoRouter configuration
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart         # Spacing, sizing, animation constants
│   │   ├── models/
│   │   │   ├── scan_result.dart           # Hasil scan (item, kategori, confidence)
│   │   │   ├── user_session.dart          # Sesi pengguna (XP, history, stats)
│   │   │   └── waste_category.dart        # Enum 6 kategori sampah + detail
│   │   ├── providers/
│   │   │   ├── app_provider.dart          # Scan mode, selected category
│   │   │   ├── camera_guide_provider.dart # Real-time detection + classification
│   │   │   ├── camera_provider.dart       # Camera service lifecycle
│   │   │   ├── scan_provider.dart         # Classification logic + results
│   │   │   └── session_provider.dart      # User session state
│   │   ├── services/
│   │   │   ├── camera_service.dart        # Camera init, capture, dispose
│   │   │   ├── object_validator_service.dart # Object detection via pixel analysis
│   │   │   ├── session_service.dart       # SharedPreferences persistence
│   │   │   └── tflite_service.dart        # TFLite model loading & inference
│   │   └── theme/
│   │       ├── app_colors.dart            # Color palette (40+ colors)
│   │       ├── app_responsive.dart        # Responsive scaling utilities
│   │       ├── app_theme.dart             # Material3 theme
│   │       └── app_typography.dart        # Text styles
│   │
│   ├── features/
│   │   ├── idle/                          # Screen 01 — Screensaver
│   │   ├── welcome/                       # Screen 02 — Welcome
│   │   ├── onboarding/                    # Screen 03 — Onboarding (4 steps)
│   │   ├── mode_select/                   # Screen 04 — Mode Selection
│   │   ├── category_select/               # Screen 05 — Category Selection
│   │   ├── camera_guide/                  # Screen 06 — Camera Guide
│   │   ├── scanning/                      # Screen 07 — Scanning Animation
│   │   ├── countdown/                     # Screen 08 — Countdown 3-2-1
│   │   ├── result/                        # Screen 09 — Result Detection
│   │   ├── multi_result/                  # Screen 10 — Multi-Result (Mixed)
│   │   ├── detail_item/                   # Screen 11 — Detail Item Popup
│   │   ├── unknown_detected/              # Screen 12 — Unknown Detected
│   │   ├── analyzing/                     # Screen 13 — Analyzing (AI Agent)
│   │   ├── conclusion_new/                # Screen 14 — Conclusion (New Category)
│   │   ├── conclusion_existing/           # Screen 15 — Conclusion (Existing)
│   │   ├── dataset_saved/                 # Screen 16 — Dataset Saved
│   │   ├── continue_session/              # Screen 17 — Continue Session
│   │   ├── thank_you/                     # Screen 18 — Thank You
│   │   ├── manual_correction/             # Koreksi manual kategori
│   │   ├── out_of_frame/                  # Error: Objek di luar frame
│   │   ├── too_large/                     # Error: Objek terlalu besar
│   │   ├── low_confidence/                # Error: Confidence rendah
│   │   ├── mixed_attached/                # Mixed: Objek menempel
│   │   ├── mixed_partial/                 # Mixed: Objek partial
│   │   ├── mixed_too_many/                # Mixed: Terlalu banyak objek
│   │   ├── mixed_check/                   # Mixed: Verifikasi objek
│   │   └── feedback/                      # Feedback pengguna
│   │
│   └── shared/
│       └── widgets/
│           ├── biny_mascot.dart            # Mascot animasi (21 ekspresi)
│           ├── blob_background.dart        # Decorative blob shapes
│           ├── cta_chip.dart               # CTA button chip
│           ├── eco_icon.dart               # Eco icon widget
│           ├── led_indicator.dart          # Status LED
│           └── placeholder_screen.dart     # Empty state template
│
├── assets/
│   ├── images/                            # SVG animations (Biny, blobs, eco icons)
│   ├── icons/                             # PNG icons (categories, modes)
│   └── models/                            # TFLite, ONNX, PyTorch models
│
├── android/                               # Android native config
├── test/                                  # Unit & widget tests
│
├── train_and_export.py                    # Training script (EfficientNet)
├── train_mobilenet.py                     # Training script (MobileNet)
├── export_tflite.py                       # Export PyTorch → TFLite
├── prepare_hf_dataset.py                  # Dataset preparation
└── pubspec.yaml                           # Flutter project config
```

---

## 5. Alur Aplikasi (User Flow)

### Single Mode Flow

```
[Idle/ScreenSaver]
       ↓ (tap)
[Welcome] → Input nama
       ↓
[Onboarding] → 4 langkah tutorial
       ↓
[Mode Select] → Pilih "Single"
       ↓
[Category Select] → Pilih kategori (opsional)
       ↓
[Camera Guide] → Live camera + deteksi objek + validasi
       ↓ (objek ready, tekan "Mulai Scan")
[Countdown] → 3-2-1
       ↓
[Scanning] → Animasi scan + capture + klasifikasi AI
       ↓
   ┌─────────────┐
   │ Berhasil?    │
   ├─ Ya ────────→ [Result Screen] → Info kategori, confidence, XP
   │                    ↓
   │              [Detail Item] (popup) → Cara membuang + fakta
   │                    ↓
   │              [Dataset Saved] → Data tersimpan, XP bertambah
   │                    ↓
   │              [Continue Session] → Scan lagi atau selesai
   │                    ↓
   │              [Thank You]
   │
   └─ Tidak ────→ [Unknown Detected] → Scan ulang / bantu identifikasi
                       ↓
                  [Manual Correction] → Pilih kategori manual
                       ↓
                  [Analyzing] → AI memproses koreksi
                       ↓
                  [Conclusion] → XP + lanjut
```

### Mixed Mode Flow

```
[Mode Select] → Pilih "Mixed Waste"
       ↓
[Camera Guide] → Deteksi multi-objek + validasi
       │         (maks 5 objek, tidak menempel, dalam boundary)
       ↓
[Scanning] → Klasifikasi per-region
       ↓
[Multi-Result] → Daftar semua objek terdeteksi
       ↓ (tap objek)
[Detail Item] → Detail per objek
       ↓
[Continue Session] / [Thank You]
```

---

## 6. Daftar Screen & Deskripsi

### Screen Utama

| #   | Route                  | Screen                   | Deskripsi                                     |
| --- | ---------------------- | ------------------------ | --------------------------------------------- |
| 01  | `/`                    | IdleScreen               | Screensaver dengan Biny idle, tap untuk mulai |
| 02  | `/welcome`             | WelcomeScreen            | Input nama pengguna                           |
| 03  | `/onboarding`          | OnboardingScreen         | 4-step tutorial penggunaan                    |
| 04  | `/mode-select`         | ModeSelectScreen         | Pilih Single / Mixed Waste                    |
| 05  | `/category-select`     | CategorySelectScreen     | Grid 6 kategori (opsional)                    |
| 06  | `/camera-guide`        | CameraGuideScreen        | Live camera + real-time deteksi + validasi    |
| 07  | `/scanning`            | ScanningScreen           | Animasi scan + capture + AI klasifikasi       |
| 08  | `/countdown`           | CountdownScreen          | Hitung mundur 3-2-1                           |
| 09  | `/result`              | ResultScreen             | Hasil klasifikasi: kategori, confidence, XP   |
| 10  | `/multi-result`        | MultiResultScreen        | Hasil multi-objek (mixed mode)                |
| 11  | `/detail-item`         | DetailItemScreen         | Popup detail: cara membuang, fakta edukasi    |
| 12  | `/unknown-detected`    | UnknownDetectedScreen    | AI tidak yakin, opsi scan ulang / koreksi     |
| 13  | `/analyzing`           | AnalyzingScreen          | AI menganalisis koreksi pengguna              |
| 14  | `/conclusion-new`      | ConclusionNewScreen      | Kategori baru terdeteksi                      |
| 15  | `/conclusion-existing` | ConclusionExistingScreen | Kategori sudah ada di dataset                 |
| 16  | `/dataset-saved`       | DatasetSavedScreen       | Konfirmasi data tersimpan + XP                |
| 17  | `/continue-session`    | ContinueSessionScreen    | Lanjut scan atau akhiri sesi                  |
| 18  | `/thank-you`           | ThankYouScreen           | Penutup sesi + statistik                      |

### Screen Error / Edge Case

| Route                | Screen                 | Deskripsi                           |
| -------------------- | ---------------------- | ----------------------------------- |
| `/manual-correction` | ManualCorrectionScreen | Grid kategori untuk koreksi manual  |
| `/out-of-frame`      | OutOfFrameScreen       | Objek di luar area boundary         |
| `/too-large`         | TooLargeScreen         | Objek menutupi terlalu banyak frame |
| `/low-confidence`    | LowConfidenceScreen    | Confidence AI terlalu rendah        |

### Screen Mixed Mode

| Route             | Screen              | Deskripsi                 |
| ----------------- | ------------------- | ------------------------- |
| `/mixed-attached` | MixedAttachedScreen | Objek saling menempel     |
| `/mixed-partial`  | MixedPartialScreen  | Objek terdeteksi sebagian |
| `/mixed-too-many` | MixedTooManyScreen  | Lebih dari 5 objek        |
| `/mixed-check`    | MixedCheckScreen    | Perlu verifikasi objek    |

---

## 7. Data Model

### WasteCategory

Enum dengan 6 kategori utama + 1 fallback:

| Kategori    | Icon                | Warna              | Contoh Sampah                |
| ----------- | ------------------- | ------------------ | ---------------------------- |
| **Plastik** | `Icons.local_drink` | `#2196F3` (Blue)   | Botol, kemasan, plastik wrap |
| **Kertas**  | `Icons.description` | `#FFC107` (Yellow) | Kardus, koran, kertas HVS    |
| **Organik** | `Icons.eco`         | `#4CAF50` (Green)  | Sisa makanan, daun, buah     |
| **Logam**   | `Icons.build`       | `#78909C` (Gray)   | Kaleng, tutup botol, foil    |
| **Kaca**    | `Icons.wine_bar`    | `#00BCD4` (Cyan)   | Botol kaca, pecahan          |
| **Residu**  | `Icons.delete`      | `#9C27B0` (Purple) | Styrofoam, tisu, popok       |
| **Lainnya** | `Icons.help`        | `#E91E63` (Pink)   | Tidak termasuk kategori lain |

Setiap kategori memiliki:

- **`name`** — Nama tampilan
- **`subtitle`** — Contoh item
- **`icon`** — Ikon Material Design
- **`color` / `softColor`** — Warna utama dan warna soft
- **`disposalInfo`** — Ringkasan cara pembuangan
- **`disposalSteps`** — Langkah-langkah pembuangan (title + detail)
- **`eduFact`** — Fakta edukasi ("Tahukah kamu?")
- **`parse()`** — Parsing dari string (mendukung variasi nama)

### ScanResult

```dart
class ScanResult {
  final String itemName;                    // Nama item terdeteksi
  final WasteCategory category;             // Kategori klasifikasi
  final double confidence;                  // Skor keyakinan (0.0-1.0)
  final String disposalInfo;                // Cara pembuangan
  final String description;                 // Deskripsi item
  final bool isCorrected;                   // Apakah dikoreksi manual
  final WasteCategory? originalCategory;    // Kategori asli sebelum koreksi
  final String? funFact;                    // Fakta edukasi
  final Map<String, double> allProbabilities; // Probabilitas semua kelas
}
```

**Methods:**

- `confidencePercent` → `"85%"`
- `topProbabilities(n)` → Top-N prediksi terurut
- `copyWith(...)` — Immutable update

### UserSession

```dart
class UserSession {
  final String userName;
  final int totalXP;              // Total poin
  final int scanCount;            // Jumlah scan
  final int correctionCount;      // Jumlah koreksi
  final List<ScanResult> scanHistory;  // Riwayat scan
}
```

**Computed Properties:**

- `uniqueCategoryCount` — Jumlah kategori unik yang di-scan
- `averageConfidence` — Rata-rata confidence
- `accuracyPercent` — Persentase akurasi

---

## 8. State Management (Providers)

### App Provider (`app_provider.dart`)

| Provider                   | Tipe                            | Deskripsi                            |
| -------------------------- | ------------------------------- | ------------------------------------ |
| `scanModeProvider`         | `StateProvider<String>`         | Mode scan: `'single'` atau `'mixed'` |
| `selectedCategoryProvider` | `StateProvider<WasteCategory?>` | Kategori yang dipilih pengguna       |

### Camera Provider (`camera_provider.dart`)

| Provider                | Tipe                    | Deskripsi               |
| ----------------------- | ----------------------- | ----------------------- |
| `cameraProvider`        | `StateNotifierProvider` | CameraService lifecycle |
| `isCameraReadyProvider` | `Provider<bool>`        | Status kamera siap      |

### Camera Guide Provider (`camera_guide_provider.dart`)

| Provider                        | Tipe                                  | Deskripsi                                  |
| ------------------------------- | ------------------------------------- | ------------------------------------------ |
| `cameraGuideProvider`           | `StateNotifierProvider`               | Validasi real-time + klasifikasi per-objek |
| `detectedObjectsProvider`       | `StateProvider<List<DetectedObject>>` | Objek terdeteksi + bounding box            |
| `scanRegionsProvider`           | `StateProvider<List<Rect>>`           | Region tersimpan untuk scanning screen     |
| `scanSourceAspectRatioProvider` | `StateProvider<double>`               | Aspect ratio gambar sumber                 |

**State Union:**

```dart
sealed class CameraGuideState {}
class CameraGuideSingle extends CameraGuideState {
  final ObjectValidation validation;  // idle, noObject, ready, tooLarge
}
class CameraGuideMixed extends CameraGuideState {
  final MixedObjectValidation validation;  // idle, noObject, ready, tooManyObjects, ...
  final int objectCount;
}
```

**DetectedObject:**

```dart
class DetectedObject {
  final Rect rect;               // Classification rect (normalized 0-1)
  final Rect displayRect;        // Display rect (tight, normalized 0-1)
  final String categoryName;     // "Plastik", "Kertas", etc.
  final double confidence;       // 0.0-1.0
  final ObjectStatus status;     // readable, tooClose, outsideBoundary, unsure
  final double sourceAspectRatio; // Width/height of source image
}
```

### Scan Provider (`scan_provider.dart`)

| Provider                      | Tipe                         | Deskripsi               |
| ----------------------------- | ---------------------------- | ----------------------- |
| `scanProvider`                | `StateNotifierProvider`      | Klasifikasi utama       |
| `scanResultProvider`          | `Provider<ScanResult?>`      | Hasil scan saat ini     |
| `isScanningProvider`          | `Provider<bool>`             | Status scanning         |
| `isCorrectedProvider`         | `Provider<bool>`             | Apakah dikoreksi        |
| `multiResultsProvider`        | `Provider<List<ScanResult>>` | Hasil multi-scan        |
| `capturedImageProvider`       | `StateProvider<Uint8List?>`  | Gambar hasil capture    |
| `selectedDetailIndexProvider` | `StateProvider<int>`         | Index item yang dipilih |
| `tfliteServiceProvider`       | `Provider<TFLiteService>`    | TFLite lifecycle        |

### Session Provider (`session_provider.dart`)

| Provider            | Tipe                         | Deskripsi          |
| ------------------- | ---------------------------- | ------------------ |
| `sessionProvider`   | `StateProvider<UserSession>` | Data sesi pengguna |
| `userNameProvider`  | `Provider<String>`           | Nama pengguna      |
| `xpProvider`        | `Provider<int>`              | Total XP           |
| `scanCountProvider` | `Provider<int>`              | Jumlah scan        |

---

## 9. Service Layer

### CameraService (`camera_service.dart`)

```dart
class CameraService {
  Future<void> initializeCamera();      // Init back camera, autofocus
  Future<Uint8List?> captureSmallFrame(); // takePicture() → bytes
  Future<XFile?> capturePhoto();         // Full-res capture
  void dispose();                        // Release resources
}
```

**Konfigurasi:**

- Kamera belakang (back camera)
- Flash: off
- Auto-focus: enabled
- Resolution: highest available

### TFLiteService (`tflite_service.dart`)

```dart
class TFLiteService {
  Future<void> loadModel();
  Future<ScanResult?> classifyImage(Uint8List bytes);
  Future<List<ScanResult>> classifyMultipleImages(Uint8List bytes, {List<Rect>? regions});
  ScanResult? classifyFrameQuick(Uint8List bytes);
  void dispose();
}
```

**Detail Model:**

- **Arsitektur**: EfficientNet-B0
- **Input**: 256x256 RGB
- **Output**: 6 kelas (Kaca, Kertas, Logam, Organik, Plastik, Residu)
- **Threshold**: 0.35 (minimum confidence)
- **Preprocessing**:
  - Resize ke 256x256
  - Deteksi background gelap (papan hitam) → brightening
  - Normalisasi ImageNet (mean: [0.485, 0.456, 0.406], std: [0.229, 0.224, 0.225])

### ObjectValidatorService (`object_validator_service.dart`)

```dart
class ObjectValidatorService {
  Future<ObjectValidationResult> validate(Uint8List jpegBytes);      // Single mode
  Future<MixedValidationResult> validateMixed(Uint8List jpegBytes);  // Mixed mode
  Future<List<DetectedRegion>> detectObjectRegions(Uint8List bytes);  // Region detection
}
```

**Algoritma Deteksi:**

1. Decode JPEG → resize ke 128x128
2. Binary threshold (luminance > 80)
3. BFS flood fill → connected component labeling
4. Filter noise (minimum 25 piksel)
5. Hitung bounding box per cluster

**Hasil:**

```dart
class DetectedRegion {
  final Rect displayRect;         // Tight bounding box (untuk UI)
  final Rect classificationRect;  // Padded + squared (untuk model)
}
```

**Validasi Single Mode:**

| State      | Kondisi             |
| ---------- | ------------------- |
| `noObject` | Coverage < 5%       |
| `tooLarge` | Coverage > 65%      |
| `ready`    | 5% ≤ coverage ≤ 65% |

**Validasi Mixed Mode:**

| State                   | Kondisi                              |
| ----------------------- | ------------------------------------ |
| `noObject`              | Coverage < 5%                        |
| `tooManyObjects`        | Cluster > 5                          |
| `objectsOverlapping`    | Cluster area > 30% boundary          |
| `objectOutsideBoundary` | >30% piksel cluster di luar boundary |
| `ready`                 | 1-5 cluster, semua dalam boundary    |

**Parameter:**

- Analysis size: 128x128
- Luminance threshold: 80
- Boundary fraction: 92% (center)
- Min cluster area: 25 piksel
- Max objects: 5
- Padding klasifikasi: 20% + squared

### SessionService (`session_service.dart`)

```dart
class SessionService {
  static const int xpNewCategory = 10;
  static const int xpExistingCategory = 5;
  static const int xpCorrection = 2;

  Future<UserSession> loadSession();
  Future<void> saveSession(UserSession session);
  Future<void> resetSession();
}
```

**Storage:** SharedPreferences dengan JSON serialization

---

## 10. AI / Machine Learning

### Pipeline Training

```
Dataset (HuggingFace / Local)
       ↓
[prepare_hf_dataset.py] → Split train/val/test
       ↓
[train_and_export.py] → Train EfficientNet-B0 (PyTorch)
       ↓
[export_tflite.py] → Export: PyTorch → ONNX → TFLite
       ↓
waste_classifier.tflite (17MB, float32)
       ↓
assets/models/ → Flutter app reads at runtime
```

### Model Spec

| Parameter   | Nilai                   |
| ----------- | ----------------------- |
| Arsitektur  | EfficientNet-B0         |
| Framework   | PyTorch → ONNX → TFLite |
| Input size  | 256x256 RGB             |
| Output      | 6 kelas                 |
| Tipe        | float32                 |
| Ukuran file | ~17MB                   |

### Label (Kelas)

| Index | Label   |
| ----- | ------- |
| 0     | Kaca    |
| 1     | Kertas  |
| 2     | Logam   |
| 3     | Organik |
| 4     | Plastik |
| 5     | Residu  |

### Inference Flow

1. **Capture** — CameraX `takePicture()` → JPEG bytes
2. **Preprocess** — Resize 256x256, deteksi background gelap → brightening, normalisasi ImageNet
3. **Inference** — TFLite interpreter → output probabilities
4. **Post-process** — Ambil kelas tertinggi, threshold confidence 0.35
5. **Result** — `ScanResult` dengan kategori, confidence, disposal info

### Multi-object Classification (Mixed Mode)

1. **detectObjectRegions()** — BFS flood fill pada grid 128x128 → `List<DetectedRegion>`
2. **Crop per region** — Potong gambar berdasarkan `classificationRect` (padded + squared)
3. **Classify each crop** — TFLite inference per crop
4. **Fallback** — Jika multi-classify gagal, klasifikasi whole-image sebagai fallback

---

## 11. Tema & UI

### Color Palette (`app_colors.dart`)

**Primary:**

- `primary` = `#7C5CFC` (Ungu utama)
- `primaryPress` = `#5B3FD6`
- `primarySoft` = `#EDE8FF`
- `primaryLight` = `#B8AAFF`
- `primaryDark` = `#4A36B0`

**Background:**

- `background` = `#FBFAFF`
- `backgroundDark` = `#1A1434`

**Text:**

- `textPrimary` = `#2B2A45`
- `textSecondary` = `#5C5980`
- `textMuted` = `#9494AD`
- `textOnPrimary` = `#FFFFFF`

**Semantic:**

- Green: `#22C55E` (success)
- Yellow: `#F59E0B` (warning)
- Red: `#EF4444` (error)

**Kategori:**

- Plastik: `#2196F3` / soft `#E3F2FD`
- Kertas: `#FFC107` / soft `#FFF8E1`
- Organik: `#4CAF50` / soft `#E8F5E9`
- Logam: `#78909C` / soft `#ECEFF1`
- Kaca: `#00BCD4` / soft `#E0F7FA`
- Residu: `#9C27B0` / soft `#F3E5F5`

### Typography

- **Headings**: Baloo 2 (Google Fonts) — weight 700-800
- **Body**: Plus Jakarta Sans (Google Fonts) — weight 400-700

### Responsive Design (`app_responsive.dart`)

| Parameter     | Rumus                | Range      |
| ------------- | -------------------- | ---------- |
| Font scale    | `shortestSide / 834` | 0.55 — 1.3 |
| Spacing scale | `shortestSide / 834` | 0.5 — 1.4  |
| Design target | iPad landscape       | 1194x834   |

**Layout Strategy:**

- **Portrait**: Column layout (camera atas, panel bawah)
- **Landscape**: Row layout (camera kiri, panel kanan)
- Setiap screen cek `AppResponsive.isPortrait(size)` untuk branching

---

## 12. Shared Widgets

### BinyMascot

Mascot animasi SVG dengan 21 ekspresi:

| Ekspresi              | Konteks            |
| --------------------- | ------------------ |
| `idle`                | Screensaver        |
| `welcome`             | Welcome screen     |
| `onboard1`–`onboard4` | Onboarding steps   |
| `mode`                | Mode selection     |
| `category`            | Category selection |
| `guide`               | Camera guide       |
| `countdown`           | Countdown          |
| `scanning`            | Scanning animation |
| `result`              | Scan result        |
| `multiResult`         | Multi-result       |
| `detail`              | Detail item        |
| `unknown`             | Unknown detected   |
| `analyzing`           | AI analyzing       |
| `conclusionNew`       | New category       |
| `conclusionExisting`  | Existing category  |
| `datasetSaved`        | Dataset saved      |
| `cont`                | Continue session   |
| `feedback`            | Feedback           |
| `thankyou`            | Thank you          |

**Animasi:**

- Bobbing (vertikal bounce)
- Head tilt (untuk ekspresi thinking)
- Arm wave / pointing
- Eye blinking
- Particle effects: sparkles, hearts, think bubbles, scan lines, confetti

### Widget Lainnya

| Widget           | Fungsi                                 |
| ---------------- | -------------------------------------- |
| `BlobBackground` | Dekorasi background dengan blob shapes |
| `CTAChip`        | Tombol call-to-action dengan ikon      |
| `EcoIcon`        | Ikon lingkungan                        |
| `LEDIndicator`   | Lampu status (hijau/abu)               |

---

## 13. Assets

### Images (`assets/images/`)

- `biny_01_idle.svg` sampai `biny_21_low_confidence.svg` — Mascot per screen
- `blob_1.svg` sampai `blob_purple.svg` — Background decorations
- `eco_icon_*.png` — Eco icons

### Icons (`assets/icons/`)

- `cat_plastik.png`, `cat_kertas.png`, `cat_organik.png`, `cat_logam.png`, `cat_kaca.png`, `cat_residu.png`
- `mode_single.png`, `mode_mixed.png`

### Models (`assets/models/`)

- `waste_classifier.tflite` — Model utama (~17MB, float32)
- `waste_classifier.onnx` — Format ONNX (~17MB)
- `waste_efficientnet_best.pth` — PyTorch checkpoint (~17MB)
- `waste_mobilenet_best.pth` — MobileNet checkpoint (~6MB)

---

## 14. Konfigurasi & Build

### Build Commands

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Run on device
flutter run
```

### Minimum Requirements

- Flutter SDK: ^3.12.1
- Dart SDK: ^3.12.1
- Android: minSdkVersion 21+
- Camera permission required
- Model file harus ada di `assets/models/waste_classifier.tflite`

### Environment Setup

1. Clone repository
2. `flutter pub get`
3. Pastikan `waste_classifier.tflite` ada di `assets/models/`
4. `flutter run` atau `flutter build apk --release`

---

## XP System

| Aksi                   | XP     |
| ---------------------- | ------ |
| Scan kategori baru     | +10 XP |
| Scan kategori existing | +5 XP  |
| Koreksi manual         | +2 XP  |

---

_Dokumentasi terakhir diperbarui: Juni 2026_
