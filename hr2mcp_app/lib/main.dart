import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/api_service.dart';
import 'services/heart_rate_service.dart';
import 'services/zone_service.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';

void main() {
  runApp(const HeartRate2McpApp());
}

class HeartRate2McpApp extends StatelessWidget {
  const HeartRate2McpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heart Rate 2 MCP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppLoader(),
    );
  }
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  final ApiService _apiService = ApiService();
  final HeartRateService _heartRateService = HeartRateService();
  final ZoneService _zoneService = ZoneService();
  
  bool _isLoading = true;
  bool _needsSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Request permissions
      await _requestPermissions();
      
      // Initialize services
      await _apiService.init();
      await _zoneService.init();
      
      // Check if setup is needed
      final needsSetup = !_zoneService.isConfigured;
      
      setState(() {
        _needsSetup = needsSetup;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    // Bluetooth permissions
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    
    // Location is required for BLE scanning on Android
    await Permission.locationWhenInUse.request();
  }

  void _onSetupComplete() {
    setState(() {
      _needsSetup = false;
    });
  }

  @override
  void dispose() {
    _heartRateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error initializing app',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initialize();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_needsSetup) {
      return SetupScreen(
        apiService: _apiService,
        zoneService: _zoneService,
        onComplete: _onSetupComplete,
      );
    }

    return HomeScreen(
      apiService: _apiService,
      heartRateService: _heartRateService,
      zoneService: _zoneService,
    );
  }
}
