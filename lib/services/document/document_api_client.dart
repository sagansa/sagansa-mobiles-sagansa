import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import '../api_client.dart';
import '../auth_session.dart';
import '../token_store.dart';

/// Akses mudah ke kode error terstruktur service document.
///
/// Envelope error service document berbentuk
/// `{error: {code, message, details?}}` dengan kode
/// UNAUTHENTICATED/FORBIDDEN/NOT_FOUND/DOCUMENT_LOCKED/SIGNING_INCOMPLETE/
/// PDF_INVALID/PDF_UNSUPPORTED/ALREADY_SIGNED/VALIDATION_ERROR/SERVER_ERROR.
/// Kode tersimpan di [ApiException.body]; extension ini menyuguhkan tanpa
/// memaksa pemanggil mengurai map manual.
extension DocumentApiExceptionX on ApiException {
  /// Kode error backend (mis. `DOCUMENT_LOCKED`) atau null bila body tidak
  /// berbentuk envelope error document.
  String? get errorCode {
    final error = body?['error'];
    if (error is Map<String, dynamic>) {
      return error['code']?.toString();
    }
    return null;
  }

  /// Detail validasi per-field (`error.details`) bila ada.
  Map<String, dynamic>? get errorDetails {
    final error = body?['error'];
    if (error is Map<String, dynamic> && error['details'] is Map) {
      return (error['details'] as Map).cast<String, dynamic>();
    }
    return null;
  }
}

