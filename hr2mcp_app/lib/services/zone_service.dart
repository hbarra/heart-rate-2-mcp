import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/heart_rate_zone.dart';

class ZoneService {
  static const String _zonesKey = 'heart_rate_zones';
  static const String _ageKey = 'user_age';
  static const String _useAgeBasedKey = 'use_age_based_zones';
  
  HeartRateZones? _zones;
  int? _age;
  bool _useAgeBased = true;
  
  HeartRateZones get zones => _zones ?? HeartRateZones.defaults();
  int? get age => _age;
  bool get useAgeBased => _useAgeBased;
  bool get isConfigured => _zones != null;
  
  /// Initialize service, load saved config
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    _useAgeBased = prefs.getBool(_useAgeBasedKey) ?? true;
    _age = prefs.getInt(_ageKey);
    
    final zonesJson = prefs.getString(_zonesKey);
    if (zonesJson != null) {
      _zones = HeartRateZones.fromJson(jsonDecode(zonesJson));
    } else if (_age != null) {
      _zones = HeartRateZones.fromAge(_age!);
    }
  }
  
  /// Set zones based on age
  Future<void> setAge(int age) async {
    _age = age;
    _useAgeBased = true;
    _zones = HeartRateZones.fromAge(age);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ageKey, age);
    await prefs.setBool(_useAgeBasedKey, true);
    await prefs.setString(_zonesKey, jsonEncode(_zones!.toJson()));
  }
  
  /// Set manual zone thresholds
  Future<void> setManualZones(HeartRateZones zones) async {
    _zones = zones;
    _useAgeBased = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useAgeBasedKey, false);
    await prefs.setString(_zonesKey, jsonEncode(zones.toJson()));
  }
  
  /// Get zone for a BPM value
  int getZone(int bpm) {
    return zones.getZone(bpm);
  }
}
