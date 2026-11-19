import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_create_wizard.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/services/document/incoming_models.dart';
import 'package:sagansa/services/document/incoming_service.dart';

/// Kontrak UI wizard mode balasan (Task 11 fase 1b):
/// - banner "Membalas: {agenda} — {pengirim}" tampil sejak langkah 1 dan
///   jenis surat TETAP dipilih pengguna (tidak di-auto);
/// - prefill langkah 2: perihal "Re: {subject}" + penerima = pengirim
///   (exact-match buku pihak → tawaran "Simpan ke buku pihak" tidak muncul);
/// - createDraft mengirim `in_reply_to {type: incoming_letter, id,
///   relation: balasan}` + bodyHtml paragraf pembuka di depan template;
/// - langkah 3 menyimpan body dengan paragraf pembuka DULU, lalu template;
/// - finalize sukses (mode balasan) → dialog menawarkan "Lihat runutan"
///   → detail surat keluar baru menggantikan wizard.

const _stType = LetterTypeModel(code: 'ST', name: 'Surat Tugas');

/// Fake IncomingService — dialog "Lihat runutan" membuka Detail Surat yang
/// memuat runutan secara eager; tanpa fake ini test memakai service asli
/// (HTTP nyata) dan spinner tak pernah selesai (pumpAndSettle timeout).
class _FakeIncomingService extends IncomingService {
  @override
  Future<ThreadModel> getThread(String rootType, String rootId) async =>
      ThreadModel(rootType: rootType, rootId: rootId);
}

final _replyLetter = IncomingLetterModel(
  id: 'il-1',
  agendaNumber: 'SM-017/X/2026',
  numberExternal: '017/PT-ABC/X/2026',
  senderParty: const PartyModel(id: 9, name: 'PT ABC Makmur'),
  letterDate: DateTime(2026, 10, 1),
  receivedAt: DateTime(2026, 10, 2),
  subject: 'Undangan rapat tahunan',
  sifat: 'biasa',
  classification: 'umum',
  status: 'terdaftar',
);

class _FakeReplyWizardService extends DocumentService {
  final List<PartyModel> parties;

  /// Simulasi jaringan gagal saat memuat template jenis surat.
  final bool failTemplates;

  _FakeReplyWizardService({this.parties = const [], this.failTemplates = false});

  /// ID detail yang diminta (membuktikan detail surat baru terbuka).
  final List<String> detailIds = [];

  Map<String, dynamic>? lastCreateInReplyTo;
  String? lastCreateSubject;
  String? lastCreateBodyHtml;
  Map<String, dynamic>? lastCreateMetadata;
  String? lastUpdateBodyHtml;

  @override
  Future<List<LetterTypeModel>> getLetterTypes() async => const [_stType];

  @override
  Future<List<TemplateModel>> getTemplates(String letterTypeCode) async {
    if (failTemplates) throw Exception('jaringan terputus');
    return const [
      TemplateModel(
        id: 7,
        name: 'Template ST Standar',
        letterTypeCode: 'ST',
        bodyHtml: '<p>Isi template</p>',
        isDefault: true,
      ),
    ];
  }

  @override
  Future<PaginatedResult<PartyModel>> getParties({
    String? query,
    int page = 1,
  }) async =>
      PaginatedResult(
        items: parties,
        currentPage: 1,
        lastPage: 1,
        total: parties.length,
        perPage: 15,
      );

  @override
  Future<DocumentModel> getDetail(String id) async {
    detailIds.add(id);
    return DocumentModel(
      id: id,
      status: 'draft',
      classification: 'umum',
      subject: 'draf',
    );
  }

  @override
  Future<List<SignerModel>> getMySigners() async => const [];

  @override
  Future<List<SignerModel>> getSigners() async => const [];

  @override
  Future<Map<String, dynamic>> reserveNumber(String id) async =>
      {'number': '021/ST/DIR/X/2026', 'seq': 21};

  @override
  Future<Map<String, dynamic>> preFinal(
    String id, {
    required String mode,
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
  }) async =>
      {'download_url': 'https://signed.example/preview'};

