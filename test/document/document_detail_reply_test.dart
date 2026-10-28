import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_detail_page.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/services/document/incoming_models.dart';
import 'package:sagansa/services/document/incoming_service.dart';
import 'package:sagansa/widgets/documents/letter_thread_timeline.dart';

/// Kontrak UI detail surat keluar fase 1b (Task 11):
/// - chip "Membalas: {number_or_agenda}" di header bila `in_reply_to` ada;
///   tap → detail surat masuk induk;
/// - tab Runutan: LetterThreadTimeline via `getThread('document', id)` +
///   node saat ini disorot; tap node lain → detail terkait;
/// - guard simetris: tap node saat ini (document) = no-op;
/// - menu "Daftarkan surat masuk (balasan pihak luar)" (terbit) → form
///   mode balasan eksternal (prefill pengirim = penerima metadata);
/// - model: parse `in_reply_to` detail.

const _stType = LetterTypeModel(code: 'ST', name: 'Surat Tugas');

DocumentModel _terbitReplyDoc() => DocumentModel(
      id: 'doc-1',
      number: '020/ST/DIR/X/2026',
      status: 'terbit',
      classification: 'umum',
      subject: 'Surat tugas audit',
      date: DateTime(2026, 10, 20),
      letterType: _stType,
      unit: 'DIR',
      metadata: const {
        'recipient': {'name': 'PT Mitra Jaya'},
      },
      inReplyTo: const InReplyToRef(
        type: 'incoming_letter',
        id: 'il-1',
        numberOrAgenda: 'SM-017/X/2026',
        relation: 'balasan',
      ),
    );

const _thread = ThreadModel(
  rootType: 'document',
  rootId: 'doc-1',
  total: 3,
  nodes: [
    ThreadNodeModel(
      type: 'document',
      id: 'doc-1',
      number: '020/ST/DIR/X/2026',
      title: 'Surat tugas audit',
      partyName: 'PT Mitra Jaya',
      depth: 0,
    ),
    ThreadNodeModel(
      type: 'incoming_letter',
      id: 'il-9',
      number: 'SM-021/X/2026',
      partyName: 'PT Mitra Jaya',
      relationToParent: 'balasan',
      depth: 1,
    ),
    ThreadNodeModel(
      type: 'document',
      id: 'doc-2',
      number: '021/ST/DIR/X/2026',
      partyName: 'PT Mitra Jaya',
      relationToParent: 'tindak_lanjut',
      depth: 1,
    ),
  ],
);

class _FakeReplyDetailService extends DocumentService {
  _FakeReplyDetailService(this.detail);

  DocumentModel detail;

  /// ID detail yang diminta — membuktikan navigasi node → detail lain.
  final List<String> detailIds = [];

  @override
  Future<DocumentModel> getDetail(String id) async {
    detailIds.add(id);
    return detail;
  }

  @override
  Future<PaginatedResult<PartyModel>> getParties({
    String? query,
    int page = 1,
  }) async =>
      const PaginatedResult(
        items: [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
        perPage: 15,
      );
}

class _FakeThreadIncomingService extends IncomingService {
  int threadCalls = 0;
  final List<(String, String)> threadArgs = [];
  final List<String> incomingDetailIds = [];

  @override
  Future<ThreadModel> getThread(String type, String id) async {
    threadCalls++;
    threadArgs.add((type, id));
    return _thread;
  }

