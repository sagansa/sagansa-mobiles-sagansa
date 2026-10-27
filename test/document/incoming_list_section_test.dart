import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_list_page.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/services/document/incoming_models.dart';
import 'package:sagansa/services/document/incoming_service.dart';
import 'package:sagansa/widgets/status_badge.dart';

/// Kontrak UI tab "Masuk" pada `DocumentListPage` (fase 1b):
/// - segmented control Keluar|Masuk; state tiap tab dipertahankan
///   (IndexedStack) — pindah pulang-pergi tidak memuat ulang data;
/// - kartu masuk menampilkan nomor agenda (bold), nomor eksternal (bila
///   ada), pengirim, perihal, tanggal diterima, badge sifat (rahasia
///   merah / segera amber / biasa netral) dan badge status dengan label
///   benar;
/// - pencarian debounce mengirim field `q`; chip status/sifat mengirim
///   filter ke service;
/// - tap kartu membuka placeholder detail (TODO Task 10); FAB masuk
///   membuka placeholder form (TODO Task 9) lalu me-refresh daftar;
/// - menu kartu "Daftarkan sebagai balasan pihak luar" tampil namun
///   dinonaktifkan sampai Task 11.

/// Outgoing service minimal — tab Keluar kosong (fokus test tab Masuk);
/// badge tugas ttd di-override agar tidak ada request nyata.
class _FakeDocumentService extends DocumentService {
  @override
  Future<PaginatedResult<DocumentModel>> getDocuments({
    String? status,
    String? letterType,
    int? year,
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

  @override
  Future<List<LetterTypeModel>> getLetterTypes() async => const [];

  @override
  Future<PaginatedResult<SigningRequestModel>> mySigningRequests({
    String? status,
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

class _FakeIncomingService extends IncomingService {
  _FakeIncomingService({this.letters = const [], this.fail = false});

  List<IncomingLetterModel> letters;
  bool fail;

  int calls = 0;
  String? lastStatus;
  String? lastSifat;
  int? lastYear;
  String? lastQuery;

  @override
  Future<PaginatedResult<IncomingLetterModel>> getIncoming({
    String? status,
    String? sifat,
    int? year,
    String? query,
    int page = 1,
  }) async {
    calls++;
    lastStatus = status;
    lastSifat = sifat;
    lastYear = year;
    lastQuery = query;
    if (fail) throw Exception('Gagal memuat surat masuk.');
    return PaginatedResult(
      items: letters,
      currentPage: 1,
      lastPage: 1,
      total: letters.length,
      perPage: 15,
    );
  }
}

IncomingLetterModel _incoming(
  String id,
  String agenda, {
  String? numberExternal,
  String? sender,
  String subject = 'Perihal surat masuk',
  DateTime? receivedAt,
  String sifat = 'biasa',
  String status = 'terdaftar',
}) =>
    IncomingLetterModel(
      id: id,
      agendaNumber: agenda,
      numberExternal: numberExternal,
      senderParty: sender == null ? null : PartyModel(id: 1, name: sender),
      receivedAt: receivedAt ?? DateTime(2026, 10, 1),
      subject: subject,
      sifat: sifat,
      classification: 'umum',
      status: status,
    );

final _letters = [
  _incoming('i1', 'SM-001/X/2026',
      numberExternal: '001/PT-ABC/X/2026',
      sender: 'PT ABC Makmur',
      subject: 'Undangan rapat tahunan',
      sifat: 'rahasia',
      status: 'terdaftar'),
  _incoming('i2', 'SM-002/X/2026',
      subject: 'Korespondensi penawaran', sifat: 'segera', status: 'diproses'),
  _incoming('i3', 'SM-003/X/2026',
      sender: 'Kantor Notaris',
      subject: 'Pemberitahuan perubahan direktur',
      sifat: 'biasa',
      status: 'selesai'),
];

/// Viewport ponsel realistis (pola document_list_page_test) — kartu
/// ketiga perlu viewport tinggi agar dibangun ListView yang lazy.
Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeIncomingService incoming,
}) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DocumentListPage(
        service: _FakeDocumentService(),
        incomingService: incoming,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openIncomingTab(WidgetTester tester) async {
  await tester.tap(find.text('Masuk'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kartu masuk menampilkan agenda, nomor eksternal, pengirim, '
      'perihal, tanggal diterima + label badge benar', (tester) async {
    final incoming = _FakeIncomingService(letters: _letters);
    await _pumpPage(tester, incoming: incoming);

    // Tab Keluar default: kartu masuk belum dimuat (lazy mount).
    expect(incoming.calls, 0);
    expect(find.byTooltip('Buat Surat'), findsOneWidget);

    await _openIncomingTab(tester);
    expect(incoming.calls, 1);

    expect(find.text('SM-001/X/2026'), findsOneWidget);
    expect(find.text('SM-002/X/2026'), findsOneWidget);
    expect(find.text('SM-003/X/2026'), findsOneWidget);
    expect(find.text('No. eksternal: 001/PT-ABC/X/2026'), findsOneWidget);
    // i2 tanpa nomor eksternal → baris itu tidak dirender.
    expect(find.textContaining('No. eksternal:'), findsOneWidget);
    expect(find.text('Undangan rapat tahunan'), findsOneWidget);
    expect(find.text('PT ABC Makmur • Diterima 1 Okt 2026'), findsOneWidget);
    expect(find.text('Pengirim tidak diketahui • Diterima 1 Okt 2026'),
        findsOneWidget);
    expect(find.text('Kantor Notaris • Diterima 1 Okt 2026'), findsOneWidget);

    // Sifat + status tiap kartu memakai label bahasa Indonesia.
    final badgeTypeByLabel = <String, StatusType>{};
    for (final badge
        in tester.widgetList<StatusBadge>(find.byType(StatusBadge))) {
      badgeTypeByLabel[badge.label] = badge.type;
    }
    expect(badgeTypeByLabel['Rahasia'], StatusType.error);
    expect(badgeTypeByLabel['Segera'], StatusType.warning);
    expect(badgeTypeByLabel['Biasa'], StatusType.neutral);
    expect(badgeTypeByLabel['Terdaftar'], StatusType.neutral);
    expect(badgeTypeByLabel['Diproses'], StatusType.warning);
    expect(badgeTypeByLabel['Selesai'], StatusType.success);

    // FAB kontekstual berganti di tab Masuk.
    expect(find.byTooltip('Daftar Surat Masuk'), findsOneWidget);
    expect(find.byTooltip('Buat Surat'), findsNothing);
  });

  testWidgets('pencarian debounce mengirim field q; chip status/sifat '
      'mengirim filter', (tester) async {
    final incoming = _FakeIncomingService(letters: _letters);
    await _pumpPage(tester, incoming: incoming);
    await _openIncomingTab(tester);

    // Buka baris pencarian lewat ikon AppBar (tab aktif = Masuk).
    await tester.tap(find.byTooltip('Cari Surat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'undangan');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(incoming.lastQuery, 'undangan');
    expect(incoming.calls, 2);

    // Chip filter status + sifat (widgetWithText: label sama dengan badge
    // kartu, pilih khusus chip). Baris chip scrollable horizontal —
    // geser kiri dulu agar chip target terlihat.
    await tester.drag(
        find.widgetWithText(ChoiceChip, 'Terdaftar'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Diproses'));
    await tester.pumpAndSettle();
    expect(incoming.lastStatus, 'diproses');

    await tester.drag(
        find.widgetWithText(ChoiceChip, 'Biasa'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Rahasia'));
    await tester.pumpAndSettle();
    expect(incoming.lastSifat, 'rahasia');
    expect(incoming.lastStatus, 'diproses');
  });

  testWidgets('pindah tab pulang-pergi mempertahankan state Masuk '
      '(tanpa muat ulang)', (tester) async {
    final incoming = _FakeIncomingService(letters: _letters);
    await _pumpPage(tester, incoming: incoming);
    await _openIncomingTab(tester);

    // Aktifkan pencarian dengan isi tertentu.
    await tester.tap(find.byTooltip('Cari Surat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'notaris');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final callsAfterSearch = incoming.calls;

    // Pindah ke Keluar: FAB & search state Keluar yang aktif.
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Buat Surat'), findsOneWidget);

    // Kembali ke Masuk: tidak ada fetch ulang (IndexedStack) dan query
    // pencarian masih terisi.
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(incoming.calls, callsAfterSearch);
    expect(find.text('notaris'), findsOneWidget);
    expect(find.text('SM-001/X/2026'), findsOneWidget);
  });

  testWidgets('tap kartu membuka placeholder detail (TODO Task 10)',
      (tester) async {
    final incoming = _FakeIncomingService(letters: [_letters.first]);
    await _pumpPage(tester, incoming: incoming);
    await _openIncomingTab(tester);

    await tester.tap(find.text('SM-001/X/2026'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Surat Masuk'), findsOneWidget);
    expect(find.text('SM-001/X/2026'), findsOneWidget);
    expect(find.textContaining('Tugas 10'), findsOneWidget);
  });

  testWidgets('FAB masuk membuka placeholder form (TODO Task 9) lalu '
      'me-refresh daftar', (tester) async {
    final incoming = _FakeIncomingService(letters: _letters);
    await _pumpPage(tester, incoming: incoming);
    await _openIncomingTab(tester);
    expect(incoming.calls, 1);

    await tester.tap(find.byTooltip('Daftar Surat Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Form pendaftaran surat masuk'), findsOneWidget);
    expect(find.textContaining('Tugas 9'), findsOneWidget);

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    // Kembali dari form → buku agenda di-refresh.
    expect(incoming.calls, 2);
    expect(find.text('SM-001/X/2026'), findsOneWidget);
  });

  testWidgets('menu kartu menampilkan aksi balasan pihak luar yang '
      'dinonaktifkan sampai Task 11', (tester) async {
    final incoming = _FakeIncomingService(letters: [_letters.first]);
    await _pumpPage(tester, incoming: incoming);
    await _openIncomingTab(tester);

    await tester.tap(find.byTooltip('Aksi Surat Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Daftarkan sebagai balasan pihak luar'), findsOneWidget);
    expect(find.text('Tersedia setelah Tugas 11'), findsOneWidget);
    final item =
        tester.widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>));
    expect(item.enabled, isFalse);
  });

  testWidgets('state error menampilkan pesan + coba lagi yang memuat ulang',
      (tester) async {
    final incoming = _FakeIncomingService(letters: _letters, fail: true);
    await _pumpPage(tester, incoming: incoming);
    await _openIncomingTab(tester);

    expect(find.text('Gagal memuat surat masuk.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    incoming.fail = false;
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat surat masuk.'), findsNothing);
    expect(find.text('SM-001/X/2026'), findsOneWidget);
  });
}
