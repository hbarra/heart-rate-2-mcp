class HeartRateZones {
  final int zone1Max; // Zone 1: 0 - zone1Max
  final int zone2Max; // Zone 2: zone1Max+1 - zone2Max
  final int zone3Max; // Zone 3: zone2Max+1 - zone3Max
  final int zone4Max; // Zone 4: zone3Max+1 - zone4Max
  // Zone 5: zone4Max+1 - infinity

  HeartRateZones({
    required this.zone1Max,
    required this.zone2Max,
    required this.zone3Max,
    required this.zone4Max,
  });

  /// Create zones from age using standard formula
  /// Max HR = 220 - age
  /// Zone 1: 50-60% of max HR
  /// Zone 2: 60-70% of max HR
  /// Zone 3: 70-80% of max HR
  /// Zone 4: 80-90% of max HR
  /// Zone 5: 90-100% of max HR
  factory HeartRateZones.fromAge(int age) {
    final maxHr = 220 - age;
    return HeartRateZones(
      zone1Max: (maxHr * 0.60).round(),
      zone2Max: (maxHr * 0.70).round(),
      zone3Max: (maxHr * 0.80).round(),
      zone4Max: (maxHr * 0.90).round(),
    );
  }

  /// Get zone (1-5) for a given BPM
  int getZone(int bpm) {
    if (bpm <= zone1Max) return 1;
    if (bpm <= zone2Max) return 2;
    if (bpm <= zone3Max) return 3;
    if (bpm <= zone4Max) return 4;
    return 5;
  }

  /// Get zone boundaries as a map
  Map<String, dynamic> toJson() => {
    'zone1Max': zone1Max,
    'zone2Max': zone2Max,
    'zone3Max': zone3Max,
    'zone4Max': zone4Max,
  };

  factory HeartRateZones.fromJson(Map<String, dynamic> json) => HeartRateZones(
    zone1Max: json['zone1Max'] as int,
    zone2Max: json['zone2Max'] as int,
    zone3Max: json['zone3Max'] as int,
    zone4Max: json['zone4Max'] as int,
  );

  /// Default zones for age 30
  factory HeartRateZones.defaults() => HeartRateZones.fromAge(30);

  /// Get display string for zone range
  String getZoneRange(int zone) {
    switch (zone) {
      case 1:
        return '0-$zone1Max';
      case 2:
        return '${zone1Max + 1}-$zone2Max';
      case 3:
        return '${zone2Max + 1}-$zone3Max';
      case 4:
        return '${zone3Max + 1}-$zone4Max';
      case 5:
        return '${zone4Max + 1}+';
      default:
        return '';
    }
  }
}
