/// Model untuk data lokasi yang akan divalidasi
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double bearing;
  final DateTime timestamp;
  final String provider;
  final Map<String, dynamic> extras;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.speed,
    required this.bearing,
    required this.timestamp,
    required this.provider,
    this.extras = const {},
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      accuracy: json['accuracy']?.toDouble() ?? 0.0,
      altitude: json['altitude']?.toDouble() ?? 0.0,
      speed: json['speed']?.toDouble() ?? 0.0,
      bearing: json['bearing']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      provider: json['provider'] ?? '',
      extras: Map<String, dynamic>.from(json['extras'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'bearing': bearing,
      'timestamp': timestamp.toIso8601String(),
      'provider': provider,
      'extras': extras,
    };
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: $accuracy, provider: $provider)';
  }
}
