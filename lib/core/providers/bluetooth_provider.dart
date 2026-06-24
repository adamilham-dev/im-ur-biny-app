import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
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

  BluetoothConnection? _connection;
  final String _targetDeviceName = "SmartBin_ESP32";
  
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
      // Cek status bluetooth
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled == false) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      // Get list of paired devices
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? targetDevice;
      
      for (BluetoothDevice device in devices) {
        if (device.name == _targetDeviceName) {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice != null) {
        await _connectToDevice(targetDevice);
      } else {
        // If not paired
        state = BTConnectionState.error;
        debugPrint("Device not paired. Please pair 'SmartBin_ESP32' in Android Bluetooth Settings first.");
      }
    } catch (e) {
      state = BTConnectionState.error;
      debugPrint("Bluetooth Error: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      state = BTConnectionState.connected;
      debugPrint("Connected to the SmartBin_ESP32");
      
      _connection!.input!.listen((Uint8List data) {
        // Menerima pesan dari Arduino jika ada (opsional)
        debugPrint("ESP32: ${ascii.decode(data)}");
      }).onDone(() {
        state = BTConnectionState.disconnected;
        debugPrint("Disconnected by remote request");
      });
    } catch (e) {
      state = BTConnectionState.error;
      debugPrint("Connection Error: $e");
    }
  }

  void sendCategory(WasteCategory category) {
    if (_connection != null && _connection!.isConnected) {
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
        _connection!.output.add(ascii.encode(signal));
        _connection!.output.allSent.then((_) {
          debugPrint("Bluetooth Signal Sent: $signal");
        });
      }
    } else {
      debugPrint("Cannot send: Bluetooth not connected");
      // Coba reconnect
      _initBluetooth();
    }
  }

  void sendCloseAll() {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(ascii.encode('0'));
      _connection!.output.allSent.then((_) {
        debugPrint("Bluetooth Signal Sent: 0 (Close All)");
      });
    } else {
      debugPrint("Cannot send: Bluetooth not connected");
      _initBluetooth();
    }
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }
}

final bluetoothProvider = StateNotifierProvider<BluetoothStateNotifier, BTConnectionState>((ref) {
  return BluetoothStateNotifier();
});
