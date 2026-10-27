import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_create_wizard.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';

/// Kontrak UI `DocumentCreateWizard` (task 20) — alur happy path
/// langkah 1 → 2 → 3:
/// - langkah 1: Lanjut terblokir sebelum jenis dipilih; kartu jenis
///   memuat template (default otomatis terpilih);
/// - langkah 2: perihal wajib (Lanjut terblokir + pesan), menyimpan draf
///   via createDraft dengan letter type/unit/subject/metadata/template;
/// - langkah 3: editor isi tampil (flutter_quill) dan Lanjut lanjut
///   tanpa PATCH body saat editor kosong.
class _FakeWizardService extends DocumentService {
  _FakeWizardService({
    this.letterTypes = const [],
    Map<String, List<TemplateModel>> templatesPerType = const {},
  }) : _templatesPerType = templatesPerType;

  final List<LetterTypeModel> letterTypes;
  final Map<String, List<TemplateModel>> _templatesPerType;

  String? lastCreateLetterType;
  String? lastCreateSubject;
  String? lastCreateUnit;
  int? lastCreateTemplateId;
  String? lastCreateBodyHtml;
  Map<String, dynamic>? lastCreateMetadata;
  int updateDraftCalls = 0;
  String? lastUpdateBodyHtml;

  @override
  Future<List<LetterTypeModel>> getLetterTypes() async => letterTypes;

  @override
  Future<List<TemplateModel>> getTemplates(String letterTypeCode) async =>
      _templatesPerType[letterTypeCode] ?? const [];

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
  }) async {
    lastCreateLetterType = letterTypeCode;
    lastCreateSubject = subject;
    lastCreateUnit = unit;
    lastCreateTemplateId = templateId;
    lastCreateBodyHtml = bodyHtml;
    lastCreateMetadata = metadata;
    return DocumentModel(
      id: 'draft-1',
      status: 'draft',
      classification: 'umum',
      subject: subject,
    );
  }

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
    updateDraftCalls++;
    lastUpdateBodyHtml = bodyHtml;
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
    LetterSpecificField(key: 'penerima_kuasa_nama', label: 'Nama Penerima Kuasa'),
  ],
);

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

void main() {
  testWidgets('langkah 1: Lanjut terblokir sampai jenis dipilih; template '
      'default otomatis terpilih', (tester) async {
    final service = _FakeWizardService(
      letterTypes: const [
        _kuaType,
        LetterTypeModel(code: 'ST', name: 'Surat Tugas'),
      ],
      templatesPerType: const {
        'KUA': [
          TemplateModel(
            id: 7,
            name: 'Template KUA Standar',
            letterTypeCode: 'KUA',
            isDefault: true,
          ),
        ],
      },
    );

    await _pumpWizard(tester, service);

    expect(find.text('Buat Surat'), findsOneWidget); // judul appbar
    expect(find.text('Pilih jenis surat dulu.'), findsOneWidget);
    final nextButton = find.widgetWithText(FilledButton, 'Lanjut');
    expect(nextButton, findsOneWidget);
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    // Pilih jenis KUA → template dimuat, default terpilih.
    await tester.tap(find.text('Surat Kuasa'));
    await tester.pumpAndSettle();

    expect(find.text('Template KUA Standar'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Pilih jenis surat dulu.'), findsNothing);
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
  });

  testWidgets('langkah 2: perihal wajib + createDraft membawa '
      'jenis/unit/subject/metadata/template', (tester) async {
    final service = _FakeWizardService(
      letterTypes: const [_kuaType],
      templatesPerType: const {
        'KUA': [
          TemplateModel(
            id: 7,
            name: 'Template KUA Standar',
            letterTypeCode: 'KUA',
            bodyHtml: '<p>Isi template</p>',
            isDefault: true,
          ),
        ],
      },
    );

    await _pumpWizard(tester, service);
    await tester.tap(find.text('Surat Kuasa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Langkah 2: form terlihat.
    expect(find.text('Unit & perihal'), findsOneWidget);
    expect(find.text('Perihal *'), findsOneWidget);

    // Perihal kosong → terblokir + pesan.
    expect(find.text('Perihal wajib diisi.'), findsOneWidget);

    // Isi perihal + penerima + field khusus KUA.
    await tester.enterText(
        find.widgetWithText(TextField, 'Perihal *'), 'Kuasa pengurusan pajak');
    await tester.pump();
    expect(find.text('Perihal wajib diisi.'), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextField, 'Nama penerima'), 'Budi Santoso');
    await tester.enterText(
        find.widgetWithText(TextField, 'Nama Penerima Kuasa'), 'Budi Santoso');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // createDraft terpanggil dengan isi form (+ body template sebagai awal).
    expect(service.lastCreateLetterType, 'KUA');
    expect(service.lastCreateUnit, 'DIR');
    expect(service.lastCreateSubject, 'Kuasa pengurusan pajak');
    expect(service.lastCreateTemplateId, 7);
    expect(service.lastCreateBodyHtml, '<p>Isi template</p>');
    expect(service.lastCreateMetadata, isNotNull);
    expect(
      service.lastCreateMetadata!['recipient'],
      {'name': 'Budi Santoso'},
    );
    expect(
      service.lastCreateMetadata!['specific'],
      {'penerima_kuasa_nama': 'Budi Santoso'},
    );
    expect(service.lastCreateMetadata!['validity'], isNotNull);

    // Langkah 3: editor + catatan tabel tampil; header pindah ke langkah 3.
    expect(find.text('Untuk isi ber tabel kompleks, gunakan unggah PDF '
        '(Mode B).'), findsOneWidget);
    expect(find.text('Langkah 3 dari 6 — Isi surat'), findsOneWidget);
  });

  testWidgets('langkah 3: editor terprefill template → Lanjut menyimpan '
      'body_html baru', (tester) async {
    final service = _FakeWizardService(
      letterTypes: const [_kuaType],
      templatesPerType: const {
        'KUA': [
          TemplateModel(
            id: 7,
            name: 'Template KUA Standar',
            letterTypeCode: 'KUA',
            bodyHtml: '<p>Isi template</p>',
            isDefault: true,
          ),
        ],
      },
    );

    await _pumpWizard(tester, service);
    await tester.tap(find.text('Surat Kuasa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Perihal *'), 'Kuasa pengurusan pajak');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    // Snackbar "Draf tersimpan." melayang di atas tombol — tunggu hilang.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Editor terprefill dari template → Lanjut menyimpan body baru
    // (kebenaran prefill dibuktikan lewat body_html yang di-PATCH).
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(service.updateDraftCalls, 1);
    expect(service.lastUpdateBodyHtml, isNotNull);
    expect(service.lastUpdateBodyHtml, contains('Isi template'));
  });
}
