import '../services/image_service.dart';

/// Backend kadang mengirim angka sebagai string (mis. `payment_status: "1"`
/// dari response create yang belum di-cast) — parse secara toleran, bukan
/// hard cast yang melempar TypeError dan memutus alur simpan.
int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  return _asInt(v);
}

/// Satu baris item produk dalam SalesOrderEmployee.
class SalesOrderEmployeeItem {
  final int id;
  final int productId;
  final String productName;
  final String? productUnit;
  final int quantity;
  final int unitPrice;
  final int subtotalPrice;

  SalesOrderEmployeeItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productUnit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotalPrice,
  });

  factory SalesOrderEmployeeItem.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>? ?? {};
    return SalesOrderEmployeeItem(
      id: _asInt(j['id']),
      productId: _asInt(j['product_id']),
      productName: product['name'] as String? ?? '',
      productUnit: product['unit']?['unit'] as String?,
      quantity: _asInt(j['quantity']),
      unitPrice: _asInt(j['unit_price']),
      subtotalPrice: _asInt(j['subtotal_price']),
    );
  }
}

/// Sales order kategori employee (for=2).
class SalesOrderEmployeeModel {
  final int id;
  final int storeId;
  final String? storeName;
  final DateTime? deliveryDate;
  final int? deliveryAddressId;
  final String? deliveryAddressName;
  final int? transferToAccountId;
  final String? transferToAccountName;
  final String? imagePayment;
  String? get imagePaymentUrl => ImageService.buildUrl(imagePayment);
  final int paymentStatus; // 1..4
  final int deliveryStatus;
  final int orderedById;
  final String? orderedByName;
  final String? notes;
  final int totalPrice;
  final List<SalesOrderEmployeeItem> items;
  final String? createdAt;

  SalesOrderEmployeeModel({
    required this.id,
    required this.storeId,
    this.storeName,
    this.deliveryDate,
    this.deliveryAddressId,
    this.deliveryAddressName,
    this.transferToAccountId,
    this.transferToAccountName,
    this.imagePayment,
    required this.paymentStatus,
    required this.deliveryStatus,
    required this.orderedById,
    this.orderedByName,
    this.notes,
    required this.totalPrice,
    required this.items,
    this.createdAt,
  });

  factory SalesOrderEmployeeModel.fromJson(Map<String, dynamic> j) {
    final store = j['store'] as Map<String, dynamic>?;
    final orderedBy = j['ordered_by'] as Map<String, dynamic>?;
    final transferToAccount = j['transfer_to_account'] as Map<String, dynamic>?;
    final deliveryAddress = j['delivery_address'] as Map<String, dynamic>?;

    final rawDate = j['delivery_date']?.toString();
    DateTime? date;
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        date = DateTime.parse(rawDate.contains('T') ? rawDate : '${rawDate}T00:00:00');
      } catch (_) {
        date = null;
      }
    }

    final rawItems = (j['detail_sales_orders'] as List<dynamic>?)
            ?.map((e) => SalesOrderEmployeeItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SalesOrderEmployeeModel(
      id: _asInt(j['id']),
      storeId: _asInt(j['store_id']),
      storeName: store?['nickname'] as String?,
      deliveryDate: date,
      deliveryAddressId: _asIntOrNull(j['delivery_address_id']),
      deliveryAddressName: deliveryAddress?['delivery_address_name'] as String?,
      transferToAccountId: _asIntOrNull(j['transfer_to_account_id']),
      transferToAccountName: transferToAccount?['transfer_name'] as String?,
      imagePayment: j['image_payment'] as String?,
      paymentStatus: _asInt(j['payment_status'], 1),
      deliveryStatus: _asInt(j['delivery_status'], 1),
      orderedById: _asInt(j['ordered_by_id']),
      orderedByName: orderedBy?['name'] as String?,
      notes: j['notes'] as String?,
      totalPrice: _asInt(j['total_price']),
      items: rawItems,
      createdAt: j['created_at']?.toString(),
    );
  }

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 1:
        return 'Belum Diperiksa';
      case 2:
        return 'Valid';
      case 3:
        return 'Tidak Valid';
      case 4:
        return 'Menunggu Pembayaran';
      default:
        return '-';
    }
  }

  /// Indikator apakah order masih boleh diubah/dihapus oleh sales pemilik.
  bool get isLocked => paymentStatus == 2;
}
