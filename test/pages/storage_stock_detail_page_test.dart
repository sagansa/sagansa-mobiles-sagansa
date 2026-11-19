import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/storage_stock_model.dart';
import 'package:sagansa/pages/storage_stock_detail_page.dart';
import 'package:sagansa/services/storage_stock_service.dart';

class _FakeService extends StorageStockService {
  _FakeService(this.report);
  final StorageStockModel report;

  @override
  Future<StorageStockModel> getStorageStock(int id) async => report;
}

StorageStockModel _report({required bool canBeEdited, String? updater}) =>
    StorageStockModel(
      id: 12,
      storeId: 3,
      date: '2026-09-20',
      status: 1,
      storeName: 'Gudang Pusat',
      createdByName: 'Budi',
      updatedByName: updater,
      canBeEdited: canBeEdited,
      details: const [],
    );

Future<void> pumpPage(WidgetTester tester, StorageStockModel report) async {
  await tester.pumpWidget(MaterialApp(
    home: StorageStockDetailPage(reportId: 12, service: _FakeService(report)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tombol Edit Laporan & baris Diperbarui oleh tampil saat canBeEdited',
      (tester) async {
    await pumpPage(tester, _report(canBeEdited: true, updater: 'Sari'));

    expect(find.text('Edit Laporan'), findsOneWidget);
    expect(find.text('Diperbarui oleh'), findsOneWidget);
    expect(find.text('Sari'), findsOneWidget);
  });

  testWidgets('tanpa canBeEdited -> tombol & baris Diperbarui oleh hilang',
      (tester) async {
    await pumpPage(tester, _report(canBeEdited: false));

    expect(find.text('Edit Laporan'), findsNothing);
    expect(find.text('Diperbarui oleh'), findsNothing);
  });

  testWidgets('canBeEdited tapi belum pernah diedit -> tombol tampil, baris updater tidak',
      (tester) async {
    await pumpPage(tester, _report(canBeEdited: true));

    expect(find.text('Edit Laporan'), findsOneWidget);
    expect(find.text('Diperbarui oleh'), findsNothing);
  });
}
