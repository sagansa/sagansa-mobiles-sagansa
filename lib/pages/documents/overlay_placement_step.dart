import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// Jenis overlay yang bisa ditempel ke PDF (Mode B) — `qr` menempel QR
/// verifikasi (dibuat klien, menunjuk UUID surat), `image` menempel gambar
/// bebas PNG (mis. TTD scan / meterai visual), `signature` menempel aset
/// tanda tangan tersimpan milik penandatangan (fase 1c).
enum OverlayKind { qr, image, signature }

/// Preset posisi overlay (ponsel) — koordinat mm dihitung [OverlayMath].
enum OverlayPreset { bottomRight, bottomLeft, center }

extension OverlayPresetX on OverlayPreset {
  String get label {
    switch (this) {
      case OverlayPreset.bottomRight:
        return 'Kanan bawah';
      case OverlayPreset.bottomLeft:
        return 'Kiri bawah';
      case OverlayPreset.center:
        return 'Tengah';
    }
  }
}

/// Satu overlay yang ditempel ke halaman PDF.
///
/// Kontrak koordinat PERSIS backend (`PdfStamper` service document):
/// satuan mm, origin KIRI-BAWAH halaman — [xMm] jarak tepi KIRI gambar dari
/// tepi kiri halaman, [yMm] jarak tepi BAWAH gambar dari tepi bawah halaman.
/// Tinggi tampilan server = [widthMm] × rasio piksel gambar ([aspectRatio]
/// = tinggi/lebar) — rasio aspek klien ikut mengirim width saja.
class OverlayItem {
  final String id;
  final OverlayKind kind;
  final int page; // 1-based
  final double xMm;
  final double yMm;
  final double widthMm;
  final double aspectRatio;

  /// PNG overlay (server FPDI menempel tipe 'PNG' — semua gambar klien
  /// dijamin PNG; QR qr_flutter memang PNG, gambar galeri di-encode ulang).
  final Uint8List pngBytes;

  const OverlayItem({
    required this.id,
    required this.kind,
    required this.page,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.aspectRatio,
    required this.pngBytes,
  });

  double get heightMm => widthMm * aspectRatio;

  OverlayItem copyWith({
    String? id,
    OverlayKind? kind,
    int? page,
    double? xMm,
    double? yMm,
    double? widthMm,
    double? aspectRatio,
    Uint8List? pngBytes,
  }) {
    return OverlayItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      page: page ?? this.page,
      xMm: xMm ?? this.xMm,
      yMm: yMm ?? this.yMm,
      widthMm: widthMm ?? this.widthMm,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      pngBytes: pngBytes ?? this.pngBytes,
    );
  }
}

/// Info halaman PDF hasil parse — ukuran tiap halaman dalam POINT PDF
/// (`pt`, 1 pt = 1/72 inci). A4 = 595.28 × 841.89 pt = 210 × 297 mm.
class PdfPagesInfo {
  final int pageCount;
  final List<({double widthPt, double heightPt})> pages;

  const PdfPagesInfo({required this.pageCount, required this.pages});

  /// Fallback A4 portrait bila dimensi halaman tak terbaca.
  static const ({double widthPt, double heightPt}) a4 =
      (widthPt: 595.28, heightPt: 841.89);

  ({double widthPt, double heightPt}) pageAt(int pageNumber) {
    if (pageNumber < 1 || pageNumber > pages.length) return a4;
    return pages[pageNumber - 1];
  }
}

/// Hasil decode gambar pilihan → PNG siap kirim + rasio aspeknya.
class OverlayImageData {
  final Uint8List png;
  final double aspectRatio; // tinggi / lebar

  const OverlayImageData({required this.png, required this.aspectRatio});

  /// Bungkus bytes PNG yang SUDAH tervalidasi (mis. aset TTD tersimpan dari
  /// server) tanpa decode ulang; rasio dibaca dari header IHDR.
  /// Null bila bytes bukan PNG sah.
  static OverlayImageData? fromPngBytes(Uint8List bytes) {
    const magic = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    if (bytes.length < 24) return null;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return null;
    }
    // Chunk pertama PNG wajib IHDR (offset 12..15).
    if (bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return null;
    }

