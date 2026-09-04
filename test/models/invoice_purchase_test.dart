import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/procurement_model.dart';

void main() {
  group('InvoicePurchase.fromJson sales link', () {
    test('parsing sales_order terkait', () {
      final inv = InvoicePurchase.fromJson({
        'id': 5,
        'store_id': 1,
        'date': '2026-09-04',
        'payment_status': '2',
        'created_by_id': 9,
        'sales_order_id': 11739,
        'sales_order': {
          'id': 11739,
          'for': 1,
          'receipt_no': null,
          'delivery_date': '2026-09-01',
          'total_price': 710000,
          'store': {'nickname': 'Toko A'},
        },
      });

      expect(inv.salesOrderId, 11739);
      expect(inv.salesOrder?.id, 11739);
      expect(inv.salesOrder?.storeName, 'Toko A');
      expect(inv.salesOrder?.typeName, 'DIRECT');
    });

    test('tanpa kaitan -> null', () {
      final inv = InvoicePurchase.fromJson({
        'id': 6,
        'store_id': 1,
        'date': '2026-09-04',
        'created_by_id': 9,
      });

      expect(inv.salesOrderId, isNull);
      expect(inv.salesOrder, isNull);
    });

    test('SalesOrderCandidate.fromJson', () {
      final c = SalesOrderCandidate.fromJson({
        'id': 42,
        'for': 3,
        'receipt_no': 'SPX-001',
        'store_name': 'Toko B',
        'delivery_date': '2026-08-30',
        'total_price': 150000,
      });

      expect(c.id, 42);
      expect(c.typeName, 'ONLINE');
      expect(c.receiptNo, 'SPX-001');
      expect(c.totalPrice, 150000);
    });
  });
}
