import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/incoming/incoming_detail_page.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/services/document/incoming_models.dart';
import 'package:sagansa/services/document/incoming_service.dart';
import 'package:sagansa/widgets/documents/letter_thread_timeline.dart';

/// Kontrak UI `IncomingDetailPage` (Task 10 fase 1b):
/// - header agenda besar + badge sifat/status; tab Info merender pengirim,
///   nomor eksternal, tanggal, perihal, klasifikasi, integritas scan;
/// - tab Disposisi: daftar kepada/instruksi/status, tombol Selesaikan
///   (konfirmasi ringan → completeDisposition + refresh);
/// - disposisi terakhir selesai → dialog tawaran menandai surat selesai;
/// - tambah disposisi: sheet dropdown signer aktif + instruksi wajib →
///   addDisposition dengan argumen benar;
/// - menu aksi: Tandai Diproses/Selesai sesuai status, Balas → wizard
///   surat keluar mode balasan asli (Task 11), Ubah nonaktif;
/// - tab Scan memuat bytes → viewer via seam pdfPreviewBuilder.

const _signers = [
  SignerModel(id: 3, role: 'direktur', displayName: 'Ari Direktur'),
  SignerModel(id: 5, role: 'komisaris', displayName: 'Budi Komisaris'),
];

DispositionModel _disposition(
  String id,
  String label,
  String instruction,
  String status, {
  DateTime? actedAt,
}) =>
    DispositionModel(
      id: id,
      toUserId: 5,
      toUserLabel: label,
      instruction: instruction,
      status: status,
      actedAt: actedAt,
      createdAt: DateTime(2026, 10, 2),
    );

IncomingLetterModel _letter({String status = 'diproses'}) => IncomingLetterModel(
      id: 'il-1',
      agendaNumber: 'SM-017/X/2026',
      numberExternal: '017/PT-ABC/X/2026',
      senderParty: const PartyModel(
          id: 9, name: 'PT ABC Makmur', address: 'Jl. Merdeka 12, Bandung'),
      letterDate: DateTime(2026, 10, 1),
      receivedAt: DateTime(2026, 10, 2),
      subject: 'Undangan rapat tahunan',
      sifat: 'segera',
      classification: 'umum',
      status: status,
      scanSha256: 'a1b2c3d4e5f6a7b8c9d0',
      scanSize: 348000,
      scanPages: 3,
      attachmentsNote: '2 berkas proposal',
      dispositions: [
        _disposition('d1', 'Pengguna #3', 'Siapkan ruang rapat', 'selesai',
            actedAt: DateTime(2026, 10, 3)),
        _disposition('d2', 'Pengguna #5', 'Susun draf tanggapan', 'open'),
      ],
      thread: const ThreadModel(
        rootType: 'document',
        rootId: 'doc-1',
        total: 2,
        nodes: [
          ThreadNodeModel(
            type: 'document',
            id: 'doc-1',
            number: '010/ST/DIR/X/2026',
            partyName: 'PT ABC Makmur',
            depth: 0,
          ),
          ThreadNodeModel(
            type: 'incoming_letter',
            id: 'il-1',
            number: 'SM-017/X/2026',
            partyName: 'PT ABC Makmur',
            relationToParent: 'balasan',
            depth: 1,
          ),
        ],
      ),
    );

/// Fake yang MENIRU efek samping backend: complete/add/status memutasi
/// detail sehingga refresh berikutnya mengembalikan state terkini.
class _FakeIncomingService extends IncomingService {
  _FakeIncomingService(this.detail);

  IncomingLetterModel detail;
  int detailCalls = 0;
  final List<({String incomingId, int toUserId, String instruction})>
      addCalls = [];
  final List<String> completeCalls = [];
  final List<({String id, String status})> statusCalls = [];
  int scanBytesCalls = 0;

  @override
  Future<IncomingLetterModel> getIncomingDetail(String id) async {
    detailCalls++;
    return detail;
  }

  @override
  Future<DispositionModel> addDisposition(
    String incomingId, {
    required int toUserId,
    required String instruction,
  }) async {
    addCalls.add(
        (incomingId: incomingId, toUserId: toUserId, instruction: instruction));
    final created = _disposition(
        'd-new', 'Pengguna #$toUserId', instruction, 'open');
    detail = _withDispositions(detail, [...detail.dispositions, created]);
    return created;
  }