    final header = ByteData.sublistView(bytes);
    final width = header.getUint32(16);
    final height = header.getUint32(20);

    if (width == 0 || height == 0) return null;

    return OverlayImageData(png: bytes, aspectRatio: height / width);
  }
}

/// Matematika konversi kanvas (pt @72dpi) ↔ mm origin kiri-bawah.
///
/// Kanvas penempatan menggambar halaman sebagai kotak logis berukuran
/// `widthPt × heightPt` (72 dpi → A4 ≈ 595×842 logis px; gambar render
/// di-`BoxFit.fill` ke kotak ini sehingga resolusi render bebas mempengaruhi
/// ketajaman saja). Skala mm/pt EKSAK: 25.4 / 72 — untuk halaman A4 hasil
/// konversi 210 × 297 mm tepat.
class OverlayMath {
  static const double mmPerPt = 25.4 / 72;

  /// 1 pt = 25.4/72 mm ≈ 0.352778 mm.
  static double ptToMm(double pt) => pt * mmPerPt;

  static double mmToPt(double mm) => mm / mmPerPt;

  static double pageWidthMm(double widthPt) => ptToMm(widthPt);

  static double pageHeightMm(double heightPt) => ptToMm(heightPt);

  /// Pembulatan payload 2 desimal (backend validasi numeric saja; ini
  /// menjaga JSON rapi tanpa noise floating point).
  static double roundMm(double mm) => (mm * 100).roundToDouble() / 100;

  /// Konversi posisi kotak overlay (koordinat kanvas top-left, pt) ke
  /// kontrak server (origin kiri-bawah, mm): y dihitung dari tepi BAWAH
  /// gambar ke tepi bawah halaman.
  static ({double xMm, double yMm}) fromTopLeftPt({
    required double leftPt,
    required double topPt,
    required double heightPt,
    required double pageHeightPt,
  }) {
    final bottomPt = pageHeightPt - topPt - heightPt;
    return (xMm: ptToMm(leftPt), yMm: ptToMm(bottomPt));
  }

  /// Inverse [fromTopLeftPt] — posisi mm server → kotak top-left pt kanvas
  /// (dipakai me-render overlay di atas halaman).
  static ({double leftPt, double topPt, double widthPt, double heightPt})
      toTopLeftPt({
    required double xMm,
    required double yMm,
    required double widthMm,
    required double heightMm,
    required double pageHeightPt,
  }) {
    final widthPt = mmToPt(widthMm);
    final heightPt = mmToPt(heightMm);
    final bottomPt = mmToPt(yMm);
    return (
      leftPt: mmToPt(xMm),
      topPt: pageHeightPt - bottomPt - heightPt,
      widthPt: widthPt,
      heightPt: heightPt,
    );
  }

  /// Geser overlay oleh delta drag kanvas (pt, y ke bawah) → mm baru,
  /// di-clamp agar gambar tetap di dalam halaman.
  static OverlayItem moveByPtDelta(
    OverlayItem item, {
    required double dxPt,
    required double dyPt,
    required double pageWidthMm,
    required double pageHeightMm,
  }) {
    return fitIntoPage(
      item.copyWith(
        xMm: item.xMm + ptToMm(dxPt),
        // Kanvas y ke bawah, server y ke atas → delta berlawanan tanda.
        yMm: item.yMm - ptToMm(dyPt),
      ),
      pageWidthMm: pageWidthMm,
      pageHeightMm: pageHeightMm,
    );
  }

  /// Clamp posisi (dan lebar) agar overlay seluruhnya berada di halaman.
  static OverlayItem fitIntoPage(
    OverlayItem item, {
    required double pageWidthMm,
    required double pageHeightMm,
  }) {
    final width = item.widthMm.clamp(1.0, pageWidthMm);
    final height = width * item.aspectRatio;
    final x = item.xMm.clamp(0.0, pageWidthMm - width);
    final y = item.yMm.clamp(0.0, pageHeightMm - height);
    return item.copyWith(xMm: x, yMm: y, widthMm: width);
  }

