import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/zone_service.dart';
import '../models/heart_rate_zone.dart';

// Design System Constants (shared with home_screen.dart)
class _AppStyles {
  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double buttonHeight = 48.0;
  static const double spacing = 16.0;
  static const double spacingSmall = 12.0;
  static const double spacingLarge = 24.0;

  static final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadius),
  );

  static final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cardRadius),
  );

  static final inputDecoration = InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  final ApiService apiService;
  final ZoneService zoneService;
  
  const SettingsScreen({
    super.key,
    required this.apiService,
    required this.zoneService,
  });
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ageController = TextEditingController();
  final _zone1Controller = TextEditingController();
  final _zone2Controller = TextEditingController();
  final _zone3Controller = TextEditingController();
  final _zone4Controller = TextEditingController();
  final _serverUrlController = TextEditingController();
  
  bool _useAgeBased = true;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  void _loadSettings() {
    _useAgeBased = widget.zoneService.useAgeBased;
    
    if (widget.zoneService.age != null) {
      _ageController.text = widget.zoneService.age.toString();
    }
    
    final zones = widget.zoneService.zones;
    _zone1Controller.text = zones.zone1Max.toString();
    _zone2Controller.text = zones.zone2Max.toString();
    _zone3Controller.text = zones.zone3Max.toString();
    _zone4Controller.text = zones.zone4Max.toString();
    
    _serverUrlController.text = widget.apiService.serverUrl ?? ApiService.defaultServerUrl;
  }
  
  Future<void> _saveAge() async {
    final age = int.tryParse(_ageController.text);
    if (age == null || age < 10 || age > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age (10-100)')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    await widget.zoneService.setAge(age);
    
    // Update manual zone fields to reflect calculated values
    final zones = widget.zoneService.zones;
    _zone1Controller.text = zones.zone1Max.toString();
    _zone2Controller.text = zones.zone2Max.toString();
    _zone3Controller.text = zones.zone3Max.toString();
    _zone4Controller.text = zones.zone4Max.toString();
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zones calculated from age')),
      );
    }
  }
  
  Future<void> _saveManualZones() async {
    final z1 = int.tryParse(_zone1Controller.text);
    final z2 = int.tryParse(_zone2Controller.text);
    final z3 = int.tryParse(_zone3Controller.text);
    final z4 = int.tryParse(_zone4Controller.text);
    
    if (z1 == null || z2 == null || z3 == null || z4 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid zone thresholds')),
      );
      return;
    }
    
    if (!(z1 < z2 && z2 < z3 && z3 < z4)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zone thresholds must be in ascending order')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    await widget.zoneService.setManualZones(HeartRateZones(
      zone1Max: z1,
      zone2Max: z2,
      zone3Max: z3,
      zone4Max: z4,
    ));
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual zones saved')),
      );
    }
  }
  
  Future<void> _regeneratePairingCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Pairing Code?'),
        content: const Text(
          'This will create a new pairing code. You will need to update the code in your Dreamer agent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      final newCode = await widget.apiService.regeneratePairingCode();
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New pairing code: $newCode')),
        );
      }
    }
  }
  
  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    
    // Save URL first
    await widget.apiService.setServerUrl(_serverUrlController.text);
    
    final success = await widget.apiService.testConnection();
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Connection successful!' : 'Connection failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(_AppStyles.spacing),
              children: [
                // Zone Configuration Section
                _buildSectionHeader('Heart Rate Zones'),
                const SizedBox(height: 8),

                // Toggle between age-based and manual
                Card(
                  shape: _AppStyles.cardShape,
                  child: Padding(
                    padding: const EdgeInsets.all(_AppStyles.spacing),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                title: const Text('Age-based'),
                                value: true,
                                groupValue: _useAgeBased,
                                onChanged: (v) => setState(() => _useAgeBased = v!),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                title: const Text('Manual'),
                                value: false,
                                groupValue: _useAgeBased,
                                onChanged: (v) => setState(() => _useAgeBased = v!),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: _AppStyles.spacing),

                        if (_useAgeBased) ...[
                          // Age input
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ageController,
                                  decoration: InputDecoration(
                                    labelText: 'Your Age',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(_AppStyles.borderRadius),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                              ),
                              const SizedBox(width: _AppStyles.spacingSmall),
                              ElevatedButton(
                                onPressed: _saveAge,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, _AppStyles.buttonHeight),
                                  shape: _AppStyles.buttonShape,
                                ),
                                child: const Text('Calculate'),
                              ),
                            ],
                          ),
                          const SizedBox(height: _AppStyles.spacingSmall),
                          Text(
                            'Max HR = 220 - age. Zones calculated as % of max.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ] else ...[
                          // Manual zone inputs
                          _buildZoneInput('Zone 1 max', _zone1Controller, Colors.grey),
                          _buildZoneInput('Zone 2 max', _zone2Controller, Colors.blue),
                          _buildZoneInput('Zone 3 max', _zone3Controller, Colors.green),
                          _buildZoneInput('Zone 4 max', _zone4Controller, Colors.orange),
                          const SizedBox(height: 8),
                          Text(
                            'Zone 5: everything above Zone 4 max',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: _AppStyles.spacingSmall),
                          ElevatedButton(
                            onPressed: _saveManualZones,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, _AppStyles.buttonHeight),
                              shape: _AppStyles.buttonShape,
                            ),
                            child: const Text('Save Manual Zones'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: _AppStyles.spacingLarge),

                // Pairing Code Section
                _buildSectionHeader('Pairing Code'),
                const SizedBox(height: 8),

                Card(
                  shape: _AppStyles.cardShape,
                  child: Padding(
                    padding: const EdgeInsets.all(_AppStyles.spacing),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.apiService.pairingCode ?? '---',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                final code = widget.apiService.pairingCode;
                                if (code != null) {
                                  Clipboard.setData(ClipboardData(text: code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied!')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: _AppStyles.spacingSmall),
                        Text(
                          'Share this code with your Dreamer agent',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: _AppStyles.spacingSmall),
                        OutlinedButton(
                          onPressed: _regeneratePairingCode,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, _AppStyles.buttonHeight),
                            shape: _AppStyles.buttonShape,
                          ),
                          child: const Text('Regenerate Code'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: _AppStyles.spacingLarge),

                // Server Configuration Section
                _buildSectionHeader('Server'),
                const SizedBox(height: 8),

                Card(
                  shape: _AppStyles.cardShape,
                  child: Padding(
                    padding: const EdgeInsets.all(_AppStyles.spacing),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _serverUrlController,
                          decoration: InputDecoration(
                            labelText: 'Server URL',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(_AppStyles.borderRadius),
                            ),
                            hintText: 'https://hr2mcp.onrender.com',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: _AppStyles.spacingSmall),
                        ElevatedButton(
                          onPressed: _testConnection,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, _AppStyles.buttonHeight),
                            shape: _AppStyles.buttonShape,
                          ),
                          child: const Text('Test Connection'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: _AppStyles.spacingLarge),

                // Zone Reference
                _buildSectionHeader('Zone Reference'),
                const SizedBox(height: 8),

                Card(
                  shape: _AppStyles.cardShape,
                  child: Padding(
                    padding: const EdgeInsets.all(_AppStyles.spacing),
                    child: Column(
                      children: [
                        _buildZoneRow(1, 'Recovery', Colors.grey, widget.zoneService.zones),
                        _buildZoneRow(2, 'Aerobic', Colors.blue, widget.zoneService.zones),
                        _buildZoneRow(3, 'Tempo', Colors.green, widget.zoneService.zones),
                        _buildZoneRow(4, 'Threshold', Colors.orange, widget.zoneService.zones),
                        _buildZoneRow(5, 'VO2 Max', Colors.red, widget.zoneService.zones),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildZoneInput(String label, TextEditingController controller, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _AppStyles.spacingSmall),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: _AppStyles.spacingSmall),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_AppStyles.borderRadius),
                ),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildZoneRow(int zone, String name, Color color, HeartRateZones zones) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
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
          const SizedBox(width: _AppStyles.spacingSmall),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            zones.getZoneRange(zone),
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _ageController.dispose();
    _zone1Controller.dispose();
    _zone2Controller.dispose();
    _zone3Controller.dispose();
    _zone4Controller.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
}
