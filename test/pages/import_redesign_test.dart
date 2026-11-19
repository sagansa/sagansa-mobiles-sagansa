import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/import_detail_page.dart';
import 'package:sagansa/pages/import_form_page.dart';
import 'package:sagansa/pages/import_list_page.dart';
import 'package:sagansa/providers/theme_provider.dart';
import 'package:sagansa/services/import_service.dart';
import 'package:sagansa/widgets/modern_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Golden + smoke test redesign halaman impor (list / form / detail).
///
/// HTTP dimock penuh; golden di-generate via
/// `flutter test --update-goldens test/pages/import_redesign_test.dart`
/// lalu diperiksa manual (layout, tema light/dark, overflow).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  Map<String, dynamic> itemJson(
    int id,
    int productId,
    String name,
    double qty,
    double price, {
    double? received,
    double? hppEstimateUnit,
    double? hppRealUnit,
    bool priceRealized = false,
  }) =>
      {
        'id': id,
        'product_id': productId,
        'quantity': qty,
        'unit_price_foreign': price,
        if (received != null) 'quantity_received': received,
        if (hppEstimateUnit != null) 'hpp_estimate_unit': hppEstimateUnit,
        if (hppRealUnit != null) 'hpp_real_unit': hppRealUnit,
        if (hppEstimateUnit != null || hppRealUnit != null)
          'unit_price_idr': priceRealized ? hppRealUnit : hppEstimateUnit,
        if (hppEstimateUnit != null || hppRealUnit != null)
          'price_is_realized': priceRealized,
        'product': {
          'name': name,
          'unit': {'unit': 'kg'},
        },
      };

  Map<String, dynamic> detailData() => {
        'id': 7,
        'supplier_id': 3,
        'supplier': {'name': 'Olam Vietnam Ltd'},
        'currency': 'USD',
        'exchange_rate': 17545,
        'invoice_number': 'INV-OLAM-2026-001',
        'purchase_date': '2026-10-18',
        'stage': 'customs',
        'notes': 'Kontrak mete kernel Oktober 2026 — 1×40 ft container.',
        'total_estimate': 417099315,
        'total_real': 0,
        'items': [
          itemJson(11, 21, 'Mete Kernel BB2 (Carton 50 lb)', 19500, 0.78,
              hppEstimateUnit: 14050),
          itemJson(12, 22, 'Mete Kernel BB3 (Flexy 80 kg)', 10500, 0.74,
              hppEstimateUnit: 13392),
        ],
        'costs': [
          {
            'id': 31,
            'stage': 'payment',
            'name': 'Transfer Bank',
            'category': 'bank',
            'is_foreign_currency': true,
            'amount_foreign': 25,
            'amount_estimate': 400000,
            'amount_real': 438625,
          },
          {
            'id': 32,
            'stage': 'customs',
            'name': 'PPh Impor 2,5%',
            'category': 'tax',
            'tax_rate': 2.5,
            'is_foreign_currency': false,
            'amount_estimate': 10077090,
          },
          {
            'id': 33,
            'stage': 'arrival',
            'name': 'Handling Koja',
            'category': 'logistics',
            'is_foreign_currency': false,
            'amount_estimate': 3500000,
            'amount_real': 3500000,
          },
        ],
        'payments': [
          {
            'id': 51,
            'amount': 290000000,
            'paid_at': '2026-10-18',
            'note': 'Transfer tahap 1',
            'proof_path': 'documents/ImportPurchase/bayar-1.webp',
            'proof_original_name': 'bukti-transfer.jpeg',
            'proof_mime_type': 'image/webp',
            'proof_size_bytes': 2048,
          },
        ],
        'notuls': [
          {
            'id': 61,
            'notul_number': 'NOTUL-2026-001',
            'notul_date': '2026-10-20',
            'pph_amount': 13000000,
            'ppn_amount': 31000000,
            'penalty_amount': 1000000,
            'other_amount': 0,
            'other_description': null,
            'document_path': 'documents/ImportPurchase/notul.webp',
            'document_original_name': 'notul.webp',
            'document_mime_type': 'image/webp',
            'document_size_bytes': 1024,
          },
        ],
        'documents': [
          {
            'id': 41,
            'type': 'invoice',
            'file_path': 'documents/ImportPurchase/inv.pdf',
            'original_name': 'invoice-olam-2026.pdf',
            'mime_type': 'application/pdf',
          },
          {
            'id': 42,
            'type': 'payment_proof',
            'file_path': 'documents/ImportPurchase/proof.webp',
            'original_name': 'bukti-transfer.jpeg',
            'mime_type': 'image/webp',
          },
          {
            'id': 43,
            'type': 'bl',
            'file_path': 'documents/ImportPurchase/bl.pdf',
            'original_name': 'bill-of-lading.pdf',
            'mime_type': 'application/pdf',
          },
        ],
        'documents_count': 3,
      };

  Map<String, dynamic> detailJson() => {
        'success': true,
        'data': detailData(),
        'hpp': {
          'goods_total': 403083600,
          'total_estimate': 417099315,
          'total_real': 0,
          'variance': 0,
          'variance_percent': null,
          'hpp_pajak': 406583600,
          'tax_total_estimate': 10077090,
          'bank_total_estimate': 438625,
          'items': [
            {
              'id': 11,
              'goods_value': 266859450,
              'allocated_estimate': 8629550,
              'hpp_estimate_unit': 14134,
              'hpp_real_unit': 0,
            },
            {
              'id': 12,
              'goods_value': 136224150,
              'allocated_estimate': 4441538,
              'hpp_estimate_unit': 13392,
              'hpp_real_unit': 0,
            },
          ],
        },
        'checklist': {
          'draft': {'label': 'Draft', 'state': 'done', 'documents': {}},
          'payment': {
            'label': 'Pembayaran',
            'state': 'done',
            'documents': {
              'invoice': {
                'label': 'Invoice',
                'required': true,
                'present': true,
              },
              'payment_proof': {
                'label': 'Bukti Bayar',
                'required': true,
                'present': true,
              },
            },
          },
          'shipment': {
            'label': 'Pengiriman',
            'state': 'done',
            'documents': {
              'bl': {
                'label': 'B/L / AWB',
                'required': true,
                'present': true,
              },
              'packing_list': {
                'label': 'Packing List',
                'required': true,
                'present': false,
              },
            },
          },
          'customs': {
            'label': 'Kepabeanan',
            'state': 'current',
            'documents': {
              'pib': {
                'label': 'PIB / SPPB',
                'required': true,
                'present': false,
              },
              'tax_proof': {
                'label': 'Bukti Setor Pajak',
                'required': true,
                'present': false,
              },
            },
          },
          'arrival': {
            'label': 'Kedatangan',
            'state': 'upcoming',
            'documents': {
              'delivery_order': {
                'label': 'Delivery Order',
                'required': false,
                'present': false,
              },
            },
          },
          'receiving': {
            'label': 'Penerimaan',
            'state': 'upcoming',
            'documents': {},
          },
          'finalized': {
            'label': 'Final',
            'state': 'upcoming',
            'documents': {},
          },
        },
        'next_stage': 'arrival',
      };

  http.Client mockClient() {
    return MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/import-purchases')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              detailData(),
              {
                'id': 6,
                'supplier_id': 9,
                'supplier': {'name': 'Mete Supply Co (India)'},
                'currency': 'USD',
                'exchange_rate': 17000,
                'invoice_number': 'INV-METE-009',
                'purchase_date': '2026-10-12',
                'stage': 'receiving',
                'total_estimate': 324164616,
                'total_real': 357525590,
                'items': [
                  itemJson(9, 21, 'Mete Kernel BB2 (Carton 50 lb)', 19500, 0.78,
                      received: 19110,
                      hppEstimateUnit: 16624,
                      hppRealUnit: 18709,
                      priceRealized: true),
                ],
                'costs': [],
                'documents': [],
                'documents_count': 6,
              },
            ],
            'meta': {
              'stage_counts': {
                'draft': 1,
                'customs': 1,
                'receiving': 1,
              },
            },
            'pagination': {'current_page': 1, 'last_page': 1},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/import-purchases/7')) {
        return http.Response(
          jsonEncode(detailJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/procurement/products')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 21,
                'name': 'Mete Kernel BB2 (Carton 50 lb)',
                'unit': {'unit': 'kg'},
              },
              {
                'id': 22,
                'name': 'Mete Kernel BB3 (Flexy 80 kg)',
                'unit': {'unit': 'kg'},
              },
              {
                'id': 23,
                'name': 'Mete Kernel LP2 (Karung 80 kg)',
                'unit': {'unit': 'kg'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/suppliers')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 3,
                'name': 'Olam Vietnam Ltd',
                'status': 2,
              },
              {
                'id': 9,
                'name': 'Mete Supply Co (India)',
                'status': 2,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light
            ? ThemeProvider.lightTheme
            : ThemeProvider.darkTheme,
        home: page,
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('list impor — render + golden light & dark', (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportListPage());
      expect(tester.takeException(), isNull);
      expect(find.text('Olam Vietnam LTD'), findsOneWidget);
      expect(find.text('Mete Supply Co (India)'), findsOneWidget);
      expect(find.textContaining('INV-OLAM-2026-001'), findsOneWidget);
      expect(find.textContaining('18 Okt 2026'), findsOneWidget);
      expect(find.text('Kepabeanan'), findsWidgets);
      expect(find.text('Penerimaan'), findsWidgets);
      // Nominal bergaya Indonesia (titik ribuan), bukan koma en_US.
      expect(find.text('Rp 417.099.315'), findsOneWidget);
      // Harga satuan per produk: realisasi bila tersedia, fallback
      // estimasi selama belum — chip kecil menandai sumbernya.
      expect(find.text('Harga satuan produk'), findsNWidgets(2));
      expect(find.textContaining('Rp 14.050 / kg'), findsOneWidget);
      expect(find.textContaining('Rp 18.709 / kg'), findsOneWidget);
      expect(find.text('Realisasi'), findsWidgets);
      expect(find.text('Estimasi'), findsWidgets);

      await expectLater(
        find.byType(ImportListPage),
        matchesGoldenFile('goldens/import_list_light.png'),
      );
    }, () => mock);

    final mockDark = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportListPage(),
          brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ImportListPage),
        matchesGoldenFile('goldens/import_list_dark.png'),
      );
    }, () => mockDark);
  });

  testWidgets('detail impor — render + golden light & dark', (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportDetailPage(importId: 7));
      expect(tester.takeException(), isNull);
      expect(find.text('Olam Vietnam LTD'), findsOneWidget);
      expect(find.text('18 Oktober 2026'), findsOneWidget);
      expect(find.text('INV-OLAM-2026-001'), findsNWidgets(2));
      expect(find.text('Total Estimasi'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mete Kernel BB2 (Carton 50 lb)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mete Kernel BB2 (Carton 50 lb)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Kelengkapan Dokumen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PIB / SPPB'), findsOneWidget);
      expect(find.text('Lanjut: Kedatangan'), findsOneWidget);

      await expectLater(
        find.byType(ImportDetailPage),
        matchesGoldenFile('goldens/import_detail_light.png'),
      );
    }, () => mock);

    final mockDark = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportDetailPage(importId: 7),
          brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ImportDetailPage),
        matchesGoldenFile('goldens/import_detail_dark.png'),
      );
    }, () => mockDark);
  });

  testWidgets('detail impor — pembayaran & notul tampil', (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportDetailPage(importId: 7));
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Tranche 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tranche 1'), findsOneWidget);
      expect(find.text('Rp 290.000.000'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('NOTUL-2026-001'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('NOTUL-2026-001'), findsOneWidget);
      expect(find.text('PPh Impor'), findsOneWidget);
      expect(find.text('PPN Impor'), findsOneWidget);
    }, () => mock);
  });

  testWidgets(
      'detail impor — tombol lanjut bergaya peringatan saat syarat tahap '
      'berikutnya belum lengkap (golden)', (tester) async {
    // Tahap payment → berikutnya shipment; B/L & Packing List wajib dan
    // belum diupload → tombol outlined + banner ringkasan jumlah dokumen.
    final gated = detailJson();
    (gated['data'] as Map<String, dynamic>)['stage'] = 'payment';
    gated['next_stage'] = 'shipment';
    gated['checklist'] = {
      'draft': {'label': 'Draft', 'state': 'done', 'documents': {}},
      'payment': {
        'label': 'Pembayaran',
        'state': 'current',
        'documents': {
          'invoice': {'label': 'Invoice', 'required': true, 'present': true},
          'payment_proof': {
            'label': 'Bukti Bayar',
            'required': true,
            'present': true,
          },
        },
      },
      'shipment': {
        'label': 'Pengiriman',
        'state': 'upcoming',
        'documents': {
          'bl': {'label': 'B/L / AWB', 'required': true, 'present': false},
          'packing_list': {
            'label': 'Packing List',
            'required': true,
            'present': false,
          },
        },
      },
    };

    final mock = MockClient(
      (request) async => http.Response(
        jsonEncode(gated),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await http.runWithClient(() async {
      await pumpPage(tester, const ImportDetailPage(importId: 7));
      expect(tester.takeException(), isNull);

      // Banner ringkasan + tombol varian peringatan.
      expect(
        find.textContaining('2 dokumen wajib untuk tahap Pengiriman'),
        findsOneWidget,
      );
      final button = tester.widget<ModernButton>(
        find.byWidgetPredicate(
          (w) => w is ModernButton && w.text == 'Lanjut: Pengiriman',
        ),
      );
      expect(button.variant, ModernButtonVariant.outlined);
      expect(button.icon, Icons.warning_amber_rounded);

      // Geometri: banner persis di atas tombol, keduanya berada dalam
      // area bar aksi bawah dan tidak saling menimpa.
      final bannerRect = tester.getRect(
        find.textContaining('2 dokumen wajib untuk tahap Pengiriman'),
      );
      final buttonRect = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is ModernButton && w.text == 'Lanjut: Pengiriman',
        ),
      );
      expect(bannerRect.bottom, lessThanOrEqualTo(buttonRect.top));
      expect(buttonRect.bottom, lessThan(844));

      await expectLater(
        find.byType(ImportDetailPage),
        matchesGoldenFile('goldens/import_detail_gated_light.png'),
      );
    }, () => mock);
  });

  testWidgets('detail impor — dokumen wajib dikelompokkan per tahap',
      (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportDetailPage(importId: 7));
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Bukti Setor Pajak'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Tiap tahap punya blok sendiri — pembagian syarat langsung terbaca.
      expect(find.text('Pembayaran'), findsWidgets);
      expect(find.text('Pengiriman'), findsWidgets);
      expect(find.text('Kepabeanan'), findsWidgets);
      expect(find.text('2/2 wajib'), findsOneWidget);
      expect(find.text('1/2 wajib'), findsOneWidget);
      expect(find.text('0/2 wajib'), findsOneWidget);
      expect(find.text('Lengkap'), findsOneWidget);
      expect(find.text('Dilewati'), findsOneWidget);
      expect(find.text('Berjalan'), findsOneWidget);

      // Ringkasan lintas tahap: 3 dari 6 dokumen wajib sudah ada.
      expect(find.text('3/6 wajib'), findsOneWidget);

      // Dokumen duduk di grupnya masing-masing, bukan daftar datar.
      expect(find.text('Bukti Bayar'), findsOneWidget);
      expect(find.text('Packing List'), findsOneWidget);
      expect(find.text('PIB / SPPB'), findsOneWidget);
      expect(find.text('Bukti Setor Pajak'), findsOneWidget);
      expect(find.text('invoice-olam-2026.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => mock);
  });

  testWidgets('detail impor — upload langsung dari baris dokumen tahap',
      (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportDetailPage(importId: 7));
      expect(tester.takeException(), isNull);

      final uploadButton = find.byKey(const ValueKey('upload-packing_list'));
      await tester.scrollUntilVisible(
        uploadButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible hanya memulai animasi ensureVisible; tunggu sampai
      // baris benar-benar masuk viewport sebelum menekan tombolnya.
      await tester.pumpAndSettle();
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      // Tipe dokumen sudah pasti dari baris tahap — tidak ada pemilih tipe.
      expect(find.text('Upload Packing List'), findsOneWidget);
      expect(find.text('Kamera (foto dokumen)'), findsOneWidget);
      expect(find.text('Tipe Dokumen'), findsNothing);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('Upload Packing List'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => mock);
  });

  testWidgets('detail impor 320dp — checklist tahap tanpa overflow',
      (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(
        tester,
        const ImportDetailPage(importId: 7),
        size: const Size(320, 720),
      );
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Bukti Setor Pajak'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pembayaran'), findsWidgets);
      expect(find.text('Pengiriman'), findsWidgets);
      expect(tester.takeException(), isNull);
    }, () => mock);
  });

  testWidgets('form impor baru — render + golden light', (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(tester, const ImportFormPage());
      expect(tester.takeException(), isNull);
      expect(find.text('Informasi Umum'), findsOneWidget);
      expect(find.text('Tanggal Impor'), findsOneWidget);
      expect(find.text('No. Invoice'), findsOneWidget);
      expect(find.text('Produk Diimpor (1)'), findsOneWidget);
      // Produk dari impor sebelumnya tidak ikut tersalin.
      expect(find.text('Mete Kernel BB2 (Carton 50 lb)'), findsNothing);
      // Baris biaya standar (sheet HPP METE) tersedia sebagai default.
      await tester.scrollUntilVisible(
        find.text('Biaya-biaya (14)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Biaya-biaya (14)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Transfer Bank'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Transfer Bank'), findsOneWidget);
      expect(find.text('PPH Impor'), findsOneWidget);
      expect(find.text('PPN Impor'), findsOneWidget);
      expect(find.text('Handling Koja'), findsOneWidget);
      expect(find.text('Lift-off Depo SPM'), findsOneWidget);
      // Nominal realisasi biaya non-pajak disalin; estimasi lama & PPh/PPN
      // tidak dipakai.
      expect(find.text('438.625'), findsOneWidget);
      expect(find.text('400.000'), findsNothing);
      expect(find.text('3.500.000'), findsOneWidget);
      expect(find.text('10.077.090'), findsNothing);
      await expectLater(
        find.byType(ImportFormPage),
        matchesGoldenFile('goldens/import_form_costs_light.png'),
      );
      await tester.scrollUntilVisible(
        find.text('35.000'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('35.000'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Total Estimasi'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Total Estimasi'), findsOneWidget);
      expect(find.text('Simpan Proses Impor'), findsOneWidget);

      await expectLater(
        find.byType(ImportFormPage),
        matchesGoldenFile('goldens/import_form_light.png'),
      );
    }, () => mock);
  });

  testWidgets('form impor 320dp: tanggal, invoice & produk tanpa overflow',
      (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      await pumpPage(
        tester,
        const ImportFormPage(),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tanggal Impor'), findsOneWidget);
      expect(find.text('No. Invoice'), findsOneWidget);

      // Header kini memuat kurs USD → VND — seksi di bawahnya perlu
      // digulir sampai ter-build (sliver malas pada viewport pendek).
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Produk Diimpor (1)'),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('Produk Diimpor (1)'), findsOneWidget);
      expect(find.text('Harga satuan (USD)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Biaya-biaya (14)'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('Biaya-biaya (14)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => mock);
  });

  testWidgets('form edit proses impor — prefill + golden light',
      (tester) async {
    final mock = mockClient();
    await http.runWithClient(() async {
      final service = ImportService();
      final detail = await service.getDetail(7);
      await pumpPage(tester, ImportFormPage(existing: detail.importPurchase));
      expect(tester.takeException(), isNull);
      expect(find.text('Edit Proses Impor'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
      expect(find.text('Produk Diimpor (2)'), findsOneWidget);
      // Prefill bergaya Indonesia: kurs terkelompok titik, harga USD dengan
      // koma desimal (bug lama: desimal tak bisa diketik / tampil "0.78").
      expect(find.text('17.545'), findsOneWidget);
      expect(find.text('0,78'), findsOneWidget);
      expect(find.text('0,74'), findsOneWidget);
      // Prefill biaya: PPh otomatis terpilih mode persen pajak.
      await tester.scrollUntilVisible(
        find.text('Biaya-biaya (3)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PPh Impor 2,5%'), findsOneWidget);
      // Kelompok tahap + total ratusan juta terbaca utuh (tanpa elipsis).
      // Nilai dihitung live dari isian: 19.500×0,78×17.545 + 10.500×0,74×
      // 17.545 = 403.184.100 barang; + 25 USD×kurs + 2,5% + 3,5 jt biaya.
      await tester.scrollUntilVisible(
        find.text('Total Estimasi'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rp 417.202.328'), findsOneWidget);
      expect(find.text('Rp 403.184.100'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(ImportFormPage),
        matchesGoldenFile('goldens/import_form_edit_light.png'),
      );
    }, () => mock);
  });
}
