import 'dart:typed_data';
import 'dart:ui';

import 'waste_category.dart';

class ScanResult {
  final String itemName;
  final WasteCategory category;
  final double confidence;
  final String disposalInfo;
  final String description;
  final bool isCorrected;
  final WasteCategory? originalCategory;
  final String? funFact;

  /// Probability breakdown for each category (e.g., {'Plastik': 0.85, 'Logam': 0.10, ...})
  final Map<String, double> allProbabilities;

  /// Bounding box from object detection (RT-DETR), null for classifier-based results.
  final Rect? boundingBox;

  /// Cropped image bytes of the detected object, null for whole-image results.
  final Uint8List? croppedImage;

  const ScanResult({
    required this.itemName,
    required this.category,
    required this.confidence,
    required this.disposalInfo,
    required this.description,
    this.isCorrected = false,
    this.originalCategory,
    this.funFact,
    this.allProbabilities = const {},
    this.boundingBox,
    this.croppedImage,
  });

  ScanResult copyWith({
    String? itemName,
    WasteCategory? category,
    double? confidence,
    String? disposalInfo,
    String? description,
    bool? isCorrected,
    WasteCategory? originalCategory,
    String? funFact,
    Map<String, double>? allProbabilities,
    Rect? boundingBox,
    Uint8List? croppedImage,
  }) {
    return ScanResult(
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      disposalInfo: disposalInfo ?? this.disposalInfo,
      description: description ?? this.description,
      isCorrected: isCorrected ?? this.isCorrected,
      originalCategory: originalCategory ?? this.originalCategory,
      funFact: funFact ?? this.funFact,
      allProbabilities: allProbabilities ?? this.allProbabilities,
      boundingBox: boundingBox ?? this.boundingBox,
      croppedImage: croppedImage ?? this.croppedImage,
    );
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  /// Returns top-N probabilities sorted descending
  List<MapEntry<String, double>> get topProbabilities {
    final entries = allProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
