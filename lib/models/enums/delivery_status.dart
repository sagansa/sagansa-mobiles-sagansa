import '../../widgets/status_badge.dart';

enum DeliveryStatus {
  pending(1),
  valid(2),
  delivered(3),
  ready(4),
  fix(5),
  returned(6),
  cancelled(7);

  final int code;
  const DeliveryStatus(this.code);

  static DeliveryStatus fromCode(int? code) {
    return switch (code) {
      1 => DeliveryStatus.pending,
      2 => DeliveryStatus.valid,
      3 => DeliveryStatus.delivered,
      4 => DeliveryStatus.ready,
      5 => DeliveryStatus.fix,
      6 => DeliveryStatus.returned,
      7 => DeliveryStatus.cancelled,
      _ => DeliveryStatus.pending,
    };
  }

  StatusType get badgeType => switch (this) {
        DeliveryStatus.valid => StatusType.success,
        DeliveryStatus.delivered => StatusType.info,
        DeliveryStatus.returned => StatusType.error,
        DeliveryStatus.cancelled => StatusType.error,
        _ => StatusType.warning,
      };

  String get label => switch (this) {
        DeliveryStatus.pending => 'Belum Dikirim',
        DeliveryStatus.valid => 'Valid (Terkunci)',
        DeliveryStatus.delivered => 'Sudah Dikirim',
        DeliveryStatus.ready => 'Siap Dikirim',
        DeliveryStatus.fix => 'Perbaiki',
        DeliveryStatus.returned => 'Dikembalikan',
        DeliveryStatus.cancelled => 'Dibatalkan',
      };

  bool get isLocked =>
      this == DeliveryStatus.valid ||
      this == DeliveryStatus.returned ||
      this == DeliveryStatus.delivered ||
      this == DeliveryStatus.cancelled;

  bool get canMarkReady => this == DeliveryStatus.pending;

  bool get canSubmitDelivery =>
      !isLocked && !canMarkReady;

  bool get canRefund => this == DeliveryStatus.delivered;

  /// Boleh dibatalkan admin: barang belum terkunci & belum dikirim
  /// (1 Belum Dikirim, 4 Siap Dikirim, 5 Perbaiki).
  bool get canCancel =>
      this == DeliveryStatus.pending ||
      this == DeliveryStatus.ready ||
      this == DeliveryStatus.fix;
}
