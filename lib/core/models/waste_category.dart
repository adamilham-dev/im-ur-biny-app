import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum WasteCategory {
  plastik,
  kertas,
  organik,
  logam,
  residu,
  lainnya;

  /// Stable lowercase identifier for SERIALIZATION (Hive, Supabase, exports).
  ///
  /// Use this — NOT [index] — to persist a category. The enum *declaration
  /// order* here (plastik, kertas, ...) intentionally differs from the trained
  /// MODEL class order (Kaca(0), Kertas(1), ...), so `index` is
  /// meaningless across the model boundary and brittle if constants are
  /// reordered. This id only changes if a constant is renamed (a deliberate
  /// code change), never on reorder.
  ///
  /// Declared in the enum body (not the extension) so it's a real member of the
  /// type — callable wherever WasteCategory is visible, no extra import needed.
  String get stableId {
    switch (this) {
      case WasteCategory.plastik:
        return 'plastik';
      case WasteCategory.kertas:
        return 'kertas';
      case WasteCategory.organik:
        return 'organik';
      case WasteCategory.logam:
        return 'logam';
      case WasteCategory.residu:
        return 'residu';
      case WasteCategory.lainnya:
        return 'lainnya';
    }
  }

  /// Inverse of [stableId]. Unknown / legacy values fall back to [lainnya].
  static WasteCategory fromStableId(String id) {
    final lower = id.toLowerCase().trim();
    for (final c in WasteCategory.values) {
      if (c.stableId == lower) return c;
    }
    return WasteCategory.lainnya;
  }
}

extension WasteCategoryX on WasteCategory {
  String get name {
    switch (this) {
      case WasteCategory.plastik:
        return 'Plastik';
      case WasteCategory.kertas:
        return 'Kertas';
      case WasteCategory.organik:
        return 'Organik';
      case WasteCategory.logam:
        return 'Logam';
      case WasteCategory.residu:
        return 'Residu';
      case WasteCategory.lainnya:
        return 'Lainnya';
    }
  }

  IconData get icon {
    switch (this) {
      case WasteCategory.plastik:
        return Icons.local_drink;
      case WasteCategory.kertas:
        return Icons.description;
      case WasteCategory.organik:
        return Icons.eco;
      case WasteCategory.logam:
        return Icons.build;
      // case WasteCategory.kaca:
      //   return Icons.local_bar;
      case WasteCategory.residu:
        return Icons.delete;
      case WasteCategory.lainnya:
        return Icons.more_horiz;
    }
  }

  Color get color {
    switch (this) {
      case WasteCategory.plastik:
        return AppColors.catPlastik;
      case WasteCategory.kertas:
        return AppColors.catKertas;
      case WasteCategory.organik:
        return AppColors.catOrganik;
      case WasteCategory.logam:
        return AppColors.catLogam;
      // case WasteCategory.kaca:
      //   return AppColors.catKaca;
      case WasteCategory.residu:
        return AppColors.catResidu;
      case WasteCategory.lainnya:
        return AppColors.catLainnya;
    }
  }

  Color get softColor {
    switch (this) {
      case WasteCategory.plastik:
        return AppColors.catPlastik.withValues(alpha: 0.3);
      case WasteCategory.kertas:
        return AppColors.catKertas.withValues(alpha: 0.3);
      case WasteCategory.organik:
        return AppColors.catOrganik.withValues(alpha: 0.3);
      case WasteCategory.logam:
        return AppColors.catLogam.withValues(alpha: 0.3);
      // case WasteCategory.kaca:
      //   return AppColors.catKaca.withValues(alpha: 0.3);
      case WasteCategory.residu:
        return AppColors.catResidu.withValues(alpha: 0.3);
      case WasteCategory.lainnya:
        return AppColors.catLainnya.withValues(alpha: 0.3);
    }
  }

  String get subtitle {
    switch (this) {
      case WasteCategory.plastik:
        return 'Botol, kemasan';
      case WasteCategory.kertas:
        return 'Kardus, koran';
      case WasteCategory.organik:
        return 'Sisa makanan';
      case WasteCategory.logam:
        return 'Kaleng, tutup';
      case WasteCategory.residu:
        return 'Tidak terdaur';
      case WasteCategory.lainnya:
        return 'Biar AI tentukan';
    }
  }

  String get disposalInfo {
    switch (this) {
      case WasteCategory.plastik:
        return 'Masukkan ke tempat daur ulang plastik (biru)';
      case WasteCategory.kertas:
        return 'Masukkan ke tempat daur ulang kertas (putih)';
      case WasteCategory.organik:
        return 'Masukkan ke tempat sampah organik (hijau)';
      case WasteCategory.logam:
        return 'Masukkan ke tempat daur ulang logam (abu-abu)';
      case WasteCategory.residu:
        return 'Masukkan ke tempat sampah residu (merah)';
      case WasteCategory.lainnya:
        return 'Masukkan ke tempat sampah umum';
    }
  }

