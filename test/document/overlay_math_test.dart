import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/pages/documents/overlay_placement_step.dart';

/// Kontrak matematika overlay (task 21) — konversi kanvas pt @72dpi ↔ mm
/// origin KIRI-BAWAH (kontrak `PdfStamper` service document) dengan angka
/// konkret, preset posisi, clamp, dan bentuk payload backend.
void main() {
  group('OverlayMath pt ↔ mm', () {
    test('1 pt = 25.4/72 mm eksak; A4 = 210 × 297 mm', () {
      expect(OverlayMath.ptToMm(72), 25.4);
      expect(OverlayMath.mmToPt(25.4), closeTo(72, 1e-9));
      // A4 595.28 × 841.89 pt.
      expect(OverlayMath.pageWidthMm(595.28), closeTo(210, 0.01));
      expect(OverlayMath.pageHeightMm(841.89), closeTo(297, 0.01));
    });

    test('top-left pt kanvas → mm origin kiri-bawah: tepi BAWAH gambar ke '
        'tepi bawah halaman', () {
      // A4, QR 25×25 mm dengan tepi bawah 15 mm dari bawah halaman:
      // topPt = pageHeightPt - mm(15) - mm(25) ≈ 728.50 pt.
      final heightPt = OverlayMath.mmToPt(25); // 70.866 pt
      final yPt = OverlayMath.mmToPt(15); // 42.520 pt
      final topPt = 841.89 - yPt - heightPt;
      final mm = OverlayMath.fromTopLeftPt(
        leftPt: 0,
        topPt: topPt,
        heightPt: heightPt,
        pageHeightPt: 841.89,
      );
      expect(mm.xMm, closeTo(0, 1e-6));
      expect(mm.yMm, closeTo(15, 0.01));
    });

    test('mm → top-left pt (render) round-trip', () {
      final box = OverlayMath.toTopLeftPt(
        xMm: 105,
        yMm: 150,
        widthMm: 25,
        heightMm: 25,
        pageHeightPt: 841.89,
      );
      // y=150mm dari bawah → jarak dari atas = 297 - 150 - 25 = 122 mm.
      expect(OverlayMath.ptToMm(box.topPt), closeTo(122, 0.01));
      expect(OverlayMath.ptToMm(box.leftPt), closeTo(105, 0.01));
      expect(OverlayMath.ptToMm(box.widthPt), closeTo(25, 0.01));

      final back = OverlayMath.fromTopLeftPt(
        leftPt: box.leftPt,
        topPt: box.topPt,
        heightPt: box.heightPt,
        pageHeightPt: 841.89,
      );
      expect(back.xMm, closeTo(105, 1e-6));
      expect(back.yMm, closeTo(150, 0.01));
    });

    test('drag delta pt → mm (y layar ke bawah = y mm berkurang)', () {
      final item = OverlayItem(
        id: 'qr',
        kind: OverlayKind.qr,
        page: 1,
        xMm: 100,
        yMm: 100,
        widthMm: 25,
        aspectRatio: 1,
        pngBytes: Uint8List(0),
      );
      const pageWidthMm = 210.0;
      const pageHeightMm = 297.0;
      final tenMmPt = OverlayMath.mmToPt(10);

      final moved = OverlayMath.moveByPtDelta(
        item,
        dxPt: tenMmPt,
        dyPt: -tenMmPt, // drag ke atas layar → y mm bertambah
        pageWidthMm: pageWidthMm,
        pageHeightMm: pageHeightMm,
      );
      expect(moved.xMm, closeTo(110, 1e-9));
      expect(moved.yMm, closeTo(110, 1e-9));

      final movedDown = OverlayMath.moveByPtDelta(
        item,
        dxPt: 0,
        dyPt: tenMmPt, // drag ke bawah layar → y mm berkurang
        pageWidthMm: pageWidthMm,
        pageHeightMm: pageHeightMm,
      );
      expect(movedDown.yMm, closeTo(90, 1e-9));
    });

    test('drag melewati tepi halaman di-clamp ke dalam halaman', () {
      final item = OverlayItem(
        id: 'img',
        kind: OverlayKind.image,
        page: 1,
        xMm: 200,
        yMm: 280,
        widthMm: 25,
        aspectRatio: 0.5, // tinggi 12.5 mm
        pngBytes: Uint8List(0),
      );
      final moved = OverlayMath.moveByPtDelta(
        item,
        dxPt: OverlayMath.mmToPt(50),
        dyPt: -OverlayMath.mmToPt(50),
        pageWidthMm: 210,
        pageHeightMm: 297,
      );
      expect(moved.xMm, 185); // 210 - 25
      expect(moved.yMm, closeTo(284.5, 1e-9)); // 297 - 12.5
    });
  });

  group('preset posisi (ponsel)', () {
    test('kanan-bawah / kiri-bawah / tengah A4 margin 12 mm', () {
      const pageW = 210.0;
      const pageH = 297.0;
      final bottomRight = OverlayMath.presetPosition(
        OverlayPreset.bottomRight,
        widthMm: 25,
        aspectRatio: 1,
        pageWidthMm: pageW,
        pageHeightMm: pageH,
      );
      expect(bottomRight.xMm, 173); // 210 - 25 - 12
      expect(bottomRight.yMm, 12);

      final bottomLeft = OverlayMath.presetPosition(
        OverlayPreset.bottomLeft,
        widthMm: 25,
        aspectRatio: 1,
        pageWidthMm: pageW,
        pageHeightMm: pageH,
      );
      expect(bottomLeft.xMm, 12);
      expect(bottomLeft.yMm, 12);

      final center = OverlayMath.presetPosition(
        OverlayPreset.center,
        widthMm: 25,
        aspectRatio: 1,
        pageWidthMm: pageW,
        pageHeightMm: pageH,
      );
      expect(center.xMm, 92.5); // (210 - 25) / 2
      expect(center.yMm, 136); // (297 - 25) / 2
    });

    test('matchingPreset mengenali posisi preset & posisi custom', () {
      const pageW = 210.0;
      const pageH = 297.0;
      final onPreset = OverlayItem(
        id: 'qr',
        kind: OverlayKind.qr,
        page: 1,
        xMm: 173,
        yMm: 12,
        widthMm: 25,
        aspectRatio: 1,
        pngBytes: Uint8List(0),
      );
      expect(
        OverlayMath.matchingPreset(
          onPreset,
          pageWidthMm: pageW,
          pageHeightMm: pageH,
        ),
        {OverlayPreset.bottomRight},
      );

      final custom = OverlayItem(
        id: 'qr',
        kind: OverlayKind.qr,
        page: 1,
        xMm: 50,
        yMm: 120,
        widthMm: 25,
        aspectRatio: 1,
        pngBytes: Uint8List(0),
      );
      expect(
        OverlayMath.matchingPreset(
          custom,
          pageWidthMm: pageW,
          pageHeightMm: pageH,
        ),
        isEmpty,
      );
    });

    test('fitIntoPage: lebar & posisi di luar halaman dikembalikan ke dalam',
        () {
      final item = OverlayItem(
        id: 'img',
        kind: OverlayKind.image,
        page: 1,
        xMm: 500,
        yMm: -20,
        widthMm: 300,
        aspectRatio: 0.5,
        pngBytes: Uint8List(0),
      );
      final fitted = OverlayMath.fitIntoPage(
        item,
        pageWidthMm: 210,
        pageHeightMm: 297,
      );
      expect(fitted.widthMm, 210);
      expect(fitted.xMm, 0); // 210 - 210
      expect(fitted.yMm, 0);
    });
  });

  group('OverlayPayloads bentuk payload backend', () {
    test('item → {page, x_mm, y_mm, width_mm, image_base64} base64 polos',
        () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
      final items = [
        OverlayItem(
          id: 'qr-1',
          kind: OverlayKind.qr,
          page: 2,
          xMm: 173.006,
          yMm: 12,
          widthMm: 25,
          aspectRatio: 1,
          pngBytes: png,
        ),
      ];
      final payload = OverlayPayloads.toRequest(items);

      expect(payload, hasLength(1));
      // Persis kunci kontrak IssuanceController overlayRules.
      expect(payload[0].keys.toList(),
          ['page', 'x_mm', 'y_mm', 'width_mm', 'image_base64']);
      expect(payload[0]['page'], 2);
      expect(payload[0]['x_mm'], 173.01); // pembulatan 2 desimal.
      expect(payload[0]['y_mm'], 12.0);
      expect(payload[0]['width_mm'], 25.0);
      // Base64 polos (tanpa prefiks data:) — decode mengembalikan PNG.
      expect(payload[0]['image_base64'], base64Encode(png));
      expect(
        base64Decode(payload[0]['image_base64'] as String),
        png,
      );
    });
  });
}
