import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/detection_database.dart';
import '../models/models.dart';
import '../utils/json_utils.dart';

/// Service untuk mengelola audit logging sistem deteksi GPS palsu
class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  final DetectionDatabase _database = DetectionDatabase();
  Timer? _cleanupTimer;
  Timer? _syncTimer;

  /// Inisialisasi audit service
  Future<void> initialize() async {
    // Setup periodic cleanup untuk menghapus log lama
    _setupPeriodicCleanup();

    // Setup periodic sync jika diperlukan
    _setupPeriodicSync();
  }

  /// Log aktivitas deteksi
  Future<void> logDetection({
    required String userId,
    required LocationData location,
    required ValidationResult result,
    Map<String, dynamic> additionalDetails = const {},
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final log = DetectionLog.create(
        userId: userId,
        location: location,
        result: result,
        deviceInfo: deviceInfo,
        detectionDetails: {
          ...additionalDetails,
          'platform': Platform.operatingSystem,
          'appVersion': '1.0.0', // Should be retrieved from package info
          'detectionMethods': _getEnabledDetectionMethods(result),
        },
      );

      await _database.insertLog(log);

      // Log ke console untuk debugging
      if (kDebugMode) {
        print('Detection logged: ${log.id} - Valid: ${result.isValid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to log detection: $e');
      }
      // Don't throw error to avoid breaking the main detection flow
    }
  }

  /// Mendapatkan riwayat log untuk user tertentu
  Future<List<DetectionLog>> getDetectionHistory({
    required String userId,
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _database.getLogsByUserId(
      userId,
      limit: limit,
      offset: offset,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Mendapatkan statistik deteksi untuk user
  Future<DetectionStatistics> getDetectionStatistics({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final stats = await _database.getDetectionStats(
      userId,
      startDate: startDate,
      endDate: endDate,
    );

    return DetectionStatistics(
      totalDetections: stats['totalLogs'],
      validDetections: stats['validLogs'],
      invalidDetections: stats['invalidLogs'],
      successRate: stats['successRate'],
      averageRiskScore: stats['averageRiskScore'],
      periodStart: startDate,
      periodEnd: endDate,
    );
  }

  /// Mendapatkan log yang belum disinkronisasi
  Future<List<DetectionLog>> getUnsyncedLogs({int limit = 100}) async {
    return await _database.getUnsyncedLogs(limit: limit);
  }

  /// Menandai log sebagai sudah disinkronisasi
  Future<void> markLogsAsSynced(List<String> logIds) async {
    await _database.markLogsAsSynced(logIds);
  }

  /// Export log ke JSON untuk backup atau analisis
  Future<String> exportLogsToJson({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final logs = await _database.getLogsByUserId(
      userId,
      limit: 10000, // Large limit for export
      startDate: startDate,
      endDate: endDate,
    );

    return JsonUtils.serializeDetectionLogs(logs);
  }

  /// Import log dari JSON
  Future<void> importLogsFromJson(String jsonString) async {
    try {
      final logs = JsonUtils.deserializeDetectionLogs(jsonString);

      for (final log in logs) {
        await _database.insertLog(log);
      }
    } catch (e) {
      throw Exception('Failed to import logs: $e');
    }
  }

  /// Membersihkan log lama
  Future<int> cleanupOldLogs({Duration? olderThan}) async {
    final cutoffDate = DateTime.now().subtract(
      olderThan ?? const Duration(days: 90), // Default 90 hari
    );

    return await _database.deleteOldLogs(cutoffDate);
  }

  /// Setup periodic cleanup
  void _setupPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(hours: 24), // Cleanup setiap 24 jam
      (timer) async {
        try {
          final deletedCount = await cleanupOldLogs();
          if (kDebugMode && deletedCount > 0) {
            print('Cleaned up $deletedCount old detection logs');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to cleanup old logs: $e');
          }
        }
      },
    );
  }

  /// Setup periodic sync (jika diperlukan untuk sync ke server)
  void _setupPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 30), // Sync setiap 30 menit
      (timer) async {
        try {
          await _syncLogsToServer();
        } catch (e) {
          if (kDebugMode) {
            print('Failed to sync logs: $e');
          }
        }
      },
    );
  }

  /// Sync log ke server (implementasi placeholder)
  Future<void> _syncLogsToServer() async {
    final unsyncedLogs = await getUnsyncedLogs(limit: 50);

    if (unsyncedLogs.isEmpty) return;

    // TODO: Implementasi actual sync ke server
    // Untuk sekarang, hanya mark sebagai synced setelah delay
    await Future.delayed(const Duration(seconds: 1));

    final logIds = unsyncedLogs.map((log) => log.id).toList();
    await markLogsAsSynced(logIds);

    if (kDebugMode) {
      print('Synced ${logIds.length} detection logs to server');
    }
  }

  /// Mendapatkan informasi device
  Future<String> _getDeviceInfo() async {
    try {
      final platform = Platform.operatingSystem;
      final version = Platform.operatingSystemVersion;

      return '$platform $version';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Mendapatkan metode deteksi yang aktif
  List<String> _getEnabledDetectionMethods(ValidationResult result) {
    final methods = <String>[];

    for (final flag in result.flags) {
      switch (flag) {
        case DetectionFlag.mockLocationEnabled:
        case DetectionFlag.developerOptionsEnabled:
          methods.add('MockLocationDetector');
          break;
        case DetectionFlag.signalInconsistent:
        case DetectionFlag.locationJumping:
          methods.add('SignalAnalyzer');
          break;
        case DetectionFlag.sensorMismatch:
          methods.add('SensorValidator');
          break;
        case DetectionFlag.networkMismatch:
          methods.add('NetworkValidator');
          break;
        case DetectionFlag.behaviorAnomalous:
          methods.add('BehaviorAnalyzer');
          break;
        case DetectionFlag.timeInconsistent:
          methods.add('TimeValidator');
          break;
      }
    }

    return methods.toSet().toList(); // Remove duplicates
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _syncTimer?.cancel();
  }
}

/// Model untuk statistik deteksi
class DetectionStatistics {
  final int totalDetections;
  final int validDetections;
  final int invalidDetections;
  final double successRate;
  final double averageRiskScore;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const DetectionStatistics({
    required this.totalDetections,
    required this.validDetections,
    required this.invalidDetections,
    required this.successRate,
    required this.averageRiskScore,
    this.periodStart,
    this.periodEnd,
  });

  @override
  String toString() {
    return 'DetectionStatistics(total: $totalDetections, valid: $validDetections, success: ${(successRate * 100).toStringAsFixed(1)}%)';
  }
}