  /// Posisi mm preset (ponsel): [marginMm] dari tepi halaman.
  static ({double xMm, double yMm}) presetPosition(
    OverlayPreset preset, {
    required double widthMm,
    required double aspectRatio,
    required double pageWidthMm,
    required double pageHeightMm,
    double marginMm = 12,
  }) {
    final heightMm = widthMm * aspectRatio;
    switch (preset) {
      case OverlayPreset.bottomRight:
        return (
          xMm: pageWidthMm - widthMm - marginMm,
          yMm: marginMm,
        );
      case OverlayPreset.bottomLeft:
        return (xMm: marginMm, yMm: marginMm);
      case OverlayPreset.center:
        return (
          xMm: (pageWidthMm - widthMm) / 2,
          yMm: (pageHeightMm - heightMm) / 2,
        );
    }
  }

  /// Preset yang cocok dengan posisi item saat ini (untuk keadaan awal
  /// SegmentedButton; empty = posisi custom hasil drag).
  static Set<OverlayPreset> matchingPreset(
    OverlayItem item, {
    required double pageWidthMm,
    required double pageHeightMm,
    double marginMm = 12,
    double epsilon = 0.5,
  }) {
    bool close(double a, double b) => (a - b).abs() <= epsilon;
    for (final preset in OverlayPreset.values) {
      final pos = presetPosition(
        preset,
        widthMm: item.widthMm,
        aspectRatio: item.aspectRatio,
        pageWidthMm: pageWidthMm,
        pageHeightMm: pageHeightMm,
        marginMm: marginMm,
      );
      if (close(pos.xMm, item.xMm) && close(pos.yMm, item.yMm)) {
        return {preset};
      }
    }
    return const {};
  }
}

/// Builder payload overlay bentuk PERSIS backend (IssuanceController):
/// `{page, x_mm, y_mm, width_mm, image_base64}` — base64 polos PNG TANPA
/// prefiks `data:` (backend `base64_decode` + `getimagesizefromstring`).
///
/// [image_base64] selalu dikirim agar posisi QR custom — bila klien tidak
/// mengirim overlay sama sekali, backend menempel QR default posisi tetap.
class OverlayPayloads {
  static List<Map<String, dynamic>> toRequest(List<OverlayItem> items) {
    return items
        .map((item) => <String, dynamic>{
              'page': item.page,
              'x_mm': OverlayMath.roundMm(item.xMm),
              'y_mm': OverlayMath.roundMm(item.yMm),
              'width_mm': OverlayMath.roundMm(item.widthMm),
              'image_base64': base64Encode(item.pngBytes),
            })
        .toList(growable: false);
  }
}

/// Langkah penempatan overlay di atas PDF terunggah (Mode B).
///
/// Tablet (lebar ≥700): kanvas `InteractiveViewer` — halaman digambar
/// berukuran `widthPt × heightPt` logis (72 dpi) sebagai latar; tiap overlay
/// `Positioned` dari mm → pt dan bisa digeser (drag = delta pt → mm; skala
/// ekzak 25.4/72). Pinch/scroll = zoom-pan kanvas; drag pada overlay hanya
/// menggeser overlay (gesture arena: recognizer anak menang).
///
/// Ponsel: preset posisi per item (kanan-bawah / kiri-bawah / tengah) +
/// pilih halaman + slider lebar.
///
/// Widget UI murni: pembuatan QR, pemilihan gambar, dan panggilan API
/// di-orkestrasi `DocumentUploadPage` lewat callback/seam.
class StepOverlayPlacement extends StatefulWidget {
  static const double wideBreakpoint = 700;

  final PdfPagesInfo pagesInfo;
  final int activePage;
  final ValueChanged<int> onPageChanged;

  final List<OverlayItem> overlays;
  final String? selectedId;
  final void Function(OverlayItem item) onSelectOverlay;
  final void Function(OverlayItem updated) onUpdateOverlay;

  /// Drag kanvas tablet: delta pt untuk item by id — diterapkan pada item
  /// TERKINI (bukan instance [OverlayItem] yang mungkin basi di widget).
  final void Function(String itemId, double dxPt, double dyPt) onDragOverlay;
  final void Function(OverlayItem item) onRemoveOverlay;

