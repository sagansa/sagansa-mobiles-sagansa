/// Detail satu user di daftar "order terakhir user"
/// (endpoint admin/last-orders/{userId}).
library;

/// Baris summary satu produk yang pernah diorder user (all-time, order direct).
class LastOrderProductSummary {
  final int? productId;
  final String name;
  final int quantity;

  /// Harga satuan termutakhir (harga bisa berubah antar order).
  final int unitPrice;

  /// Total historis = SUM(subtotal_price).
  final int total;

  const LastOrderProductSummary({
    this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory LastOrderProductSummary.fromJson(Map<String, dynamic> json) =>
      LastOrderProductSummary(
        productId: (json['product_id'] as num?)?.toInt(),
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : 'Tanpa Produk',
        quantity: (json['quantity'] as num? ?? 0).toInt(),
        unitPrice: (json['unit_price'] as num? ?? 0).toInt(),
        total: (json['total'] as num? ?? 0).toInt(),
      );
}

/// Satu catatan follow-up "sudah dihubungi".
class LastOrderFollowUp {
  final int id;
  final String byName;
  final DateTime? createdAt;

  const LastOrderFollowUp({
    required this.id,
    required this.byName,
    this.createdAt,
  });

  factory LastOrderFollowUp.fromJson(Map<String, dynamic> json) =>
      LastOrderFollowUp(
        id: (json['id'] as num? ?? 0).toInt(),
        byName: (json['by_name'] as String?)?.trim().isNotEmpty == true
            ? json['by_name'] as String
            : '-',
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );
}

/// Response lengkap GET admin/last-orders/{userId}.
class LastOrderUserDetail {
  final int userId;
  final String name;
  final String? email;
  final DateTime? lastOrderAt;
  final int totalOrders;
  final int totalNominal;
  final List<String> phones;
  final List<LastOrderProductSummary> products;
  final List<LastOrderFollowUp> followUps;

  const LastOrderUserDetail({
    required this.userId,
    required this.name,
    this.email,
    this.lastOrderAt,
    this.totalOrders = 0,
    this.totalNominal = 0,
    this.phones = const [],
    this.products = const [],
    this.followUps = const [],
  });

  factory LastOrderUserDetail.fromJson(Map<String, dynamic> json) =>
      LastOrderUserDetail(
        userId: (json['user_id'] as num? ?? 0).toInt(),
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : '-',
        email: (json['email'] as String?)?.trim().isNotEmpty == true
            ? json['email'] as String
            : null,
        lastOrderAt: json['last_order_at'] == null
            ? null
            : DateTime.tryParse(json['last_order_at'] as String),
        totalOrders: (json['total_orders'] as num? ?? 0).toInt(),
        totalNominal: (json['total_nominal'] as num? ?? 0).toInt(),
        phones: (json['phones'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList(),
        products: (json['products'] as List<dynamic>? ?? const [])
            .map((e) => LastOrderProductSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        followUps: (json['follow_ups'] as List<dynamic>? ?? const [])
            .map((e) => LastOrderFollowUp.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
