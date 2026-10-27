import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sagansa/pages/documents/document_create_wizard.dart';
import 'package:sagansa/pages/documents/document_detail_page.dart';
import 'package:sagansa/pages/documents/signing_task_page.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/widgets/documents/issuance_timeline.dart';

/// Kontrak UI task 22: DocumentDetailPage (tab Info/Terbitan + aksi sesuai
/// status), IssuanceTimeline (Berlaku/Digantikan + note), SigningTaskPage
/// (approve/reject via service), parse bodyHtml/unit model, dan mode edit
/// wizard (param documentId).

const _kuaType = LetterTypeModel(
  code: 'KUA',
  name: 'Surat Kuasa',
  specificFields: [
    LetterSpecificField(key: 'penerima_kuasa_nama', label: 'Nama Penerima Kuasa'),
  ],
);
const _stType = LetterTypeModel(code: 'ST', name: 'Surat Tugas');

DocumentModel _kuaTerbit() => DocumentModel(
      id: 'doc-1',
      number: '017/KUA/DIR/X/2026',
      status: 'terbit',
      classification: 'umum',
      subject: 'Kuasa pengurusan pajak',
      date: DateTime(2026, 3, 15),
      letterType: _kuaType,
      unit: 'DIR',
      metadata: const {
        'recipient': {'name': 'PT Mitra Jaya', 'identity_no': '32750100'},
        'specific': {'penerima_kuasa_nama': 'Andi Saputra'},
        'validity': {'mode': 'until_date', 'until_date': '2026-12-31'},
      },
      createdBy: 7,
      activeIssuance: const IssuanceModel(
        id: 'iss-2',
        method: 'b',
        methodLabel: 'elektronik',
        fileSha256: 'bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11',
        isActive: true,
        finalizedAt: null,
      ),
      issuances: const [
        IssuanceModel(
          id: 'iss-2',
          method: 'b',
          methodLabel: 'elektronik',
          fileSha256: 'bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11',
          isActive: true,
        ),
        IssuanceModel(
          id: 'iss-1',
          method: 'a',
          methodLabel: 'elektronik',
          fileSha256: 'cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22',
          note: 'Salah isi penerima pada versi sebelumnya',
          isActive: false,
          finalizedAt: null,
        ),
      ],
      attachments: const [
        AttachmentModel(id: 'att-1', label: 'Daftar Hadir', sort: 0, size: 204800),
      ],
      signingRequests: const [
        SigningRequestModel(
          id: 'req-1',
          status: 'disetujui',
          signer: SignerModel(id: 3, role: 'komisaris', displayName: 'Budi Komisaris'),
        ),
        SigningRequestModel(
          id: 'req-2',
          status: 'diminta',
          signer: SignerModel(id: 4, role: 'direktur', displayName: 'Ari Direktur'),
        ),
      ],
    );

class _FakeDetailService extends DocumentService {
  _FakeDetailService(this.detail);

  DocumentModel detail;
  int detailReloads = 0;
  final List<({String id, String reason, DateTime revokedAt})> revokeCalls = [];
  final List<({String id, String reason})> voidCalls = [];

  @override
  Future<DocumentModel> getDetail(String id) async {
    detailReloads++;
    return detail;
  }

  @override
  Future<Map<String, dynamic>> revoke(
    String id, {
    required String reason,
    required DateTime revokedAt,
  }) async {
    revokeCalls.add((id: id, reason: reason, revokedAt: revokedAt));
    return {'id': id, 'status': 'dicabut'};
  }

  @override
  Future<Map<String, dynamic>> voidDocument(String id,
      {required String reason}) async {
    voidCalls.add((id: id, reason: reason));
    return {'id': id, 'status': 'dibatalkan'};
  }
}

SigningRequestModel _pendingRequest() => const SigningRequestModel(
      id: 'req-9',
      status: 'diminta',
      requestedAt: null,
      document: SigningRequestDocumentRef(
        id: 'doc-9',
        number: '018/ST/DIR/X/2026',
        subject: 'Surat Tugas Audit Internal',
        status: 'menunggu_ttd',
      ),
    );

class _FakeSigningService extends DocumentService {
  final List<SigningRequestModel> requests;
  String? approvedId;
  String? approvedNote;
  String? rejectedId;
  String? rejectedNote;

  _FakeSigningService(this.requests);

  @override
  Future<PaginatedResult<SigningRequestModel>> mySigningRequests({
    String? status,
    int page = 1,
  }) async {
    return PaginatedResult(
      items: requests,
      currentPage: 1,
      lastPage: 1,
      total: requests.length,
      perPage: 15,
    );
  }

