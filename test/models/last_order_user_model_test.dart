import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/last_order_user_model.dart';

void main() {
  group('LastOrderUserModel.fromJson', () {
    test('parse lengkap', () {
      final m = LastOrderUserModel.fromJson({
        'user_id': 12,
        'name': 'Budi Santoso',
        'email': 'budi@contoh.com',
        'last_order_at': '2026-10-01 09:30:00',
        'total_orders': 14,
        'total_nominal': 12500000,
        'phones': ['0812-3456-7890', '0898-7654-3210'],
        'last_follow_up_at': '2026-10-03 07:30:00',
        'last_follow_up_by_name': 'Sari Admin',
      });

      expect(m.userId, 12);
      expect(m.name, 'Budi Santoso');
      expect(m.email, 'budi@contoh.com');
      expect(m.lastOrderAt, DateTime(2026, 10, 1, 9, 30));
      expect(m.totalOrders, 14);
      expect(m.totalNominal, 12500000);
      expect(m.phones, ['0812-3456-7890', '0898-7654-3210']);
      expect(m.lastFollowUpAt, DateTime(2026, 10, 3, 7, 30));
      expect(m.lastFollowUpByName, 'Sari Admin');
    });

    test('default aman untuk field hilang', () {
      final m = LastOrderUserModel.fromJson({});

      expect(m.userId, 0);
      expect(m.name, '-');
      expect(m.email, isNull);
      expect(m.lastOrderAt, isNull);
      expect(m.totalOrders, 0);
      expect(m.totalNominal, 0);
      expect(m.phones, isEmpty);
      expect(m.lastFollowUpAt, isNull);
      expect(m.lastFollowUpByName, isNull);
    });

    test('phones kosong dibuang, tanggal invalid jadi null', () {
      final m = LastOrderUserModel.fromJson({
        'user_id': 1,
        'last_order_at': 'bukan-tanggal',
        'phones': [' ', '', '0812'],
      });

      expect(m.lastOrderAt, isNull);
      expect(m.phones, ['0812']);
    });
  });
}
