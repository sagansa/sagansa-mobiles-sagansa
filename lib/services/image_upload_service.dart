import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'token_store.dart';

/// MultipartRequest yang melaporkan progres byte terkirim via [onProgress]
/// (sent/total) — dipakai UI untuk progress bar upload dokumen.
class ProgressMultipartRequest extends http.MultipartRequest {
  ProgressMultipartRequest(
    super.method,
    super.url, {
    this.onProgress,
  });

  final void Function(int sent, int total)? onProgress;

  @override
  http.ByteStream finalize() {
    final stream = super.finalize();
    final callback = onProgress;
    if (callback == null) return stream;

    final total = contentLength;
    var sent = 0;
    return http.ByteStream(stream.transform<List<int>>(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (List<int> data, EventSink<List<int>> sink) {
          sent += data.length;
          callback(sent, total);
          sink.add(data);
        },
      ),
    ));
  }
}

/// Service untuk upload & delete gambar langsung ke img.sagansa.id.
///
/// Menggunakan Sanctum token yang sama dengan api service (img service membaca
/// tabel personal_access_tokens di sagansa_user). Mobile upload file langsung
/// ke img service, dapat relative path string, lalu kirim path ke api service
/// sebagai form field biasa.
class ImageUploadService {
  static const String _baseUrl = String.fromEnvironment(
    'IMG_SERVICE_URL',
    defaultValue: 'https://img.sagansa.id',
  );

  /// Batas waktu menunggu response dari img service. Sebelumnya tidak ada
  /// timeout, sehingga koneksi macet menggantung spinner submit tanpa batas.
  static const Duration _timeout = Duration(seconds: 30);

  /// Ambil Sanctum token dari secure storage (TokenStore). Sebelumnya membaca
  /// dari SharedPreferences, namun token sudah dimigrasi ke secure storage —
  /// SharedPreferences kini sudah tidak menyimpan token.
  static Future<String?> _getToken() async {
    return TokenStore.instance.readToken();
  }

  /// Upload file ke img service.
  ///
  /// [directory] menentukan subfolder penyimpanan (mis. "images/FuelService").
  /// Return relative path (mis. "images/FuelService/uuid.webp").
  ///
  /// [onProgress] (opsional) dipanggil tiap chunk terkirim dengan
  /// (byteTerkirim, totalByte) untuk progress bar.
  ///
  /// Melempar [Exception] bila gagal — pesannya memuat HTTP status code dan
  /// cuplikan body server agar mudah didiagnosis (sebelumnya error ditelan
  /// jadi `return null` sehingga pemanggil hanya bisa menampilkan pesan generik).
  static Future<String?> upload(File imageFile,
      {String directory = '',
      String? filename,
      void Function(int sent, int total)? onProgress}) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token tidak ditemukan, silakan login ulang.');
    }

    final uri = Uri.parse('$_baseUrl/api/upload');
    final request =
        ProgressMultipartRequest('POST', uri, onProgress: onProgress);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (directory.isNotEmpty) {
      request.fields['directory'] = directory;
    }

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path,
          filename: filename),
    );

    return _sendAndParse(request);
  }

  /// Upload dokumen PDF ke img service (multipart field `file`).
  ///
  /// Berbeda dari [upload]: img service menyimpan PDF asli tanpa re-encode
  /// WebP (validasi magic bytes di sisi server). Return relative path
  /// (mis. "documents/ImportPurchase/uuid.pdf").
  static Future<String?> uploadPdf(File pdfFile,
      {String directory = '',
      String? filename,
      void Function(int sent, int total)? onProgress}) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token tidak ditemukan, silakan login ulang.');
    }

    final uri = Uri.parse('$_baseUrl/api/upload');
    final request =
        ProgressMultipartRequest('POST', uri, onProgress: onProgress);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (directory.isNotEmpty) {
      request.fields['directory'] = directory;
    }

    request.files.add(
      await http.MultipartFile.fromPath('file', pdfFile.path,
          filename: filename),
    );

    return _sendAndParse(request);
  }

  /// Upload bytes ke img service (untuk web/kIsWeb).
  ///
  /// [filename] nama file dengan extension.
  /// Return relative path atau melempar [Exception] bila gagal.
  static Future<String?> uploadBytes(
    Uint8List bytes,
    String filename, {
    String directory = '',
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token tidak ditemukan, silakan login ulang.');
    }

    final uri = Uri.parse('$_baseUrl/api/upload');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (directory.isNotEmpty) {
      request.fields['directory'] = directory;
    }

    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );

    return _sendAndParse(request);
  }

  /// Kirim [request], validasi response, lalu ekstrak relative path "path".
  ///
  /// Dipecah ke method bersama karena logika ini sama untuk [upload] (File)
  /// maupun [uploadBytes] (web).
  static Future<String?> _sendAndParse(http.MultipartRequest request) async {
    try {
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse JSON sungguhan, BUKAN regex ke body mentah: Laravel meng-
        // escape '/' menjadi '\/' di body JSON (default json_encode PHP)
        // sehingga regex menangkap backslash dan path terkirim ter-escape
        // ke api service.
        final dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw Exception(
              'Respon img service tidak valid (path tidak ditemukan).');
        }
        final path = decoded is Map<String, dynamic> ? decoded['path'] : null;
        if (path is String && path.isNotEmpty) {
          return path;
        }
        // 2xx tapi payload tidak memuat "path" — respon server tidak sesuai
        // kontrak (mis. halaman HTML dari proxy/CDN dengan status 200).
        throw Exception(
            'Respon img service tidak valid (path tidak ditemukan).');
      }

      throw Exception(_failureMessage(response.statusCode, response.body));
    } on TimeoutException {
      throw Exception(
          'Upload timeout: img service tidak merespons dalam ${_timeout.inSeconds} detik.');
    } on Exception {
      rethrow;
    } catch (e) {
      // Error jaringan lain (SocketException, TLS failure, dll).
      throw Exception('Gagal terhubung ke img service: $e');
    }
  }

  /// Susun pesan kegagalan yang informatif: HTTP status + cuplikan body.
  static String _failureMessage(int statusCode, String body) {
    final trimmed = body.trim();
    final short =
        trimmed.length > 150 ? '${trimmed.substring(0, 150)}…' : trimmed;
    return short.isEmpty
        ? 'Upload gagal ($statusCode).'
        : 'Upload gagal ($statusCode): $short';
  }

  /// Hapus gambar by path dari img service.
  ///
  /// Return true bila berhasil.
  static Future<bool> delete(String path) async {
    final token = await _getToken();
    if (token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/images'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: '{"path": "$path"}',
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ImageUploadService: delete exception: $e');
      return false;
    }
  }
}