  @override
  Future<Map<String, dynamic>> finalize(
    String id, {
    required String method,
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
  }) async =>
      {'number': '021/ST/DIR/X/2026', 'verify_url': 'https://v.example/1'};

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
    Map<String, dynamic>? inReplyTo,
  }) async {
    lastCreateInReplyTo = inReplyTo;
    lastCreateSubject = subject;
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
    lastUpdateBodyHtml = bodyHtml;
    return DocumentModel(
      id: id,
      status: 'draft',
      classification: 'umum',
      subject: subject ?? 'draf',
    );
  }
}

Future<void> _pumpReplyWizard(
  WidgetTester tester,
  _FakeReplyWizardService service, {
  Future<Uint8List> Function(String url)? fetchUrl,
}) async {
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
      home: DocumentCreateWizard(
        service: service,
        replyTo: _replyLetter,
        fetchUrl: fetchUrl,
        incomingService: _FakeIncomingService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('banner "Membalas" tampil sejak langkah 1; jenis tetap '
      'dipilih pengguna (tidak auto-terpilih)', (tester) async {
    final service = _FakeReplyWizardService(parties: const [
      PartyModel(id: 9, name: 'PT ABC Makmur'),
    ]);
    await _pumpReplyWizard(tester, service);

    expect(find.text('Buat Surat'), findsOneWidget); // judul wizard.
    expect(
      find.text('Membalas: SM-017/X/2026 — PT ABC Makmur'),
      findsOneWidget,
      reason: 'banner chip mode balasan di header wizard',
    );
    // Jenis belum dipilih — Lanjut terblokir sampai user memilih (mode
    // balasan tidak meng-auto pilih jenis).
    expect(find.text('Pilih jenis surat dulu.'), findsOneWidget);
    final next = find.widgetWithText(FilledButton, 'Lanjut');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);

    await tester.tap(find.text('Surat Tugas'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  });

  testWidgets('prefill langkah 2: perihal "Re: …" + penerima = pengirim '
      '(exact-match buku pihak); createDraft mengirim in_reply_to + body '
      'paragraf pembuka di depan template', (tester) async {
    final service = _FakeReplyWizardService(parties: const [
      PartyModel(id: 9, name: 'PT ABC Makmur'),
    ]);
    await _pumpReplyWizard(tester, service);

    await tester.tap(find.text('Surat Tugas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Prefill perihal + penerima dari surat masuk.
    expect(find.widgetWithText(TextField, 'Re: Undangan rapat tahunan'),
        findsOneWidget);
    expect(find.widgetWithText(TextField, 'PT ABC Makmur'), findsOneWidget);
    // Penerima cocok buku pihak (exact-match resolve) → tawaran simpan
    // tidak ditawarkan.
    expect(find.text('Simpan ke buku pihak'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(service.lastCreateSubject, 'Re: Undangan rapat tahunan');
    expect(service.lastCreateInReplyTo, {
      'type': 'incoming_letter',
      'id': 'il-1',
      'relation': 'balasan',
    });
    expect(service.lastCreateMetadata!['recipient'], {'name': 'PT ABC Makmur'});
    // bodyHtml create = paragraf pembuka DULU + template.
    expect(service.lastCreateBodyHtml, contains('Menanggapi surat Saudara'));
    expect(service.lastCreateBodyHtml, contains('Isi template'));
    expect(
      service.lastCreateBodyHtml!.indexOf('Menanggapi surat Saudara') <
          service.lastCreateBodyHtml!.indexOf('Isi template'),
      isTrue,
      reason: 'paragraf pembuka menyisip di depan konten template',
    );

    // Langkah 3 → Lanjut menyimpan body editor (pembuka tetap di depan).
    await tester.pump(const Duration(seconds: 4)); // snackbar "Draf tersimpan."
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(service.lastUpdateBodyHtml, isNotNull);
    expect(service.lastUpdateBodyHtml, contains('Menanggapi surat Saudara'));
    expect(service.lastUpdateBodyHtml, contains('Isi template'));
    expect(
      service.lastUpdateBodyHtml!.indexOf('Menanggapi surat Saudara') <
          service.lastUpdateBodyHtml!.indexOf('Isi template'),
      isTrue,
    );
    // Wording paragraf pembuka lengkap: nomor eksternal dipakai (bukan
    // agenda), tanggal surat + perihal ikut.
    expect(
      service.lastUpdateBodyHtml,
      contains(
          'Menanggapi surat Saudara nomor 017/PT-ABC/X/2026 tanggal '
          '1 Oktober 2026, perihal Undangan rapat tahunan, dengan ini kami '
          'sampaikan hal-hal sebagai berikut:'),
    );
  });

  testWidgets('penerima prefill TIDAK cocok buku pihak → tawaran simpan ke '
      'buku pihak muncul (ketik-bebas state)', (tester) async {
    final service = _FakeReplyWizardService(parties: const [
      PartyModel(id: 3, name: 'PT Lain'),
    ]);
    await _pumpReplyWizard(tester, service);

    await tester.tap(find.text('Surat Tugas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'PT ABC Makmur'), findsOneWidget);
    expect(find.text('Simpan ke buku pihak'), findsOneWidget);
  });

  testWidgets('template gagal dimuat → paragraf pembuka balasan TETAP '
      'tersisip di editor (tidak hilang bersama template)', (tester) async {
    final service = _FakeReplyWizardService(
      parties: const [PartyModel(id: 9, name: 'PT ABC Makmur')],
      failTemplates: true,
    );
    await _pumpReplyWizard(tester, service);

    await tester.tap(find.text('Surat Tugas'));
    await tester.pumpAndSettle();
    // Snackbar error template muncul; alur tetap bisa lanjut.
    expect(find.textContaining('jaringan terputus'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // snackbar error hilang.
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    // Langkah 2: perihal & penerima tetap terprefill walau template gagal.
    expect(find.widgetWithText(TextField, 'Re: Undangan rapat tahunan'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4)); // snackbar formulir.
    await tester.pumpAndSettle();

    expect(service.lastCreateInReplyTo, {
      'type': 'incoming_letter',
      'id': 'il-1',
      'relation': 'balasan',
    });
    // Tanpa template, createDraft tidak mengirim body — paragraf pembuka
    // disimpan saat langkah editor (Lanjut) dari isi editor.
    expect(service.lastCreateBodyHtml, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(service.lastUpdateBodyHtml, isNotNull);
    expect(service.lastUpdateBodyHtml, contains('Menanggapi surat Saudara'));
  });

  testWidgets('finalize sukses mode balasan → dialog "Lihat runutan" membuka '
      'detail surat baru (menggantikan wizard)', (tester) async {
    final service = _FakeReplyWizardService(parties: const [
      PartyModel(id: 9, name: 'PT ABC Makmur'),
    ]);
    await _pumpReplyWizard(
      tester,
      service,
      fetchUrl: (_) async => Uint8List.fromList([1, 2, 3]),
    );

    // Langkah 1 → 2 (prefill sudah benar) → simpan formulir.
    await tester.tap(find.text('Surat Tugas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4)); // snackbar.
    await tester.pumpAndSettle();

    // Langkah 3 (editor) → 4 (lampiran) → 5 (penandatangan) → 6 (pratinjau).
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut ke pratinjau'));
    await tester.pumpAndSettle();
    expect(find.text('Langkah 6 dari 6 — Pratinjau & terbit'), findsOneWidget);

    // Pratinjau termuat via seam fetchUrl → Terbitkan aktif. Spinner
    // _finalizing terus berjalan selama dialog terbuka (await showDialog
    // sebelum finally) — pump manual, jangan pumpAndSettle.
    await tester.tap(find.text('Terbitkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Surat diterbitkan'), findsOneWidget);
    expect(find.text('Lihat runutan'), findsOneWidget,
        reason: 'mode balasan menawarkan buka runutan');

    await tester.tap(find.text('Lihat runutan'));
    await tester.pumpAndSettle();

    // Detail surat keluar baru menggantikan wizard di tumpukan.
    expect(find.text('Detail Surat'), findsOneWidget);
    expect(find.text('Runutan'), findsOneWidget); // tab tersedia.
    expect(find.text('Buat Surat'), findsNothing, reason: 'wizard tertutup');
    expect(service.detailIds, contains('draft-1'));
  });
}