  @override
  Future<DispositionModel> completeDisposition(String id) async {
    completeCalls.add(id);
    var updated = const DispositionModel(
        id: '', toUserId: 0, toUserLabel: '', instruction: '', status: '');
    for (final d in detail.dispositions) {
      if (d.id == id) {
        updated = DispositionModel(
          id: d.id,
          toUserId: d.toUserId,
          toUserLabel: d.toUserLabel,
          instruction: d.instruction,
          status: 'selesai',
          actedAt: DateTime(2026, 10, 5),
          createdAt: d.createdAt,
        );
      }
    }
    detail = _withDispositions(detail, [
      for (final d in detail.dispositions)
        d.id == id ? updated : d,
    ]);
    return updated;
  }

  @override
  Future<IncomingLetterModel> markIncomingStatus(String id, String status) async {
    statusCalls.add((id: id, status: status));
    detail = _withStatus(detail, status);
    return detail;
  }

  @override
  Future<List<int>> getIncomingScanBytes(String id) async {
    scanBytesCalls++;
    return '%PDF-1.4 scan'.codeUnits;
  }

  static IncomingLetterModel _withDispositions(
    IncomingLetterModel letter,
    List<DispositionModel> dispositions,
  ) =>
      IncomingLetterModel(
        id: letter.id,
        agendaNumber: letter.agendaNumber,
        numberExternal: letter.numberExternal,
        senderParty: letter.senderParty,
        letterDate: letter.letterDate,
        receivedAt: letter.receivedAt,
        subject: letter.subject,
        sifat: letter.sifat,
        classification: letter.classification,
        status: letter.status,
        scanSha256: letter.scanSha256,
        scanSize: letter.scanSize,
        scanPages: letter.scanPages,
        attachmentsNote: letter.attachmentsNote,
        dispositions: dispositions,
        thread: letter.thread,
      );

  static IncomingLetterModel _withStatus(
          IncomingLetterModel letter, String status) =>
      _withDispositions(letter, letter.dispositions).copyWithStatus(status);
}

class _FakeDocumentService extends DocumentService {
  @override
  Future<List<SignerModel>> getSigners() async => _signers;

  // Wizard balasan (Task 11) terbuka dari menu "Balas surat ini" —
  // kebutuhan load jenis/template/buku pihak dipasok fake (tanpa HTTP).
  @override
  Future<List<LetterTypeModel>> getLetterTypes() async => const [];

