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
        debugPrint("Bluetooth not supported");
        return;
      }

      // Check adapter state
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState adapterState) async {
        if (adapterState == BluetoothAdapterState.on) {
          _startScan();
        } else if (adapterState == BluetoothAdapterState.off) {
          state = BTConnectionState.error;
          debugPrint("Bluetooth is off");
        }
      });

    } catch (e) {
      state = BTConnectionState.error;
      debugPrint("Bluetooth Error: $e");
    }
  }

  void _startScan() {
    if (state == BTConnectionState.connected) return;
    state = BTConnectionState.connecting;
    
    _scanSubscription?.cancel();
    
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.advName == _targetDeviceName || r.device.platformName == _targetDeviceName) {
          FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _device = device;
      
      _connectionSubscription = device.connectionState.listen((BluetoothConnectionState state) async {
        if (state == BluetoothConnectionState.disconnected) {
          this.state = BTConnectionState.disconnected;
          _writeCharacteristic = null;
          debugPrint("Device Disconnected");
          
          // Auto reconnect after a short delay
          Future.delayed(const Duration(seconds: 5), () {
            if (this.state != BTConnectionState.connected && this.state != BTConnectionState.connecting) {
              _startScan();
            }
          });
        }
      });

      await device.connect(autoConnect: false);
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid == _serviceGuid) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid == _characteristicGuid) {
              _writeCharacteristic = c;
              break;
            }
          }
        }
      }

      if (_writeCharacteristic != null) {
        state = BTConnectionState.connected;
        debugPrint("Connected to SmartBin_ESP32 BLE");
      } else {
        state = BTConnectionState.error;
        debugPrint("Service/Characteristic not found");
        device.disconnect();
      }

    } catch (e) {
      state = BTConnectionState.error;
      debugPrint("Connection Error: $e");
    }
  }

  Future<void> _writeSignal(String signal) async {
    if (_writeCharacteristic != null && state == BTConnectionState.connected) {
      try {
        await _writeCharacteristic!.write(ascii.encode(signal), withoutResponse: true);
        debugPrint("Bluetooth Signal Sent: $signal");
      } catch (e) {
        debugPrint("Write Error: $e");
      }
    } else {
      debugPrint("Cannot send: Bluetooth not connected");
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
      case WasteCategory.kaca:
      case WasteCategory.residu:
        signal = 'R';
        break;
      case WasteCategory.organik:
      case WasteCategory.lainnya:
        signal = 'O';
        break;
    }
    
    if (signal.isNotEmpty) {
      _writeSignal(signal);
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
