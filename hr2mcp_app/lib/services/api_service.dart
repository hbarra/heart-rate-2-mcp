import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pairing_code.dart';

class ApiService {
  static const String _serverUrlKey = 'server_url';
  static const String _pairingCodeKey = 'pairing_code';
  
  // Default production server URL
  static const String defaultServerUrl = 'https://hr2mcp.onrender.com';
  
  String? _serverUrl;
  String? _pairingCode;
  
  String? get serverUrl => _serverUrl;
  String? get pairingCode => _pairingCode;
  
  bool get isConfigured => _serverUrl != null && _pairingCode != null;
  
  /// Initialize service, load saved config
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_serverUrlKey) ?? defaultServerUrl;
    _pairingCode = prefs.getString(_pairingCodeKey);
    
    // Generate pairing code on first launch
    if (_pairingCode == null) {
      _pairingCode = generatePairingCode();
      await prefs.setString(_pairingCodeKey, _pairingCode!);
    }
  }
  
  /// Set server URL (for custom deployments)
  Future<void> setServerUrl(String url) async {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, _serverUrl!);
  }
  
  /// Generate a new pairing code
  Future<String> regeneratePairingCode() async {
    _pairingCode = generatePairingCode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pairingCodeKey, _pairingCode!);
    return _pairingCode!;
  }
  
  /// Test connection to server
  Future<bool> testConnection() async {
    if (_serverUrl == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Send heart rate reading to server
  Future<bool> sendHeartRate(int bpm, int zone) async {
    if (_serverUrl == null || _pairingCode == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/api/hr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': _pairingCode,
          'bpm': bpm,
          'zone': zone,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      // Silent failure - don't spam logs
      return false;
    }
  }
}