  final VoidCallback onAddQr;
  final VoidCallback onAddImage;
  final VoidCallback? onAddSignature;
  final bool addingImage;
  final bool addingSignature;

  /// Render halaman aktif (kosmetik — null saat masih merender; kotak pt
  /// tetap digambar sehingga drag/preset tetap presisi).
  final ui.Image? pageImage;

  const StepOverlayPlacement({
    super.key,
    required this.pagesInfo,
    required this.activePage,
    required this.onPageChanged,
    required this.overlays,
    required this.selectedId,
    required this.onSelectOverlay,
    required this.onUpdateOverlay,
    required this.onDragOverlay,
    required this.onRemoveOverlay,
    required this.onAddQr,
    required this.onAddImage,
    this.onAddSignature,
    required this.addingImage,
    this.addingSignature = false,
    this.pageImage,
  });

  @override
  State<StepOverlayPlacement> createState() => _StepOverlayPlacementState();
}

class _StepOverlayPlacementState extends State<StepOverlayPlacement> {
  /// Pointer sedang menekan overlay → pan/zoom kanvas dimatikan sesaat
  /// agar drag overlay tidak ikut menggeser halaman (lihat _CanvasOverlay).
  bool _overlayDragActive = false;

  void _blockCanvas() {
    if (!_overlayDragActive) setState(() => _overlayDragActive = true);
  }

  void _unblockCanvas() {
    if (_overlayDragActive) setState(() => _overlayDragActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >=
        StepOverlayPlacement.wideBreakpoint;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildCanvas(context)),
          VerticalDivider(
            width: 1,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.3),
          ),
          SizedBox(width: 320, child: _buildPanel(context)),
        ],
      );
    }
    return _buildPanel(context);
  }

  // ——— kanvas (tablet) ———

  Widget _buildCanvas(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final page = widget.pagesInfo.pageAt(widget.activePage);
    final pageOverlays = widget.overlays
        .where((item) => item.page == widget.activePage)
        .toList();

    return InteractiveViewer(
      constrained: false,
      maxScale: 8,
      minScale: 0.2,
      // Saat jari menekan overlay, kanvas diam — delta pointer milik overlay.
      panEnabled: !_overlayDragActive,
      scaleEnabled: !_overlayDragActive,
      boundaryMargin: const EdgeInsets.all(600),
      child: SizedBox(
        width: page.widthPt,
        height: page.heightPt,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.pageImage != null)
              Positioned.fill(
                child: RawImage(image: widget.pageImage, fit: BoxFit.fill),
              )
            else
              Positioned.fill(
                child: ColoredBox(
                  color: colorScheme.surfaceContainerLowest,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            for (final item in pageOverlays)
              _CanvasOverlay(
                key: ValueKey('canvas-overlay-${item.id}'),
                item: item,
                page: page,
                selected: widget.selectedId == item.id,
                onTap: () => widget.onSelectOverlay(item),
                onRemove: () => widget.onRemoveOverlay(item),
                onPanByPtDelta: widget.onDragOverlay,
                onDragStart: _blockCanvas,
                onDragEnd: _unblockCanvas,
              ),
          ],
        ),
      ),
    );
  }

  // ——— panel item (ponsel penuh / tablet samping) ———

  Widget _buildPanel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Penempatan overlay',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _PageSelector(
              pageCount: widget.pagesInfo.pageCount,
              activePage: widget.activePage,
              onChanged: widget.onPageChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'QR verifikasi ditampilkan pada hasil cetak agar penerima bisa '
          'memeriksa keaslian surat.',
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onAddQr,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('QR verifikasi'),
            ),
            OutlinedButton.icon(
              onPressed: widget.addingImage ? null : widget.onAddImage,
              icon: widget.addingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: const Text('Gambar (TTD/meterai)'),
            ),
            if (widget.onAddSignature != null)
              OutlinedButton.icon(
                onPressed:
                    widget.addingSignature ? null : widget.onAddSignature,
                icon: widget.addingSignature
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gesture_rounded),
                label: const Text('Tanda tangan tersimpan'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.overlays.isEmpty)
          Text(
            'Belum ada overlay — QR verifikasi disarankan agar hasil '
            'pra-final bisa diperiksa.',
            style: textTheme.bodySmall,
          ),
        for (var i = 0; i < widget.overlays.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _OverlayCard(
              item: widget.overlays[i],
              pagesInfo: widget.pagesInfo,
              selected: widget.selectedId == widget.overlays[i].id,
              onTap: () => widget.onSelectOverlay(widget.overlays[i]),
              onChanged: widget.onUpdateOverlay,
              onRemoved: widget.onRemoveOverlay,
            ),
          ),
      ],
    );
  }
}

