import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/utils/status_mappers.dart';
import 'package:sagansa/widgets/status_badge.dart';

void main() {
  group('StatusMappers.delivery', () {
    test('delivered (3) → info', () {
      expect(StatusMappers.deliveryStatus(3), StatusType.info);
      expect(StatusMappers.deliveryLabel(3), 'Sudah Dikirim');
    });

    test('returned (6) → error', () {
      expect(StatusMappers.deliveryStatus(6), StatusType.error);
      expect(StatusMappers.deliveryLabel(6), 'Dikembalikan');
    });

    test('ready (4) → warning (default)', () {
      // 4 falls to default in existing mapper.
      expect(StatusMappers.deliveryStatus(4), StatusType.warning);
    });

    test('pending (1) → warning', () {
      expect(StatusMappers.deliveryStatus(1), StatusType.warning);
    });

    test('null → warning + unknown label', () {
      expect(StatusMappers.deliveryStatus(null), StatusType.warning);
      expect(StatusMappers.deliveryLabel(null), 'Tidak Diketahui');
    });
  });

  group('StatusMappers.payment', () {
    test('paid (1) → warning, label Sudah Dibayar', () {
      expect(StatusMappers.paymentStatus('1'), StatusType.warning);
      expect(StatusMappers.paymentLabel('1'), 'Sudah Dibayar');
    });

    test('valid (2) → success', () {
      expect(StatusMappers.paymentStatus('2'), StatusType.success);
    });

    test('invalid (3) → error', () {
      expect(StatusMappers.paymentStatus('3'), StatusType.error);
    });

    test('null → neutral', () {
      expect(StatusMappers.paymentStatus(null), StatusType.neutral);
      expect(StatusMappers.paymentLabel(null), '-');
    });
  });

  group('StatusMappers.procurement', () {
    test('approved (2) → success', () {
      expect(StatusMappers.procurementStatus(2), StatusType.success);
      expect(StatusMappers.procurementLabel(2), 'Disetujui');
    });

    test('rejected (3) → error', () {
      expect(StatusMappers.procurementStatus(3), StatusType.error);
    });

    test('completed (4) → info', () {
      expect(StatusMappers.procurementStatus(4), StatusType.info);
    });

    test('pending (1) → warning', () {
      expect(StatusMappers.procurementStatus(1), StatusType.warning);
    });
  });

  group('StatusMappers.leave', () {
    test('approved (2) → success', () {
      expect(StatusMappers.leaveStatus(2), StatusType.success);
      expect(StatusMappers.leaveLabel(2), 'Disetujui');
    });

    test('rejected (3) → error', () {
      expect(StatusMappers.leaveStatus(3), StatusType.error);
    });

    test('pending (1) → warning', () {
      expect(StatusMappers.leaveStatus(1), StatusType.warning);
    });
  });

  group('StatusMappers.dailySalary', () {
    test('paid (2) → success', () {
      expect(StatusMappers.dailySalaryStatus(2), StatusType.success);
      expect(StatusMappers.dailySalaryLabel(2), 'Sudah Dibayar');
    });

    test('ready (3) → info', () {
      expect(StatusMappers.dailySalaryStatus(3), StatusType.info);
    });

    test('unpaid (1) → warning', () {
      expect(StatusMappers.dailySalaryStatus(1), StatusType.warning);
    });

    test('fix (4) → error', () {
      expect(StatusMappers.dailySalaryStatus(4), StatusType.error);
    });
  });

  group('StatusMappers.isPayableDailySalary', () {
    // Guard sama dengan server (ProcurementController):
    // status 1 (belum dibayar) / 3 (siap dibayar) + metode Transfer.
    test('unpaid + transfer → payable', () {
      expect(
        StatusMappers.isPayableDailySalary(
            {'status': 1, 'payment_type_id': 1}),
        isTrue,
      );
    });

    test('ready + transfer → payable (string dari JSON)', () {
      expect(
        StatusMappers.isPayableDailySalary(
            {'status': '3', 'payment_type_id': '1'}),
        isTrue,
      );
    });

    test('paid (2) → tidak payable', () {
      expect(
        StatusMappers.isPayableDailySalary(
            {'status': 2, 'payment_type_id': 1}),
        isFalse,
      );
    });

    test('fix (4) → tidak payable', () {
      expect(
        StatusMappers.isPayableDailySalary(
            {'status': '4', 'payment_type_id': 1}),
        isFalse,
      );
    });

    test('unpaid tapi tunai → tidak payable', () {
      expect(
        StatusMappers.isPayableDailySalary(
            {'status': 1, 'payment_type_id': 2}),
        isFalse,
      );
    });

    test('status null → tidak payable', () {
      expect(
        StatusMappers.isPayableDailySalary({'payment_type_id': 1}),
        isFalse,
      );
    });
  });

  group('StatusMappers.hygiene', () {
    test('approved (2) → success', () {
      expect(StatusMappers.hygieneStatus(2), StatusType.success);
    });

    test('rejected (3) → error', () {
      expect(StatusMappers.hygieneStatus(3), StatusType.error);
    });

    test('pending (1) → warning', () {
      expect(StatusMappers.hygieneStatus(1), StatusType.warning);
    });
  });

  group('StatusMappers.procurementGlobalStatus', () {
    test('Partially Approved → info', () {
      expect(
        StatusMappers.procurementGlobalStatus('Partially Approved'),
        StatusType.info,
      );
      expect(StatusMappers.procurementGlobalStatus('Approved'), StatusType.info);
    });

    test('Pending Approval → warning', () {
      expect(
        StatusMappers.procurementGlobalStatus('Pending Approval'),
        StatusType.warning,
      );
    });

    test('Done → success', () {
      expect(StatusMappers.procurementGlobalStatus('Done'), StatusType.success);
    });

    test('Rejected → error', () {
      expect(
        StatusMappers.procurementGlobalStatus('Rejected'),
        StatusType.error,
      );
    });

    test('label tak dikenal → neutral', () {
      expect(StatusMappers.procurementGlobalStatus('Processed'),
          StatusType.neutral);
      expect(StatusMappers.procurementGlobalStatus('No Items'),
          StatusType.neutral);
    });
  });
}