  @override
  Future<Map<String, dynamic>> preFinal(String id,
      {required String mode,
      String? pdfBase64,
      List<Map<String, dynamic>>? overlays}) async {
    return {'download_url': 'https://signed.example/preview'};
  }

  @override
  Future<Map<String, dynamic>> approveSigning(String id, {String? note}) async {
    approvedId = id;
    approvedNote = note;
    return {};
  }

  @override
  Future<Map<String, dynamic>> rejectSigning(String id, {String? note}) async {
    rejectedId = id;
    rejectedNote = note;
    return {};
  }
}

Future<void> _pumpDetail(WidgetTester tester, DocumentService service) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: DocumentDetailPage(documentId: 'doc-1', service: service),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Aksi Surat'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detail: header + tab Info render metadata/penandatangan/'
      'lampiran; tab Terbitan menampilkan timeline Berlaku/Digantikan + note',
      (tester) async {
    final service = _FakeDetailService(_kuaTerbit());
    await _pumpDetail(tester, service);

    // Header.
    expect(find.text('017/KUA/DIR/X/2026'), findsOneWidget);
    expect(find.text('Belum bernomor'), findsNothing);
    expect(find.text('Terbit'), findsOneWidget); // badge status.

    // Tab Info (default): metadata ramah + penandatangan + lampiran.
    expect(find.text('Kuasa pengurusan pajak'), findsOneWidget);
    expect(find.text('PT Mitra Jaya'), findsOneWidget);
    expect(find.text('Andi Saputra'), findsOneWidget);
    // Bagian bawah (penandatangan/lampiran) di bawah lipatan — scroll.
    await tester.scrollUntilVisible(find.text('Budi Komisaris'), 200,
        scrollable: find
              .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
    expect(find.text('Budi Komisaris'), findsOneWidget);
    expect(find.text('Disetujui'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ari Direktur'), 200,
        scrollable: find
              .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
    expect(find.text('Ari Direktur'), findsOneWidget);
    expect(find.text('Diminta'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Daftar Hadir'), 200,
        scrollable: find
              .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
    expect(find.textContaining('Daftar Hadir'), findsOneWidget);

    // Tab Terbitan: timeline.
    await tester.tap(find.text('Terbitan'));
    await tester.pumpAndSettle();
    expect(find.text('Berlaku'), findsOneWidget);
    expect(find.text('Digantikan'), findsOneWidget);
    expect(find.textContaining('Salah isi penerima'), findsOneWidget);
  });

  // Catatan: satu testWidgets = satu halaman — pumpWidget dengan tipe widget
  // sama mempertahankan State sehingga detail dokumen lama bisa bocor ke
  // pemumpukan berikutnya (guard test terpisah per skenario).

  testWidgets('menu aksi ST terbit: Terbitkan ulang + Batalkan, TANPA Cabut '
      'kuasa', (tester) async {
    final stService = _FakeDetailService(DocumentModel(
      id: 'doc-st',
      number: '018/ST/DIR/X/2026',
      status: 'terbit',
      classification: 'umum',
      subject: 'Surat tugas audit',
      letterType: _stType,
    ));
    await _pumpDetail(tester, stService);
    await _openMenu(tester);
    expect(find.text('Terbitkan ulang…'), findsOneWidget);
    expect(find.text('Batalkan surat'), findsOneWidget);
    expect(find.text('Cabut kuasa'), findsNothing);
  });

  testWidgets('menu aksi KUA terbit: Cabut kuasa tersedia', (tester) async {
    final kuaService = _FakeDetailService(_kuaTerbit());
    await _pumpDetail(tester, kuaService);
    await _openMenu(tester);
    expect(find.text('Terbitkan ulang…'), findsOneWidget);
    expect(find.text('Cabut kuasa'), findsOneWidget);
    expect(find.text('Batalkan surat'), findsOneWidget);
  });

  testWidgets('menu aksi KUA draft: Edit + Batalkan, tanpa Cabut/Terbitkan '
      'ulang; isi draf tampil di tab Info', (tester) async {
    final draftService = _FakeDetailService(DocumentModel(
      id: 'doc-draft',
      status: 'draft',
      classification: 'umum',
      subject: 'Draf kuasa',
      letterType: _kuaType,
      bodyHtml: '<p>Isi draf <b>penting</b></p>',
    ));
    await _pumpDetail(tester, draftService);
    await _openMenu(tester);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Batalkan surat'), findsOneWidget);
    expect(find.text('Cabut kuasa'), findsNothing);
    expect(find.text('Terbitkan ulang…'), findsNothing);

    // Tutup menu → isi draf (bodyHtml) dirender sebagai teks polos di Info.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Isi draf penting'), 200,
        scrollable: find
              .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
    expect(find.textContaining('Isi draf penting'), findsOneWidget);
  });

  testWidgets('aksi Cabut kuasa: dialog alasan wajib → service.revoke dengan '
      'alasan + tanggal', (tester) async {
    final service = _FakeDetailService(_kuaTerbit());
    await _pumpDetail(tester, service);

    await _openMenu(tester);
    await tester.tap(find.text('Cabut kuasa'));
    await tester.pumpAndSettle();

    // Alasan kosong → tombol Cabut tidak menutup dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Cabut'));
    await tester.pumpAndSettle();
    expect(service.revokeCalls, isEmpty);
    expect(find.text('Alasan wajib diisi.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kuasa sudah selesai dipakai');
    await tester.tap(find.widgetWithText(FilledButton, 'Cabut'));
    await tester.pumpAndSettle();

    expect(service.revokeCalls, hasLength(1));
    expect(service.revokeCalls.single.id, 'doc-1');
    expect(service.revokeCalls.single.reason, 'Kuasa sudah selesai dipakai');
    // Tanggal default hari ini.
    final now = DateTime.now();
    final revokedAt = service.revokeCalls.single.revokedAt;
    expect(revokedAt.year, now.year);
    expect(revokedAt.month, now.month);
    expect(revokedAt.day, now.day);
    // Snackbar + detail dimuat ulang.
    expect(find.text('Kuasa dicabut.'), findsOneWidget);
    expect(service.detailReloads, greaterThanOrEqualTo(2));
  });

  testWidgets('IssuanceTimeline: aktif di atas, badge Berlaku/Digantikan, '
      'hash pendek 8 char + note', (tester) async {
    await initializeDateFormatting('id_ID');
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: IssuanceTimeline(
          issuances: [
            IssuanceModel(
              id: 'iss-1',
              method: 'a',
              methodLabel: 'elektronik',
              fileSha256:
                  'cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22',
              note: 'Salah isi penerima',
              isActive: false,
            ),
            IssuanceModel(
              id: 'iss-2',
              method: 'd',
              methodLabel: 'manual',
              fileSha256:
                  'bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11',
              isActive: true,
            ),
          ],
        ),
      ),
    ));

    expect(find.text('Berlaku'), findsOneWidget);
    expect(find.text('Digantikan'), findsOneWidget);
    expect(find.textContaining('SHA-256 cc22cc22…'), findsOneWidget);
    expect(find.textContaining('Catatan: Salah isi penerima'), findsOneWidget);
    expect(find.textContaining('Manual'), findsOneWidget);
    // Aktif di atas (tile pertama = Berlaku).
    final berlaku = tester.getTopLeft(find.text('Berlaku'));
    final digantikan = tester.getTopLeft(find.text('Digantikan'));
    expect(berlaku.dy, lessThan(digantikan.dy));
  });

  // ——— SigningTaskPage ———

  Future<void> pumpSigningTasks(
      WidgetTester tester, DocumentService service) async {
    await initializeDateFormatting('id_ID');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SigningTaskPage(
        service: service,
        fetchUrl: (_) async => Uint8List.fromList([1, 2, 3]),
        pdfPreviewBuilder: (_, bytes) => const Text('PDF-STUB'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('tugas tanda tangan: daftar diminta → pratinjau → Setujui '
      'memanggil approveSigning', (tester) async {
    final service = _FakeSigningService([_pendingRequest()]);
    await pumpSigningTasks(tester, service);

    expect(find.text('018/ST/DIR/X/2026'), findsOneWidget);
    expect(find.text('Surat Tugas Audit Internal'), findsOneWidget);

    await tester.tap(find.text('Surat Tugas Audit Internal'));
    await tester.pumpAndSettle();

    // Halaman tindak: pratinjau + tombol keputusan.
    expect(find.text('PDF-STUB'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);

    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();

    expect(service.approvedId, 'req-9');
    expect(service.approvedNote, isNull); // catatan opsional kosong.
    expect(find.text('Tanda tangan disetujui.'), findsOneWidget);
  });

  testWidgets('tugas tanda tangan: Tolak dengan catatan memanggil '
      'rejectSigning + note', (tester) async {
    final service = _FakeSigningService([_pendingRequest()]);
    await pumpSigningTasks(tester, service);

    await tester.tap(find.text('Surat Tugas Audit Internal'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Catatan (opsional)'), 'Data tidak lengkap');
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();

    expect(service.rejectedId, 'req-9');
    expect(service.rejectedNote, 'Data tidak lengkap');
    expect(find.text('Tanda tangan ditolak.'), findsOneWidget);
  });

  // ——— model bodyHtml + unit ———

  test('DocumentModel memparse bodyHtml + unit (detail draft); tanpa key → '
      'null', () {
    const draftJson = {
      'id': 'd1',
      'status': 'draft',
      'classification': 'umum',
      'subject': 'Draf kuasa',
      'unit': 'KEU',
      'body_html': '<p>Isi draf <strong>penting</strong></p>',
    };
    final draft = DocumentModel.fromJson(draftJson);
    expect(draft.bodyHtml, '<p>Isi draf <strong>penting</strong></p>');
    expect(draft.unit, 'KEU');

    // Terbit — backend tidak menyertakan body_html/unit di list/terbit.
    const terbitJson = {
      'id': 'd2',
      'status': 'terbit',
      'classification': 'umum',
      'subject': 'Sudah terbit',
    };
    final terbit = DocumentModel.fromJson(terbitJson);
    expect(terbit.bodyHtml, isNull);
    expect(terbit.unit, isNull);
  });

  test('letterHtmlToPlainText: blok → baris, list → butir, tag & entitas '
      'dibersihkan', () {
    const html = '<h1>Judul</h1>'
        '<p>Kepada <b>Budi</b> &amp; Sari,</p>'
        '<ul><li>poin satu</li><li>poin dua</li></ul>'
        '<p>Terima kasih.<br/>Hormat kami.</p>';
    final plain = letterHtmlToPlainText(html);
    expect(plain, contains('Judul\n'));
    expect(plain, contains('Kepada Budi & Sari,'));
    expect(plain, contains('• poin satu'));
    expect(plain, contains('• poin dua'));
    expect(plain, contains('Terima kasih.\nHormat kami.'));
    expect(plain.contains('<'), isFalse);
    expect(letterHtmlToPlainText('&nbsp;&lt;x&gt;'), '<x>');
  });

  // ——— wizard mode edit (param documentId) ———

  testWidgets('wizard documentId: memuat draf existing — prefill perihal/'
      'unit/penerima, mulai di langkah Formulir, editor terisi tanpa banner '
      'gagal', (tester) async {
    final service = _FakeWizardEditService();
    await initializeDateFormatting('id_ID');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        ...FlutterQuillLocalizations.localizationsDelegates,
      ],
      supportedLocales: const [Locale('id')],
      locale: const Locale('id'),
      home: DocumentCreateWizard(service: service, documentId: 'draft-9'),
    ));
    await tester.pumpAndSettle();

    // Langkah 2 (Formulir) — jenis & sumber terkunci karena draf ada.
    expect(find.text('Langkah 2 dari 6 — Formulir'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);

    // Prefill perihal + unit + penerima dari metadata.
    expect(find.text('Kuasa pengurusan dokumen'), findsOneWidget);
    expect(find.text('KEU'), findsOneWidget);
    expect(find.text('PT Mitra Jaya'), findsOneWidget);

    // Editor terisi dari bodyHtml: tidak ada banner parse gagal /
    // unsupported (HTML sederhana diparse penuh).
    expect(find.textContaining('tidak dapat dimuat'), findsNothing);
    expect(find.textContaining('diratakan menjadi teks'), findsNothing);
  });
}

/// Fake wizard edit-mode: getDetail mengembalikan draf KUA lengkap.
class _FakeWizardEditService extends DocumentService {
  @override
  Future<List<LetterTypeModel>> getLetterTypes() async =>
      const [_kuaType, _stType];

  @override
  Future<List<TemplateModel>> getTemplates(String letterTypeCode) async =>
      const [];

  @override
  Future<DocumentModel> getDetail(String id) async => DocumentModel(
        id: id,
        status: 'draft',
        classification: 'umum',
        subject: 'Kuasa pengurusan dokumen',
        date: DateTime(2026, 10, 27),
        letterType: _kuaType,
        unit: 'KEU',
        bodyHtml: '<p>Kuasa ini diberikan untuk keperluan dokumen.</p>',
        metadata: const {
          'recipient': {'name': 'PT Mitra Jaya'},
        },
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
  }) async =>
      DocumentModel(
        id: id,
        status: 'draft',
        classification: 'umum',
        subject: subject ?? 'draf',
      );
}
