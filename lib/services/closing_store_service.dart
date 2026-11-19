import 'dart:io';
import 'api_client.dart';
import 'image_upload_service.dart';

class ClosingStoreService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getClosingStores() async {
    final data = await _api.get('closing-stores', queryParams: {'per_page': '1000'});
    return data as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getClosingStoresPaged({
    int page = 1,
    int perPage = 20,
    int? storeId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? status,
  }) async {
    final response = await _api.getRaw('closing-stores', queryParams: {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (storeId != null) 'store_id': storeId.toString(),
      if (dateFrom != null)
        'date_from': dateFrom.toIso8601String().substring(0, 10),
      if (dateTo != null) 'date_to': dateTo.toIso8601String().substring(0, 10),
      if (status != null) 'status': status.toString(),
    });
    final List data = response['data'] as List<dynamic>? ?? [];
    final meta = response['pagination'] ?? {};
    final hasMore = (meta['current_page'] ?? 1) < (meta['last_page'] ?? 1);
    return {'data': data.cast<Map<String, dynamic>>(), 'has_more': hasMore};
  }

  Future<Map<String, dynamic>> getClosingStore(int id) async {
    return await _api.get('closing-stores/$id');
  }

  Future<Map<String, dynamic>> getActiveDraft() async {
    return await _api.get('closing-stores/active-draft');
  }

  Future<Map<String, dynamic>> getUnpaidTransactions() async {
    return await _api.get('closing-stores/unpaid-transactions');
  }

  Future<void> saveClosingStore(Map<String, dynamic> data) async {
    await _api.post('closing-stores/save', body: data);
  }


  Future<List<dynamic>> getVehicles() async {
    final data = await _api.get('closing-stores/vehicles');
    return data as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getSuppliers() async {
    final data = await _api.get('closing-stores/suppliers');
    return data as List<dynamic>? ?? [];
  }

  /// Get all daily salaries (with pagination)
  Future<Map<String, dynamic>> getDailySalaries({
    int page = 1,
    int perPage = 20,
    int? userId,
    String? employeeRole, // 'active' (staff) | 'former' (former-employee)
    String? status,
    int? paymentTypeId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (userId != null) params['user_id'] = userId.toString();
    if (employeeRole != null) params['employee_role'] = employeeRole;
    if (status != null) params['status'] = status;
    if (paymentTypeId != null) params['payment_type_id'] = paymentTypeId.toString();
    if (dateFrom != null) params['date_from'] = dateFrom.toIso8601String().substring(0, 10);
    if (dateTo != null) params['date_to'] = dateTo.toIso8601String().substring(0, 10);

    final response = await _api.getRaw('daily-salaries', queryParams: params);
    return {
      'data': response['data'] as List<dynamic>? ?? [],
      'meta': response['meta'] ?? {},
    };
  }

  /// Bulk update status for daily salaries (admin only)
  Future<int> bulkUpdateDailySalaryStatus(List<int> ids, int status) async {
    final result = await _api.post('daily-salaries/bulk-update-status', body: {
      'ids': ids,
      'status': status,
    });
    return (result as Map<String, dynamic>)['updated_count'] ?? 0;
  }

  /// Get daily salaries for payment receipt (transfer, status 1/3, belum
  /// terikat receipt apa pun). Endpoint for-payment, bukan index.
  Future<List<dynamic>> getDailySalariesForPayment({int? userId}) async {
    final params = <String, String>{};
    if (userId != null) params['user_id'] = userId.toString();
    final data = await _api.get('daily-salaries/for-payment',
        queryParams: params.isNotEmpty ? params : null);
    return data as List<dynamic>? ?? [];
  }

  /// Get employees for daily salary payment selection
  Future<List<dynamic>> getEmployeesForDailySalary() async {
    final data = await _api.get('daily-salaries/employees');
    return data as List<dynamic>? ?? [];
  }

  /// Buat daily salary manual (created_by = user login, status belum dibayar).
  /// Server menolak duplikat user + tanggal yang sama.
  Future<Map<String, dynamic>> createDailySalary(Map<String, dynamic> data) async {
    final result = await _api.post('daily-salaries', body: data);
    return result is Map<String, dynamic> ? result : {};
  }

  /// Update daily salary milik sendiri (atau admin), hanya selama belum
  /// dibayar. Status tidak dapat diubah dari sini.
  Future<Map<String, dynamic>> updateDailySalary(int id, Map<String, dynamic> data) async {
    final result = await _api.put('daily-salaries/$id', body: data);
    return result is Map<String, dynamic> ? result : {};
  }

  /// Hapus daily salary milik sendiri (atau admin). Yang sudah dibayar atau
  /// terikat payment receipt ditolak server.
  Future<void> deleteDailySalary(int id) async {
    await _api.delete('daily-salaries/$id');
  }


  /// Create a payment receipt
  Future<Map<String, dynamic>> createPaymentReceipt(Map<String, dynamic> data, {File? imageFile}) async {
    final fields = <String, String>{};
    data.forEach((key, value) {
      if (value != null) {
        if (value is List) {
          for (var i = 0; i < value.length; i++) {
            fields['$key[$i]'] = value[i].toString();
          }
        } else {
          fields[key] = value.toString();
        }
      }
    });

    if (imageFile != null) {
      final path = await ImageUploadService.upload(imageFile, directory: 'images/PaymentReceipt');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final result = await _api.multipart(
      method: 'POST',
      path: 'procurement/payment-receipts',
      fields: fields,
    );
    return (result as Map<String, dynamic>?) ?? {};
  }

  /// Get payment receipts list
  Future<List<dynamic>> getPaymentReceipts({int page = 1, int perPage = 10}) async {
    final data = await _api.get('procurement/payment-receipts', queryParams: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    return data as List<dynamic>? ?? [];
  }
}
