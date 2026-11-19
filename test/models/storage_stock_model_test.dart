import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/storage_stock_model.dart';

void main() {
  group('StorageStockModel.fromJson edit flags', () {
    test('parsing can_be_edited & updater', () {
      final m = StorageStockModel.fromJson({
        'id': 12,
        'store_id': 3,
        'date': '2026-09-20',
        'status': 1,
        'can_be_edited': true,
        'store': {'nickname': 'Gudang Pusat'},
        'user': {'name': 'Budi'},
        'updater': {'id': 9, 'name': 'Sari'},
        'detail_stock_cards': [
          {
            'id': 1,
            'product_id': 2,
            'quantity': 5,
            'product': {'name': 'Gula', 'unit': {'unit': 'kg'}},
          },
        ],
      });

      expect(m.canBeEdited, isTrue);
      expect(m.updatedByName, 'Sari');
      expect(m.createdByName, 'Budi');
      expect(m.details.single.quantity, 5);
    });

    test('tanpa flag/updater -> default aman', () {
      final m = StorageStockModel.fromJson({
        'id': 13,
        'store_id': 3,
        'date': '2026-09-20',
        'status': 2,
        'store': {'nickname': 'Gudang Pusat'},
        'user': {'name': 'Budi'},
        'updater': null,
        'detail_stock_cards': [],
      });

      expect(m.canBeEdited, isFalse);
      expect(m.updatedByName, isNull);
    });
  });
}
