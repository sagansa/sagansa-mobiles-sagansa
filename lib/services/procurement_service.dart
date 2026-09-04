import 'dart:io';
import '../models/procurement_model.dart';
import 'api_client.dart';
import 'image_upload_service.dart';

class ProcurementService {
  final ApiClient _api = ApiClient();

  Future<List<ProcurementProduct>> getProducts() async {
    final data = await _api.get('procurement/products');
    final List<dynamic> productsJson = data is List ? data : [];
    return productsJson.map((e) => ProcurementProduct.fromJson(e)).toList();
  }

  Future<List<RequestPurchase>> getRequests({
    int page = 1,
    int perPage = 1000,
  }) async {
    final data = await _api.get('procurement/requests', queryParams: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final List<dynamic> requestsJson = data is List ? data : [];
    return requestsJson.map((e) => RequestPurchase.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getRequestsPaged(
      {int page = 1, int perPage = 20, int? storeId}) async {
    final body = await _api.getRaw('procurement/requests', queryParams: {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (storeId != null) 'store_id': storeId.toString(),
    });
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load procurement requests');
    }
    final List<dynamic> data = body['data'] ?? [];
    final meta = body['pagination'] ?? {};
    final hasMore = (meta['current_page'] ?? 1) < (meta['last_page'] ?? 1);
    return {
      'data': data.map((e) => RequestPurchase.fromJson(e)).toList(),
      'has_more': hasMore,
    };
  }

  Future<Map<String, dynamic>> getProcurementSummary() async {
    final body = await _api.getRaw('procurement/requests');
    final List<dynamic> requestsJson = body['data'] ?? [];
    final List<RequestPurchase> requests =
        requestsJson.map((e) => RequestPurchase.fromJson(e)).toList();
    final Map<String, dynamic> meta = body['meta'] ?? {};
    final Map<String, dynamic> invoiceCounts =
        meta['invoice_counts'] ?? {'draft': 0, 'done': 0, 'unpaid': 0};

    return {
      'requests': requests,
      'invoice_draft': invoiceCounts['draft'] ?? 0,
      'invoice_done': invoiceCounts['done'] ?? 0,
      'invoice_unpaid': invoiceCounts['unpaid'] ?? 0,
    };
  }

  Future<RequestPurchase> getRequestDetail(int id) async {
    final data = await _api.get('procurement/requests/$id');
    return RequestPurchase.fromJson(data);
  }

  Future<bool> createRequest(
      int storeId, List<Map<String, dynamic>> items) async {
    await _api.post('procurement/requests', body: {
      'store_id': storeId,
      'items': items,
    });
    return true;
  }

  Future<bool> approveItem(int itemId) async {
    await _api.post('procurement/requests/items/$itemId/approve');
    return true;
  }

  Future<bool> rejectItem(int itemId) async {
    await _api.post('procurement/requests/items/$itemId/reject');
    return true;
  }

  Future<bool> cancelItem(int itemId) async {
    await _api.post('procurement/requests/items/$itemId/cancel');
    return true;
  }

  Future<bool> receiveInvoice(int invoiceId) async {
    await _api.post('procurement/invoices/$invoiceId/receive');
    return true;
  }

  Future<void> deleteInvoice(int invoiceId) async {
    await _api.delete('procurement/invoices/$invoiceId');
  }

  Future<void> deleteRequest(int requestId) async {
    await _api.delete('procurement/requests/$requestId');
  }

  Future<List<Map<String, dynamic>>> getDetailRequests({
    required int storeId,
    int? paymentTypeId,
  }) async {
    final params = <String, String>{
      'store_id': storeId.toString(),
    };
    if (paymentTypeId != null) {
      params['payment_type_id'] = paymentTypeId.toString();
    }
    final body =
        await _api.getRaw('procurement/detail-requests', queryParams: params);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load detail requests');
    }
    return List<Map<String, dynamic>>.from(body['data']);
  }

  Future<int> createInvoiceStandalone({
    required int supplierId,
    required int storeId,
    required int paymentTypeId,
    required String date,
    required List<Map<String, dynamic>> items,
    int? taxes,
    int? discounts,
    String? notes,
    File? image,
  }) async {
    final fields = <String, String>{
      'supplier_id': supplierId.toString(),
      'store_id': storeId.toString(),
      'payment_type_id': paymentTypeId.toString(),
      'date': date,
    };
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      fields['items[$i][detail_request_id]'] =
          item['detail_request_id'].toString();
      fields['items[$i][quantity_product]'] =
          item['quantity_product'].toString();
      fields['items[$i][subtotal_invoice]'] =
          item['subtotal_invoice'].toString();
    }
    if (taxes != null) fields['taxes'] = taxes.toString();
    if (discounts != null) fields['discounts'] = discounts.toString();
    if (notes != null) fields['notes'] = notes;

    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/InvoicePurchase');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final data = await _api.multipart(
      method: 'POST',
      path: 'procurement/invoices',
      fields: fields,
    );
    return data?['id'] ?? 0;
  }

  Future<int> createInvoice(
    int requestId, {
    required int supplierId,
    required List<Map<String, dynamic>> items,
    int? paymentTypeId,
    int? taxes,
    int? discounts,
    List<int>? requestIds,
    File? image,
  }) async {
    final fields = <String, String>{
      'supplier_id': supplierId.toString(),
    };
    if (paymentTypeId != null) {
      fields['payment_type_id'] = paymentTypeId.toString();
    }
    if (taxes != null) {
      fields['taxes'] = taxes.toString();
    }
    if (discounts != null) {
      fields['discounts'] = discounts.toString();
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      fields['items[$i][detail_request_id]'] =
          item['detail_request_id'].toString();
      fields['items[$i][subtotal_invoice]'] =
          item['subtotal_invoice'].toString();
      fields['items[$i][quantity]'] = item['quantity'].toString();
    }
    if (requestIds != null && requestIds.isNotEmpty) {
      for (var i = 0; i < requestIds.length; i++) {
        fields['request_ids[$i]'] = requestIds[i].toString();
      }
    }

    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/InvoicePurchase');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final rawBody = await _api.multipartRaw(
      method: 'POST',
      path: 'procurement/requests/$requestId/create-invoice',
      fields: fields,
    );
    return int.tryParse('${rawBody['invoice_id']}') ??
        int.tryParse('${rawBody['id']}') ??
        0;
  }

  Future<InvoicePurchase> updateInvoice(
    int invoiceId, {
    int? supplierId,
    int? paymentTypeId,
    int? taxes,
    int? discounts,
    String? notes,
    List<Map<String, dynamic>>? items,
    File? image,
    int? salesOrderId,
    bool clearSalesOrderLink = false,
  }) async {
    final fields = <String, String>{
      '_method': 'PUT',
    };
    if (supplierId != null) fields['supplier_id'] = supplierId.toString();
    if (paymentTypeId != null) {
      fields['payment_type_id'] = paymentTypeId.toString();
    }
    if (taxes != null) fields['taxes'] = taxes.toString();
    if (discounts != null) fields['discounts'] = discounts.toString();
    if (notes != null) fields['notes'] = notes;
    if (items != null) {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        fields['items[$i][detail_invoice_id]'] =
            item['detail_invoice_id'].toString();
        fields['items[$i][subtotal_invoice]'] =
            item['subtotal_invoice'].toString();
        fields['items[$i][quantity]'] = item['quantity'].toString();
      }
    }

    if (clearSalesOrderLink) {
      fields['sales_order_id'] = '';
    } else if (salesOrderId != null) {
      fields['sales_order_id'] = salesOrderId.toString();
    }

    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/InvoicePurchase');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final data = await _api.multipart(
      method: 'POST',
      path: 'procurement/invoices/$invoiceId',
      fields: fields,
    );
    return InvoicePurchase.fromJson(data);
  }

  /// Ganti foto invoice SAJA — berlaku di semua payment_status (endpoint
  /// khusus backend; edit penuh tetap terkunci setelah dibayar).
  Future<InvoicePurchase> updateInvoiceImage(int invoiceId, File image) async {
    final path = await ImageUploadService.upload(image,
        directory: 'images/InvoicePurchase');
    if (path == null) throw Exception('Gagal upload gambar ke img service.');

    await _api.multipart(
      method: 'POST',
      path: 'procurement/invoices/$invoiceId/image',
      fields: {'image': path},
    );
    return getInvoiceDetail(invoiceId);
  }

  /// Cari kandidat penjualan utk dikaitkan ke invoice (link-candidates).
  Future<List<SalesOrderCandidate>> searchSalesOrderCandidates(
      String query) async {
    final body = await _api.getRaw(
      'sales-orders/link-candidates',
      queryParams: {'q': query},
    );
    final list = body['data'] as List? ?? [];
    return list
        .map((e) =>
            SalesOrderCandidate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PaginatedResult<InvoicePurchase>> getInvoices({
    String? orderStatus,
    String? paymentStatus,
    int? storeId,
    int? supplierId,
    int page = 1,
    int perPage = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (orderStatus != null) params['order_status'] = orderStatus;
    if (paymentStatus != null) params['payment_status'] = paymentStatus;
    if (storeId != null) params['store_id'] = storeId.toString();
    if (supplierId != null) params['supplier_id'] = supplierId.toString();

    final body = await _api.getRaw('procurement/invoices', queryParams: params);
    final List<dynamic> invoicesJson = body['data'] ?? [];
    final meta = body['meta'] as Map<String, dynamic>? ?? {};
    return PaginatedResult(
      items: invoicesJson.map((e) => InvoicePurchase.fromJson(e)).toList(),
      currentPage: meta['current_page'] ?? 1,
      lastPage: meta['last_page'] ?? 1,
      perPage: meta['per_page'] ?? perPage,
      total: meta['total'] ?? 0,
    );
  }

  Future<PaginatedResult<PaymentReceipt>> getPaymentReceipts({
    int? invoiceId,
    int page = 1,
    int perPage = 10,
    String? paymentFor,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (invoiceId != null) params['invoice_id'] = invoiceId.toString();
    if (paymentFor != null) params['payment_for'] = paymentFor;

    final body =
        await _api.getRaw('procurement/payment-receipts', queryParams: params);
    final List<dynamic> receiptsJson = body['data'] ?? [];
    final meta = body['meta'] as Map<String, dynamic>? ?? {};
    return PaginatedResult(
      items: receiptsJson.map((e) => PaymentReceipt.fromJson(e)).toList(),
      currentPage: meta['current_page'] ?? 1,
      lastPage: meta['last_page'] ?? 1,
      perPage: meta['per_page'] ?? perPage,
      total: meta['total'] ?? 0,
    );
  }

  Future<PaymentReceipt> getPaymentReceiptDetail(int id) async {
    final data = await _api.get('procurement/payment-receipts/$id');
    return PaymentReceipt.fromJson(data);
  }

  Future<PaymentReceipt> createPaymentReceipt({
    required List<int> invoiceIds,
    required int transferAmount,
    int? totalAmount,
    String? notes,
    File? image,
  }) async {
    final fields = <String, String>{};
    for (var id in invoiceIds) {
      fields['invoice_ids[]'] = id.toString();
    }
    fields['transfer_amount'] = transferAmount.toString();
    if (totalAmount != null) {
      fields['total_amount'] = totalAmount.toString();
    }
    if (notes != null) {
      fields['notes'] = notes;
    }
    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/PaymentReceipt');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final data = await _api.multipart(
      method: 'POST',
      path: 'procurement/payment-receipts',
      fields: fields,
    );
    return PaymentReceipt.fromJson(data);
  }

  Future<Map<String, dynamic>> createFuelServicePaymentReceipt({
    required List<int> fuelServiceIds,
    required int transferAmount,
    int? totalAmount,
    String? notes,
    File? image,
  }) async {
    final fields = <String, String>{};
    // Gunakan indeks numerik (fuel_service_ids[0], [1], ...) agar setiap id
    // terkirim sebagai field terpisah. Memakai 'fuel_service_ids[]' pada Map
    // <String,String> akan saling menimpa — hanya id terakhir yang terkirim.
    for (var i = 0; i < fuelServiceIds.length; i++) {
      fields['fuel_service_ids[$i]'] = fuelServiceIds[i].toString();
    }
    fields['transfer_amount'] = transferAmount.toString();
    if (totalAmount != null) {
      fields['total_amount'] = totalAmount.toString();
    }
    if (notes != null) {
      fields['notes'] = notes;
    }
    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/PaymentReceipt');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final data = await _api.multipart(
      method: 'POST',
      path: 'procurement/fuel-service-payment-receipts',
      fields: fields,
    );
    return (data as Map<String, dynamic>?) ?? {};
  }

  /// Update payment receipt fuel & service: edit daftar item (status sync
  /// dua arah di backend) + metadata. total_amount computed backend.
  Future<Map<String, dynamic>> updateFuelServicePaymentReceipt({
    required int receiptId,
    required List<int> fuelServiceIds,
    required int transferAmount,
    String? notes,
    File? image,
  }) async {
    final fields = <String, String>{};
    // Gunakan indeks numerik (fuel_service_ids[0], [1], ...) agar setiap id
    // terkirim sebagai field terpisah. Memakai 'fuel_service_ids[]' pada Map
    // <String,String> akan saling menimpa — hanya id terakhir yang terkirim.
    for (var i = 0; i < fuelServiceIds.length; i++) {
      fields['fuel_service_ids[$i]'] = fuelServiceIds[i].toString();
    }
    fields['transfer_amount'] = transferAmount.toString();
    if (notes != null) {
      fields['notes'] = notes;
    }
    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/PaymentReceipt');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final data = await _api.multipart(
      method: 'POST',
      path: 'procurement/fuel-service-payment-receipts/$receiptId',
      fields: fields,
    );
    return (data as Map<String, dynamic>?) ?? {};
  }

  /// Update payment receipt gaji harian: edit daftar daily salary (status
  /// sync dua arah di backend) + metadata. total_amount computed backend.
  Future<Map<String, dynamic>> updateDailySalaryPaymentReceipt({
    required int receiptId,
    required List<int> dailySalaryIds,
    required int transferAmount,
    String? notes,
    File? image,
  }) async {
    final fields = <String, String>{};
    // Indeks numerik agar tiap id terkirim sebagai field terpisah.
    for (var i = 0; i < dailySalaryIds.length; i++) {
      fields['daily_salary_ids[$i]'] = dailySalaryIds[i].toString();
    }
    fields['transfer_amount'] = transferAmount.toString();
    if (notes != null) {
      fields['notes'] = notes;
    }
    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/PaymentReceipt');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final data = await _api.multipart(
      method: 'POST',
      path: 'procurement/daily-salary-payment-receipts/$receiptId',
      fields: fields,
    );
    return (data as Map<String, dynamic>?) ?? {};
  }

  /// Update invoice payment receipt (edit daftar invoice, transfer_amount, notes, image).
  Future<Map<String, dynamic>> updateInvoicePaymentReceipt({
    required int receiptId,
    required List<int> invoiceIds,
    required int transferAmount,
    String? notes,
    File? image,
  }) async {
    final fields = <String, String>{};
    for (var i = 0; i < invoiceIds.length; i++) {
      fields['invoice_ids[$i]'] = invoiceIds[i].toString();
    }
    fields['transfer_amount'] = transferAmount.toString();
    if (notes != null) {
      fields['notes'] = notes;
    }
    if (image != null) {
      final path = await ImageUploadService.upload(image,
          directory: 'images/PaymentReceipt');
      if (path == null) throw Exception('Gagal upload gambar ke img service.');
      fields['image'] = path;
    }

    final data = await _api.multipart(
      method: 'POST',
      path: 'procurement/payment-receipts/$receiptId',
      fields: fields,
    );
    return (data as Map<String, dynamic>?) ?? {};
  }

  /// Hapus payment receipt gaji harian. Backend mengembalikan status semua
  /// daily salary ter-attach menjadi siap dibayar (3).
  Future<void> deletePaymentReceipt(int receiptId) async {
    await _api.delete('procurement/payment-receipts/$receiptId');
  }

  Future<InvoicePurchase> getInvoiceDetail(int id) async {
    final data = await _api.get('procurement/invoices/$id');
    return InvoicePurchase.fromJson(data);
  }

  Future<Map<String, dynamic>> getPaymentReceiptQris(int receiptId) async {
    final body =
        await _api.getRaw('procurement/payment-receipts/$receiptId/qris');
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat QRIS payment.');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// QRIS dinamis supplier dengan nominal total invoice (tipe transfer).
  Future<Map<String, dynamic>> getInvoiceQris(int invoiceId) async {
    final body = await _api.getRaw('procurement/invoices/$invoiceId/qris');
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat QRIS invoice.');
    }
    return body['data'] as Map<String, dynamic>;
  }
}
