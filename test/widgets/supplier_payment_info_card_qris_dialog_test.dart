import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sagansa/widgets/supplier_payment_info_card.dart';

void main() {
  const validPayload =
      '00020101021126690014ID.CO.QRIS.WWW011893600915000000000202181500000000000000000303UMI5204541153033605802ID5912TOKO SAGANSA6007JAKARTA6105102106209070503A01630415C4';

  Future<void> pumpCard(WidgetTester tester, {String? qris}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupplierPaymentInfoCard(qris: qris),
        ),
      ),
    );
  }

  testWidgets(
      'payload valid → dialog QRIS ter-render dengan QrImageView tanpa exception layout',
      (tester) async {
    await pumpCard(tester, qris: validPayload);

    await tester.tap(find.text('Lihat QRIS'));
    await tester.pumpAndSettle();

    // Judul dialog muncul (selain label "QRIS Supplier" di kartu latar).
    expect(find.text('QRIS Supplier'), findsNWidgets(2));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.getSize(find.byType(QrImageView)),
      equals(const Size(240, 240)),
    );
    // Nama merchant & NMID hasil parse payload tampil untuk dicocokkan.
    expect(find.text('Nama Merchant'), findsOneWidget);
    expect(find.text('TOKO SAGANSA'), findsOneWidget);
    expect(find.text('NMID'), findsOneWidget);
    expect(find.text('936009150000000002'), findsOneWidget);
    expect(find.textContaining('QRIS statis'), findsOneWidget);
  });

  testWidgets(
      'payload non-EMV (teks pendek) → tetap tergambar QR tanpa crash',
      (tester) async {
    await pumpCard(tester, qris: 'bukan-payload-qris');

    await tester.tap(find.text('Lihat QRIS'));
    await tester.pumpAndSettle();

    expect(find.text('QRIS Supplier'), findsNWidgets(2));
    // qr_flutter bisa meng-encode string apa pun, jadi QR tetap digambar.
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('payload kosong → tombol QRIS tidak dirender', (tester) async {
    await pumpCard(tester, qris: '');
    expect(find.text('Lihat QRIS'), findsNothing);
  });

  testWidgets('amount tersedia → dialog QRIS dinamis menampilkan nominal',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupplierPaymentInfoCard(qris: validPayload, amount: 75000),
        ),
      ),
    );

    await tester.tap(find.text('Lihat QRIS'));
    await tester.pumpAndSettle();

    expect(find.text('QRIS Supplier'), findsNWidgets(2));
    expect(find.byType(QrImageView), findsOneWidget);
    // Nominal QRIS tampil di meta rows dan catatan dinamis.
    expect(find.text('Nominal QRIS'), findsOneWidget);
    expect(find.text('Rp 75.000'), findsOneWidget);
    expect(
      find.textContaining('QRIS dinamis — nominal'),
      findsOneWidget,
    );
    // Payload statis tidak mengandung tag nominal; payload dinamis iya.
    expect(validPayload.contains('540575000'), isFalse);
  });

  testWidgets('amount null → catatan QRIS statis (nominal manual)',
      (tester) async {
    await pumpCard(tester, qris: validPayload);

    await tester.tap(find.text('Lihat QRIS'));
    await tester.pumpAndSettle();

    expect(find.text('Nominal QRIS'), findsNothing);
    expect(find.textContaining('QRIS statis'), findsOneWidget);
  });
}
