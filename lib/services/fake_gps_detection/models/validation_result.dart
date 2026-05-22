import 'detection_result.dart';

/// Hasil validasi keseluruhan dari semua detector
class ValidationResult {
  final bool isValid;
  final double riskScore; // 0.0 - 1.0
  final List<DetectionFlag> flags;
  final String reason;
  final DateTime validatedAt;
  final Map<String, dynamic> metadata;
  final List<DetectionResult> detectionResults;

  const ValidationResult({
    required this.isValid,
    required this.riskScore,
    required this.flags,
    required this.reason,
    required this.validatedAt,
    this.metadata = const {},
    this.detectionResults = const [],
  });

  factory ValidationResult.fromDetectionResults(
    List<DetectionResult> results,
    double riskThreshold,
  ) {
    if (results.isEmpty) {
      return ValidationResult(
        isValid: false,
        riskScore: 1.0,
        flags: [],
        reason: 'No detection results available',
        validatedAt: DateTime.now(),
        detectionResults: results,
      );
    }

    // Hitung risk score rata-rata
    final totalRisk = results.fold<double>(
      0.0,
      (sum, result) => sum + result.riskScore,
    );
    final averageRisk = totalRisk / results.length;

    // Kumpulkan semua flags
    final allFlags = <DetectionFlag>{};
    for (final result in results) {
      allFlags.addAll(result.flags);
    }

    // Tentukan validitas berdasarkan threshold
    final isValid = averageRisk < riskThreshold;

    // Buat reason berdasarkan hasil
    String reason;
    if (isValid) {
      reason = 'Location validation passed all checks';
    } else {
      final flagNames = allFlags.map((f) => f.name).join(', ');
      reason = 'Location validation failed: $flagNames';
    }

    return ValidationResult(
      isValid: isValid,
      riskScore: averageRisk,
      flags: allFlags.toList(),
      reason: reason,
      validatedAt: DateTime.now(),
      detectionResults: results,
    );
  }

  factory ValidationResult.error(String errorMessage) {
    return ValidationResult(
      isValid: false,
      riskScore: 1.0,
      flags: [],
      reason: 'Validation error: $errorMessage',
      validatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ValidationResult(valid: $isValid, risk: $riskScore, reason: $reason)';
  }
}
