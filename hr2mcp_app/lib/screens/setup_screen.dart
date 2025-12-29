import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/zone_service.dart';
import '../models/heart_rate_zone.dart';

class SetupScreen extends StatefulWidget {
  final ApiService apiService;
  final ZoneService zoneService;
  final VoidCallback onComplete;
  
  const SetupScreen({
    super.key,
    required this.apiService,
    required this.zoneService,
    required this.onComplete,
  });
  
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ageController = TextEditingController();
  bool _isLoading = false;
  int _currentStep = 0;
  
  Future<void> _saveAgeAndContinue() async {
    final age = int.tryParse(_ageController.text);
    if (age == null || age < 10 || age > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age (10-100)')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    await widget.zoneService.setAge(age);
    setState(() {
      _isLoading = false;
      _currentStep = 1;
    });
  }
  
@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _currentStep == 0 ? _buildZoneSetup() : _buildPairingCodeDisplay(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildZoneSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        const Icon(
          Icons.favorite,
          size: 64,
          color: Colors.red,
        ),
        const SizedBox(height: 24),
        const Text(
          'Welcome to\nHR2MCP',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Let\'s set up your heart rate zones based on your age.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _ageController,
          decoration: const InputDecoration(
            labelText: 'Your Age',
            border: OutlineInputBorder(),
            helperText: 'Used to calculate your heart rate zones',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Text(
          'Max HR = 220 - age. You can customize zones later in settings.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveAgeAndContinue,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPairingCodeDisplay() {
    final zones = widget.zoneService.zones;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        const Icon(
          Icons.link,
          size: 64,
          color: Colors.blue,
        ),
        const SizedBox(height: 24),
        const Text(
          'Your Pairing Code',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Share this code with your Dreamer agent to connect.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        
        // Pairing code card
        Card(
          child: InkWell(
            onTap: () {
              final code = widget.apiService.pairingCode;
              if (code != null) {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.apiService.pairingCode ?? '---',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.copy, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Zone summary
        Text(
          'Your Zones',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        _buildZoneSummary(zones),
        
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onComplete,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Get Started', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildZoneSummary(HeartRateZones zones) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildZoneBadge(1, Colors.grey, zones),
            _buildZoneBadge(2, Colors.blue, zones),
            _buildZoneBadge(3, Colors.green, zones),
            _buildZoneBadge(4, Colors.orange, zones),
            _buildZoneBadge(5, Colors.red, zones),
          ],
        ),
      ),
    );
  }
  
  Widget _buildZoneBadge(int zone, Color color, HeartRateZones zones) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              '$zone',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          zones.getZoneRange(zone),
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }
}
