import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/last_order_user_detail_model.dart';

void main() {
  group('LastOrderUserDetail.fromJson', () {
    test('parse lengkap (produk + follow-up)', () {
      final d = LastOrderUserDetail.fromJson({
        'user_id': 12,
        'name': 'Budi Santoso',
        'email': 'budi@contoh.com',
        'last_order_at': '2026-10-01 09:30:00',
        'total_orders': 14,
        'total_nominal': 12500000,
        'phones': ['0812-3456-7890', ''],
        'products': [
          {
            'product_id': 3,
            'name': 'Gula Pasir',
            'quantity': 120,
            'unit_price': 15000,
            'total': 1800000,
          },
          {
            'product_id': null,
            'name': null,
            'quantity': 2,
            'unit_price': 5000,
            'total': 10000,
          },
        ],
        'follow_ups': [
          {'id': 9, 'by_name': 'Sari Admin', 'created_at': '2026-10-03 07:30:00'},
        ],
      });

      expect(d.userId, 12);
      expect(d.name, 'Budi Santoso');
      expect(d.lastOrderAt, DateTime(2026, 10, 1, 9, 30));
      expect(d.totalOrders, 14);
      expect(d.totalNominal, 12500000);
      expect(d.phones, ['0812-3456-7890']); // item kosong dibuang

      expect(d.products, hasLength(2));
      final gula = d.products.first;
      expect(gula.productId, 3);
      expect(gula.name, 'Gula Pasir');
      expect(gula.quantity, 120);
      expect(gula.unitPrice, 15000);
      expect(gula.total, 1800000);

      // product_id null + name null -> 'Tanpa Produk'.
      final tanpa = d.products.last;
      expect(tanpa.productId, isNull);
      expect(tanpa.name, 'Tanpa Produk');

      expect(d.followUps, hasLength(1));
      expect(d.followUps.first.byName, 'Sari Admin');
      expect(d.followUps.first.createdAt, DateTime(2026, 10, 3, 7, 30));
    });

    test('default aman untuk field hilang', () {
      final d = LastOrderUserDetail.fromJson({});

      expect(d.userId, 0);
      expect(d.name, '-');
      expect(d.email, isNull);
      expect(d.lastOrderAt, isNull);
      expect(d.phones, isEmpty);
      expect(d.products, isEmpty);
      expect(d.followUps, isEmpty);
    });
  });
}
