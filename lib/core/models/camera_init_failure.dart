/// Why [CameraService.initialize] failed — drives kiosk UI copy + actions.
enum CameraInitFailure {
  permissionDenied,
  permissionPermanentlyDenied,
  noCamera,
  hardwareError,
}

extension CameraInitFailureX on CameraInitFailure {
  String get title => switch (this) {
        CameraInitFailure.permissionDenied => 'Izin kamera diperlukan',
        CameraInitFailure.permissionPermanentlyDenied =>
          'Akses kamera diblokir',
        CameraInitFailure.noCamera => 'Kamera tidak ditemukan',
        CameraInitFailure.hardwareError => 'Kamera tidak tersedia',
      };

  String get message => switch (this) {
        CameraInitFailure.permissionDenied =>
          'Izinkan akses kamera saat diminta, lalu ketuk Coba lagi.',
        CameraInitFailure.permissionPermanentlyDenied =>
          'Buka Pengaturan → I\'m ur Biny → Kamera, lalu aktifkan.',
        CameraInitFailure.noCamera =>
          'Perangkat ini tidak memiliki kamera yang dapat digunakan.',
        CameraInitFailure.hardwareError =>
          'Gagal menghubungkan ke kamera. Coba lagi atau restart aplikasi.',
      };

  bool get canOpenSettings =>
      this == CameraInitFailure.permissionPermanentlyDenied;
}