  @override
  Future<IncomingLetterModel> getIncomingDetail(String id) async {
    incomingDetailIds.add(id);
    return IncomingLetterModel(
      id: id,
      agendaNumber: 'SM-017/X/2026',
      senderParty: const PartyModel(id: 9, name: 'PT ABC Makmur'),
      receivedAt: DateTime(2026, 10, 2),
      subject: 'Undangan rapat tahunan',
      sifat: 'biasa',
      classification: 'umum',
      status: 'terdaftar',
    );
  }
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _FakeReplyDetailService service,
  required _FakeThreadIncomingService incoming,
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
      home: DocumentDetailPage(
        documentId: 'doc-1',
        service: service,
        incomingService: incoming,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('header: chip "Membalas: {agenda}" tampil bila in_reply_to '
      'ada; tap → detail surat masuk induk', (tester) async {
    final service = _FakeReplyDetailService(_terbitReplyDoc());
    final incoming = _FakeThreadIncomingService();
    await _pumpDetail(tester, service: service, incoming: incoming);

    expect(find.text('020/ST/DIR/X/2026'), findsOneWidget);
    expect(find.text('Membalas: SM-017/X/2026'), findsOneWidget);

    await tester.tap(find.text('Membalas: SM-017/X/2026'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Surat Masuk'), findsOneWidget);
    expect(incoming.incomingDetailIds, ['il-1']);
  });

  testWidgets('tab Runutan: timeline dimuat via getThread(document, id); '
      'node saat ini disorot; tap node keluar lain → detail keluar',
      (tester) async {
    final service = _FakeReplyDetailService(_terbitReplyDoc());
    final incoming = _FakeThreadIncomingService();
    await _pumpDetail(tester, service: service, incoming: incoming);

    expect(incoming.threadCalls, 0, reason: 'malas — termuat saat tab dibuka');

    await tester.tap(find.text('Runutan'));
    await tester.pumpAndSettle();

    expect(incoming.threadCalls, 1);
    expect(incoming.threadArgs.single, ('document', 'doc-1'));
    expect(find.byType(LetterThreadTimeline), findsOneWidget);
    expect(find.text('SM-021/X/2026'), findsOneWidget); // node masuk.
    expect(find.text('021/ST/DIR/X/2026'), findsOneWidget); // node keluar lain.
    expect(find.text('Surat ini'), findsOneWidget); // node saat ini disorot.
    expect(find.text('Menindaklanjuti'), findsOneWidget); // label relasi.

    // Tap node keluar lain (doc-2) → detail keluar doc-2.
    await tester.tap(find.text('021/ST/DIR/X/2026'));
    await tester.pumpAndSettle();
    expect(service.detailIds, containsAll(['doc-1', 'doc-2']));
  });

  testWidgets('guard simetris: tap node saat ini (document) = no-op — tanpa '
      'navigasi/muat ulang', (tester) async {
    final service = _FakeReplyDetailService(_terbitReplyDoc());
    final incoming = _FakeThreadIncomingService();
    await _pumpDetail(tester, service: service, incoming: incoming);

    await tester.tap(find.text('Runutan'));
    await tester.pumpAndSettle();
    final detailCallsBefore = service.detailIds.length;
    final threadCallsBefore = incoming.threadCalls;

    // Kartu node saat ini (nomor sama dengan header) — tap di dalam
    // timeline, bukan chip header.
    await tester.tap(find.descendant(
      of: find.byType(LetterThreadTimeline),
      matching: find.text('020/ST/DIR/X/2026'),
    ));
    await tester.pumpAndSettle();

    expect(service.detailIds.length, detailCallsBefore,
        reason: 'tidak ada detail lain dimuat');
    expect(incoming.threadCalls, threadCallsBefore);
    expect(find.text('Detail Surat Masuk'), findsNothing);
  });

  testWidgets('menu terbit: "Daftarkan surat masuk (balasan pihak luar)" → '
      'form mode balasan dengan prefill pengirim dari metadata penerima',
      (tester) async {
    final service = _FakeReplyDetailService(_terbitReplyDoc());
    final incoming = _FakeThreadIncomingService();
    await _pumpDetail(tester, service: service, incoming: incoming);

    await tester.tap(find.byTooltip('Aksi Surat'));
    await tester.pumpAndSettle();
    expect(
        find.text('Daftarkan surat masuk (balasan pihak luar)'), findsOneWidget);

    await tester.tap(find.text('Daftarkan surat masuk (balasan pihak luar)'));
    await tester.pumpAndSettle();

    // Form registrasi mode balasan eksternal (Task 9): banner induk +
    // pengirim terprefill penerima surat keluar.
    expect(find.text('Daftar Surat Masuk'), findsOneWidget);
    expect(
      find.textContaining('Mendaftarkan balasan atas surat keluar'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'PT Mitra Jaya'), findsOneWidget);
  });

  test('DocumentModel memparse in_reply_to detail; tanpa key → null; label '
      'relasi ramah', () {
    const json = {
      'id': 'd1',
      'status': 'draft',
      'classification': 'umum',
      'subject': 'Draf balasan',
      'in_reply_to': {
        'type': 'incoming_letter',
        'id': 'il-1',
        'number_or_agenda': 'SM-017/X/2026',
        'relation': 'balasan',
      },
    };
    final doc = DocumentModel.fromJson(json);
    expect(doc.inReplyTo, isNotNull);
    expect(doc.inReplyTo!.type, 'incoming_letter');
    expect(doc.inReplyTo!.id, 'il-1');
    expect(doc.inReplyTo!.numberOrAgenda, 'SM-017/X/2026');
    expect(doc.inReplyTo!.relation, 'balasan');
    expect(doc.inReplyTo!.relationLabel, 'Membalas');
    expect(doc.inReplyTo!.isIncomingLetter, isTrue);

    const plain = {
      'id': 'd2',
      'status': 'draft',
      'classification': 'umum',
      'subject': 'Tanpa induk',
    };
    expect(DocumentModel.fromJson(plain).inReplyTo, isNull);

    const tindakLanjut = {
      'id': 'd3',
      'status': 'draft',
      'classification': 'umum',
      'subject': 'Tindak lanjut',
      'in_reply_to': {
        'type': 'document',
        'id': 'd0',
        'number_or_agenda': null,
        'relation': 'tindak_lanjut',
      },
    };
    final ref = DocumentModel.fromJson(tindakLanjut).inReplyTo!;
    expect(ref.relationLabel, 'Menindaklanjuti');
    expect(ref.numberOrAgenda, isNull);
  });
}
