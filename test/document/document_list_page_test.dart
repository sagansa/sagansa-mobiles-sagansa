import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_list_page.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/widgets/status_badge.dart';

/// Kontrak UI `DocumentListPage` (Arsip Surat Perusahaan):
/// - kartu menampilkan nomor (atau "Belum bernomor"), perihal, jenis,
///   tanggal, dan badge status dengan label yang benar;
/// - aksi "Salin surat ini" → konfirmasi → duplicateFrom ke service
///   → snackbar sukses;
/// - FAB "Buat Surat" tersedia.
class _FakeDocumentService extends DocumentService {
  _FakeDocumentService({
    this.documents = const [],
    this.letterTypes = const [],
  });

  List<DocumentModel> documents;
  List<LetterTypeModel> letterTypes;

  /// Argumen terakhir createDraft (dipanggil duplicateFrom) —
  /// membuktikan duplikasi lewat `duplicate_from_id`.
  String? lastDuplicateFromId;
  String? lastSubject;
  String? lastLetterTypeCode;

  @override
  Future<PaginatedResult<DocumentModel>> getDocuments({
    String? status,
    String? letterType,
    int? year,
    String? query,
    int page = 1,
  }) async {
    return PaginatedResult(
      items: documents,
      currentPage: 1,
      lastPage: 1,
      total: documents.length,
      perPage: 15,
    );
  }

  @override
  Future<List<LetterTypeModel>> getLetterTypes() async => letterTypes;

  /// Task 22: draf hasil salinan dibuka di DocumentDetailPage (bukan
  /// placeholder) — detail page memanggil getDetail saat dibuka.
  @override
  Future<DocumentModel> getDetail(String id) async => DocumentModel(
        id: id,
        status: 'draft',
        classification: 'umum',
        subject: 'Perihal surat',
        letterType: _kua,
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
  }) async {
    lastDuplicateFromId = duplicateFromId;
    lastSubject = subject;
    lastLetterTypeCode = letterTypeCode;
    return DocumentModel(
      id: 'draft-baru',
      status: 'draft',
      classification: 'umum',
      subject: subject,
      letterType: LetterTypeModel(code: letterTypeCode, name: letterTypeCode),
    );
  }
}

const _kua = LetterTypeModel(code: 'KUA', name: 'Surat Kuasa');

DocumentModel _doc(
  String id,
  String status, {
  String? number,
  String subject = 'Perihal surat',
  DateTime? date,
  LetterTypeModel? letterType = _kua,
}) =>
    DocumentModel(
      id: id,
      number: number,
      status: status,
      classification: 'umum',
      subject: subject,
      date: date ?? DateTime(2026, 3, 15),
      letterType: letterType,
    );

/// Viewport ponsel realistis (360x800/360x1067 logis) — viewport default
/// 800x600 terlalu pendek: snackbar mengambang tidak muat di atas FAB +
/// bottom nav, dan kartu ke-4/5 tidak terbangun (ListView lazy) sehingga
/// badge-nya tidak pernah dirender. [tall] untuk banyak kartu.
Future<void> _pumpListPage(WidgetTester tester, _FakeDocumentService service,
    {bool tall = false}) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize =
      tall ? const Size(1080, 3200) : const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: DocumentListPage(service: service)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kartu menampilkan nomor/"Belum bernomor", perihal, jenis, '
      'tanggal, dan FAB Buat Surat', (tester) async {
    final service = _FakeDocumentService(
      letterTypes: const [_kua],
      documents: [
        _doc('d1', 'terbit', number: '017/KUA/III/2026', subject: 'Kuasa jual'),
        _doc('d2', 'draft', subject: 'Kuasa beli'),
      ],
    );
    await _pumpListPage(tester, service);

    expect(find.text('Surat Perusahaan'), findsWidgets); // judul appbar
    expect(find.text('017/KUA/III/2026'), findsOneWidget);
    expect(find.text('Belum bernomor'), findsOneWidget);
    expect(find.text('Kuasa jual'), findsOneWidget);
    expect(find.text('Kuasa beli'), findsOneWidget);
    expect(find.text('Surat Kuasa • 15 Mar 2026'), findsNWidgets(2));
    expect(find.byTooltip('Buat Surat'), findsOneWidget);
  });

  testWidgets('badge status kartu: label tiap status dokumen', (tester) async {
    final service = _FakeDocumentService(
      documents: [
        _doc('d1', 'draft'),
        _doc('d2', 'menunggu_ttd'),
        _doc('d3', 'terbit'),
        _doc('d4', 'dicabut'),
        _doc('d5', 'dibatalkan'),
      ],
    );
    await _pumpListPage(tester, service, tall: true);

    final badgeLabels = tester
        .widgetList<StatusBadge>(find.byType(StatusBadge))
        .map((badge) => badge.label)
        .toList();
    expect(badgeLabels, containsAll(<String>[
      'Draft',
      'Menunggu ttd',
      'Terbit',
      'Dicabut',
      'Dibatalkan',
    ]));
  });

  testWidgets('tap "Salin surat ini" → konfirmasi → duplicateFrom dipanggil '
      'dengan id sumber + snackbar sukses', (tester) async {
    final service = _FakeDocumentService(
      letterTypes: const [_kua],
      documents: [_doc('d1', 'terbit', number: '017/KUA/III/2026')],
    );
    await _pumpListPage(tester, service, tall: true);

    await tester.tap(find.byTooltip('Aksi Surat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salin surat ini'));
    await tester.pumpAndSettle();

    // Dialog konfirmasi muncul; batal tidak menduplikasi.
    expect(find.text('Salin Surat'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(service.lastDuplicateFromId, isNull);

    // Ulangi lalu konfirmasi.
    await tester.tap(find.byTooltip('Aksi Surat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salin surat ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salin'));
    await tester.pumpAndSettle();

    expect(service.lastDuplicateFromId, 'd1');
    expect(service.lastLetterTypeCode, 'KUA');
    expect(service.lastSubject, 'Perihal surat');
    expect(
      find.text('Surat berhasil disalin menjadi draf baru.'),
      findsOneWidget,
    );
    // Draf hasil salinan dibuka (placeholder detail Task 22).
    expect(find.text('Detail Surat'), findsOneWidget);
  });

  testWidgets('state error menampilkan pesan + tombol coba lagi yang '
      'memuat ulang', (tester) async {
    final service = _FailingDocumentService();
    await _pumpListPage(tester, service);

    expect(find.text('Gagal memuat surat.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Retry sukses setelah "koneksi pulih".
    service.fail = false;
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat surat.'), findsNothing);
  });
}

/// Service yang gagal memuat daftar (simulasi offline), bisa dipulihkan.
class _FailingDocumentService extends _FakeDocumentService {
  bool fail = true;

  @override
  Future<PaginatedResult<DocumentModel>> getDocuments({
    String? status,
    String? letterType,
    int? year,
    String? query,
    int page = 1,
  }) async {
    if (fail) throw Exception('Gagal memuat surat.');
    return super.getDocuments(
      status: status,
      letterType: letterType,
      year: year,
      query: query,
      page: page,
    );
  }
}
