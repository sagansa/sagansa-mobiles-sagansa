/// Baris daftar "order terakhir user" (endpoint admin/last-orders).
class LastOrderUserModel {
  final int userId;
  final String name;
  final String? email;

  /// Waktu order direct terakhir (MAX(created_at) dari backend).
  final DateTime? lastOrderAt;
  final int totalOrders;
  final int totalNominal;

  /// Semua no telp dari alamat pengiriman user (bentuk asli, mis.
  /// "0812-3456-7890"), normalisasi ke wa.me dilakukan WhatsAppUtils.
  final List<String> phones;

  /// Follow-up ("sudah dihubungi") terakhir — null bila belum pernah.
  final DateTime? lastFollowUpAt;
  final String? lastFollowUpByName;

  const LastOrderUserModel({
    required this.userId,
    required this.name,
    this.email,
    this.lastOrderAt,
    this.totalOrders = 0,
    this.totalNominal = 0,
    this.phones = const [],
    this.lastFollowUpAt,
    this.lastFollowUpByName,
  });

  factory LastOrderUserModel.fromJson(Map<String, dynamic> json) =>
      LastOrderUserModel(
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
        lastFollowUpAt: json['last_follow_up_at'] == null
            ? null
            : DateTime.tryParse(json['last_follow_up_at'] as String),
        lastFollowUpByName:
            (json['last_follow_up_by_name'] as String?)?.trim().isNotEmpty == true
                ? json['last_follow_up_by_name'] as String
                : null,
      );
}
