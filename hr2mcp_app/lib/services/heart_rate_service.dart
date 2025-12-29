import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Heart rate measurement from BLE device
class HeartRateMeasurement {
  final int bpm;
  final DateTime timestamp;
  
  HeartRateMeasurement({required this.bpm, required this.timestamp});
}

/// Connection state for the heart rate monitor
enum HRConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

class HeartRateService {
  // Standard Bluetooth Heart Rate Service UUID
  static final Guid heartRateServiceUuid = Guid('0000180d-0000-1000-8000-00805f9b34fb');
  // Heart Rate Measurement Characteristic UUID
  static final Guid heartRateMeasurementUuid = Guid('00002a37-0000-1000-8000-00805f9b34fb');
  
  final _heartRateController = StreamController<HeartRateMeasurement>.broadcast();
  final _connectionStateController = StreamController<HRConnectionState>.broadcast();
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  
  Stream<HeartRateMeasurement> get heartRateStream => _heartRateController.stream;
  Stream<HRConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<ScanResult>> get scanResultsStream => _scanResultsController.stream;
  
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? _lastConnectedDevice; // For reconnection
  StreamSubscription? _hrSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;

  HRConnectionState _connectionState = HRConnectionState.disconnected;
  HRConnectionState get connectionState => _connectionState;

  String? get connectedDeviceName => _connectedDevice?.platformName;

  // Test mode for development without a chest strap
  bool _testMode = false;
  Timer? _testTimer;

  bool get isTestMode => _testMode;
  
  void _updateConnectionState(HRConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }
  
  /// Check if Bluetooth is available and on
  Future<bool> isBluetoothAvailable() async {
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) return false;

    // On iOS, the first state is often 'unknown' before transitioning to 'on'
    // Wait for a definitive state (not unknown) with a timeout
    try {
      final state = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 2));
      return state == BluetoothAdapterState.on;
    } catch (e) {
      // Timeout - check current state directly
      final currentState = await FlutterBluePlus.adapterState.first;
      // If still unknown after timeout, assume it's on (iOS quirk)
      return currentState == BluetoothAdapterState.on ||
          currentState == BluetoothAdapterState.unknown;
    }
  }
  
  /// Start scanning for heart rate monitors
  Future<void> startScan() async {
    _updateConnectionState(HRConnectionState.scanning);
    
    final results = <ScanResult>[];
    
    _scanSubscription = FlutterBluePlus.scanResults.listen((scanResults) {
      // Filter to only devices advertising Heart Rate Service
      // or known HR monitor brands
      final hrDevices = scanResults.where((r) {
        // Check for Heart Rate Service
        final hasHrService = r.advertisementData.serviceUuids
            .any((uuid) => uuid == heartRateServiceUuid);
        
        // Check for known HR monitor names
        final name = r.device.platformName.toLowerCase();
        final isKnownBrand = name.contains('polar') ||
            name.contains('garmin') ||
            name.contains('wahoo') ||
            name.contains('heart') ||
            name.contains('hrm') ||
            name.contains('tickr');
        
        return hasHrService || isKnownBrand;
      }).toList();
      
      results.clear();
      results.addAll(hrDevices);
      _scanResultsController.add(List.from(results));
    });
    
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      withServices: [heartRateServiceUuid],
    );
    
    // When scan completes
    await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
    
    if (_connectionState == HRConnectionState.scanning) {
      _updateConnectionState(HRConnectionState.disconnected);
    }
  }
  
  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }
  
  /// Connect to a specific device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await stopScan();
      _updateConnectionState(HRConnectionState.connecting);
      
      await device.connect(timeout: const Duration(seconds: 15));
      
      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find Heart Rate Service
      final hrService = services.firstWhere(
        (s) => s.uuid == heartRateServiceUuid,
        orElse: () => throw Exception('Heart Rate Service not found'),
      );
      
      // Find Heart Rate Measurement Characteristic
      final hrCharacteristic = hrService.characteristics.firstWhere(
        (c) => c.uuid == heartRateMeasurementUuid,
        orElse: () => throw Exception('Heart Rate Measurement not found'),
      );
      
      // Subscribe to notifications
      await hrCharacteristic.setNotifyValue(true);
      
      _hrSubscription = hrCharacteristic.onValueReceived.listen((value) {
        final bpm = _parseHeartRate(value);
        if (bpm != null) {
          _heartRateController.add(HeartRateMeasurement(
            bpm: bpm,
            timestamp: DateTime.now(),
          ));
        }
      });
      
      _connectedDevice = device;
      _lastConnectedDevice = device; // Remember for reconnection
      _updateConnectionState(HRConnectionState.connected);
      return true;

    } catch (e) {
      print('Error connecting: $e');
      await disconnect();
      return false;
    }
  }

  /// Try to reconnect to the last connected device
  Future<bool> tryReconnect() async {
    if (_lastConnectedDevice == null) return false;
    if (_connectionState != HRConnectionState.disconnected) return false;

    print('Attempting to reconnect to ${_lastConnectedDevice!.platformName}');
    return await connect(_lastConnectedDevice!);
  }
  
  /// Parse heart rate from BLE characteristic value
  int? _parseHeartRate(List<int> value) {
    if (value.isEmpty) return null;
    
    final flags = value[0];
    final is16Bit = (flags & 0x01) != 0;
    
    if (is16Bit) {
      if (value.length < 3) return null;
      return value[1] | (value[2] << 8);
    } else {
      if (value.length < 2) return null;
      return value[1];
    }
  }
  
  void _handleDisconnection() {
    _connectedDevice = null;
    _hrSubscription?.cancel();
    _hrSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _updateConnectionState(HRConnectionState.disconnected);
  }
  
  /// Disconnect from current device
  Future<void> disconnect() async {
    _testMode = false;
    _testTimer?.cancel();
    _testTimer = null;
    
    await _connectedDevice?.disconnect();
    _handleDisconnection();
  }
  
  /// Start test mode (simulates heart rate data)
  void startTestMode() {
    _testMode = true;
    _updateConnectionState(HRConnectionState.connected);
    
    int baseBpm = 70;
    int direction = 1;
    
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate varying heart rate
      baseBpm += direction * (1 + DateTime.now().millisecond % 3);
      
      if (baseBpm > 170) {
        direction = -1;
      } else if (baseBpm < 60) {
        direction = 1;
      }
      
      _heartRateController.add(HeartRateMeasurement(
        bpm: baseBpm,
        timestamp: DateTime.now(),
      ));
    });
  }
  
  /// Dispose of resources
  void dispose() {
    disconnect();
    _heartRateController.close();
    _connectionStateController.close();
    _scanResultsController.close();
  }
}
