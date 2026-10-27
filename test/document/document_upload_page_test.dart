import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/pages/documents/document_upload_page.dart';
import 'package:sagansa/pages/documents/overlay_placement_step.dart';
import 'package:sagansa/services/document/document_service.dart';

/// Kontrak UI `DocumentUploadPage` (task 21) — alur Mode B pra-final →
/// lanjutan C/D, reissue b/d, preset ponsel & drag kanvas tablet, semua
/// lewat service fake + seam (pick/fetch/compress) tanpa jaringan.
class _FakeUploadService extends DocumentService {
  // preFinal captures.
  int preFinalCalls = 0;
  String? lastPreFinalId;
  String? lastPreFinalMode;
  String? lastPreFinalPdfBase64;
  List<Map<String, dynamic>>? lastPreFinalOverlays;

  // finalize captures.
  String? lastFinalizeMethod;
  String? lastFinalizePdfBase64;

  // finalizeManual captures.
  int lastManualFileCount = 0;
  String? lastManualNote;

  // reissue captures.
  String? lastReissueMethod;
  String? lastReissueNote;
  String? lastReissuePdfBase64;
  List<Map<String, dynamic>>? lastReissueOverlays;
  List<String>? lastReissueImagesBase64;

  final Map<String, dynamic> _result = const {
    'issuance': {'id': 'iss-1', 'method': 'c'},
    'verify_url': 'https://document.sagansa.id/verify/doc-1',
    'number': '017/KUA/X/2026',
  };

  @override
  Future<Map<String, dynamic>> preFinal(
    String id, {
    required String mode,
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
  }) async {
    preFinalCalls++;
    lastPreFinalId = id;
    lastPreFinalMode = mode;
    lastPreFinalPdfBase64 = pdfBase64;
    lastPreFinalOverlays = overlays;
    return {'download_url': 'https://example.com/pre-final.pdf',
        'expires_in': 900};
  }

  @override
  Future<Map<String, dynamic>> finalize(
    String id, {
    required String method,
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
  }) async {
    lastFinalizeMethod = method;
    lastFinalizePdfBase64 = pdfBase64;
    return _result;
  }

  @override
  Future<Map<String, dynamic>> finalizeManual(
    String id,
    List<File> images, {
    String? note,
  }) async {
    lastManualFileCount = images.length;
    lastManualNote = note;
    return _result;
  }

  @override
  Future<Map<String, dynamic>> reissue(
    String id, {
    required String method,
    required String note,
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
    List<String>? imagesBase64,
  }) async {
    lastReissueMethod = method;
    lastReissueNote = note;
    lastReissuePdfBase64 = pdfBase64;
    lastReissueOverlays = overlays;
    lastReissueImagesBase64 = imagesBase64;
    return {..._result, 'note': note};
  }
}

/// PDF minimal dengan magic %PDF.
final Uint8List _pdfBytes =
    Uint8List.fromList('%PDF-1.4\nfake body\n'.codeUnits);

final Uint8List _finalPdfBytes =
    Uint8List.fromList('%PDF-1.4\nfinal tte\n'.codeUnits);

/// PNG 1×1 px valid — Image.memory di kanvas perlu bytes yang terdekode.
final Uint8List _qrPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

