import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/sales_order_employee_model.dart';

void main() {
  group('SalesOrderEmployeeModel.fromJson', () {
    // Payload apa adanya dari response POST /sales-orders/employee:
    // payment_status & delivery_status berupa string karena backend create()
    // menerima literal '1' (tanpa cast di model) — mobile tidak boleh crash.
    test('toleran terhadap status berupa string', () {
      final m = SalesOrderEmployeeModel.fromJson({
        'id': 36379,
        'store_id': 136,
        'delivery_date': '2026-10-18',
        'delivery_address_id': 2345,
        'transfer_to_account_id': 16,
        'payment_status': '1',
        'delivery_status': '1',
        'ordered_by_id': 1375,
        'total_price': 870000,
        'detail_sales_orders': [
          {
            'id': 36739,
            'product_id': 38338929,
            'quantity': 3,
            'unit_price': 290000,
            'subtotal_price': 870000,
            'product': {
              'id': 38338929,
              'name': 'Mete Menir - BB2 (1kg)',
              'unit': {'unit': 'pcs'},
            },
          },
        ],
      });

      expect(m.id, 36379);
      expect(m.paymentStatus, 1);
      expect(m.deliveryStatus, 1);
      expect(m.paymentStatusLabel, 'Belum Diperiksa');
      expect(m.totalPrice, 870000);
      expect(m.items, hasLength(1));
      expect(m.items.first.quantity, 3);
      expect(m.items.first.unitPrice, 290000);
    });

    test('default aman untuk field hilang', () {
      final m = SalesOrderEmployeeModel.fromJson({});

      expect(m.id, 0);
      expect(m.paymentStatus, 1);
      expect(m.deliveryStatus, 1);
      expect(m.totalPrice, 0);
      expect(m.items, isEmpty);
    });
  });
}
