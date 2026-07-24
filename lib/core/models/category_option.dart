import 'dart:ui';
import 'waste_category.dart';

class CategoryOption {
  final String id;
  final String name;
  final String subtitle;
  final Color color;
  final String iconAsset;
  final WasteCategory baseCategory;
  final bool isCustom;
  final String? customItemName;

  const CategoryOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.iconAsset,
    required this.baseCategory,
    this.isCustom = false,
    this.customItemName,
  });

  factory CategoryOption.fromWasteCategory(WasteCategory category) {
    String iconAsset;
    switch (category) {
      case WasteCategory.plastik:
        iconAsset = 'assets/images/page_5/plastik.png';
        break;
      case WasteCategory.kertas:
        iconAsset = 'assets/images/page_5/kertas.png';
        break;
      case WasteCategory.organik:
        iconAsset = 'assets/images/page_5/organik.png';
        break;
      case WasteCategory.logam:
        iconAsset = 'assets/images/page_5/logam.png';
        break;
      case WasteCategory.residu:
        iconAsset = 'assets/images/page_5/residu.png';
        break;
      case WasteCategory.lainnya:
        iconAsset = 'assets/images/page_5/auto.png';
        break;
    }

    return CategoryOption(
      id: category.stableId,
      name: category == WasteCategory.lainnya ? 'Auto' : category.name,
      subtitle: category == WasteCategory.lainnya ? 'Biar AI tentukan' : category.subtitle,
      color: category.color,
      iconAsset: iconAsset,
      baseCategory: category,
    );
  }

  factory CategoryOption.custom(String itemName) {
    final lowerName = itemName.toLowerCase();
    Color color = WasteCategory.lainnya.color;
    String iconAsset = 'assets/images/page_5/auto.png';
    String subtitle = 'Biar AI tentukan';
    
    if (lowerName.contains('kaca')) {
      color = const Color(0xFF34D6E0);
      iconAsset = 'assets/icons/cat_kaca.png';
      subtitle = 'Botol, pecahan';
    } else if (lowerName.contains('karet')) {
      color = const Color(0xFFA9734D);
      iconAsset = 'assets/icons/cat_karet.png';
      subtitle = 'Ban, alas sepatu';
    } else if (lowerName.contains('tekstil')) {
      color = const Color(0xFF44979D);
      iconAsset = 'assets/icons/cat_tekstil.png';
      subtitle = 'Baju, kain';
    } else if (lowerName.contains('elektronik')) {
      color = const Color(0xFFCDC19B);
      iconAsset = 'assets/icons/cat_elektronik.png';
      subtitle = 'Alat elektronik';
    } else if (lowerName.contains('minyak')) {
      color = const Color(0xFFCFA64E);
      iconAsset = 'assets/icons/cat_minyak.png';
      subtitle = 'Jelantah, pelumas';
    } else if (lowerName.contains('b3')) {
      color = const Color(0xFFD9708E);
      iconAsset = 'assets/icons/cat_bahayadanberacun.png';
      subtitle = 'Berbahan kimia';
    }

    return CategoryOption(
      id: 'custom_${itemName.toLowerCase().replaceAll(' ', '_')}',
      name: itemName,
      subtitle: subtitle,
      color: color,
      iconAsset: iconAsset,
      baseCategory: WasteCategory.lainnya,
      isCustom: true,
      customItemName: itemName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
