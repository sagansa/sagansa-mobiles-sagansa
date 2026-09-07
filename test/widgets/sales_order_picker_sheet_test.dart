import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/procurement_model.dart';
import 'package:sagansa/widgets/procurement/sales_order_picker_sheet.dart';

SalesOrderCandidate candidate(int i) => SalesOrderCandidate(
      id: 1000 + i,
      forType: 3,
      receiptNo: 'SPX-$i',
      storeName: 'Toko $i',
      deliveryDate: '2026-09-01',
      totalPrice: 100000 + i,
      buyerName: 'Pembeli $i',
      buyerPhone: '08123456789',
      buyerAddress: 'Jl. Contoh No. $i',
    );

void main() {
  testWidgets('memuat daftar otomatis lalu memilih kandidat', (tester) async {
    SalesOrderCandidate? picked;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderPickerSheet(
          onLoad: () async => [candidate(0), candidate(1)],
          onSelected: (c) => picked = c,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pembeli 0'), findsOneWidget);
    expect(find.text('Pembeli 1'), findsOneWidget);

    await tester.tap(find.text('Pembeli 1'));
    await tester.pump();

    expect(picked?.id, 1001);
  });

  testWidgets('hasil kosong menampilkan empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderPickerSheet(
          onLoad: () async => [],
          onSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada order 5 hari terakhir.'), findsOneWidget);
  });

  testWidgets('error menampilkan pesan dan bisa dicoba lagi', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderPickerSheet(
          onLoad: () async {
            calls++;
            if (calls == 1) throw Exception('Gagal memuat kandidat.');
            return [candidate(0)];
          },
          onSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat kandidat.'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Pembeli 0'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('banyak hasil (12) dapat discroll tanpa overflow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderPickerSheet(
          onLoad: () async => List.generate(12, candidate),
          onSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pembeli 0'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Pembeli 11'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Pembeli 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
