import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/procurement_model.dart';
import 'package:sagansa/widgets/procurement/purchase_invoice_picker_sheet.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('menampilkan hasil pencarian dan memilih kandidat',
      (tester) async {
    InvoiceLinkCandidate? picked;
    final candidate = InvoiceLinkCandidate(
        id: 7, supplierName: 'PT Sumber Pangan', totalPrice: 150000);

    await tester.pumpWidget(wrap(PurchaseInvoicePickerSheet(
      onSearch: (q) async => [candidate],
      onSelected: (c) => picked = c,
    )));
    await tester.pumpAndSettle();

    expect(find.text('PT Sumber Pangan'), findsOneWidget);

    await tester.tap(find.text('PT Sumber Pangan'));
    await tester.pumpAndSettle();
    expect(picked?.id, 7);
  });

  testWidgets('kolom cari memanggil onSearch dengan keyword', (tester) async {
    String? queried;
    await tester.pumpWidget(wrap(PurchaseInvoicePickerSheet(
      onSearch: (q) async {
        queried = q;
        return const [];
      },
      onSelected: (_) {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sumber');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(queried, 'Sumber');
    expect(find.textContaining('Tidak ada invoice'), findsOneWidget);
  });
}