  /// Step-by-step disposal instructions.
  List<DisposalStep> get disposalSteps {
    switch (this) {
      case WasteCategory.plastik:
        return [
          DisposalStep(title: 'Kosongkan & bilas', detail: 'Buang sisa isi, bilas sebentar.'),
          DisposalStep(title: 'Masukkan ke tempat Plastik', detail: 'Tutup botol boleh disertakan.'),
        ];
      case WasteCategory.kertas:
        return [
          DisposalStep(title: 'Lipat atau ratakan', detail: 'Pastikan kertas tidak tergulung.'),
          DisposalStep(title: 'Masukkan ke tempat Kertas', detail: 'Pisahkan dari plastik pelapis.'),
        ];
      case WasteCategory.organik:
        return [
          DisposalStep(title: 'Buang ke tempat Organik', detail: 'Pisahkan dari kemasan non-organik.'),
          DisposalStep(title: 'Tutup tempat sampah', detail: 'Cegah bau dan hama.'),
        ];
      case WasteCategory.logam:
        return [
          DisposalStep(title: 'Bilas sisa isi', detail: 'Pastikan kaleng bersih.'),
          DisposalStep(title: 'Masukkan ke tempat Logam', detail: 'Tutup kaleng boleh disertakan.'),
        ];
      // case WasteCategory.kaca:
      //   return [
      //     DisposalStep(title: 'Bungkus pecahan', detail: 'Gunakan kertas/kardus agar aman.'),
      //     DisposalStep(title: 'Masukkan ke tempat Kaca', detail: 'Pisahkan dari sampah lain.'),
      //   ];
      case WasteCategory.residu:
        return [
          DisposalStep(title: 'Pastikan bukan daur ulang', detail: 'Cek kembali jenis sampah.'),
          DisposalStep(title: 'Masukkan ke tempat Residu', detail: 'Jangan campur dengan organik.'),
        ];
      case WasteCategory.lainnya:
        return [
          DisposalStep(title: 'Periksa kategori', detail: 'Cek apakah bisa didaur ulang.'),
          DisposalStep(title: 'Masukkan ke tempat umum', detail: 'Jika ragu, tempat umum saja.'),
        ];
    }
  }

  /// Educational fun fact ("Tahukah kamu?").
  String get eduFact {
    switch (this) {
      case WasteCategory.plastik:
        return 'Botol plastik PET bisa didaur ulang jadi serat baju, tas, bahkan botol baru. Memilah dengan benar bikin daur ulang jauh lebih mudah.';
      case WasteCategory.kertas:
        return 'Kertas karton bisa didaur ulang hingga 7 kali. Satu ton kertas daur ulang menghemat 17 pohon.';
      case WasteCategory.organik:
        return 'Sampah organik bisa diolah jadi kompos yang menyuburkan tanah dalam 2–3 bulan.';
      case WasteCategory.logam:
        return 'Kaleng aluminium bisa didaur ulang tanpa batas dan hemat 95% energi vs produksi baru.';
      // case WasteCategory.kaca:
      //   return 'Kaca 100% daur ulang tanpa kehilangan kualitas. Satu botol kaca daur ulang hemat energi untuk menyalakan lampu 4 jam.';
      case WasteCategory.residu:
        return 'Sampah residu biasanya dibakar atau ke landfill. Mengurangi residu berarti mengurangi beban lingkungan.';
      case WasteCategory.lainnya:
        return 'Banyak sampah "lainnya" sebenarnya bisa didaur ulang — cek label kemasan untuk panduan.';
    }
  }

  static WasteCategory? fromString(String value) {
    final lower = value.toLowerCase().trim();
    for (final cat in WasteCategory.values) {
      if (cat.name.toLowerCase() == lower) return cat;
    }
    // Handle common variations
    switch (lower) {
      case 'plastic':
      case 'botol plastik':
        return WasteCategory.plastik;
      case 'paper':
      case 'kardus':
        return WasteCategory.kertas;
      case 'organic':
      case 'makanan':
        return WasteCategory.organik;
      case 'metal':
      case 'kaleng':
        return WasteCategory.logam;
      // case 'glass':
      // case 'botol kaca':
      //   return WasteCategory.kaca;
      case 'residual':
        return WasteCategory.residu;
      default:
        return null;
    }
  }
}

class DisposalStep {
  final String title;
  final String detail;
  const DisposalStep({required this.title, required this.detail});
}
