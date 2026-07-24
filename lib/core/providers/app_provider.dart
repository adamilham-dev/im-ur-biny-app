import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_option.dart';
import '../models/waste_category.dart';

// Selected scan mode: 'single' or 'mixed'
final scanModeProvider = StateProvider<String>((ref) => 'single');

// Selected category before scan
final selectedCategoryProvider =
    StateProvider<CategoryOption?>((ref) => null);

// When true, scanning screen skips camera and goes directly to scanning phase
// using the already-captured photo (for "PINDAI LAGI" / rescan)
final rescanProvider = StateProvider<bool>((ref) => false);
