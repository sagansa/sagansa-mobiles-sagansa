import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/procurement_model.dart';
import 'package:sagansa/widgets/procurement/sales_order_link_card.dart';

InvoicePurchase _invoice({SalesOrderSummary? salesOrder}) => InvoicePurchase(
      id: 5,
      storeId: 1,
      date: '2026-09-04',
      createdById: 9,
      storeName: 'Toko A',
      salesOrderId: salesOrder?.id,
      salesOrder: salesOrder,
    );

void main() {
  testWidgets('menampilkan ringkasan penjualan terkait', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderLinkCard(
          invoice: _invoice(
            salesOrder: SalesOrderSummary(
              id: 11739,
              forType: 1,
              storeName: 'Toko A',
              deliveryDate: '2026-09-01',
              totalPrice: 710000,
            ),
          ),
          canEdit: false,
          onLink: () {},
          onUnlink: () {},
        ),
      ),
    ));

    expect(find.text('Penjualan Terkait'), findsOneWidget);
    expect(find.text('ORDER #11739'), findsOneWidget);
    expect(find.text('DIRECT'), findsOneWidget);
    expect(find.text('Kaitkan ke Penjualan'), findsNothing);
  });

  testWidgets('belum terkait + canEdit -> tombol kaitkan', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderLinkCard(
          invoice: _invoice(),
          canEdit: true,
          onLink: () {},
          onUnlink: () {},
        ),
      ),
    ));

    expect(find.text('Kaitkan ke Penjualan'), findsOneWidget);
  });

  testWidgets('terkait + canEdit -> tombol ubah & lepas', (tester) async {
    var unlinkPressed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SalesOrderLinkCard(
          invoice: _invoice(
            salesOrder: SalesOrderSummary(
                id: 1, forType: 1, storeName: 'Toko A'),
          ),
          canEdit: true,
          onLink: () {},
          onUnlink: () => unlinkPressed = true,
        ),
      ),
    ));

    await tester.tap(find.text('Lepas'));
    await tester.pump();

    expect(unlinkPressed, isTrue);
    expect(find.text('Ubah'), findsOneWidget);
  });
}
