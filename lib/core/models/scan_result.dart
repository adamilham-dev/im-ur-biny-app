import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'waste_category.dart';
import 'category_option.dart';

class ScanResult {
  final String itemName;
  final WasteCategory category;
  final double confidence;
  final String disposalInfo;
  final String description;
  final bool isCorrected;
  final WasteCategory? originalCategory;
  final String? funFact;
  final bool isFromGemini;

  /// Probability breakdown for each category (e.g., {'Plastik': 0.85, 'Logam': 0.10, ...})
  final Map<String, double> allProbabilities;

  /// Bounding box from object detection (RT-DETR), null for classifier-based results.
  final Rect? boundingBox;

  /// Cropped image bytes of the detected object, null for whole-image results.
  final Uint8List? croppedImage;

  final String? dynamicCategoryName;

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
    this.dynamicCategoryName,
    this.isFromGemini = false,
  });

  String get displayCategoryName {
    if (category == WasteCategory.lainnya && dynamicCategoryName != null) {
      return dynamicCategoryName!;
    }
    return category.name;
  }

  Color get displayCategoryColor {
    if (category == WasteCategory.lainnya && dynamicCategoryName != null) {
      return CategoryOption.custom(dynamicCategoryName!).color;
    }
    return category.color;
  }

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
    String? dynamicCategoryName,
    bool? isFromGemini,
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
      dynamicCategoryName: dynamicCategoryName ?? this.dynamicCategoryName,
      isFromGemini: isFromGemini ?? this.isFromGemini,
    );
  }

  /// Returns the configured color if this is a custom category, otherwise the default category color
  Color get displayColor {
    if (dynamicCategoryName == null || category != WasteCategory.lainnya) {
      return category.color;
    }
    
    final lowerName = dynamicCategoryName!.toLowerCase();
    if (lowerName.contains('kaca')) return const Color(0xFF34D6E0);
    if (lowerName.contains('karet')) return const Color(0xFFA9734D);
    if (lowerName.contains('tekstil')) return const Color(0xFF44979D);
    if (lowerName.contains('elektronik')) return const Color(0xFFCDC19B);
    if (lowerName.contains('minyak')) return const Color(0xFFCFA64E);
    if (lowerName.contains('b3')) return const Color(0xFFD9708E);

    return WasteCategory.lainnya.color;
  }

  /// Returns the custom icon asset if this is a custom category, otherwise the default category icon
  String get displayIconAsset {
    if (dynamicCategoryName != null && category == WasteCategory.lainnya) {
      final lowerName = dynamicCategoryName!.toLowerCase();
      if (lowerName.contains('kaca')) return 'assets/icons/cat_kaca.png';
      if (lowerName.contains('karet')) return 'assets/icons/cat_karet.png';
      if (lowerName.contains('tekstil')) return 'assets/icons/cat_tekstil.png';
      if (lowerName.contains('elektronik')) return 'assets/icons/cat_elektronik.png';
      if (lowerName.contains('minyak')) return 'assets/icons/cat_minyak.png';
      if (lowerName.contains('b3')) return 'assets/icons/cat_bahayadanberacun.png';
      return 'assets/images/page_5/auto.png';
    }
    
    switch (category) {
      case WasteCategory.plastik:
        return 'assets/images/page_5/plastik.png';
      case WasteCategory.kertas:
        return 'assets/images/page_5/kertas.png';
      case WasteCategory.organik:
        return 'assets/images/page_5/organik.png';
      case WasteCategory.logam:
        return 'assets/images/page_5/logam.png';
      case WasteCategory.residu:
        return 'assets/images/page_5/residu.png';
      case WasteCategory.lainnya:
        return 'assets/images/page_5/auto.png';
    }
  }


  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  /// Returns top-N probabilities sorted descending
  List<MapEntry<String, double>> get topProbabilities {
    final entries = allProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
