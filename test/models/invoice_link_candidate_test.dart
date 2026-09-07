import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/procurement_model.dart';

void main() {
  test('parse lengkap dari json endpoint', () {
    final c = InvoiceLinkCandidate.fromJson({
      'id': 12,
      'supplier_name': 'PT Sumber Pangan',
      'total_price': 1500000,
      'payment_status': '1',
      'order_status': '2',
      'date': '2026-09-07',
    });

    expect(c.id, 12);
    expect(c.supplierName, 'PT Sumber Pangan');
    expect(c.totalPrice, 1500000);
    expect(c.isDraft, isTrue);
    expect(c.paymentLabel, 'Belum Dibayar');
  });

  test('supplier null dan status dibayar ditangani', () {
    final c = InvoiceLinkCandidate.fromJson({
      'id': 13,
      'supplier_name': null,
      'total_price': 0,
      'payment_status': '2',
    });

    expect(c.supplierName, '-');
    expect(c.isDraft, isFalse);
    expect(c.paymentLabel, 'Sudah Dibayar');
    expect(c.date, isNull);
  });
}
