import 'dart:io';
import 'dart:typed_data';

import '../models/sales_order_online_model.dart';
import '../models/store_model.dart';
import 'api_client.dart';
import 'image_upload_service.dart';

class SalesOrderService {
  final ApiClient _api = ApiClient();

  /// Daftar produk yang bisa dijual online.
  Future<List<SalesOrderOnlineProduct>> getOnlineProducts() async {
    final data = await _api.get('sales-orders/online-products');
    final list = data as List;
    return list.map((e) => SalesOrderOnlineProduct.fromJson(e)).toList();
  }

  /// Daftar online shop provider (Shopee, Tokopedia, dll).
  Future<List<OnlineShopProvider>> getOnlineShopProviders() async {
    final data = await _api.get('sales-orders/online-shop-providers');
    final list = data as List;
    return list.map((e) => OnlineShopProvider.fromJson(e)).toList();
  }

  /// Daftar delivery service (JNE, SiCepat, dll).
  Future<List<DeliveryServiceOption>> getDeliveryServices() async {
    final data = await _api.get('sales-orders/delivery-services');
    final list = data as List;
    return list.map((e) => DeliveryServiceOption.fromJson(e)).toList();
  }

  /// Buat sales order online.
  /// [items] sebagai JSON string (karena multipart form tidak support nested array
  /// secara native — dikirim sebagai field string lalu di-decode backend).
  Future<void> createOnlineOrder({
    required Store selectedStore,
    required String deliveryDate,
    required int onlineShopProviderId,
    required int deliveryServiceId,
    required String receiptNo,
    required List<SalesOrderItemRequest> items,
    required String idempotencyKey,
    bool confirmDuplicateReceipt = false,
    File? imagePayment,
    Uint8List? imagePaymentBytes,
  }) async {
    final fields = <String, String>{
      'store_id': selectedStore.id.toString(),
      'delivery_date': deliveryDate,
      'online_shop_provider_id': onlineShopProviderId.toString(),
      'delivery_service_id': deliveryServiceId.toString(),
      'receipt_no': receiptNo,
      // Idempotency: key sama saat retry → backend mengembalikan order
      // existing (200), bukan membuat order kedua.
      'idempotency_key': idempotencyKey,
      if (confirmDuplicateReceipt) 'confirm_duplicate_receipt': 'true',
    };

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      fields['items[$i][product_id]'] = item.productId.toString();
      fields['items[$i][quantity]'] = item.quantity.toString();
      fields['items[$i][unit_price]'] = item.unitPrice.toString();
    }

    if (imagePayment != null) {
      final path =
          await ImageUploadService.upload(imagePayment, directory: 'images/SalesOrder');
      if (path == null) throw Exception('Gagal upload bukti pembayaran.');
      fields['image_payment'] = path;
    } else if (imagePaymentBytes != null) {
      final path = await ImageUploadService.uploadBytes(
        imagePaymentBytes,
        'payment.jpg',
        directory: 'images/SalesOrder',
      );
      if (path == null) throw Exception('Gagal upload bukti pembayaran.');
      fields['image_payment'] = path;
    }

    try {
      await _api.multipart(
        method: 'POST',
        path: 'sales-orders/online',
        fields: fields,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409 && e.body?['duplicate_receipt'] == true) {
        final data = (e.body?['data'] as Map<String, dynamic>?) ?? const {};
        throw DuplicateReceiptException(
          message: e.message,
          existingOrderId: (data['existing_order_id'] as num?)?.toInt() ?? 0,
          receiptNo: (data['receipt_no'] as String?) ?? receiptNo,
          deliveryDate: data['delivery_date'] as String?,
          totalPrice: data['total_price'] == null
              ? null
              : (data['total_price'] as num).toInt(),
          storeNickname: data['store_nickname'] as String?,
          existingCreatedAt: data['existing_created_at'] as String?,
        );
      }
      rethrow;
    }
  }

  /// Batalkan order online (admin) — POST sales-orders/{id}/cancel.
  /// [reason] wajib: backend menyimpannya ke kolom notes. Error backend
  /// (403/400/422) dilempar sebagai ApiException dengan pesan asli.
  Future<void> cancelOrder({
    required int orderId,
    required String reason,
  }) async {
    await _api.postRaw(
      'sales-orders/$orderId/cancel',
      body: {'reason': reason},
    );
  }
}

/// Order online dengan resi yang sama sudah ada dalam window (backend 409).
/// toString() = message polos agar dialog generik tetap kompatibel.
class DuplicateReceiptException implements Exception {
  final String message;
  final int existingOrderId;
  final String receiptNo;
  final String? deliveryDate;
  final int? totalPrice;
  final String? storeNickname;
  final String? existingCreatedAt;

  DuplicateReceiptException({
    required this.message,
    required this.existingOrderId,
    required this.receiptNo,
    this.deliveryDate,
    this.totalPrice,
    this.storeNickname,
    this.existingCreatedAt,
  });

  @override
  String toString() => message;
}
