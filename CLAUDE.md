# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**I'm ur Biny** — Flutter app pemilah sampah yang mengkombinasikan ML dan LLMs / AI Agent untuk display interaktif (target iPad landscape 1194×834). Inferensi ML berjalan **on-device** (offline). Teks UI berbahasa Indonesia.

## Commands

```bash
flutter pub get                 # install/update dependencies
flutter run                     # debug run on connected device
flutter run -d <device-id>      # target a specific device (flutter devices to list)
flutter analyze                 # static analysis / lint
flutter test                    # run all tests
flutter test test/foo_test.dart # run a single test file
flutter build apk --release     # release APK (Android)
flutter build ios --release     # release build (iOS)
```

## Architecture

- **State**: Riverpod (`flutter_riverpod`, `StateNotifier`). `ProviderScope` wraps the app in `lib/main.dart`. Data between screens flows through providers, **not** route parameters — GoRouter routes take no args.
- **Navigation**: GoRouter. All routes are defined in one place: `lib/app.dart`. Adding a screen = create `lib/features/<name>/presentation/<name>_screen.dart` + register its route in `lib/app.dart`.
- **Feature-per-folder**: each screen lives under `lib/features/<name>/presentation/`. Shared widgets in `lib/shared/widgets/`. Cross-cutting code (models, providers, services, theme, constants) in `lib/core/`.

### ML inference pipeline (`lib/core/services/`)

Dual-model, runs entirely on-device:

1. **`rtdetr_service.dart`** — RT-DETR object detector. Model `assets/models/rtdetr_best_fp32.tflite`, input 640×640, ImageNet normalization, conf threshold 0.35, NMS IoU 0.45, max 5 objects. Used for mixed mode and as the primary single-object detector.
2. **`tflite_service.dart`** — classifier. Model `assets/models/waste_classifier.tflite`, input 256×256, ImageNet normalization. Has adaptive brightening for dark (black-board) backgrounds before normalization.
3. **`object_validator_service.dart`** — luminance-based live validation of object position/size on the camera preview (fallback when RT-DETR unavailable).

Flow: try RT-DETR first; if it loads and finds objects, use its boxes; otherwise fall back to full-image TFLite classification. Result is a `ScanResult`.

`scanProvider` (`lib/core/providers/scan_provider.dart`) orchestrates both services — `classifyImage`, `classifyMultipleImages`, `correctResult`, `clearResult`.

### Class order (critical)

The 6 model classes are index-ordered: **`Kaca(0), Kertas(1), Logam(2), Organik(3), Plastik(4), Residu(5)`**. This order must match the trained model output — do not reorder without retraining. `WasteCategory` enum (`lib/core/models/waste_category.dart`) also has a 7th value `lainnya` for unknown items, plus per-category metadata (color, icon, subtitle, disposal steps, edu facts).

## Conventions

- App modes: `scanModeProvider` is `'single'` or `'mixed'`. Mixed mode has its own result/edge-case screens (`/multi-result`, `/mixed-*`).
- Responsive sizing goes through `lib/core/theme/app_responsive.dart` helpers (`sp/rs/wp/hp`) against the 1194×834 design target — avoid hard-coded pixel sizes for fonts/spacing.
- Camera requires permission via `permission_handler`; platform config in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.

## Notes

- `assets/models/rtdetr_best_fp32.tflite` is ~63 MB (above GitHub's 50 MB recommendation). Consider Git LFS if repo size becomes an issue.
- Git history was rewritten to drop AI co-author trailers; commit as the human author without co-author trailers.
