import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/api_service.dart';
import '../services/heart_rate_service.dart';
import '../services/zone_service.dart';
import 'settings_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  int? _currentBpm;
  int? _currentZone;
  bool _isSending = false;
  HRConnectionState _connectionState = HRConnectionState.disconnected;
  List<ScanResult> _scanResults = [];
  
  StreamSubscription? _hrSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }
  
  void _setupListeners() {
    _hrSubscription = widget.heartRateService.heartRateStream.listen((measurement) {
      final zone = widget.zoneService.getZone(measurement.bpm);
      setState(() {
        _currentBpm = measurement.bpm;
        _currentZone = zone;
      });
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
  
  @override
  void dispose() {
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
        title: const Text('Heart Rate 2 MCP'),
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
            margin: const EdgeInsets.all(16),
            child: InkWell(
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pairing Code',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    const Icon(Icons.copy, size: 20, color: Colors.grey),
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
            padding: const EdgeInsets.all(16),
            child: _buildConnectionButton(),
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
          const SizedBox(height: 16),
          Text(
            'Not Connected',
            style: TextStyle(
              fontSize: 18,
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
        // Device name
        if (widget.heartRateService.connectedDeviceName != null ||
            widget.heartRateService.isTestMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bluetooth_connected, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  widget.heartRateService.isTestMode
                      ? 'Test Mode'
                      : widget.heartRateService.connectedDeviceName ?? 'Connected',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        
        // BPM display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              Icons.favorite,
              size: 40,
              color: zoneColor,
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
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Zone display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: zoneColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
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
                const SizedBox(width: 12),
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
  
  Widget _buildConnectionButton() {
    switch (_connectionState) {
      case HRConnectionState.disconnected:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => widget.heartRateService.startScan(),
                icon: const Icon(Icons.search),
                label: const Text('Scan for Devices'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => widget.heartRateService.startTestMode(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
              child: const Text('Test'),
            ),
          ],
        );
        
      case HRConnectionState.scanning:
        return ElevatedButton.icon(
          onPressed: () => widget.heartRateService.stopScan(),
          icon: const Icon(Icons.stop),
          label: const Text('Stop Scanning'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.orange,
          ),
        );
        
      case HRConnectionState.connecting:
        return ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Connecting...'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        );
        
      case HRConnectionState.connected:
        return ElevatedButton.icon(
          onPressed: () => widget.heartRateService.disconnect(),
          icon: const Icon(Icons.bluetooth_disabled),
          label: const Text('Disconnect'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        );
    }
  }
}
