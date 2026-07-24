import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_option.dart';
import '../models/waste_category.dart';
import 'local_dataset_provider.dart';

class CategoryOptionsNotifier extends StateNotifier<List<CategoryOption>> {
  final Ref _ref;
  
  static const _standardOrder = [
    WasteCategory.plastik,
    WasteCategory.kertas,
    WasteCategory.organik,
    WasteCategory.logam,
    WasteCategory.residu,
    WasteCategory.lainnya, // Auto
  ];

  CategoryOptionsNotifier(this._ref) : super([]) {
    refresh();
    _listenToDatasetChanges();
  }

  void _listenToDatasetChanges() {
    final datasetService = _ref.read(localDatasetProvider);
    // Listen to changes in the underlying dataset to automatically refresh options
    datasetService.watch().listen((_) {
      refresh();
    });
  }

  void refresh() {
    final datasetService = _ref.read(localDatasetProvider);
    final customNames = <String>{};

    for (final entry in datasetService.allEntries()) {
      if (entry.category == WasteCategory.lainnya && entry.itemName != null) {
        customNames.add(entry.itemName!);
      }
    }

    final options = <CategoryOption>[];
    
    // 1. Add standard categories
    for (final cat in _standardOrder) {
      options.add(CategoryOption.fromWasteCategory(cat));
    }

    // 2. Add custom categories
    final sortedCustomNames = customNames.toList()..sort();
    for (final name in sortedCustomNames) {
      options.add(CategoryOption.custom(name));
    }

    state = options;
  }
}

final categoryOptionsProvider =
    StateNotifierProvider<CategoryOptionsNotifier, List<CategoryOption>>((ref) {
  return CategoryOptionsNotifier(ref);
});
