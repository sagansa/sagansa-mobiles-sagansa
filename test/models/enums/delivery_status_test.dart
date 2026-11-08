import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/enums/delivery_status.dart';
import 'package:sagansa/utils/status_mappers.dart';
import 'package:sagansa/widgets/status_badge.dart';

void main() {
  group('DeliveryStatus', () {
    test('fromCode memetakan semua kode backend', () {
      expect(DeliveryStatus.fromCode(1), DeliveryStatus.pending);
      expect(DeliveryStatus.fromCode(2), DeliveryStatus.valid);
      expect(DeliveryStatus.fromCode(3), DeliveryStatus.delivered);
      expect(DeliveryStatus.fromCode(4), DeliveryStatus.ready);
      expect(DeliveryStatus.fromCode(5), DeliveryStatus.fix);
      expect(DeliveryStatus.fromCode(6), DeliveryStatus.returned);
      expect(DeliveryStatus.fromCode(7), DeliveryStatus.cancelled);
    });

    test('cancelled berlabel Dibatalkan dengan badge error', () {
      expect(DeliveryStatus.cancelled.label, 'Dibatalkan');
      expect(DeliveryStatus.cancelled.badgeType, StatusType.error);
      expect(
        StatusMappers.deliveryStatus(7),
        StatusType.error,
      );
      expect(StatusMappers.deliveryLabel(7), 'Dibatalkan');
    });

    test('cancelled final/terkunci', () {
      expect(DeliveryStatus.cancelled.isLocked, isTrue);
      expect(DeliveryStatus.cancelled.canSubmitDelivery, isFalse);
      expect(DeliveryStatus.cancelled.canMarkReady, isFalse);
      expect(DeliveryStatus.cancelled.canRefund, isFalse);
    });

    test('canCancel hanya untuk status 1, 4, 5', () {
      expect(DeliveryStatus.pending.canCancel, isTrue);
      expect(DeliveryStatus.ready.canCancel, isTrue);
      expect(DeliveryStatus.fix.canCancel, isTrue);
      expect(DeliveryStatus.valid.canCancel, isFalse);
      expect(DeliveryStatus.delivered.canCancel, isFalse);
      expect(DeliveryStatus.returned.canCancel, isFalse);
      expect(DeliveryStatus.cancelled.canCancel, isFalse);
    });
  });
}
