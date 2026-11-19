import 'dart:io';
import '../models/supplier_model.dart';
import 'api_client.dart';
import 'image_upload_service.dart';

class SupplierService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch all suppliers with optional filters (used by dropdowns).
  /// Uses a large per_page so dropdowns still receive all suppliers.
  Future<List<SupplierModel>> getSuppliers({
    String? search,
    int? bankId,
    int? status,
  }) async {
    final queryParams = <String, String>{'per_page': '1000'};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (bankId != null) queryParams['bank_id'] = bankId.toString();
    if (status != null) queryParams['status'] = status.toString();

    final data = await _apiClient.get('suppliers', queryParams: queryParams);
    return (data as List).map((e) => SupplierModel.fromJson(e)).toList();
  }

  /// Fetch a single page of suppliers with optional filters.
  /// Returns a map with `data` (a list of SupplierModel) and `has_more` (bool).
  Future<Map<String, dynamic>> getSuppliersPaged({
    int page = 1, int perPage = 20,
    String? search, int? bankId, int? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (bankId != null) queryParams['bank_id'] = bankId.toString();
    if (status != null) queryParams['status'] = status.toString();
    final json = await _apiClient.getRaw('suppliers', queryParams: queryParams);
    if (json['success'] == true) {
      final List data = json['data'] ?? [];
      final meta = json['pagination'] ?? {};
      final hasMore = (meta['current_page'] ?? 1) < (meta['last_page'] ?? 1);
      return {
        'data': data.map((e) => SupplierModel.fromJson(e as Map<String, dynamic>)).toList(),
        'has_more': hasMore,
      };
    }
    throw Exception(json['message'] ?? 'Gagal memuat supplier.');
  }

  /// Fetch a single supplier by id
  Future<SupplierModel> getSupplier(int id) async {
    final data = await _apiClient.get('suppliers/$id');
    return SupplierModel.fromJson(data);
  }

  /// Create a new supplier (with optional image upload)
  Future<SupplierModel> createSupplier(Map<String, dynamic> data, {File? image}) async {
    final Map<String, String> fields = {};
    data.forEach((key, value) {
      if (value != null) fields[key] = value.toString();
    });

    if (image != null) {
      final path = await ImageUploadService.upload(image, directory: 'images/Supplier');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final responseData = await _apiClient.multipart(
      method: 'POST',
      path: 'suppliers',
      fields: fields,
    );
    return SupplierModel.fromJson(responseData);
  }

  /// Update an existing supplier (with optional image upload)
  Future<SupplierModel> updateSupplier(int id, Map<String, dynamic> data, {File? image}) async {
    final Map<String, String> fields = {};
    data.forEach((key, value) {
      if (value != null) fields[key] = value.toString();
    });

    if (image != null) {
      final path = await ImageUploadService.upload(image, directory: 'images/Supplier');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    // Use POST with _method=PUT for multipart form
    final responseData = await _apiClient.multipart(
      method: 'POST',
      path: 'suppliers/$id',
      fields: fields,
    );
    return SupplierModel.fromJson(responseData);
  }

  /// Delete a supplier by id
  Future<void> deleteSupplier(int id) async {
    await _apiClient.delete('suppliers/$id');
  }

  // ── Lookup Methods ─────────────────────────────────────────────────────────

  Future<List<ProvinceModel>> getProvinces() async {
    final data = await _apiClient.get('provinces');
    return (data as List).map((e) => ProvinceModel.fromJson(e)).toList();
  }

  Future<List<CityModel>> getCities(int provinceId) async {
    final data = await _apiClient.get('cities', queryParams: {'province_id': provinceId.toString()});
    return (data as List).map((e) => CityModel.fromJson(e)).toList();
  }

  Future<List<DistrictModel>> getDistricts(int cityId) async {
    final data = await _apiClient.get('districts', queryParams: {'city_id': cityId.toString()});
    return (data as List).map((e) => DistrictModel.fromJson(e)).toList();
  }

  Future<List<SubdistrictModel>> getSubdistricts(int districtId) async {
    final data = await _apiClient.get('subdistricts', queryParams: {'district_id': districtId.toString()});
    return (data as List).map((e) => SubdistrictModel.fromJson(e)).toList();
  }

  Future<List<PostalCodeModel>> getPostalCodes(int subdistrictId) async {
    final data = await _apiClient.get('postal-codes', queryParams: {'subdistrict_id': subdistrictId.toString()});
    return (data as List).map((e) => PostalCodeModel.fromJson(e)).toList();
  }

  Future<List<BankModel>> getBanks() async {
    final data = await _apiClient.get('banks');
    return (data as List).map((e) => BankModel.fromJson(e)).toList();
  }

  /// Validate and parse a QRIS payload (tanpa supplier id — jalan di
  /// mode create maupun edit).
  Future<Map<String, dynamic>> validateQris(String qrisPayload) async {
    final data = await _apiClient.post(
      'suppliers/validate-qris',
      body: {'qris': qrisPayload},
    );
    return data as Map<String, dynamic>;
  }
}
