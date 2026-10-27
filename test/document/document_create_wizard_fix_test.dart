import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_create_wizard.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';

/// Fix review task 20:
/// (a) alur salin surat → langkah 2 prefilled dari metadata salinan;
/// (b) form tidak diubah → PATCH TANPA key metadata & tanpa unit
///     (metadata/unit salinan tidak tertimpa);
/// (c) jenis & template terkunci setelah draft ada.
class _FakeDuplicateService extends DocumentService {
  /// Metadata yang "disalin backend" ke draf baru.
  final Map<String, dynamic> copiedMetadata;

  _FakeDuplicateService(this.copiedMetadata);

  String? lastUpdateUnit;
  Map<String, dynamic>? lastUpdateMetadata;
  String? lastUpdateSubject;

  @override
  Future<List<LetterTypeModel>> getLetterTypes() async => const [
        _kuaType,
        LetterTypeModel(code: 'ST', name: 'Surat Tugas'),
      ];

  @override
  Future<List<TemplateModel>> getTemplates(String letterTypeCode) async =>
      switch (letterTypeCode) {
        'KUA' => const [
            TemplateModel(
              id: 7,
              name: 'Template KUA Standar',
              letterTypeCode: 'KUA',
              isDefault: true,
            ),
          ],
        'ST' => const [
            TemplateModel(
              id: 8,
              name: 'Template ST',
              letterTypeCode: 'ST',
              isDefault: false,
            ),
          ],
        _ => const [],
      };

  @override
  Future<PaginatedResult<DocumentModel>> getDocuments({
    String? status,
    String? letterType,
    int? year,
    String? query,
    int page = 1,
  }) async =>
      PaginatedResult(
        items: [
          DocumentModel(
            id: 'src-1',
            number: '017/KUA/III/2026',
            status: 'terbit',
            classification: 'umum',
            subject: 'Kuasa jual kendaraan',
            date: DateTime(2026, 3, 15),
            letterType: const LetterTypeModel(code: 'KUA', name: 'Surat Kuasa'),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
        perPage: 15,
      );

  @override
  Future<DocumentModel> createDraft({
    required String letterTypeCode,
    String? unit,
    required String subject,
    required DateTime date,
    String? bodyHtml,
    Map<String, dynamic>? metadata,
    String? classification,
    String? companyId,
    int? templateId,
    String? duplicateFromId,
  }) async =>
      DocumentModel(
        id: 'draft-salin',
        status: 'draft',
        classification: 'umum',
        subject: subject,
        // Backend menyalin metadata sumber ke draf duplikat.
        metadata: duplicateFromId == null ? metadata : copiedMetadata,
      );

  @override
  Future<DocumentModel> updateDraft(
    String id, {
    String? unit,
    String? subject,
    DateTime? date,
    String? bodyHtml,
    Map<String, dynamic>? metadata,
    String? classification,
  }) async {
    lastUpdateUnit = unit;
    lastUpdateSubject = subject;
    lastUpdateMetadata = metadata;
    return DocumentModel(
      id: id,
      status: 'draft',
      classification: 'umum',
      subject: subject ?? 'draf',
    );
  }
}

const _kuaType = LetterTypeModel(
  code: 'KUA',
  name: 'Surat Kuasa',
  specificFields: [
    LetterSpecificField(
        key: 'penerima_kuasa_nama', label: 'Nama Penerima Kuasa'),
  ],
);

final _copiedMetadata = <String, dynamic>{
  'recipient': {
    'name': 'Siti Rahayu',
    'identity_no': '3271234567890001',
    'address': 'Jl. Merdeka 12',
  },
  'specific': {'penerima_kuasa_nama': 'Siti Rahayu (penerima kuasa)'},
  'validity': {'mode': 'until_date', 'until_date': '2027-01-15'},
};

Future<void> _pumpWizard(WidgetTester tester, DocumentService service) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        ...FlutterQuillLocalizations.localizationsDelegates,
      ],
      supportedLocales: const [Locale('id')],
      locale: const Locale('id'),
      home: DocumentCreateWizard(service: service),
    ),
  );
  await tester.pumpAndSettle();
}