Future<void> _pumpUploadPage(
  WidgetTester tester, {
  required _FakeUploadService service,
  DocumentUploadMode mode = DocumentUploadMode.uploadDraft,
  String reissueMethod = 'b',
  List<PickedPdf?> pdfPicks = const [],
  List<List<PickedPhoto>> imagePicks = const [],
}) async {
  final pdfQueue = List<PickedPdf?>.from(pdfPicks);
  final imageQueue = List<List<PickedPhoto>>.from(imagePicks);
  await tester.pumpWidget(
    MaterialApp(
      home: DocumentUploadPage(
        documentId: 'doc-1',
        documentSubject: 'Kuasa pengurusan pajak',
        mode: mode,
        reissueMethod: reissueMethod,
        service: service,
        pickPdf: () async => pdfQueue.isEmpty ? null : pdfQueue.removeAt(0),
        pickImages: () async => imageQueue.isEmpty ? [] : imageQueue.removeAt(0),
        fetchUrl: (url) async => _pdfBytes,
        openPdfInfo: (bytes) async => const PdfPagesInfo(
          pageCount: 2,
          pages: [
            (widthPt: 595.28, heightPt: 841.89),
            (widthPt: 595.28, heightPt: 841.89),
          ],
        ),
        buildQrPng: (data) async => _qrPng,
        decodeImageToPng: (bytes) async =>
            OverlayImageData(png: Uint8List(0), aspectRatio: 0.5),
        compressImage: (path) async => Uint8List.fromList(('J:$path').codeUnits),
        writeTempFile: (bytes, name) async => File('/tmp/fake-$name'),
        previewBuilder: (context, bytes) =>
            const SizedBox(height: 24, child: Text('PREVIEW-OK')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Mode B happy path: pilih PDF → QR otomatis → pra-final '
      'payload benar → pratinjau → lanjutan C finalize tanpa overlay',
      (tester) async {
    _setViewport(tester, const Size(360, 800));
    final service = _FakeUploadService();
    await _pumpUploadPage(
      tester,
      service: service,
      pdfPicks: [
        PickedPdf(name: 'surat.pdf', bytes: _pdfBytes),
        PickedPdf(name: 'final.pdf', bytes: _finalPdfBytes),
      ],
    );

    // Tahap pilih → placement: QR verifikasi otomatis ditambah.
    await tester.tap(find.text('Pilih PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Penempatan overlay'), findsOneWidget);
    expect(find.text('QR verifikasi'), findsWidgets);

    // Pra-final: mode b + pdf_base64 + overlay QR preset kanan-bawah A4.
    await tester.tap(find.text('Buat pra-final'));
    await tester.pumpAndSettle();

    expect(service.preFinalCalls, 1);
    expect(service.lastPreFinalId, 'doc-1');
    expect(service.lastPreFinalMode, 'b');
    expect(service.lastPreFinalPdfBase64, base64Encode(_pdfBytes));
    expect(service.lastPreFinalOverlays, hasLength(1));
    expect(service.lastPreFinalOverlays!.first['page'], 1);
    expect(service.lastPreFinalOverlays!.first['x_mm'], 173.0);
    expect(service.lastPreFinalOverlays!.first['y_mm'], 12.0);
    expect(service.lastPreFinalOverlays!.first['width_mm'], 25.0);
    expect(service.lastPreFinalOverlays!.first['image_base64'],
        base64Encode(_qrPng));

    // Pratinjau + dua jalur lanjutan tampil.
    expect(find.text('PREVIEW-OK'), findsOneWidget);
    expect(find.text('Bagikan / simpan pra-final'), findsOneWidget);

    // Lanjutan C: finalize metode c TANPA overlay.
    await tester.tap(find.text('Sudah diberi e-materai resmi / TTE'));
    await tester.pumpAndSettle();
    expect(service.lastFinalizeMethod, 'c');
    expect(service.lastFinalizePdfBase64, base64Encode(_finalPdfBytes));

    // Dialog sukses: nomor + tutup → halaman pop.
    expect(find.text('Surat diterbitkan'), findsOneWidget);
    expect(find.text('017/KUA/X/2026'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Unggah Dokumen'), findsNothing);
  });

  testWidgets('Mode B lanjutan D: 2 foto → kompresi → finalizeManual '
      'multipart 2 file', (tester) async {
    _setViewport(tester, const Size(360, 800));
    final service = _FakeUploadService();
    await _pumpUploadPage(
      tester,
      service: service,
      pdfPicks: [
        PickedPdf(name: 'surat.pdf', bytes: _pdfBytes),
      ],
      imagePicks: [
        [
          const PickedPhoto(path: '/tmp/a.jpg', name: 'a.jpg'),
          const PickedPhoto(path: '/tmp/b.jpg', name: 'b.jpg'),
        ],
      ],
    );

    await tester.tap(find.text('Pilih PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat pra-final'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tanda tangan basah — pindai hasil'));
    await tester.pumpAndSettle();

    // Note opsional dikosongkan (Lanjut langsung).
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(service.lastManualFileCount, 2);
    expect(service.lastManualNote, isNull);
    expect(find.text('Surat diterbitkan'), findsOneWidget);
  });

  testWidgets('preset ponsel: Kiri bawah mengubah payload overlay',
      (tester) async {
    _setViewport(tester, const Size(360, 800));
    final service = _FakeUploadService();
    await _pumpUploadPage(
      tester,
      service: service,
      pdfPicks: [PickedPdf(name: 'surat.pdf', bytes: _pdfBytes)],
    );

    await tester.tap(find.text('Pilih PDF'));
    await tester.pumpAndSettle();

    // Pilih preset Kiri bawah pada kartu QR.
    await tester.tap(find.text('Kiri bawah'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat pra-final'));
    await tester.pumpAndSettle();

    final overlay = service.lastPreFinalOverlays!.first;
    expect(overlay['x_mm'], 12.0);
    expect(overlay['y_mm'], 12.0);
  });

  testWidgets('kanvas tablet: drag QR menggeser mm (dx kanan, dy atas)',
      (tester) async {
    _setViewport(tester, const Size(1600, 1200));
    final service = _FakeUploadService();
    await _pumpUploadPage(
      tester,
      service: service,
      pdfPicks: [PickedPdf(name: 'surat.pdf', bytes: _pdfBytes)],
    );

    await tester.tap(find.text('Pilih PDF'));
    await tester.pumpAndSettle();

    final overlayWidget = find.byKey(const ValueKey('canvas-overlay-qr-1'));
    expect(overlayWidget, findsOneWidget);

    // Overlay memakai Listener mentah — dua langkah moveBy presisi: total
    // 10 mm ke kanan & 10 mm ke atas layar (pt @72dpi).
    final tenMmPt = OverlayMath.mmToPt(10);
    final gesture = await tester.startGesture(tester.getCenter(overlayWidget));
    await gesture.moveBy(const Offset(20, -20));
    await gesture.moveBy(Offset(tenMmPt - 20, -(tenMmPt - 20)));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat pra-final'));
    await tester.pumpAndSettle();

    final overlay = service.lastPreFinalOverlays!.first;
    expect(overlay['x_mm'], closeTo(183, 0.05)); // 173 + 10
    expect(overlay['y_mm'], closeTo(22, 0.05)); // 12 + 10
  });

  testWidgets('reissue d: pilih 2 foto → note wajib → images_base64 '
      'terkompresi', (tester) async {
    _setViewport(tester, const Size(360, 800));
    final service = _FakeUploadService();
    await _pumpUploadPage(
      tester,
      service: service,
      mode: DocumentUploadMode.reissue,
      reissueMethod: 'd',
      imagePicks: [
        [
          const PickedPhoto(path: '/tmp/a.jpg', name: 'a.jpg'),
          const PickedPhoto(path: '/tmp/b.jpg', name: 'b.jpg'),
        ],
      ],
    );

    await tester.tap(find.text('Pilih foto/scan (bisa banyak)'));
    await tester.pumpAndSettle();
    expect(find.text('a.jpg'), findsOneWidget);

    // Note wajib: kosong ditolak (tetap di dialog), terisi lanjut.
    await tester.tap(find.text('Terbitkan ulang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(find.text('Alasan terbitkan ulang'), findsOneWidget);
    expect(service.lastReissueMethod, isNull);

    await tester.enterText(find.byType(TextField), 'Salah isi versi awal');
    await tester.tap(find.text('Lanjut'));
    // Spinner bottom bar masih berputar di balik dialog — pumpAndSettle akan
    // timeout; pump beberapa frame cukup untuk rantai async fake selesai.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.lastReissueMethod, 'd');
    expect(service.lastReissueNote, 'Salah isi versi awal');
    expect(service.lastReissueImagesBase64, hasLength(2));
    expect(service.lastReissueImagesBase64![0],
        base64Encode(Uint8List.fromList('J:/tmp/a.jpg'.codeUnits)));
    expect(find.text('Surat diterbitkan ulang'), findsOneWidget);
  });

  testWidgets('PDF tanpa magic %PDF ditolak di klien (tetap tahap pilih)',
      (tester) async {
    _setViewport(tester, const Size(360, 800));
    final service = _FakeUploadService();
    await _pumpUploadPage(
      tester,
      service: service,
      pdfPicks: [
        PickedPdf(
          name: 'bukan.pdf',
          bytes: Uint8List.fromList('INI BUKAN PDF'.codeUnits),
        ),
      ],
    );

    await tester.tap(find.text('Pilih PDF'));
    await tester.pumpAndSettle();

    expect(service.preFinalCalls, 0);
    expect(find.text('Penempatan overlay'), findsNothing);
    expect(find.textContaining('Berkas bukan PDF valid'), findsOneWidget);
  });
}
