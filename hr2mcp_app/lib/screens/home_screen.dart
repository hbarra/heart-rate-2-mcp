import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
import '../services/heart_rate_service.dart';
import '../services/zone_service.dart';
import 'settings_screen.dart';

// Design System Constants
class _AppStyles {
  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double buttonHeight = 52.0;
  static const double maxButtonWidth = 320.0;
  static const double spacing = 16.0;
  static const double spacingSmall = 12.0;
  static const double spacingLarge = 24.0;

  static final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadius),
  );

  static final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cardRadius),
  );
}

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final HeartRateService heartRateService;
  final ZoneService zoneService;
  
  const HomeScreen({
    super.key,
    required this.apiService,
    required this.heartRateService,
    required this.zoneService,
  });
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int? _currentBpm;
  int? _currentZone;
  bool _isSending = false;
  HRConnectionState _connectionState = HRConnectionState.disconnected;
  List<ScanResult> _scanResults = [];
  bool _wasConnectedBeforeBackground = false;

  StreamSubscription? _hrSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;

  // Heart pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPulseAnimation();
    _setupListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // App going to background - remember if we were connected
        _wasConnectedBeforeBackground =
            _connectionState == HRConnectionState.connected;
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground - try to reconnect if needed
        if (_wasConnectedBeforeBackground &&
            _connectionState == HRConnectionState.disconnected) {
          widget.heartRateService.tryReconnect();
        }
        break;
      default:
        break;
    }
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      }
    });
  }

  void _triggerPulse() {
    if (_pulseController.isAnimating) return;
    _pulseController.forward();
  }
  
  void _setupListeners() {
    _hrSubscription = widget.heartRateService.heartRateStream.listen((measurement) {
      final zone = widget.zoneService.getZone(measurement.bpm);
      setState(() {
        _currentBpm = measurement.bpm;
        _currentZone = zone;
      });
      _triggerPulse();
      _sendToServer(measurement.bpm, zone);
    });

    _connectionSubscription = widget.heartRateService.connectionStateStream.listen((state) {
      setState(() {
        _connectionState = state;
        if (state == HRConnectionState.disconnected) {
          _currentBpm = null;
          _currentZone = null;
        }
      });

      // Enable wakelock when connected to keep screen on and maintain BLE connection
      if (state == HRConnectionState.connected) {
        WakelockPlus.enable();
      } else if (state == HRConnectionState.disconnected) {
        WakelockPlus.disable();
      }
    });
    
    _scanSubscription = widget.heartRateService.scanResultsStream.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });
  }
  
  Future<void> _sendToServer(int bpm, int zone) async {
    if (_isSending) return;
    _isSending = true;
    await widget.apiService.sendHeartRate(bpm, zone);
    _isSending = false;
  }

  Future<void> _startScanWithBluetoothCheck() async {
    final isAvailable = await widget.heartRateService.isBluetoothAvailable();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Bluetooth to scan for devices'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    widget.heartRateService.startScan();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _pulseController.dispose();
    _hrSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }
  
  Color _getZoneColor(int zone) {
    switch (zone) {
      case 1: return Colors.grey;
      case 2: return Colors.blue;
      case 3: return Colors.green;
      case 4: return Colors.orange;
      case 5: return Colors.red;
      default: return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR2MCP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(
                  apiService: widget.apiService,
                  zoneService: widget.zoneService,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pairing code card
          Card(
            margin: const EdgeInsets.all(_AppStyles.spacing),
            shape: _AppStyles.cardShape,
            child: InkWell(
              borderRadius: BorderRadius.circular(_AppStyles.cardRadius),
              onTap: () {
                final code = widget.apiService.pairingCode;
                if (code != null) {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pairing code copied!')),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(_AppStyles.spacing),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 24),
                    const SizedBox(width: _AppStyles.spacingSmall),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pairing Code',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          widget.apiService.pairingCode ?? '---',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.copy, size: 20, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
          
          // Heart rate display
          Expanded(
            child: Center(
              child: _buildMainContent(),
            ),
          ),
          
          // Device list when scanning
          if (_connectionState == HRConnectionState.scanning ||
              (_connectionState == HRConnectionState.disconnected && _scanResults.isNotEmpty))
            _buildDeviceList(),
          
          // Connection button
          Padding(
            padding: const EdgeInsets.all(_AppStyles.spacing),
            child: Center(child: _buildConnectionButton()),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    if (_connectionState == HRConnectionState.disconnected && _currentBpm == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: _AppStyles.spacing),
          Text(
            'Not Connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap Scan to find your heart rate monitor',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    }

    if (_connectionState == HRConnectionState.scanning) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: _AppStyles.spacing),
          Text(
            'Scanning for devices...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    if (_connectionState == HRConnectionState.connecting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: _AppStyles.spacing),
          Text(
            'Connecting...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    // Connected - show BPM
    final zoneColor = _currentZone != null ? _getZoneColor(_currentZone!) : Colors.grey;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Device name badge
        if (widget.heartRateService.connectedDeviceName != null ||
            widget.heartRateService.isTestMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_AppStyles.borderRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bluetooth_connected, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  widget.heartRateService.isTestMode
                      ? 'Test Mode'
                      : widget.heartRateService.connectedDeviceName ?? 'Connected',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: _AppStyles.spacingLarge),

        // BPM display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Icon(
                Icons.favorite,
                size: 40,
                color: zoneColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currentBpm?.toString() ?? '--',
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.bold,
                color: zoneColor,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'BPM',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: _AppStyles.spacingLarge),

        // Zone display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: zoneColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(_AppStyles.borderRadius),
            border: Border.all(color: zoneColor, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Zone ${_currentZone ?? '-'}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: zoneColor,
                ),
              ),
              if (_currentZone != null) ...[
                const SizedBox(width: _AppStyles.spacingSmall),
                Text(
                  widget.zoneService.zones.getZoneRange(_currentZone!),
                  style: TextStyle(
                    fontSize: 16,
                    color: zoneColor.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDeviceList() {
    if (_scanResults.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final result = _scanResults[index];
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : 'Unknown Device';
          
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(name),
            subtitle: Text('RSSI: ${result.rssi} dBm'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.heartRateService.connect(result.device),
          );
        },
      ),
    );
  }
  
  // Helper method for consistent button styling
  ButtonStyle _buttonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(0, _AppStyles.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      shape: _AppStyles.buttonShape,
      elevation: 0,
    );
  }

  Widget _buildConnectionButton() {
    switch (_connectionState) {
      case HRConnectionState.disconnected:
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _AppStyles.maxButtonWidth),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startScanWithBluetoothCheck(),
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('Scan'),
                  style: _buttonStyle(),
                ),
              ),
              const SizedBox(width: _AppStyles.spacingSmall),
              ElevatedButton(
                onPressed: () => widget.heartRateService.startTestMode(),
                style: _buttonStyle(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.grey[700],
                ),
                child: const Text('Test'),
              ),
            ],
          ),
        );

      case HRConnectionState.scanning:
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _AppStyles.maxButtonWidth),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.heartRateService.stopScan(),
              icon: const Icon(Icons.stop, size: 20),
              label: const Text('Stop Scanning'),
              style: _buttonStyle(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );

      case HRConnectionState.connecting:
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _AppStyles.maxButtonWidth),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: const Text('Connecting...'),
              style: _buttonStyle(),
            ),
          ),
        );

      case HRConnectionState.connected:
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _AppStyles.maxButtonWidth),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.heartRateService.disconnect(),
              icon: const Icon(Icons.bluetooth_disabled, size: 20),
              label: const Text('Disconnect'),
              style: _buttonStyle(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );
    }
  }
}