  @override
  Future<List<TemplateModel>> getTemplates(String letterTypeCode) async =>
      const [];

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

extension on IncomingLetterModel {
  /// Helper test kecil — hanya status yang berubah.
  IncomingLetterModel copyWithStatus(String status) => IncomingLetterModel(
        id: id,
        agendaNumber: agendaNumber,
        numberExternal: numberExternal,
        senderParty: senderParty,
        letterDate: letterDate,
        receivedAt: receivedAt,
        subject: subject,
        sifat: sifat,
        classification: classification,
        status: status,
        scanSha256: scanSha256,
        scanSize: scanSize,
        scanPages: scanPages,
        attachmentsNote: attachmentsNote,
        dispositions: dispositions,
        thread: thread,
      );
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _FakeIncomingService service,
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
      home: IncomingDetailPage(
        letterId: 'il-1',
        service: service,
        documentService: _FakeDocumentService(),
        pdfPreviewBuilder: (_, bytes) => const Text('PDF-PREVIEW'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('header agenda + badge sifat/status; tab Info merender '
      'pengirim, nomor, tanggal, integritas scan', (tester) async {
    final service = _FakeIncomingService(_letter());
    await _pumpDetail(tester, service: service);

    expect(find.text('Detail Surat Masuk'), findsOneWidget);
    expect(find.text('SM-017/X/2026'), findsOneWidget); // header besar.
    expect(find.text('Segera'), findsOneWidget); // badge sifat.
    expect(find.text('Diproses'), findsOneWidget); // badge status.
    expect(find.text('Undangan rapat tahunan'), findsOneWidget);

    // Section pengirim & tanggal (dalam lipatan — scroll tab Info).
    await tester.scrollUntilVisible(find.text('PT ABC Makmur'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('PT ABC Makmur'), findsOneWidget);
    expect(find.text('Jl. Merdeka 12, Bandung'), findsOneWidget);
    expect(find.text('017/PT-ABC/X/2026'), findsOneWidget);
    expect(find.text('1 Okt 2026'), findsWidgets); // tanggal surat.
    expect(find.text('Umum'), findsOneWidget); // klasifikasi.
    expect(find.text('2 berkas proposal'), findsOneWidget);
    expect(find.textContaining('SHA-256 a1b2c3d4…'), findsOneWidget);
    expect(find.textContaining('3 halaman'), findsOneWidget);
  });

  testWidgets('tab Disposisi: daftar kepada/instruksi/status; tombol '
      'Selesaikan → konfirmasi → completeDisposition + refresh', (tester) async {
    final service = _FakeIncomingService(_letter());
    await _pumpDetail(tester, service: service);

    await tester.tap(find.text('Disposisi'));
    await tester.pumpAndSettle();

    expect(find.text('Pengguna #3'), findsOneWidget);
    expect(find.text('Pengguna #5'), findsOneWidget);
    expect(find.text('Siapkan ruang rapat'), findsOneWidget);
    expect(find.text('Susun draf tanggapan'), findsOneWidget);
    // d1 selesai (badge Selesai + tanggal selesai), d2 terbuka.
    expect(find.text('Terbuka'), findsOneWidget);
    expect(find.textContaining('Diselesaikan 5 Okt 2026'), findsNothing);
    // Tombol selesaikan hanya untuk item terbuka (satu).
    expect(find.text('Selesaikan'), findsOneWidget);

    await tester.tap(find.text('Selesaikan'));
    await tester.pumpAndSettle();

    // Konfirmasi ringan.
    expect(find.text('Selesaikan disposisi?'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Selesaikan')));
    await tester.pumpAndSettle();

    expect(service.completeCalls, ['d2']);
    expect(service.detailCalls, greaterThanOrEqualTo(2)); // refresh.

    // d2 adalah disposisi terbuka TERAKHIR → dialog tawaran tandai selesai.
    expect(find.text('Semua disposisi selesai'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Tandai Selesai')));
    await tester.pumpAndSettle();

    expect(service.statusCalls.length, 1);
    expect(service.statusCalls.single.id, 'il-1');
    expect(service.statusCalls.single.status, 'selesai');
    // Header mengikuti status baru (badge header + 2 badge disposisi selesai).
    expect(find.text('Selesai'), findsWidgets);
    expect(find.text('Tambah Disposisi'), findsNothing); // selesai dibekukan.
  });

  testWidgets('selesaikan disposisi terakhir tapi tolak tawaran status → '
      'surat tetap diproses', (tester) async {
    final service = _FakeIncomingService(_letter());
    await _pumpDetail(tester, service: service);
    await tester.tap(find.text('Disposisi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selesaikan'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Selesaikan')));
    await tester.pumpAndSettle();
    expect(find.text('Semua disposisi selesai'), findsOneWidget);

    await tester.tap(find.text('Nanti'));
    await tester.pumpAndSettle();

    expect(service.statusCalls, isEmpty);
    expect(find.text('Diproses'), findsOneWidget);
  });

  testWidgets('tambah disposisi: validasi kosong → pilih signer + instruksi '
      '→ addDisposition dengan argumen benar + refresh', (tester) async {
    final service = _FakeIncomingService(_letter());
    await _pumpDetail(tester, service: service);
    await tester.tap(find.text('Disposisi'));
    await tester.pumpAndSettle();
    final detailCallsBefore = service.detailCalls;

    await tester.tap(find.text('Tambah Disposisi'));
    await tester.pumpAndSettle();

    // Signer aktif termuat di dropdown.
    expect(find.text('Penerima disposisi'), findsOneWidget);
    expect(find.text('Instruksi disposisi'), findsOneWidget);

    // Validasi: submit tanpa isi sama sekali → tetap di sheet.
    await tester.tap(find.text('Kirim Disposisi'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih penerima disposisi.'), findsOneWidget);
    expect(service.addCalls, isEmpty);

    // Pilih signer dari dropdown.
    await tester.tap(find.byType(DropdownButton<SignerModel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budi Komisaris (Komisaris)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Instruksi disposisi'),
        'Siapkan materi presentasi');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim Disposisi'));
    await tester.pumpAndSettle();

    expect(service.addCalls.length, 1);
    expect(service.addCalls.single.incomingId, 'il-1');
    expect(service.addCalls.single.toUserId, 5);
    expect(service.addCalls.single.instruction, 'Siapkan materi presentasi');
    expect(find.text('Disposisi ditambahkan.'), findsOneWidget);
    expect(service.detailCalls, detailCallsBefore + 1); // refresh setelah add.
  });

  testWidgets('tab Runutan: timeline embed dengan node saat ini disorot',
      (tester) async {
    final service = _FakeIncomingService(_letter());
    await _pumpDetail(tester, service: service);

    // TabBar scrollable — tab terakhir di luar viewport; gulir dulu.
    await tester.ensureVisible(find.text('Runutan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Runutan'));
    await tester.pumpAndSettle();

    expect(find.byType(LetterThreadTimeline), findsOneWidget);
    expect(find.text('010/ST/DIR/X/2026'), findsOneWidget);
    // Agenda muncul 2x: header besar + kartu node timeline.
    expect(find.text('SM-017/X/2026'), findsNWidgets(2));
    expect(find.text('Membalas'), findsOneWidget);
    expect(find.text('Surat ini'), findsOneWidget);
  });

  testWidgets('tab Scan: muat bytes → viewer via seam; meta tidak dimuat '
      'ulang tanpa aksi', (tester) async {
    final service = _FakeIncomingService(_letter());
    await _pumpDetail(tester, service: service);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Berkas scan surat'), findsOneWidget);
    expect(service.scanBytesCalls, 0); // malas — hanya saat diminta.

    await tester.tap(find.text('Muat scan'));
    await tester.pumpAndSettle();

    expect(service.scanBytesCalls, 1);
    expect(find.text('PDF-PREVIEW'), findsOneWidget);
  });

  testWidgets('menu aksi surat terdaftar: Balas → wizard balasan asli '
      '(Task 11), Ubah nonaktif, Tandai Diproses → markIncomingStatus',
      (tester) async {
    final service = _FakeIncomingService(_letter(status: 'terdaftar'));
    await _pumpDetail(tester, service: service);

    await tester.tap(find.byTooltip('Aksi Surat Masuk'));
    await tester.pumpAndSettle();

    // Menu ⋮ kini bottom sheet aksi (bukan PopupMenu). "Ubah" tetap
    // tampil (nonaktif — penyuntingan menyusul); ketuk tidak menutup
    // sheet maupun menavigasi.
    expect(find.text('Ubah (penyuntingan menyusul)'), findsOneWidget);
    expect(find.text('Tandai Diproses'), findsOneWidget);

    await tester.tap(find.text('Tandai Diproses'));
    await tester.pumpAndSettle();
    expect(service.statusCalls.single.status, 'diproses');
    expect(service.statusCalls.single.id, 'il-1');
    expect(find.text('Surat ditandai Diproses.'), findsOneWidget);

    // Balas surat ini → wizard surat keluar mode balasan (Task 11):
    // banner Membalas + pulang me-refresh detail.
    final detailCallsBefore = service.detailCalls;
    await tester.tap(find.byTooltip('Aksi Surat Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balas surat ini'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Surat'), findsOneWidget);
    expect(find.text('Membalas: SM-017/X/2026 — PT ABC Makmur'), findsOneWidget);

    // Kembali dari wizard → detail dimuat ulang (runutan bisa bertambah).
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Surat Masuk'), findsOneWidget);
    expect(service.detailCalls, greaterThan(detailCallsBefore));
  });

  testWidgets('surat selesai: tanpa aksi status & tanpa tombol tambah '
      'disposisi', (tester) async {
    final service = _FakeIncomingService(_letter(status: 'selesai'));
    await _pumpDetail(tester, service: service);
    await tester.tap(find.text('Disposisi'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Disposisi'), findsNothing);

    await tester.tap(find.byTooltip('Aksi Surat Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Tandai Diproses'), findsNothing);
    expect(find.text('Tandai Selesai'), findsNothing);
  });

  testWidgets('gagal memuat detail → pesan + coba lagi memuat ulang',
      (tester) async {
    final service = _FakeIncomingService(_letter());
    var fail = true;
    final failing = _FlakyIncomingService(service.detail, () => fail);
    await _pumpDetail(tester, service: failing);

    expect(find.textContaining('Gagal memuat detail surat masuk'),
        findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(find.text('SM-017/X/2026'), findsOneWidget);
  });
}

/// Wrapper yang mendelegasikan ke fake dasar dengan kegagalan opsional —
/// memakai tipe fake sendiri agar `getIncomingDetail` bisa flaky.
class _FlakyIncomingService extends _FakeIncomingService {
  _FlakyIncomingService(super.detail, this.isFailing);

  final bool Function() isFailing;

  @override
  Future<IncomingLetterModel> getIncomingDetail(String id) async {
    if (isFailing()) throw Exception('Gagal memuat detail surat masuk.');
    return super.getIncomingDetail(id);
  }
}
