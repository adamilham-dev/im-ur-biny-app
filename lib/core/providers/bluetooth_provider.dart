import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/waste_category.dart';

enum BTConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class BluetoothStateNotifier extends StateNotifier<BTConnectionState> {
  BluetoothStateNotifier() : super(BTConnectionState.disconnected) {
    _initBluetooth();
  }

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _adapterStateSubscription;

  // Guard flag: mencegah double-connect saat scan menemukan device berkali-kali
  bool _isConnecting = false;

  final String _targetDeviceName = "SmartBin_ESP32";
  final Guid _serviceGuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid _characteristicGuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  Future<void> _initBluetooth() async {
    if (state == BTConnectionState.connecting || state == BTConnectionState.connected) return;

    state = BTConnectionState.connecting;

    // Request permissions
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    try {
      if (await FlutterBluePlus.isSupported == false) {
        state = BTConnectionState.error;
        debugPrint("[BLE] Bluetooth not supported on this device");
        return;
      }

      // Cancel existing adapter subscription jika ada
      _adapterStateSubscription?.cancel();

      // Listen ke adapter state SEKALI — jika sudah ON langsung scan
      bool hasStartedScan = false;
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState adapterState) {
        debugPrint("[BLE] Adapter state: $adapterState");
        if (adapterState == BluetoothAdapterState.on && !hasStartedScan) {
          hasStartedScan = true;
          _startScan();
        } else if (adapterState == BluetoothAdapterState.off) {
          state = BTConnectionState.error;
          hasStartedScan = false;
          debugPrint("[BLE] Bluetooth is OFF");
        }
      });

    } catch (e) {
      state = BTConnectionState.error;
      debugPrint("[BLE] Init Error: $e");
    }
  }

  void _startScan() {
    if (state == BTConnectionState.connected || _isConnecting) return;
    state = BTConnectionState.connecting;
    _isConnecting = false;

    _scanSubscription?.cancel();

    debugPrint("[BLE] Memulai scan BLE untuk '$_targetDeviceName'...");

    // Scan tanpa filter UUID agar lebih luas — filter by name di listener
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 20),
      androidUsesFineLocation: true,
    );

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        final name = r.device.advName.isNotEmpty
            ? r.device.advName
            : r.device.platformName;

        debugPrint("[BLE] Ditemukan: '$name' (${r.device.remoteId})");

        if (name == _targetDeviceName && !_isConnecting) {
          _isConnecting = true;
          FlutterBluePlus.stopScan();
          debugPrint("[BLE] SmartBin ditemukan! Menghubungkan...");
          _connectToDevice(r.device);
          break;
        }
      }
    }, onError: (e) {
      debugPrint("[BLE] Scan Error: $e");
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _device = device;

      // Batalkan listener koneksi lama jika ada
      _connectionSubscription?.cancel();

      _connectionSubscription = device.connectionState.listen((BluetoothConnectionState connState) {
        debugPrint("[BLE] Connection state: $connState");
        if (connState == BluetoothConnectionState.disconnected) {
          state = BTConnectionState.disconnected;
          _writeCharacteristic = null;
          _isConnecting = false;
          debugPrint("[BLE] Device terputus. Mencoba reconnect dalam 5 detik...");

          // Auto reconnect
          Future.delayed(const Duration(seconds: 5), () {
            if (state != BTConnectionState.connected &&
              state != BTConnectionState.connecting) {
              _startScan();
            }
          });
        }
      });

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      debugPrint("[BLE] Jumlah service ditemukan: ${services.length}");

      for (BluetoothService service in services) {
        debugPrint("[BLE] Service UUID: ${service.uuid}");
        if (service.uuid == _serviceGuid) {
          for (BluetoothCharacteristic c in service.characteristics) {
            debugPrint("[BLE]   Characteristic UUID: ${c.uuid}");
            if (c.uuid == _characteristicGuid) {
              _writeCharacteristic = c;
              break;
            }
          }
        }
      }

      if (_writeCharacteristic != null) {
        state = BTConnectionState.connected;
        _isConnecting = false;
        debugPrint("[BLE] ✅ Terhubung ke SmartBin_ESP32!");
      } else {
        state = BTConnectionState.error;
        _isConnecting = false;
        debugPrint("[BLE] ❌ Service/Characteristic tidak ditemukan.");
        device.disconnect();
      }

    } catch (e) {
      state = BTConnectionState.error;
      _isConnecting = false;
      debugPrint("[BLE] Connection Error: $e");
    }
  }

  Future<void> _writeSignal(String signal) async {
    if (_writeCharacteristic != null && state == BTConnectionState.connected) {
      try {
        final signalWithNewline = signal.endsWith('\n') ? signal : '$signal\n';
        // Coba withoutResponse dulu (lebih cepat), fallback ke dengan response
        await _writeCharacteristic!.write(
          ascii.encode(signalWithNewline),
          withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
        );
        debugPrint("[BLE] Signal Sent: '${signalWithNewline.replaceAll('\n', '\\n')}'");
      } catch (e) {
        debugPrint("[BLE] Write Error: $e");
      }
    } else {
      debugPrint("[BLE] Tidak bisa kirim: belum terhubung (state=$state)");
      if (state == BTConnectionState.disconnected || state == BTConnectionState.error) {
        _initBluetooth();
      }
    }
  }

  void sendCategory(WasteCategory category) {
    String signal = '';
    switch (category) {
      case WasteCategory.plastik:
        signal = 'P';
        break;
      case WasteCategory.kertas:
        signal = 'K';
        break;
      case WasteCategory.logam:
        signal = 'L';
        break;
      case WasteCategory.organik:
        signal = 'O';
        break;
      case WasteCategory.residu:
      case WasteCategory.lainnya:
        signal = 'R';
        break;
    }

    if (signal.isNotEmpty) {
      _writeSignal(signal);
    }
  }

  void sendCategories(List<WasteCategory> categories) {
    final Set<String> signals = {};
    for (final category in categories) {
      switch (category) {
        case WasteCategory.plastik:
          signals.add('P');
          break;
        case WasteCategory.kertas:
          signals.add('K');
          break;
        case WasteCategory.logam:
          signals.add('L');
          break;
        case WasteCategory.organik:
          signals.add('O');
          break;
        case WasteCategory.residu:
        case WasteCategory.lainnya:
          signals.add('R');
          break;
      }
    }

    if (signals.isNotEmpty) {
      final joinedSignal = signals.join(', ');
      _writeSignal(joinedSignal);
    }
  }

  void sendCloseAll() {
    _writeSignal('0');
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _device?.disconnect();
    super.dispose();
  }
}

final bluetoothProvider = StateNotifierProvider<BluetoothStateNotifier, BTConnectionState>((ref) {
  return BluetoothStateNotifier();
});