/// Buka sheet "Salin surat lama" dan pilih sumber arsip.
Future<void> _duplicateViaSheet(WidgetTester tester) async {
  await tester.tap(find.text('Salin surat lama'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('017/KUA/III/2026'));
  await tester.pumpAndSettle();
  // Snackbar "Draf salinan dibuat…" melayang di atas bottom bar — tunggu
  // hilang agar tap Lanjut tidak mengenai snackbar.
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) salin surat → langkah 2 prefilled dari metadata salinan',
      (tester) async {
    final service = _FakeDuplicateService(_copiedMetadata);
    await _pumpWizard(tester, service);
    await _duplicateViaSheet(tester);

    // Langkah 2 aktif, subject dari sumber.
    expect(find.text('Unit & perihal'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Salinan — Kuasa jual kendaraan'),
      findsOneWidget,
    );

    // Recipient + field khusus + masa berlaku salinan memenuhi form.
    expect(find.widgetWithText(TextField, 'Siti Rahayu'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, '3271234567890001'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Jl. Merdeka 12'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Siti Rahayu (penerima kuasa)'),
      findsOneWidget,
    );
    // Bagian masa berlaku di bawah lipat viewport — gulir dulu.
    await tester.dragUntilVisible(
      find.text('Masa berlaku'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    // Mode "Hingga tanggal" terpilih + tanggalnya tampil.
    expect(find.text('Berlaku hingga tanggal'), findsOneWidget);
    expect(find.text('15 Januari 2027'), findsOneWidget);
  });

  testWidgets('(b) form salinan tak diubah → PATCH tanpa metadata & unit',
      (tester) async {
    final service = _FakeDuplicateService(_copiedMetadata);
    await _pumpWizard(tester, service);
    await _duplicateViaSheet(tester);

    // Subject sudah terisi prefill; Lanjut langsung menyimpan draf.
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(service.lastUpdateSubject, 'Salinan — Kuasa jual kendaraan');
    // Inti fix: key metadata TIDAK ikut PATCH (isi salinan dipertahankan)
    // dan unit 'DIR' default TIDAK menimpa unit sumber.
    expect(service.lastUpdateMetadata, isNull,
        reason: 'metadata tidak boleh dikirim saat form sama dengan salinan');
    expect(service.lastUpdateUnit, isNull,
        reason: 'unit default DIR tidak boleh dikirim saat tidak diubah');
  });

  testWidgets('(b2) ubah penerima setelah salin → metadata ter-PATCH utuh',
      (tester) async {
    final service = _FakeDuplicateService(_copiedMetadata);
    await _pumpWizard(tester, service);
    await _duplicateViaSheet(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Siti Rahayu'), 'Siti Rahayu Baru');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Berubah → metadata dikirim (replace penuh, form = source of truth).
    expect(service.lastUpdateMetadata, isNotNull);
    expect(
      service.lastUpdateMetadata!['recipient'],
      containsPair('name', 'Siti Rahayu Baru'),
    );
    // Bagian lain tetap terbawa (terprefill dari salinan).
    expect(
      service.lastUpdateMetadata!['specific'],
      _copiedMetadata['specific'],
    );
    expect(
      service.lastUpdateMetadata!['validity'],
      _copiedMetadata['validity'],
    );
  });

  testWidgets('(c) jenis & template terkunci setelah draft dibuat',
      (tester) async {
    final service = _FakeDuplicateService(_copiedMetadata);
    await _pumpWizard(tester, service);
    await _duplicateViaSheet(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    // Snackbar "Draf tersimpan." menutupi bottom bar — tunggu hilang.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Mundur dua langkah (editor → formulir → jenis): banner kunci tampil.
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Jenis terkunci setelah draft dibuat'),
      findsOneWidget,
    );

    // Tap jenis lain (Surat Tugas) TIDAK mengubah pilihan: template jenis
    // itu tidak dimuat dan jenis KUA tetap terpilih (kartunya tetap biru
    // terpilih; template KUA masih tampil).
    await tester.tap(find.text('Surat Tugas'));
    await tester.pumpAndSettle();

    expect(find.text('Template ST'), findsNothing);
    expect(find.text('Template KUA Standar'), findsOneWidget);

    // Tombol "Salin surat lama" juga nonaktif saat terkunci.
    final dupButton =
        find.widgetWithText(OutlinedButton, 'Salin surat lama');
    expect(tester.widget<OutlinedButton>(dupButton).onPressed, isNull);
  });
}
