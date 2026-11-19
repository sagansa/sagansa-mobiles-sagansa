import '../models/sales_order_employee_model.dart';
import 'api_client.dart';

class SalesOrderEmployeeService {
  final ApiClient _api = ApiClient();

  /// List penjualan employee.
  /// [salesId] hanya dipakai role admin untuk filter per sales.
  /// [page] untuk pagination. Mengembalikan (list, hasNext).
  Future<(List<SalesOrderEmployeeModel>, bool)> getList({
    int? salesId,
    int page = 1,
    int perPage = 20,
  }) async {
    final body = await _api.getRaw(
      'sales-orders/employee',
      queryParams: {
        'page': '$page',
        'per_page': '$perPage',
        if (salesId != null) 'sales_id': '$salesId',
      },
    );
    final data = (body['data'] as List<dynamic>?) ?? [];
    final meta = (body['meta'] as Map<String, dynamic>?) ?? {};
    final list = data
        .map((e) => SalesOrderEmployeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final currentPage = (meta['current_page'] as num? ?? 1).toInt();
    final lastPage = (meta['last_page'] as num? ?? 1).toInt();
    final hasNext = currentPage < lastPage;
    return (list, hasNext);
  }

  /// Data pendukung untuk form (transfer account, delivery address, products).
  /// Dipanggil sekali saat buka form create/edit.
  Future<Map<String, dynamic>> getSupportingData() async {
    final data = await _api.get('sales-orders/employee/supporting-data');
    return (data as Map<String, dynamic>?) ?? {};
  }

  Future<SalesOrderEmployeeModel> getDetail(int id) async {
    final data = await _api.get('sales-orders/employee/$id');
    return SalesOrderEmployeeModel.fromJson(
        (data as Map<String, dynamic>?) ?? {});
  }

  /// Create penjualan employee (role sales).
  Future<SalesOrderEmployeeModel> create({
    required int storeId,
    required String deliveryDate, // yyyy-MM-dd
    required int deliveryAddressId,
    required int transferToAccountId,
    String? imagePayment,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _api.post(
      'sales-orders/employee',
      body: {
        'store_id': storeId,
        'delivery_date': deliveryDate,
        'delivery_address_id': deliveryAddressId,
        'transfer_to_account_id': transferToAccountId,
        if (imagePayment != null) 'image_payment': imagePayment,
        if (notes != null) 'notes': notes,
        'items': items,
      },
    );
    return SalesOrderEmployeeModel.fromJson(
        (data as Map<String, dynamic>?) ?? {});
  }

  /// Update penjualan employee (role sales, milik sendiri, belum valid).
  /// Field yang null tidak dikirim (partial update).
  Future<SalesOrderEmployeeModel> update(
    int id, {
    int? storeId,
    String? deliveryDate,
    int? deliveryAddressId,
    int? transferToAccountId,
    String? imagePayment,
    bool clearImage = false,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) async {
    final payload = <String, dynamic>{};
    if (storeId != null) payload['store_id'] = storeId;
    if (deliveryDate != null) payload['delivery_date'] = deliveryDate;
    if (deliveryAddressId != null) payload['delivery_address_id'] = deliveryAddressId;
    if (transferToAccountId != null) payload['transfer_to_account_id'] = transferToAccountId;
    if (clearImage) {
      payload['image_payment'] = null;
    } else if (imagePayment != null) {
      payload['image_payment'] = imagePayment;
    }
    if (notes != null) payload['notes'] = notes;
    if (items != null) payload['items'] = items;

    final data = await _api.put(
      'sales-orders/employee/$id',
      body: payload,
    );
    return SalesOrderEmployeeModel.fromJson(
        (data as Map<String, dynamic>?) ?? {});
  }

  Future<void> delete(int id) async {
    await _api.delete('sales-orders/employee/$id');
  }

  /// Set payment_status (role admin).
  /// Endpoint backend terdaftar sebagai PATCH (bukan POST).
  Future<SalesOrderEmployeeModel> updatePaymentStatus(int id, int status) async {
    final data = await _api.patch(
      'sales-orders/employee/$id/payment',
      body: {'payment_status': status},
    );
    return SalesOrderEmployeeModel.fromJson(
        (data as Map<String, dynamic>?) ?? {});
  }
}
