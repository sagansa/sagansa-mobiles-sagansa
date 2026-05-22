import '../models/location_data.dart';
import '../models/detection_result.dart';

/// Abstract base class untuk semua detector GPS palsu
abstract class LocationValidator {
  /// Nama identifier untuk validator ini
  String get name;

  /// Deskripsi singkat tentang apa yang divalidasi oleh validator ini
  String get description;

  /// Apakah validator ini tersedia di platform saat ini
  Future<bool> get isAvailable;

  /// Validasi lokasi dan return hasil deteksi
  ///
  /// [location] - Data lokasi yang akan divalidasi
  /// [previousLocations] - Riwayat lokasi sebelumnya untuk analisis pola
  ///
  /// Returns [DetectionResult] yang berisi hasil validasi
  Future<DetectionResult> validate(
    LocationData location, {
    List<LocationData> previousLocations = const [],
  });

  /// Inisialisasi validator (jika diperlukan)
  /// Dipanggil sekali saat service dimulai
  Future<void> initialize() async {}

  /// Cleanup resources saat validator tidak digunakan lagi
  Future<void> dispose() async {}

  /// Validasi konfigurasi validator
  /// Returns true jika konfigurasi valid
  bool validateConfiguration(Map<String, dynamic> config) => true;

  /// Update konfigurasi validator
  Future<void> updateConfiguration(Map<String, dynamic> config) async {}
}