/// Client HTTP khusus service document (surat).
///
/// Service document berjalan di host terpisah dari API utama
/// (`DOCUMENT_BASE_URL`, default https://document.sagansa.id) tetapi memakai
/// bearer token Sanctum yang SAMA (TokenStore). Karena itu kelas ini meniru
/// perilaku [ApiClient] — timeout per-request, ApiException terstruktur,
/// auto-logout saat 401 — dengan dua penyesuaian:
///
/// - base URL `documentBaseUrl` + prefix `/api/v1`;
/// - timeout upload (multipart) 60 detik (unggah PDF/lampiran 20 MB di
///   jaringan lambat butuh lebih dari 30 detik default).
///
/// Error envelope service ini memakai `error.code` (bukan `message` root
/// ala Laravel legacy), sehingga [ApiException.body] selalu menyimpan body
/// asli dan [DocumentApiExceptionX.errorCode] membaca kodenya.
class DocumentApiClient {
  static final DocumentApiClient _instance = DocumentApiClient._internal();
  factory DocumentApiClient() => _instance;
  DocumentApiClient._internal();

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 60);

  String get _baseUrl => '${ApiConstants.documentBaseUrl}/api/v1';

  Future<String?> _getToken() => TokenStore.instance.readToken();

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    var uri = Uri.parse('$_baseUrl/$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  /// GET yang mengembalikan isi `data` dari envelope sukses.
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = _uri(path, queryParams);
    AppLogger.debug('DocumentApiClient GET: $uri');
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_requestTimeout);
    return _handleResponse(response, path: path);
  }

  /// GET yang mengembalikan SELURUH body JSON (termasuk `meta` paginasi).
  Future<Map<String, dynamic>> getRaw(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = _uri(path, queryParams);
    AppLogger.debug('DocumentApiClient GET (raw): $uri');
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_requestTimeout);
    return _handleRawResponse(response, path: path);
  }

  /// GET yang mengembalikan BYTES mentah — untuk endpoint non-JSON
  /// (mis. stream scan PDF `GET /incoming-letters/{id}/scan`, PDF ~20 MB
  /// dengan timeout 60 detik ala upload). Error tetap diparse sebagai
  /// envelope `{error:{code,message}}` bila body-nya JSON.
  Future<Uint8List> getBytes(String path) async {
    final uri = _uri(path);
    AppLogger.debug('DocumentApiClient GET (bytes): $uri');
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_uploadTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401) {
      _onUnauthorized();
    }

    dynamic json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      json = null; // body bukan JSON (mis. HTML gateway) — fallback generik.
    }
    throw _toApiException(json, response.statusCode);
  }

  /// POST JSON yang mengembalikan isi `data` dari envelope sukses.
  Future<dynamic> post(String path, {dynamic body}) async {
    final uri = _uri(path);
    AppLogger.debug('DocumentApiClient POST: $uri');
    final response = await http
        .post(uri, headers: await _headers(),
            body: body != null ? jsonEncode(body) : null)
        .timeout(_requestTimeout);
    return _handleResponse(response, path: path);
  }

  /// PATCH JSON yang mengembalikan isi `data` dari envelope sukses.
  Future<dynamic> patch(String path, {dynamic body}) async {
    final uri = _uri(path);
    AppLogger.debug('DocumentApiClient PATCH: $uri');
    final response = await http
        .patch(uri, headers: await _headers(),
            body: body != null ? jsonEncode(body) : null)
        .timeout(_requestTimeout);
    return _handleResponse(response, path: path);
  }

  /// DELETE yang mengembalikan isi `data` (biasanya null) dari envelope.
  Future<dynamic> delete(String path) async {
    final uri = _uri(path);
    AppLogger.debug('DocumentApiClient DELETE: $uri');
    final response = await http
        .delete(uri, headers: await _headers())
        .timeout(_requestTimeout);
    return _handleResponse(response, path: path);
  }

  /// Multipart request (unggah lampiran / finalize metode d foto) dengan
  /// timeout 60 detik.
  Future<dynamic> multipart({
    required String method,
    required String path,
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
  }) async {
    final token = await _getToken();
    final uri = _uri(path);
    AppLogger.debug('DocumentApiClient Multipart $method: $uri');

    final request = http.MultipartRequest(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    request.fields.addAll(fields);
    request.files.addAll(files);

    final streamedResponse =
        await request.send().timeout(_uploadTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response, path: path);
  }

  /// Trigger auto-logout saat 401 (sesi habis) — sama perilakunya dengan
  /// [ApiClient]; fire-and-forget agar caller tetap menerima exception.
  void _onUnauthorized() {
    AuthSession.instance.handleUnauthorized();
  }

  dynamic _handleResponse(http.Response response, {String? path}) {
    AppLogger.debug('DocumentApiClient Response (${response.statusCode}): '
        '${AppLogger.preview(response.body)}');

    if (response.statusCode == 401) {
      _onUnauthorized();
    }
    final json = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json is Map<String, dynamic> && json['success'] == true) {
        return json['data'];
      }
      return json;
    }

    throw _toApiException(json, response.statusCode);
  }

  Map<String, dynamic> _handleRawResponse(http.Response response,
      {String? path}) {
    AppLogger.debug('DocumentApiClient Response (${response.statusCode}): '
        '${AppLogger.preview(response.body)}');

    if (response.statusCode == 401) {
      _onUnauthorized();
    }
    final json = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json is Map<String, dynamic>) return json;
      throw ApiException(
        message: 'Format respons tidak dikenali.',
        statusCode: response.statusCode,
      );
    }

    throw _toApiException(json, response.statusCode);
  }

  /// Bangun [ApiException] dari body error service document.
  ///
  /// Bentuk utama: `{error: {code, message, details?}}`. Fallback ke
  /// `message` root / `errors` per-field Laravel untuk menjaga kompatibilitas
  /// bila backend menulis bentuk legacy.
  ApiException _toApiException(dynamic json, int statusCode) {
    Map<String, dynamic>? map;
    if (json is Map<String, dynamic>) map = json;

    final error = map?['error'];
    if (error is Map<String, dynamic>) {
      return ApiException(
        message: error['message']?.toString() ??
            'Terjadi kesalahan pada server (Status $statusCode).',
        statusCode: statusCode,
        body: map,
      );
    }

    final errors = map?['errors'];
    if (errors is Map) {
      final message = errors.values
          .expand((e) => e is List ? e : [e])
          .map((e) => e.toString())
          .join(', ');
      return ApiException(
        message: message,
        statusCode: statusCode,
        body: map,
      );
    }

    return ApiException(
      message: map?['message']?.toString() ??
          'Terjadi kesalahan pada server (Status $statusCode).',
      statusCode: statusCode,
      body: map,
    );
  }
}
