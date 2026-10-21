import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';
import '../utils/constants.dart';
import 'auth_session.dart';
import 'token_store.dart';

/// Exception HTTP berstatus & body ter-parse — pemanggil bisa membaca
/// payload error terstruktur (mis. data.blockers pada advance impor).
/// toString() mengembalikan message polos agar dialog generik yang
/// memanggil replaceFirst('Exception: ', '') tetap berperilaku sama.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? body;

  ApiException({
    required this.message,
    required this.statusCode,
    this.body,
  });

  @override
  String toString() => message;
}

class ApiClient {
  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Batas waktu maksimum setiap request HTTP. Tanpa timeout, request yang
  /// menggantung (jaringan lambat / server tidak merespons) akan membuat
  /// aplikasi tampak macet selamanya — mis. splash tidak hilang, login/logout
  /// tidak kembali ke menu.
  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return http.get(uri, headers: headers).timeout(_requestTimeout);
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(uri, headers: headers, body: body).timeout(_requestTimeout);
  }

  Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.put(uri, headers: headers, body: body).timeout(_requestTimeout);
  }

  Future<http.Response> _patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return http.delete(uri, headers: headers).timeout(_requestTimeout);
  }

  Future<String?> _getToken() => TokenStore.instance.readToken();

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Sends a GET request to the specified endpoint path.
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    AppLogger.debug('ApiClient GET: $uri');
    final response = await _get(uri, headers: await _headers());
    return _handleResponse(response, path: path);
  }

  /// Deteksi response sukses dari backend yang **inkonsisten**:
  /// - Sebagian controller pakai `'success' => true`
  /// - Sebagian controller (Leave, Readiness, Presence, Hygiene, Location,
  ///   AdminTrackLocation) pakai `'status' => 'success'`
  /// Keduanya dianggap sukses agar legacy controller tetap kompatibel.
  bool _isSuccess(Map<String, dynamic> json) =>
      json['success'] == true || json['status'] == 'success';

  /// GET yang langsung return `List<T>`.
  ///
  /// Memanggil [get] lalu decode setiap elemen via [fromJson].
  Future<List<T>> getList<T>(
    String path, {
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, String>? queryParams,
  }) async {
    final data = await get(path, queryParams: queryParams);
    final list = data is List ? data : const <dynamic>[];
    return list
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// GET yang return single object `T`.
  Future<T> getObject<T>(
    String path, {
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, String>? queryParams,
  }) async {
    final data = await get(path, queryParams: queryParams);
    return fromJson(data as Map<String, dynamic>);
  }

  /// Sama seperti [get], tapi mengembalikan SELURUH body JSON (termasuk
  /// key `pagination`/`meta`) agar pemanggil bisa membaca metadata paginasi.
  Future<Map<String, dynamic>> getRaw(String path,
      {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    AppLogger.debug('ApiClient GET (raw): $uri');
    final response = await _get(uri, headers: await _headers());

    if (response.statusCode == 401) {
      _onUnauthorized(path: path);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) return json;
      throw Exception('Format respons tidak dikenali.');
    }

    final json = jsonDecode(response.body);
    final errors = json['errors'];
    if (errors != null && errors is Map) {
      final message = errors.values.expand((e) => e as List).join(', ');
      throw Exception(message);
    }

    throw Exception(json['message'] ??
        'Terjadi kesalahan pada server (Status ${response.statusCode}).');
  }

  /// Sends a POST request to the specified endpoint path.
  Future<dynamic> post(String path, {dynamic body}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    AppLogger.debug('ApiClient POST: $uri');
    final response = await _post(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, path: path);
  }

  /// POST yang return single object `T`.
  Future<T> postObject<T>(
    String path, {
    required T Function(Map<String, dynamic> json) fromJson,
    dynamic body,
  }) async {
    final data = await post(path, body: body);
    return fromJson(data as Map<String, dynamic>);
  }

  /// Sama seperti [post], tapi mengembalikan SELURUH body JSON agar
  /// pemanggil bisa membaca field di luar `data`.
  Future<Map<String, dynamic>> postRaw(String path, {dynamic body}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    AppLogger.debug('ApiClient POST (raw): $uri');
    final response = await _post(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      _onUnauthorized(path: path);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) return json;
      throw Exception('Format respons tidak dikenali.');
    }

    final json = jsonDecode(response.body);
    final map = json is Map<String, dynamic> ? json : null;
    final errors = map?['errors'];
    if (errors != null && errors is Map) {
      final message = errors.values.expand((e) => e as List).join(', ');
      throw ApiException(
        message: message,
        statusCode: response.statusCode,
        body: map,
      );
    }

    throw ApiException(
      message: map?['message']?.toString() ??
          'Terjadi kesalahan pada server (Status ${response.statusCode}).',
      statusCode: response.statusCode,
      body: map,
    );
  }

  /// Sends a PUT request to the specified endpoint path.
  Future<dynamic> put(String path, {dynamic body}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    AppLogger.debug('ApiClient PUT: $uri');
    final response = await _put(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, path: path);
  }

  /// Sama seperti [put], tapi mengembalikan SELURUH body JSON agar
  /// pemanggil bisa membaca field di luar `data`.
  Future<Map<String, dynamic>> putRaw(String path, {dynamic body}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    AppLogger.debug('ApiClient PUT (raw): $uri');
    final response = await _put(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      _onUnauthorized(path: path);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) return json;
      throw Exception('Format respons tidak dikenali.');
    }

    final json = jsonDecode(response.body);
    final errors = json['errors'];
    if (errors != null && errors is Map) {
      final message = errors.values.expand((e) => e as List).join(', ');
      throw Exception(message);
    }

    throw Exception(json['message'] ??
        'Terjadi kesalahan pada server (Status ${response.statusCode}).');
  }

  /// Sends a PATCH request to the specified endpoint path.
  Future<dynamic> patch(String path, {dynamic body}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    AppLogger.debug('ApiClient PATCH: $uri');
    final response = await _patch(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, path: path);
  }

  /// PUT yang return single object `T`.
  Future<T> putObject<T>(
    String path, {
    required T Function(Map<String, dynamic> json) fromJson,
    dynamic body,
  }) async {
    final data = await put(path, body: body);
    return fromJson(data as Map<String, dynamic>);
  }

  /// Sends a DELETE request to the specified endpoint path.
  Future<dynamic> delete(String path, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    AppLogger.debug('ApiClient DELETE: $uri');
    final response = await _delete(uri, headers: await _headers());
    return _handleResponse(response, path: path);
  }

  /// Sends a multipart request (e.g. for uploads).
  Future<dynamic> multipart({
    required String method,
    required String path,
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    AppLogger.debug('ApiClient Multipart $method: $uri');

    final request = http.MultipartRequest(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    request.fields.addAll(fields);
    if (files != null) {
      request.files.addAll(files);
    }

    final streamedResponse = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response, path: path);
  }

  /// Sama seperti [multipart], tapi mengembalikan SELURUH body JSON agar
  /// pemanggil bisa membaca field di luar `data` (mis. `invoice_id`).
  Future<Map<String, dynamic>> multipartRaw({
    required String method,
    required String path,
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}/$path');
    AppLogger.debug('ApiClient Multipart $method (raw): $uri');

    final request = http.MultipartRequest(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    request.fields.addAll(fields);
    if (files != null) {
      request.files.addAll(files);
    }

    final streamedResponse = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401) {
      _onUnauthorized(path: path);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) return json;
      throw Exception('Format respons tidak dikenali.');
    }

    return _handleResponse(response, path: path);
  }

  /// Trigger auto-logout saat 401, kecuali untuk endpoint publik (login).
  /// Fire-and-forget — tidak di-await agar caller tetap dapat exception 401.
  void _onUnauthorized({String? path}) {
    // Endpoint login dikecualikan: 401 di login = kredensial salah, bukan
    // sesi expired.
    if (path != null && (path == 'login' || path.startsWith('login/'))) {
      return;
    }
    AuthSession.instance.handleUnauthorized();
  }

  dynamic _handleResponse(http.Response response, {String? path}) {
    AppLogger.debug('ApiClient Response (${response.statusCode}): '
        '${AppLogger.preview(response.body)}');

    if (response.statusCode == 401) {
      _onUnauthorized(path: path);
    }
    final json = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json is Map<String, dynamic> && _isSuccess(json)) {
        return json['data'];
      }
    }

    // Handle Laravel validation errors or similar custom maps
    final errors = json['errors'];
    if (errors != null && errors is Map) {
      final message = errors.values.expand((e) => e as List).join(', ');
      throw Exception(message);
    }

    throw Exception(json['message'] ?? 'Terjadi kesalahan pada server (Status ${response.statusCode}).');
  }
}
