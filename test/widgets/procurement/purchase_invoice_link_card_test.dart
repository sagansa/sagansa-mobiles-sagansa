import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sagansa/models/procurement_model.dart';
import 'package:sagansa/services/procurement_service.dart';
import 'package:sagansa/widgets/procurement/purchase_invoice_link_card.dart';

class _MockProcurementService extends Mock implements ProcurementService {}

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late _MockProcurementService service;

  setUp(() {
    service = _MockProcurementService();
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  testWidgets('state kosong menampilkan teks dan tombol kaitkan',
      (tester) async {
    when(() => service.getPurchaseInvoices(1)).thenAnswer((_) async => []);

    await tester
        .pumpWidget(wrap(PurchaseInvoiceLinkCard(orderId: 1, service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Invoice Pembelian Terkait'), findsOneWidget);
    expect(find.textContaining('Belum ada invoice terkait'), findsOneWidget);
    expect(find.text('Kaitkan Invoice Pembelian'), findsOneWidget);
  });

  testWidgets('invoice draft menampilkan tombol Lepas, bukan draft tidak',
      (tester) async {
    when(() => service.getPurchaseInvoices(1)).thenAnswer((_) async => const [
          InvoiceLinkCandidate(id: 1, supplierName: 'A', paymentStatus: '1'),
          InvoiceLinkCandidate(id: 2, supplierName: 'B', paymentStatus: '2'),
        ]);

    await tester.pumpWidget(
        wrap(PurchaseInvoiceLinkCard(orderId: 1, service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Lepas'), findsOneWidget); // hanya milik invoice draft
    expect(find.textContaining('Sudah Dibayar'), findsOneWidget);
  });
}
