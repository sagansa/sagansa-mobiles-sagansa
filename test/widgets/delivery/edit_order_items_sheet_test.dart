import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/providers/delivery_provider.dart';
import 'package:sagansa/services/delivery_status_repository.dart';
import 'package:sagansa/services/payment_proof_pdf_service.dart';
import 'package:sagansa/services/presence_service.dart';
import 'package:sagansa/services/sales_order_service.dart';
import 'package:sagansa/services/sticker_print_orchestrator.dart';
import 'package:sagansa/widgets/delivery/edit_order_items_sheet.dart';
import 'package:sagansa/widgets/modern_dropdown.dart';

class _MockPresence extends Mock implements PresenceService {}

class _MockRepository extends Mock implements DeliveryStatusRepository {}

class _MockPdf extends Mock implements PaymentProofPdfService {}

class _MockSticker extends Mock implements StickerPrintOrchestrator {}

class _MockSalesOrderService extends Mock implements SalesOrderService {}

Map<String, dynamic> checkoutOrder() => {
      'id': 5,
      'delivery_status': 1,
      'shipping_cost': 10000,
      'items': [
        {
          'product_id': 3,
          'product_online_group_id': null,
          'quantity': 2,
          'unit_price': 10000,
          'subtotal_price': 20000,
          'product_name': 'Kacang Hijau',
          'product_unit': 'kg',
        },
        {
          'product_id': null,
          'product_online_group_id': 9,
          'quantity': 1,
          'unit_price': 50000,
          'subtotal_price': 50000,
          'product_name': 'Paket Group Test',
          'product_unit': 'paket',
        },
      ],
    };

/// Dua baris GRUP dengan nama & product_online_group_id berbeda —
/// untuk regresi penghapusan baris grup pertama.
Map<String, dynamic> twoGroupOrder() => {
      'id': 7,
      'delivery_status': 1,
      'shipping_cost': 10000,
      'items': [
        {
          'product_id': null,
          'product_online_group_id': 9,
          'quantity': 1,
          'unit_price': 50000,
          'subtotal_price': 50000,
          'product_name': 'Paket Group Test',
          'product_unit': 'paket',
        },
        {
          'product_id': null,
          'product_online_group_id': 11,
          'quantity': 2,
          'unit_price': 30000,
          'subtotal_price': 60000,
          'product_name': 'Paket Lain Test',
          'product_unit': 'paket',
        },
      ],
    };

void main() {
  setUpAll(() {
    // Fallback untuk any(named: 'items') bertipe List<Map<String, dynamic>>.
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  Future<DeliveryProvider> makeProvider() async {
    final presence = _MockPresence();
    final repo = _MockRepository();
    when(() => repo.loadAdminRole()).thenAnswer((_) async => true);
    when(() => repo.loadCanManageSalesLink()).thenAnswer((_) async => false);
    when(() => repo.loadDeliveryPhotoEditRole()).thenAnswer((_) async => false);
    when(() => repo.loadPrintedStickers()).thenAnswer((_) async => {});
    when(() => presence.getSalesOrders(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          orderFor: any(named: 'orderFor'),
        )).thenAnswer((_) async =>
        {'success': true, 'data': [], 'meta': {'last_page': 1}});
    final provider = DeliveryProvider(
      orderMode: OrderMode.direct,
      presenceService: presence,
      repository: repo,
      pdfService: _MockPdf(),
      stickerOrchestrator: _MockSticker(),
    );
    await provider.initialize();
    return provider;
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    required DeliveryProvider provider,
    required SalesOrderService salesOrderService,
    Map<String, dynamic>? order,
  }) async {
    // Permukaan test diperbesar agar kedua kartu item seluruhnya termuat
    // dalam viewport ListView.builder — baris grup tidak akan ke-build
    // (dan tak bisa ditemukan finder) bila berada di luar layar pada
    // permukaan default 800x600.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DeliveryProvider>.value(value: provider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EditOrderItemsSheet(
            order: order ?? checkoutOrder(),
            provider: provider,
            salesOrderService: salesOrderService,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('baris grup: nama paket tampil read-only, tanpa picker produk',
      (tester) async {
    final service = _MockSalesOrderService();
    when(() => service.getOnlineProducts()).thenAnswer((_) async => []);
    final provider = await makeProvider();

    await pumpSheet(tester, provider: provider, salesOrderService: service);

    expect(find.text('Paket Group Test'), findsOneWidget);
    expect(find.text('Nama Paket (tetap)'), findsOneWidget);
    // Hanya baris produk biasa punya picker; baris grup memakai TextFormField.
    // byType melakukan perbandingan runtimeType secara exact sehingga
    // ModernDropdown<dynamic> tidak akan cocok dengan ModernDropdown<int> —
    // gunakan predikat subtype (sesuai maksud fallback brief).
    expect(
      find.byWidgetPredicate((w) => w is ModernDropdown),
      findsOneWidget,
    );
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
  });

  testWidgets(
      'hapus baris grup pertama: TextFormField tidak menerima initialValue baris lain',
      (tester) async {
    final service = _MockSalesOrderService();
    when(() => service.getOnlineProducts()).thenAnswer((_) async => []);
    final provider = await makeProvider();

    await pumpSheet(
      tester,
      provider: provider,
      salesOrderService: service,
      order: twoGroupOrder(),
    );

    // Dua baris grup tampil dengan nama masing-masing.
    expect(find.text('Paket Group Test'), findsOneWidget);
    expect(find.text('Paket Lain Test'), findsOneWidget);

    // Hapus baris grup PERTAMA (Item 1) lewat tombol hapus pertama.
    await tester.tap(find.byTooltip('Hapus item').first);
    await tester.pump();

    // Tanpa takeException lebih dulu: bila FlutterError "initialValue has
    // changed" muncul saat posisi baris bergeser (kartu dicocokkan by
    // posisi), test gagal di sini.
    expect(tester.takeException(), isNull);

    // Baris grup tersisa tetap menampilkan NAMA-nya sendiri.
    expect(find.text('Paket Group Test'), findsNothing);
    expect(find.text('Paket Lain Test'), findsOneWidget);
  });

  testWidgets('simpan payload: baris grup lolos validasi & sheet menutup',
      (tester) async {
    final service = _MockSalesOrderService();
    when(() => service.getOnlineProducts()).thenAnswer((_) async => []);
    final provider = await makeProvider();
    provider.selectOrder(checkoutOrder());

    final capturedItems = <List<Map<String, dynamic>>>[];
    when(() => provider.presenceService.updateSalesOrderItems(
          orderId: any(named: 'orderId'),
          items: any(named: 'items'),
          shippingCost: any(named: 'shippingCost'),
        )).thenAnswer((invocation) async {
      capturedItems.add(
        List<Map<String, dynamic>>.from(
            invocation.namedArguments[#items] as List),
      );
      return {'success': true, 'data': checkoutOrder()};
    });

    await pumpSheet(tester, provider: provider, salesOrderService: service);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump();

    // Tidak ada snackbar error "belum dipilih produknya".
    expect(find.textContaining('belum dipilih'), findsNothing);
    expect(find.textContaining('minimal 1'), findsNothing);

    // Payload yang dikirim sheet harus tetap memuat baris grup.
    expect(capturedItems, isNotEmpty);
    final groupRow = capturedItems.single
        .map((row) => row.cast<String, dynamic>())
        .firstWhere((row) => row['product_online_group_id'] != null);
    expect(groupRow['product_online_group_id'], 9);
    expect(groupRow['product_id'], isNull);
    expect(groupRow['quantity'], 1);
    expect(groupRow['unit_price'], 50000);
  });
}
