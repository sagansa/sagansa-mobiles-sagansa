import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/procurement_model.dart';
import 'package:sagansa/widgets/procurement/sales_order_picker_sheet.dart';

void main() {
  testWidgets('cari lalu pilih kandidat', (tester) async {
    SalesOrderCandidate? picked;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderPickerSheet(
          onSearch: (q) async {
            expect(q, '11739');
            return const [
              SalesOrderCandidate(
                id: 11739,
                forType: 1,
                storeName: 'Toko A',
                deliveryDate: '2026-09-01',
                totalPrice: 710000,
              ),
            ];
          },
          onSelected: (c) => picked = c,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '11739');
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();

    expect(find.text('ORDER #11739'), findsOneWidget);

    await tester.tap(find.text('ORDER #11739'));
    await tester.pump();

    expect(picked?.id, 11739);
  });

  testWidgets('hasil kosong menampilkan empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderPickerSheet(
          onSearch: (_) async => [],
          onSelected: (_) {},
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();

    expect(find.text('Penjualan tidak ditemukan.'), findsOneWidget);
  });
}