/// Pemilih halaman aktif (untuk kanvas & item baru) — halaman multi-PDF.
class _PageSelector extends StatelessWidget {
  final int pageCount;
  final int activePage;
  final ValueChanged<int> onChanged;

  const _PageSelector({
    required this.pageCount,
    required this.activePage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Halaman sebelumnya',
          onPressed: activePage > 1 ? () => onChanged(activePage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text('Hal. $activePage/$pageCount'),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Halaman berikutnya',
          onPressed:
              activePage < pageCount ? () => onChanged(activePage + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Kartu pengaturan satu overlay: preset posisi, halaman, slider lebar,
/// hapus. Dipakai ponsel (utama) & tablet (panel samping).
class _OverlayCard extends StatelessWidget {
  final OverlayItem item;
  final PdfPagesInfo pagesInfo;
  final bool selected;
  final VoidCallback onTap;
  final void Function(OverlayItem updated) onChanged;
  final void Function(OverlayItem item) onRemoved;

  const _OverlayCard({
    required this.item,
    required this.pagesInfo,
    required this.selected,
    required this.onTap,
    required this.onChanged,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final page = pagesInfo.pageAt(item.page);
    final pageWidthMm = OverlayMath.pageWidthMm(page.widthPt);
    final pageHeightMm = OverlayMath.pageHeightMm(page.heightPt);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        side: selected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: AppSpacing.paddingSM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (item.kind) {
                    OverlayKind.qr => Icons.qr_code_2_rounded,
                    OverlayKind.signature => Icons.gesture_rounded,
                    OverlayKind.image => Icons.image_outlined,
                  },
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    switch (item.kind) {
                      OverlayKind.qr => 'QR verifikasi',
                      OverlayKind.signature => 'Tanda tangan tersimpan',
                      OverlayKind.image => 'Gambar (TTD/meterai)',
                    },
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (pagesInfo.pageCount > 1)
                  DropdownButton<int>(
                    value: item.page,
                    underline: const SizedBox.shrink(),
                    borderRadius: AppSpacing.borderRadiusMD,
                    items: [
                      for (var n = 1; n <= pagesInfo.pageCount; n++)
                        DropdownMenuItem(value: n, child: Text('Hal. $n')),
                    ],
                    onChanged: (value) {
                      if (value == null || value == item.page) return;
                      onChanged(item.copyWith(page: value));
                    },
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hapus overlay',
                  onPressed: () => onRemoved(item),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<OverlayPreset>(
              emptySelectionAllowed: true,
              selected: OverlayMath.matchingPreset(
                item,
                pageWidthMm: pageWidthMm,
                pageHeightMm: pageHeightMm,
              ),
              segments: [
                for (final preset in OverlayPreset.values)
                  ButtonSegment(
                    value: preset,
                    label: Text(preset.label),
                  ),
              ],
              onSelectionChanged: (selection) {
                final preset = selection.firstOrNull;
                if (preset == null) return;
                final pos = OverlayMath.presetPosition(
                  preset,
                  widthMm: item.widthMm,
                  aspectRatio: item.aspectRatio,
                  pageWidthMm: pageWidthMm,
                  pageHeightMm: pageHeightMm,
                );
                onChanged(item.copyWith(xMm: pos.xMm, yMm: pos.yMm));
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: item.widthMm.clamp(10, 80).toDouble(),
                    min: 10,
                    max: 80,
                    divisions: 70,
                    label: '${item.widthMm.round()} mm',
                    onChanged: (value) => onChanged(
                      OverlayMath.fitIntoPage(
                        item.copyWith(widthMm: value),
                        pageWidthMm: pageWidthMm,
                        pageHeightMm: pageHeightMm,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text(
                    'Lebar ${item.widthMm.round()} mm',
                    textAlign: TextAlign.end,
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            Text(
              'x ${OverlayMath.roundMm(item.xMm)} mm • '
              'y ${OverlayMath.roundMm(item.yMm)} mm (dari kiri-bawah)',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu overlay di kanvas: `Positioned` dari mm → pt, drag menggeser
/// (delta pt dikonversi mm), tap memilih (slider lebar di panel).
///
/// Input pakai [Listener] mentah, bukan GestureDetector: overlay hidup
/// DI DALAM `InteractiveViewer` yang mendaftarkan scale recognizer — pan
/// recognizer anak kalah cepat di gesture arena saat touch slop terlampaui
/// (scale IV menerima duluan) sehingga onPanUpdate tak pernah terpanggil.
/// `Listener` menerima semua pointer event tanpa arena; sebagai gantinya
/// kanvas mematikan pan/zoom-nya (onDragStart/End) selama jari menekan
/// overlay. Delta dihitung dari `localPosition` (ruang koordinat anak —
/// zoom kanvas ikut terkompensasi otomatis).
class _CanvasOverlay extends StatefulWidget {
  final OverlayItem item;
  final ({double widthPt, double heightPt}) page;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// Delta drag (pt kanvas) untuk item [OverlayItem.id] — diterapkan parent
  /// pada versi item TERBARU (lihat catatan stale di _CanvasOverlayState).
  final void Function(String itemId, double dxPt, double dyPt) onPanByPtDelta;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _CanvasOverlay({
    super.key,
    required this.item,
    required this.page,
    required this.selected,
    required this.onTap,
    required this.onRemove,
    required this.onPanByPtDelta,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<_CanvasOverlay> createState() => _CanvasOverlayState();
}

class _CanvasOverlayState extends State<_CanvasOverlay> {
  Offset? _lastLocal;
  Offset? _downLocal;

  bool get _dragging => _lastLocal != null;

  void _onPointerDown(PointerDownEvent event) {
    _lastLocal = event.localPosition;
    _downLocal = event.localPosition;
    widget.onDragStart();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final last = _lastLocal;
    if (last == null) return;
    final delta = event.localPosition - last;
    _lastLocal = event.localPosition;
    if (delta != Offset.zero) {
      // Delta dikirim mentah — parent menerapkannya pada item TERKINI di
      // list miliknya (widget.item di sini bisa basi bila dua move tiba
      // sebelum rebuild berikutnya).
      widget.onPanByPtDelta(widget.item.id, delta.dx, delta.dy);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downLocal;
    _lastLocal = null;
    _downLocal = null;
    widget.onDragEnd();
    // Tanpa pergerakan berarti tap → pilih overlay (slider lebar panel).
    final moved =
        down != null && (event.localPosition - down).distance > kTouchSlop;
    if (!moved) widget.onTap();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _lastLocal = null;
    _downLocal = null;
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final box = OverlayMath.toTopLeftPt(
      xMm: widget.item.xMm,
      yMm: widget.item.yMm,
      widthMm: widget.item.widthMm,
      heightMm: widget.item.heightMm,
      pageHeightPt: widget.page.heightPt,
    );

    return Positioned(
      left: box.leftPt,
      top: box.topPt,
      width: box.widthPt,
      height: box.heightPt,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _dragging || widget.selected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: widget.selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Image.memory(
                  widget.item.pngBytes,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  // Gambar tak terdekode → kotak abu; kanvas & math tetap
                  // jalan (posisi mm sumber kebenaran, bukan render).
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
            // Tombol hapus kecil di pojok kanan-atas overlay terpilih.
            if (widget.selected)
              Positioned(
                right: -12,
                top: -12,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    tooltip: 'Hapus overlay',
                    onPressed: widget.onRemove,
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 24,
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
