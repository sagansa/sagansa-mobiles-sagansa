import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/pages/documents/document_upload_page.dart';
import 'package:sagansa/pages/documents/overlay_placement_step.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';

/// Fase 1c — sumber overlay "Tanda tangan tersimpan" di Mode B:
/// direktori signer disaring `hasSignature`, bytes PNG diunduh lewat
/// `getSignatureBytes`, lalu menjadi overlay 45mm di halaman aktif.

/// PNG 1×1 px valid (aspek 1.0).
final Uint8List _png1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

final Uint8List _pdfBytes =
    Uint8List.fromList('%PDF-1.4\nfake body\n'.codeUnits);

class _FakeSignatureService extends DocumentService {
  List<SignerModel> signersToReturn = const <SignerModel>[];
  Uint8List signatureBytes = _png1x1;

  int getSignersCalls = 0;
  int signatureBytesCalls = 0;
  int? lastSignerId;

  Map<String, dynamic>? lastPreFinalResult;
  List<Map<String, dynamic>>? lastPreFinalOverlays;

  @override
  Future<List<SignerModel>> getSigners() async {
    getSignersCalls++;
    return signersToReturn;
  }

  @override
  Future<Uint8List> getSignatureBytes(int signerId) async {
    signatureBytesCalls++;
    lastSignerId = signerId;
    return signatureBytes;
  }

  @override
  Future<Map<String, dynamic>> reserveNumber(String id) async =>
      {'number': '017/KUA/X/2026', 'seq': 17};

  @override
  Future<Map<String, dynamic>> preFinal(
    String id, {
    required String mode,
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
  }) async {
    lastPreFinalOverlays = overlays;
    lastPreFinalResult = {
      'download_url': 'https://example.com/pre-final.pdf',
      'expires_in': 900,
    };
    return lastPreFinalResult!;
  }
}

Future<void> _pumpPlacement(
  WidgetTester tester,
  _FakeSignatureService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DocumentUploadPage(
        documentId: 'doc-1',
        documentSubject: 'Kuasa pengurusan pajak',
        mode: DocumentUploadMode.uploadDraft,
        service: service,
        pickPdf: () async => PickedPdf(name: 'surat.pdf', bytes: _pdfBytes),
        pickImages: () async => const <PickedPhoto>[],
        fetchUrl: (url) async => _pdfBytes,
        openPdfInfo: (bytes) async => const PdfPagesInfo(
          pageCount: 1,
          pages: [(widthPt: 595.28, heightPt: 841.89)],
        ),
        buildQrPng: (data) async => _png1x1,
        previewBuilder: (context, bytes) =>
            const SizedBox(height: 24, child: Text('PREVIEW-OK')),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih PDF'));
  await tester.pumpAndSettle();
  expect(find.text('Penempatan overlay'), findsOneWidget);
}

const _rina = SignerModel(
  id: 2,
  role: 'komisaris',
  displayName: 'Rina Komisaris',
  title: 'Komisaris Utama',
  hasSignature: true,
);

const _dira = SignerModel(
  id: 1,
  role: 'direktur',
  displayName: 'Dira Direktur',
);

void main() {
  group('OverlayImageData.fromPngBytes', () {
    test('membaca rasio aspek dari header IHDR', () {
      final data = OverlayImageData.fromPngBytes(_png1x1);

      expect(data, isNotNull);
      expect(data!.png, same(_png1x1));
      expect(data.aspectRatio, 1.0);
    });

    test('menolak bytes yang bukan PNG', () {
      expect(
        OverlayImageData.fromPngBytes(Uint8List.fromList('%PDF'.codeUnits)),
        isNull,
      );
      expect(OverlayImageData.fromPngBytes(Uint8List(0)), isNull);
      expect(
        OverlayImageData.fromPngBytes(Uint8List.fromList([1, 2, 3, 4])),
        isNull,
      );
    });
  });

  testWidgets('memilih signer tersimpan menambah overlay 45mm & mengirim '
      'bytes aset ke payload pra-final', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeSignatureService()
      ..signersToReturn = const [_dira, _rina];

    await _pumpPlacement(tester, service);

    // Sumber ketiga tampil di samping QR & galeri.
    expect(find.text('Tanda tangan tersimpan'), findsOneWidget);

    await tester.tap(find.text('Tanda tangan tersimpan'));
    await tester.pumpAndSettle();

    // Sheet hanya memuat signer ber-aset TTD.
    expect(find.text('Pilih tanda tangan tersimpan'), findsOneWidget);
    expect(find.text('Rina Komisaris'), findsOneWidget);
    expect(find.text('Komisaris · Komisaris Utama'), findsOneWidget);
    expect(find.text('Dira Direktur'), findsNothing);

    await tester.tap(find.text('Rina Komisaris'));
    await tester.pumpAndSettle();

    expect(service.getSignersCalls, 1);
    expect(service.signatureBytesCalls, 1);
    expect(service.lastSignerId, 2);

    // Overlay baru terpilih: kartu pengaturan + tombol sumber.
    expect(find.text('Tanda tangan tersimpan'), findsNWidgets(2));

    await tester.tap(find.text('Buat pra-final'));
    await tester.pumpAndSettle();

    final overlays = service.lastPreFinalOverlays;
    expect(overlays, isNotNull);

    final signatureOverlay = overlays!.firstWhere(
      (overlay) => overlay['width_mm'] == 45.0,
    );
    expect(signatureOverlay['page'], 1);
    expect(signatureOverlay['image_base64'], base64Encode(_png1x1));
  });

  testWidgets('signer tanpa aset TTD tidak ditawarkan (pesan jelas)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _FakeSignatureService()
      ..signersToReturn = const [_dira];

    await _pumpPlacement(tester, service);

    await tester.tap(find.text('Tanda tangan tersimpan'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Belum ada tanda tangan tersimpan'),
      findsOneWidget,
    );
    expect(find.text('Pilih tanda tangan tersimpan'), findsNothing);
    expect(service.signatureBytesCalls, 0);
  });
}
