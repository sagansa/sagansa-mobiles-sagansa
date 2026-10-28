import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_upload_page.dart'
    show PickedPdf, PickedPhoto;
import 'package:sagansa/pages/documents/incoming/incoming_form_page.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/services/document/incoming_models.dart';
import 'package:sagansa/services/document/incoming_service.dart';

/// Kontrak UI `IncomingFormPage` (Task 9 fase 1b):
/// - happy path ketik bebas: createParty → createIncoming membawa field
///   benar (tanggal format `yyyy-MM-dd` via buildCreateFields, sifat
///   rahasia, foto scan `scan_images[]` dengan nama berkas ekstensi .jpg
///   sesuai hasil kompresi) → dialog agenda number;
/// - tanpa scan: tombol daftar dinonaktifkan + pesan scan wajib;
/// - mode replyToDocument: banner induk + pengirim resolve buku pihak +
///   scan PDF (scanFileName .pdf) + `in_reply_to` terkirim;
/// - pengirim pilih dari buku pihak: party_id terpakai TANPA createParty.

class _FakeIncomingService extends IncomingService {
  int createCalls = 0;
  int? lastSenderPartyId;
  String? lastNumberExternal;
  DateTime? lastLetterDate;
  DateTime? lastReceivedAt;
  String? lastSubject;
  String? lastSifat;
  String? lastAttachmentsNote;
  List<int>? lastScanBytes;
  String? lastScanFileName;
  List<IncomingScanImage>? lastScanImages;
  String? lastInReplyToType;
  String? lastInReplyToId;
  String? lastInReplyToRelation;

  @override
  Future<IncomingLetterModel> createIncoming({
    required int senderPartyId,
    String? numberExternal,
    DateTime? letterDate,
    required DateTime receivedAt,
    required String subject,
    required String sifat,
    String? attachmentsNote,
    String? companyId,
    List<int>? scanBytes,
    String? scanFileName,
    List<IncomingScanImage>? scanImages,
    String? inReplyToType,
    String? inReplyToId,
    String? inReplyToRelation,
  }) async {
    createCalls++;
    lastSenderPartyId = senderPartyId;
    lastNumberExternal = numberExternal;
    lastLetterDate = letterDate;
    lastReceivedAt = receivedAt;
    lastSubject = subject;
    lastSifat = sifat;
    lastAttachmentsNote = attachmentsNote;
    lastScanBytes = scanBytes;
    lastScanFileName = scanFileName;
    lastScanImages = scanImages;
    lastInReplyToType = inReplyToType;
    lastInReplyToId = inReplyToId;
    lastInReplyToRelation = inReplyToRelation;
    return IncomingLetterModel(
      id: 'il-1',
      agendaNumber: 'SM-001/X/2026',
      subject: subject,
      sifat: sifat,
      classification: sifat == 'rahasia' ? 'rahasia' : 'umum',
      status: 'terdaftar',
    );
  }
}

class _FakeDocumentService extends DocumentService {
  _FakeDocumentService({this.parties = const []});

  final List<PartyModel> parties;
  int createPartyCalls = 0;
  String? lastCreatedPartyName;

  @override
  Future<PaginatedResult<PartyModel>> getParties({
    String? query,
    int page = 1,
  }) async {
    // Cari persis pola buku pihak (LIKE); test memakai hasil penuh agar
    // tak tergantung timing debounce sheet.
    final q = (query ?? '').toLowerCase();
    final items = q.isEmpty
        ? parties
        : parties
            .where((party) => party.name.toLowerCase().contains(q))
            .toList(growable: false);
    return PaginatedResult(
      items: items,
      currentPage: 1,
      lastPage: 1,
      total: items.length,
      perPage: 15,
    );
  }

  @override
  Future<PartyModel> createParty({
    required String name,
    String? identityNo,
    String? address,
    String? occupation,
    String? notes,
  }) async {
    createPartyCalls++;
    lastCreatedPartyName = name;
    return PartyModel(id: 42, name: name);
  }
}

const _twoPhotos = <PickedPhoto>[
  PickedPhoto(path: '/tmp/foto-1.jpg', name: 'foto-1.jpg'),
  PickedPhoto(path: '/tmp/foto-2.png', name: 'foto-2.png'),
];

final _pdfBytes =
    Uint8List.fromList('%PDF-1.4 balasan eksternal'.codeUnits);

/// Bytes kompresi dummy — test hanya membuktikan bytes hasil kompresi
/// (bukan bytes asli file) yang dikirim ke service.
Uint8List _compressedBytes() => Uint8List.fromList(List<int>.filled(16, 7));

/// Launcher berbasis tombol agar `Navigator.pop` dari dialog sukses tidak
/// mem-pop route terakhir aplikasi test.
class _LauncherPage extends StatelessWidget {
  final IncomingFormPage Function() buildPage;

