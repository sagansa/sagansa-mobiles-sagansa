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

  testWidgets('banyak hasil (12) dapat discroll tanpa overflow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderPickerSheet(
          onSearch: (_) async => List.generate(
            12,
            (i) => SalesOrderCandidate(
              id: 1000 + i,
              forType: 1,
              storeName: 'Toko $i',
              deliveryDate: '2026-09-01',
              totalPrice: 100000 + i,
            ),
          ),
          onSelected: (_) {},
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'toko');
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();

    expect(find.text('ORDER #1000'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Daftar dapat digulir ke hasil terakhir.
    await tester.scrollUntilVisible(
      find.text('ORDER #1011'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('ORDER #1011'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
