/// Enum untuk flag deteksi yang menunjukkan jenis masalah yang ditemukan
enum DetectionFlag {
  mockLocationEnabled,
  developerOptionsEnabled,
  signalInconsistent,
  locationJumping,
  sensorMismatch,
  networkMismatch,
  behaviorAnomalous,
  timeInconsistent,
}

/// Hasil dari satu metode deteksi
class DetectionResult {
  final bool isValid;
  final double riskScore; // 0.0 - 1.0, dimana 1.0 = sangat mencurigakan
  final List<DetectionFlag> flags;
  final String reason;
  final DateTime detectedAt;
  final Map<String, dynamic> metadata;

  const DetectionResult({
    required this.isValid,
    required this.riskScore,
    required this.flags,
    required this.reason,
    required this.detectedAt,
    this.metadata = const {},
  });

  factory DetectionResult.valid({
    String reason = 'Location validation passed',
    Map<String, dynamic> metadata = const {},
  }) {
    return DetectionResult(
      isValid: true,
      riskScore: 0.0,
      flags: [],
      reason: reason,
      detectedAt: DateTime.now(),
      metadata: metadata,
    );
  }

  factory DetectionResult.invalid({
    required double riskScore,
    required List<DetectionFlag> flags,
    required String reason,
    Map<String, dynamic> metadata = const {},
  }) {
    return DetectionResult(
      isValid: false,
      riskScore: riskScore,
      flags: flags,
      reason: reason,
      detectedAt: DateTime.now(),
      metadata: metadata,
    );
  }

  @override
  String toString() {
    return 'DetectionResult(valid: $isValid, risk: $riskScore, flags: $flags)';
  }
}