  const _LauncherPage({required this.buildPage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => buildPage()),
          ),
          child: const Text('Buka form'),
        ),
      ),
    );
  }
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required _FakeIncomingService incoming,
  required _FakeDocumentService documents,
  ReplyToDocument? replyTo,
  Future<List<PickedPhoto>> Function()? pickImages,
  Future<PickedPdf?> Function()? pickPdf,
  Future<Uint8List?> Function(String path)? compressImage,
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
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      locale: const Locale('id'),
      home: _LauncherPage(
        buildPage: () => IncomingFormPage(
          service: incoming,
          documentService: documents,
          replyToDocument: replyTo,
          pickImages: pickImages,
          pickPdf: pickPdf,
          compressImage: compressImage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buka form'));
  await tester.pumpAndSettle();
}

/// Gulir form sampai [target] terlihat — bagian bawah (scan) di bawah lipat
/// viewport ponsel.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byType(Scrollable).first,
    const Offset(0, -250),
    maxIteration: 12,
  );
  await tester.pumpAndSettle();
}

Future<void> _fillMinimum(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'Perihal *').first,
      'Undangan rapat tahunan');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('happy path ketik bebas: createParty + foto scan + sifat '
      'rahasia → payload benar + dialog agenda', (tester) async {
    final incoming = _FakeIncomingService();
    final documents = _FakeDocumentService(parties: const [
      PartyModel(id: 7, name: 'PT Lain'),
    ]);

    await _pumpForm(
      tester,
      incoming: incoming,
      documents: documents,
      pickImages: () async => _twoPhotos,
      compressImage: (path) async => _compressedBytes(),
    );

    // Ketik bebas pengirim + nomor eksternal + perihal + sifat rahasia.
    await tester.enterText(
        find.widgetWithText(TextField, 'Nama pengirim *'), 'CV Sinar Jaya');
    await tester.enterText(find.widgetWithText(
        TextField, 'Nomor surat pengirim (opsional)'), '123/EXT/2026');
    await _fillMinimum(tester);
    await tester.tap(find.text('Rahasia'));
    await tester.pumpAndSettle();

    // Tanpa scan: tombol dinonaktifkan (dicek sekalian di sini).
    final submit = find.widgetWithText(FilledButton, 'Daftarkan Surat Masuk');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await _scrollTo(tester, find.text('Pilih PDF'));
    expect(find.textContaining('Scan wajib'), findsOneWidget);

    // Ambil 2 foto scan → thumbnail + estimasi halaman tampil.
    await tester.tap(find.text('Foto/Scan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Perkiraan 2 halaman'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    // Nama bebas → createParty dipakai, party_id hasilnya terkirim.
    expect(documents.createPartyCalls, 1);
    expect(documents.lastCreatedPartyName, 'CV Sinar Jaya');
    expect(incoming.createCalls, 1);
    expect(incoming.lastSenderPartyId, 42);
    expect(incoming.lastNumberExternal, '123/EXT/2026');
    expect(incoming.lastSubject, 'Undangan rapat tahunan');
    expect(incoming.lastSifat, 'rahasia');
    expect(incoming.lastLetterDate, isNull);
    expect(incoming.lastAttachmentsNote, isNull);
    expect(incoming.lastInReplyToId, isNull);

    // Scan bentuk foto: scan_images[] 2 foto, nama berkas ekstensi sesuai
    // hasil kompresi JPEG (OPNOTE Task 7), tanpa scanBytes.
    expect(incoming.lastScanBytes, isNull);
    expect(incoming.lastScanFileName, isNull);
    expect(incoming.lastScanImages?.length, 2);
    expect(incoming.lastScanImages?[0].fileName, 'halaman-1.jpg');
    expect(incoming.lastScanImages?[1].fileName, 'halaman-2.jpg');

    // Tanggal diterima default hari ini & format wire `yyyy-MM-dd`
    // (via builder fields yang dipakai createIncoming).
    final now = DateTime.now();
    expect(incoming.lastReceivedAt?.year, now.year);
    expect(incoming.lastReceivedAt?.month, now.month);
    expect(incoming.lastReceivedAt?.day, now.day);
    final fields = IncomingService.buildCreateFields(
      senderPartyId: incoming.lastSenderPartyId!,
      numberExternal: incoming.lastNumberExternal,
      letterDate: incoming.lastLetterDate,
      receivedAt: incoming.lastReceivedAt!,
      subject: incoming.lastSubject!,
      sifat: incoming.lastSifat!,
      attachmentsNote: incoming.lastAttachmentsNote,
    );
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    expect(fields['received_at'], '${now.year}-$mm-$dd');
    expect(fields['letter_date'], isNull); // opsional: tak diisi → tak dikirim.
    expect(fields['sender_party_id'], '42');
    expect(fields['sifat'], 'rahasia');

    // Dialog sukses menampilkan agenda number; Selesai menutup form.
    expect(find.text('Surat masuk terdaftar'), findsOneWidget);
    expect(find.textContaining('SM-001/X/2026'), findsOneWidget);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Buka form'), findsOneWidget); // kembali ke launcher.
  });

  testWidgets('mode replyToDocument: banner induk + pengirim resolve buku '
      'pihak + scan PDF scanFileName .pdf + in_reply_to terkirim',
      (tester) async {
    final incoming = _FakeIncomingService();
    final documents = _FakeDocumentService(parties: const [
      PartyModel(id: 7, name: 'PT Penerima Surat'),
      PartyModel(id: 8, name: 'PT Lain'),
    ]);

    await _pumpForm(
      tester,
      incoming: incoming,
      documents: documents,
      replyTo: const ReplyToDocument(
        id: 'doc-parent-1',
        partyName: 'PT Penerima Surat',
        subject: 'Undangan pengiriman proposal',
        number: '010/ST/DIR/X/2026',
      ),
      pickPdf: () async => PickedPdf(name: 'balasan.pdf', bytes: _pdfBytes),
    );

    // Banner mode balasan + pengirim ter-prefill nama penerima surat
    // keluar, lalu resolve exact match ke buku pihak (tanpa createParty).
    expect(find.textContaining('Mendaftarkan balasan atas surat keluar'),
        findsOneWidget);
    expect(find.textContaining('010/ST/DIR/X/2026'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'PT Penerima Surat'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('Terpilih dari buku pihak'), findsOneWidget);

    await _fillMinimum(tester);

    // Scan bentuk PDF → tile nama+ukuran, scanFileName berekstensi .pdf.
    await _scrollTo(tester, find.text('Pilih PDF'));
    await tester.tap(find.text('Pilih PDF'));
    await tester.pumpAndSettle();
    expect(find.text('balasan.pdf'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Daftarkan Surat Masuk'));
    await tester.pumpAndSettle();

    expect(incoming.createCalls, 1);
    expect(documents.createPartyCalls, 0); // resolve buku pihak menang.
    expect(incoming.lastSenderPartyId, 7);
    expect(incoming.lastScanBytes, _pdfBytes);
    expect(incoming.lastScanFileName, 'balasan.pdf');
    expect(incoming.lastScanFileName!.endsWith('.pdf'), isTrue);
    expect(incoming.lastScanImages, isNull);
    expect(incoming.lastInReplyToType, 'document');
    expect(incoming.lastInReplyToId, 'doc-parent-1');
    expect(incoming.lastInReplyToRelation, 'balasan');

    // Bentuk wire in_reply_to (PHP nested field via kurung siku).
    final fields = IncomingService.buildCreateFields(
      senderPartyId: incoming.lastSenderPartyId!,
      receivedAt: incoming.lastReceivedAt!,
      subject: incoming.lastSubject!,
      sifat: incoming.lastSifat!,
      inReplyToType: incoming.lastInReplyToType,
      inReplyToId: incoming.lastInReplyToId,
      inReplyToRelation: incoming.lastInReplyToRelation,
    );
    expect(fields['in_reply_to[type]'], 'document');
    expect(fields['in_reply_to[id]'], 'doc-parent-1');
    expect(fields['in_reply_to[relation]'], 'balasan');

    // Jalan pintas detail → placeholder Task 10.
    await tester.tap(find.text('Lihat detail'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Surat Masuk'), findsOneWidget);
    expect(find.textContaining('Tugas 10'), findsOneWidget);
  });

  testWidgets('pengirim dipilih dari buku pihak: party_id terpakai tanpa '
      'createParty', (tester) async {
    final incoming = _FakeIncomingService();
    final documents = _FakeDocumentService(parties: const [
      PartyModel(id: 7, name: 'PT Buku Pihak', identityNo: '3201000102'),
      PartyModel(id: 8, name: 'Kantor Notaris'),
    ]);

    await _pumpForm(
      tester,
      incoming: incoming,
      documents: documents,
      pickImages: () async => _twoPhotos.sublist(0, 1),
      compressImage: (path) async => _compressedBytes(),
    );

    // Buka sheet buku pihak → hasil pencarian awal tampil → pilih.
    await tester.tap(find.text('Buku pihak'));
    await tester.pumpAndSettle();
    expect(find.text('PT Buku Pihak'), findsOneWidget);
    await tester.tap(find.text('PT Buku Pihak'));
    await tester.pumpAndSettle();

    // Pilihan tampil di field + helper "terpilih".
    expect(find.widgetWithText(TextField, 'PT Buku Pihak'), findsOneWidget);
    expect(find.textContaining('Terpilih dari buku pihak (#7)'),
        findsOneWidget);

    await _fillMinimum(tester);
    await _scrollTo(tester, find.text('Foto/Scan'));
    await tester.tap(find.text('Foto/Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Daftarkan Surat Masuk'));
    await tester.pumpAndSettle();

    expect(documents.createPartyCalls, 0);
    expect(incoming.lastSenderPartyId, 7);
    expect(incoming.lastScanImages?.length, 1);
    expect(incoming.lastScanImages?[0].fileName, 'halaman-1.jpg');
  });
}
