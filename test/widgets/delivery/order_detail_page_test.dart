import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/providers/delivery_provider.dart';
import 'package:sagansa/services/delivery_status_repository.dart';
import 'package:sagansa/services/payment_proof_pdf_service.dart';
import 'package:sagansa/services/presence_service.dart';
import 'package:sagansa/services/sticker_print_orchestrator.dart';
import 'package:sagansa/widgets/delivery/order_detail_page.dart';

class _MockPresence extends Mock implements PresenceService {}

class _MockRepository extends Mock implements DeliveryStatusRepository {}

class _MockPdf extends Mock implements PaymentProofPdfService {}

class _MockSticker extends Mock implements StickerPrintOrchestrator {}

/// Regresi bug: OrderDetailPage (halaman Penjualan & deep-link notifikasi)
/// merender detail dari snapshot statis `widget.order`. Setelah
/// markReadyToShip sukses (status 1 → 4), kartu "Tandai Siap Dikirim"
/// harus hilang; kalau tetap tampil, user tap lagi dan backend menolak
/// ("Hanya order berstatus belum dikirim...").
void main() {
  late _MockPresence presence;
  late DeliveryProvider provider;

  final snapshotOrder = <String, dynamic>{
    'id': 42,
    'receipt_no': '260919EBDMGT1J',
    'delivery_status': 1,
    'items': <Map<String, dynamic>>[],
  };

  setUp(() {
    presence = _MockPresence();
    final repo = _MockRepository();
    when(() => repo.loadAdminRole()).thenAnswer((_) async => false);
    when(() => repo.loadCanManageSalesLink()).thenAnswer((_) async => false);
    when(() => repo.loadPrintedStickers()).thenAnswer((_) async => {});

    when(() => presence.getSalesOrders(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          orderFor: any(named: 'orderFor'),
        )).thenAnswer((_) async => {
              'success': true,
              'data': [],
              'meta': {'last_page': 1},
            });

    provider = DeliveryProvider(
      orderMode: OrderMode.online,
      presenceService: presence,
      repository: repo,
      pdfService: _MockPdf(),
      stickerOrchestrator: _MockSticker(),
    );
  });

  testWidgets(
      'setelah markReadyToShip sukses, kartu Tandai Siap Dikirim hilang '
      'dan diganti form pengiriman', (tester) async {
    when(() => presence.markReadyToShip(
          orderId: any(named: 'orderId'),
          orderFor: any(named: 'orderFor'),
        )).thenAnswer((_) async => {
              'success': true,
              'data': {'id': 42, 'delivery_status': 4},
            });

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: snapshotOrder,
        orderMode: OrderMode.online,
        provider: provider,
      ),
    ));
    await tester.pump(); // post-frame selectOrder(widget.order)
    await tester.pump();

    await tester.ensureVisible(find.text('Tandai Siap Dikirim'));
    expect(find.text('Tandai Siap Dikirim'), findsOneWidget);

    await tester.tap(find.text('Tandai Siap Dikirim'));
    await tester.pump(); // mulai markReadyToShip
    await tester.pump(const Duration(milliseconds: 50)); // sukses + notify
    await tester.pump(const Duration(milliseconds: 50)); // loadInitialOrders

    // Status live kini 4 (siap dikirim) — tombol mark-ready tidak boleh
    // tampil lagi; form kirim bukti pengiriman menggantikannya.
    expect(find.text('Tandai Siap Dikirim'), findsNothing);
    expect(find.text('Kirim Bukti Pengiriman'), findsWidgets);
  });

  testWidgets('markReadyToShip sukses menampilkan snackbar sukses',
      (tester) async {
    when(() => presence.markReadyToShip(
          orderId: any(named: 'orderId'),
          orderFor: any(named: 'orderFor'),
        )).thenAnswer((_) async => {
              'success': true,
              'data': {'id': 42, 'delivery_status': 4},
            });

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: snapshotOrder,
        orderMode: OrderMode.online,
        provider: provider,
      ),
    ));
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Tandai Siap Dikirim'));
    await tester.tap(find.text('Tandai Siap Dikirim'));
    await tester.pump(); // mulai markReadyToShip
    await tester.pump(const Duration(milliseconds: 50)); // sukses + snackbar

    expect(find.text('Order berhasil ditandai siap dikirim.'),
        findsOneWidget);
  });

  testWidgets(
      'setelah submitDelivery sukses (siap dikirim → sudah dikirim), '
      'status berubah ke Sudah Dikirim dan form pengiriman hilang',
      (tester) async {
    final readyOrder = <String, dynamic>{
      'id': 43,
      'receipt_no': 'REC-43',
      'delivery_status': 4,
      'items': <Map<String, dynamic>>[],
    };

    when(() => presence.updateDeliveryStatus(
          receiptNo: any(named: 'receiptNo'),
          orderId: any(named: 'orderId'),
          imageFiles: any(named: 'imageFiles'),
          receivedBy: any(named: 'receivedBy'),
          deliveryStatus: any(named: 'deliveryStatus'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) async => {
          'success': true,
          'message': 'Status pengiriman berhasil diperbarui.',
          'data': {
            'receipt_no': 'REC-43',
            'order_id': 43,
            'delivery_status': 3,
            'image_delivery_urls': ['https://example.com/proof.jpg'],
            'image_delivery_url': 'https://example.com/proof.jpg',
          },
        });

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: readyOrder,
        orderMode: OrderMode.online,
        provider: provider,
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Pastikan form pengiriman tampil karena status awal adalah 4
    expect(find.text('Kirim Bukti Pengiriman'), findsWidgets);

    // Isi nama penerima dan tambahkan foto bukti (via setPhotos agar
    // notifyListeners jalan dan tombol submit aktif).
    provider.receiverController.text = 'Pak RT';
    provider.setPhotos([File('proof.jpg')]);
    await tester.pump();

    // Tap tombol submit (FilledButton.icon — bukan ElevatedButton).
    final submitButton = find.widgetWithText(FilledButton, 'Kirim Bukti Pengiriman');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump(); // memunculkan dialog konfirmasi

    // Tap tombol "Ya, Kirim" di AlertDialog
    expect(find.text('Konfirmasi Pengiriman'), findsOneWidget);
    await tester.tap(find.text('Ya, Kirim'));
    await tester.pump(); // kirim request
    await tester.pump(const Duration(milliseconds: 100)); // update state + notify

    // Verifikasi bahwa status telah berubah menjadi Sudah Dikirim (status 3)
    // dan form submit delivery hilang
    expect(find.text('Kirim Bukti Pengiriman'), findsNothing);
    expect(find.text('Sudah Dikirim'), findsWidgets);
    expect(find.text('Status pengiriman berhasil diperbarui.'), findsOneWidget);
  });

  testWidgets('mode direct: pencil AppBar edit tidak tampil meski admin',
      (tester) async {
    final directRepo = _MockRepository();
    when(() => directRepo.loadAdminRole()).thenAnswer((_) async => true);
    when(() => directRepo.loadCanManageSalesLink()).thenAnswer((_) async => false);
    when(() => directRepo.loadDeliveryPhotoEditRole()).thenAnswer((_) async => false);
    when(() => directRepo.loadPrintedStickers()).thenAnswer((_) async => {});
    final directProvider = DeliveryProvider(
      orderMode: OrderMode.direct,
      presenceService: presence,
      repository: directRepo,
      pdfService: _MockPdf(),
      stickerOrchestrator: _MockSticker(),
    );
    await directProvider.initialize();

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: snapshotOrder,
        orderMode: OrderMode.direct,
        provider: directProvider,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Ubah Rincian Produk'), findsNothing);
  });

  testWidgets('mode online + admin: pencil AppBar edit tetap tampil',
      (tester) async {
    final onlineRepo = _MockRepository();
    when(() => onlineRepo.loadAdminRole()).thenAnswer((_) async => true);
    when(() => onlineRepo.loadCanManageSalesLink()).thenAnswer((_) async => false);
    when(() => onlineRepo.loadDeliveryPhotoEditRole()).thenAnswer((_) async => false);
    when(() => onlineRepo.loadPrintedStickers()).thenAnswer((_) async => {});
    final onlineProvider = DeliveryProvider(
      orderMode: OrderMode.online,
      presenceService: presence,
      repository: onlineRepo,
      pdfService: _MockPdf(),
      stickerOrchestrator: _MockSticker(),
    );
    await onlineProvider.initialize();

    await tester.pumpWidget(MaterialApp(
      home: OrderDetailPage(
        order: snapshotOrder,
        orderMode: OrderMode.online,
        provider: onlineProvider,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Ubah Rincian Produk'), findsOneWidget);
  });
}
