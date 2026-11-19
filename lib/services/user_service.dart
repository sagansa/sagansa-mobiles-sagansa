import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/applicant_detail_model.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    final data = await _api.get('users', queryParams: role != null ? {'role': role} : null);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<ApplicantDetail> getProfile() async {
    // Backend recruitment (GET /profile) mengembalikan
    // {success, details, experiences} — bukan {data}.
    final raw = await _api.getRaw('profile');
    final details = raw['details'];
    if (details == null) return ApplicantDetail();
    if (details is Map<String, dynamic>) {
      return ApplicantDetail.fromJson(details);
    }
    return ApplicantDetail.fromJson(
        Map<String, dynamic>.from(details as Map));
  }

  Future<ApplicantDetail> updateProfile(ApplicantDetail data,
      {bool bankOnly = false, File? ktpFile, File? selfieFile}) async {
    // Backend hanya sediakan POST /profile (tidak ada PUT) dan
    // mengembalikan {success, message, details}.
    final payload = data.toProfilePayload(bankOnly: bankOnly);

    // Ada file (KTP/selfie) → multipart seperti web recruitment
    // (FormData POST /profile). Tanpa file → JSON biasa.
    final Map<String, dynamic> raw;
    if (ktpFile != null || selfieFile != null) {
      final fields = payload.map((k, v) => MapEntry(k, v.toString()));
      final files = <http.MultipartFile>[];
      if (ktpFile != null) {
        files.add(await http.MultipartFile.fromPath(
            'ktp_image', ktpFile.path));
      }
      if (selfieFile != null) {
        files.add(await http.MultipartFile.fromPath(
            'selfie_image', selfieFile.path));
      }
      raw = await _api.multipartRaw(
        method: 'POST',
        path: 'profile',
        fields: fields,
        files: files,
      );
    } else {
      raw = await _api.postRaw('profile', body: payload);
    }
    final details = raw['details'];
    if (details == null) return data;
    if (details is Map<String, dynamic>) {
      return ApplicantDetail.fromJson(details);
    }
    return ApplicantDetail.fromJson(
        Map<String, dynamic>.from(details as Map));
  }

  /// Hapus foto KTP / selfie — backend DELETE /profile/image.
  /// [type] harus 'ktp_image' atau 'selfie_image'.
  /// Ditolak backend bila profil sudah submitted (403).
  Future<void> deleteProfileImage(String type) async {
    assert(type == 'ktp_image' || type == 'selfie_image');
    await _api.delete('profile/image', queryParams: {'type': type});
  }

  Future<Map<String, dynamic>> getAdminProfiles({
    int page = 1,
    int perPage = 20,
    String? search,
    String? status,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    return await _api.getRaw('admin/profile', queryParams: queryParams);
  }

  Future<Map<String, dynamic>> getAdminProfileDetail(dynamic profileId) async {
    final raw = await _api.getRaw('admin/profile/$profileId');
    if (raw['data'] is Map<String, dynamic>) {
      return {...raw, ...(raw['data'] as Map<String, dynamic>)};
    }
    return raw;
  }

  /// Detail profil (termasuk rekening) berdasarkan user id — dipakai untuk
  /// menampilkan rekening pegawai penerima payment receipt gaji harian.
  Future<Map<String, dynamic>?> getAdminProfileByUser(dynamic userId) async {
    try {
      final raw = await _api.getRaw('admin/profile/user/$userId');
      if (raw['data'] is Map<String, dynamic>) {
        return {...raw, ...(raw['data'] as Map<String, dynamic>)};
      }
      return raw;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> setProfileStatus(dynamic profileId, String status) async {
    final raw = await _api.putRaw('admin/profile/$profileId/status', body: {'status': status});
    if (raw['data'] is Map<String, dynamic>) {
      return {...raw, ...(raw['data'] as Map<String, dynamic>)};
    }
    return raw;
  }
}
