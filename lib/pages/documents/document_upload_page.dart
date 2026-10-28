import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/document/document_models.dart';
import '../../services/document/document_service.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/error_utils.dart';
import '../../widgets/app_page_scaffold.dart';
import '../../widgets/app_snackbar.dart';
import 'document_detail_page.dart';
import 'overlay_placement_step.dart';

/// Mode halaman upload (task 21):
/// - [uploadDraft]: PDF sendiri + penempatan overlay → pra-final (mode b)
///   → lanjutan C (unggah final ber-e-materai/TTE) atau D (foto ttd basah).
/// - [reissue]: terbitkan ulang surat `terbit` — [reissueMethod] b/c/d
///   (note alasan WAJIB dikumpulkan sebelum submit).
enum DocumentUploadMode { uploadDraft, reissue }

/// Hasil pemilih PDF satu berkas (seam injeksi test).
class PickedPdf {
  final String name;
  final Uint8List bytes;

  const PickedPdf({required this.name, required this.bytes});
}

/// Foto/scan terpilih (seam injeksi test) — path dipakai kompresi & multipart.
class PickedPhoto {
  final String path;
  final String name;

  const PickedPhoto({required this.path, required this.name});
}

/// Halaman alur Mode B/C/D (task 21).
///
/// Mode B (uploadDraft): pilih PDF → penempatan overlay (QR verifikasi +
/// gambar TTD/meterai; tablet kanvas drag, ponsel preset) → `preFinal`
/// mode b → pratinjau + bagikan → dua lanjutan:
/// C `finalize` metode c (PDF final TANPA overlay — guard 409 server),
/// D `finalizeManual` multipart foto + note opsional.
///
/// Mode reissue (dari kartu arsip "Terbitkan ulang"): sama per metode tapi
/// bermuara `reissue` + note WAJIB (metode d kirim `images_base64` hasil
/// kompresi JPEG — reissue backend hanya menerima JSON, bukan multipart).
///
/// [service] & berbagai seam fungsi (pick/compress/fetch/render) injeksi
/// test — produksi memakai implementasi default di bawah.
class DocumentUploadPage extends StatefulWidget {
  final String documentId;
  final String documentSubject;
  final DocumentUploadMode mode;

  /// 'b' | 'c' | 'd' — wajib untuk [DocumentUploadMode.reissue].
  final String reissueMethod;

  final DocumentService? service;

  final Future<PickedPdf?> Function()? pickPdf;
  final Future<List<PickedPhoto>> Function()? pickImages;
  final Future<Uint8List> Function(String url)? fetchUrl;
  final Future<PdfPagesInfo?> Function(Uint8List bytes)? openPdfInfo;
  final Future<Uint8List?> Function(String data)? buildQrPng;
  final Future<OverlayImageData?> Function(Uint8List bytes)? decodeImageToPng;
  final Future<Uint8List?> Function(String path)? compressImage;
  final Future<File> Function(Uint8List bytes, String name)? writeTempFile;
  final Widget Function(BuildContext context, Uint8List bytes)? previewBuilder;

  const DocumentUploadPage({
    super.key,
    required this.documentId,
    required this.documentSubject,
    required this.mode,
    this.reissueMethod = 'b',
    this.service,
    this.pickPdf,
    this.pickImages,
    this.fetchUrl,
    this.openPdfInfo,
    this.buildQrPng,
    this.decodeImageToPng,
    this.compressImage,
    this.writeTempFile,
    this.previewBuilder,
  });

  @override
  State<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  late final DocumentService _service = widget.service ?? DocumentService();
  late final Future<PickedPdf?> Function() _pickPdf =
      widget.pickPdf ?? _pickPdfDefault;
  late final Future<List<PickedPhoto>> Function() _pickImages =
      widget.pickImages ?? _pickImagesDefault;
  late final Future<Uint8List> Function(String url) _fetchUrl =
      widget.fetchUrl ?? _fetchUrlDefault;
  late final Future<PdfPagesInfo?> Function(Uint8List) _openPdfInfo =
      widget.openPdfInfo ?? _openPdfInfoDefault;
  late final Future<Uint8List?> Function(String data) _buildQrPng =
      widget.buildQrPng ?? _buildQrPngDefault;
  late final Future<OverlayImageData?> Function(Uint8List) _decodeImageToPng =
      widget.decodeImageToPng ?? _decodeImageToPngDefault;
  late final Future<Uint8List?> Function(String path) _compressImage =
      widget.compressImage ?? _compressImageDefault;
  late final Future<File> Function(Uint8List, String) _writeTempFile =
      widget.writeTempFile ?? _writeTempFileDefault;
  late final Widget Function(BuildContext, Uint8List) _buildPreview =
      widget.previewBuilder ?? _buildPreviewDefault;

  /// URL verifikasi QR klien — UUID surat (bukan nomor), pola response
  /// `verify_url` backend: `{document.domain}/verify/{id}`.
  late final String _verifyUrl =
      '${ApiConstants.documentBaseUrl}/verify/${widget.documentId}';

  static const _stagePick = 0;
  static const _stagePlace = 1;
  static const _stagePreview = 2;

  int _stage = _stagePick;
  bool _picking = false;
  bool _submitting = false;
  bool _addingImage = false;
  bool _addingSignature = false;

  PickedPdf? _pdf;
  PdfPagesInfo? _pagesInfo;
  int _activePage = 1;
  ui.Image? _pageImage;

  final List<OverlayItem> _overlays = [];
  String? _selectedOverlayId;
  int _overlaySeq = 0;

  Uint8List? _previewBytes;
  final List<PickedPhoto> _photos = [];

  /// Nomor surat (Fix C1) — dipesan SEKALI sebelum pra-final pertama;
  /// tampil sebagai subjudul halaman & dipakai fallback dialog sukses.
  String? _reservedNumber;
  bool _reserveAttempted = false;

  bool get _isReissue => widget.mode == DocumentUploadMode.reissue;
  String get _method => _isReissue ? widget.reissueMethod : 'b';

  @override
  void initState() {
    super.initState();
    if (_isReissue && !_isValidMethod(_method)) {
      // Defensive: metode tidak dikenal tidak boleh membocorkan payload salah.
      throw ArgumentError.value(_method, 'reissueMethod', 'harus b, c, atau d');
    }
  }

  static bool _isValidMethod(String method) =>
      method == 'b' || method == 'c' || method == 'd';

  @override
  void dispose() {
    _pageImage?.dispose();
    super.dispose();
  }

  // ——— implementasi default seam (produksi) ———

  Future<PickedPdf?> _pickPdfDefault() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return null;
    return PickedPdf(name: file.name, bytes: await file.readAsBytes());
  }

  Future<List<PickedPhoto>> _pickImagesDefault() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    return [
      for (final file in files)
        if (file.path != null) PickedPhoto(path: file.path!, name: file.name),
    ];
  }

  Future<Uint8List> _fetchUrlDefault(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh berkas (${response.statusCode}).');
    }
    return response.bodyBytes;
  }

  Future<PdfPagesInfo?> _openPdfInfoDefault(Uint8List bytes) async {
    final doc = await PdfDocument.openData(bytes, sourceName: 'upload.pdf');
    try {
      final pages = <({double widthPt, double heightPt})>[];
      for (var n = 1; n <= doc.pages.length; n++) {
        final page = doc.pages[n - 1];
        pages.add((widthPt: page.width, heightPt: page.height));
      }
      return PdfPagesInfo(pageCount: pages.length, pages: pages);
    } finally {
      doc.dispose();
    }
  }

  /// QR verifikasi dibuat KLIEN (qr_flutter) lalu dikirim sebagai gambar
  /// overlay biasa — server menempelnya 1:1 (posisi klien menang; default
  /// QR server hanya berlaku bila overlays kosong).
  Future<Uint8List?> _buildQrPngDefault(String data) async {
    final byteData = await QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
    ).toImageData(512);
    return byteData?.buffer.asUint8List();
  }

  /// Gambar galeri apa pun → PNG (server FPDI hanya menempel 'PNG') +
  /// rasio aspek asli (tinggi tampilan server = lebar × rasio).
  Future<OverlayImageData?> _decodeImageToPngDefault(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) return null;
        return OverlayImageData(
          png: png.buffer.asUint8List(),
          aspectRatio: image.height / image.width,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Kompresi foto sebelum unggah: sisi panjang ≤1920 px, JPEG kualitas 80
  /// (foto kamera modern 3-8 MB turun ke ratusan KB) — penting khususnya
  /// untuk reissue d yang lewat JSON base64. `compressWithFile` menjaga
  /// rasio aspek (fit dalam minWidth×minHeight).
  Future<Uint8List?> _compressImageDefault(String path) async {
    return FlutterImageCompress.compressWithFile(
      path,
      minWidth: 1920,
      minHeight: 1080,
      quality: 80,
      format: CompressFormat.jpeg,
    );
  }

  Future<File> _writeTempFileDefault(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/sagansa-${DateTime.now().microsecondsSinceEpoch}-$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Widget _buildPreviewDefault(BuildContext context, Uint8List bytes) {
    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusMD,
      child: PdfViewer.data(
        bytes,
        sourceName: 'pra-final.pdf',
        params: PdfViewerParams(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
      ),
    );
  }

  // ——— alur: pilih & muat PDF ———

  Future<void> _pickAndLoadPdf({required bool toPlacement}) async {
    if (_picking || _submitting) return;
    setState(() => _picking = true);
    try {
      final picked = await _pickPdf();
      if (picked == null) return;
      if (!_looksLikePdf(picked.bytes)) {
        if (mounted) {
          showErrorSnackBar(
              context,
              'Berkas bukan PDF valid (magic %PDF '
              'tidak ditemukan).');
        }
        return;
      }
      final info = await _openPdfInfo(picked.bytes);
      if (info == null || info.pageCount < 1) {
        if (mounted) showErrorSnackBar(context, 'PDF tidak dapat dibaca.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _pdf = picked;
        _pagesInfo = info;
        _activePage = 1;
        if (toPlacement) _stage = _stagePlace;
      });
      if (toPlacement) {
        _ensureDefaultQrOverlay();
        _renderActivePage();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
            context, ErrorUtils.sanitize(e, fallback: 'Gagal memuat PDF.'));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  static bool _looksLikePdf(Uint8List bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

  /// Render halaman aktif sebagai latar kanvas (kosmetik; kotak pt +
  /// matematika mm berjalan tanpanya — hanya ketajaman yang berkurat).
  Future<void> _renderActivePage() async {
    final pdf = _pdf;
    if (pdf == null) return;
    try {
      final doc = await PdfDocument.openData(pdf.bytes, sourceName: pdf.name);
      try {
        final page = doc.pages[_activePage - 1];
        const targetWidth = 1240.0;
        final targetHeight =
            (targetWidth * page.height / page.width).roundToDouble();
        final rendered = await page.render(
          fullWidth: targetWidth,
          fullHeight: targetHeight,
        );
        if (rendered == null) return;
        final image = await rendered.createImage();
        rendered.dispose();
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _pageImage?.dispose();
          _pageImage = image;
        });
      } finally {
        doc.dispose();
      }
    } catch (_) {
      // Kosmetik: kanvas tetap fungsional dengan kotak pt polos.
    }
  }

  void _onActivePageChanged(int page) {
    setState(() => _activePage = page);
    _renderActivePage();
  }

  // ——— alur: overlay ———

  OverlayItem? _newOverlayAtPreset({
    required OverlayKind kind,
    required Uint8List png,
    required double aspectRatio,
    required OverlayPreset preset,
    required double widthMm,
  }) {
    final page = _pagesInfo?.pageAt(_activePage) ?? PdfPagesInfo.a4;
    final pos = OverlayMath.presetPosition(
      preset,
      widthMm: widthMm,
      aspectRatio: aspectRatio,
      pageWidthMm: OverlayMath.pageWidthMm(page.widthPt),
      pageHeightMm: OverlayMath.pageHeightMm(page.heightPt),
    );
    return OverlayItem(
      id: '${kind.name}-${++_overlaySeq}',
      kind: kind,
      page: _activePage,
      xMm: pos.xMm,
      yMm: pos.yMm,
      widthMm: widthMm,
      aspectRatio: aspectRatio,
      pngBytes: png,
    );
  }

  /// QR verifikasi otomatis hadir sekali saat masuk penempatan (posisi
  /// kanan-bawah default, bisa digeser/dihapus user).
  Future<void> _ensureDefaultQrOverlay() async {
    if (_overlays.any((item) => item.kind == OverlayKind.qr)) return;
    await _addQrOverlay();
  }

  Future<void> _addQrOverlay() async {
    if (_submitting) return;
    try {
      final png = await _buildQrPng(_verifyUrl);
      if (png == null) {
        if (mounted) showErrorSnackBar(context, 'Gagal membuat QR verifikasi.');
        return;
      }
      if (!mounted) return;
      final item = _newOverlayAtPreset(
        kind: OverlayKind.qr,
        png: png,
        aspectRatio: 1.0, // QR selalu persegi
        preset: OverlayPreset.bottomRight,
        widthMm: 25,
      );
      if (item == null) return;
      setState(() {
        _overlays.add(item);
        _selectedOverlayId = item.id;
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _addImageOverlay() async {
    if (_addingImage) return;
    setState(() => _addingImage = true);
    try {
      final photos = await _pickImages();
      if (photos.isEmpty || !mounted) return;
      final data =
          await _decodeImageToPng(await File(photos.first.path).readAsBytes());
      if (data == null) {
        if (mounted) {
          showErrorSnackBar(context, 'Gambar tidak dapat dibaca.');
        }
        return;
      }
      if (!mounted) return;
      final item = _newOverlayAtPreset(
        kind: OverlayKind.image,
        png: data.png,
        aspectRatio: data.aspectRatio,
        preset: OverlayPreset.bottomLeft,
        widthMm: 30,
      );
      if (item == null) return;
      setState(() {
        _overlays.add(item);
        _selectedOverlayId = item.id;
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _addingImage = false);
    }
  }

  /// Sumber overlay fase 1c: aset tanda tangan tersimpan milik penandatangan.
  ///
  /// Ambil direktori signer aktif (`GET /signers`), saring `hasSignature`,
  /// pilih lewat bottom sheet, lalu unduh bytes PNG
  /// (`GET /signers/{id}/signature`). Lebar default 45mm — tanda tangan
  /// terbaca jelas tanpa menutup isi surat; rasio dari header PNG.
  Future<void> _addStoredSignatureOverlay() async {
    if (_addingSignature) return;
    setState(() => _addingSignature = true);
    try {
      final signers = await _service.getSigners();
      if (!mounted) return;

      // Spinner hanya selama fetch direktori; modal punya interaksi sendiri
      // (indikator animasi di balik sheet membuat pumpAndSettle tak pernah
      // tenang dan, di perangkat nyata, terlihat berputar tanpa guna).
      setState(() => _addingSignature = false);

      final available = signers
          .where((signer) => signer.hasSignature)
          .toList(growable: false);

      if (available.isEmpty) {
        showErrorSnackBar(
          context,
          'Belum ada tanda tangan tersimpan. Minta admin mengunggah aset '
          'TTD penandatangan lebih dulu.',
        );
        return;
      }

      final picked = await showModalBottomSheet<SignerModel>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: AppSpacing.paddingMD,
                  child: Text(
                    'Pilih tanda tangan tersimpan',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final signer in available)
                  ListTile(
                    leading: const Icon(Icons.gesture_rounded),
                    title: Text(signer.displayName),
                    subtitle: Text(
                      signer.title?.isNotEmpty == true
                          ? '${signer.roleLabel} · ${signer.title}'
                          : signer.roleLabel,
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(signer),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      );

      if (picked == null || !mounted) return;

      setState(() => _addingSignature = true);

      final bytes = await _service.getSignatureBytes(picked.id);
      if (!mounted) return;

      final data = OverlayImageData.fromPngBytes(bytes);
      if (data == null) {
        showErrorSnackBar(context, 'Aset tanda tangan tidak dapat dibaca.');
        return;
      }

      final item = _newOverlayAtPreset(
        kind: OverlayKind.signature,
        png: data.png,
        aspectRatio: data.aspectRatio,
        preset: OverlayPreset.bottomLeft,
        widthMm: 45,
      );
      if (item == null) return;

      setState(() {
        _overlays.add(item);
        _selectedOverlayId = item.id;
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _addingSignature = false);
    }
  }

  void _updateOverlay(OverlayItem updated) {
    final page = _pagesInfo?.pageAt(updated.page) ?? PdfPagesInfo.a4;
    final fitted = OverlayMath.fitIntoPage(
      updated,
      pageWidthMm: OverlayMath.pageWidthMm(page.widthPt),
      pageHeightMm: OverlayMath.pageHeightMm(page.heightPt),
    );
    setState(() {
      final index = _overlays.indexWhere((item) => item.id == updated.id);
      if (index >= 0) _overlays[index] = fitted;
    });
  }

  /// Drag kanvas: delta pt diterapkan pada item TERKINI di list (instance
  /// widget saat drag bisa basi bila beberapa move tiba antar-frame).
  void _dragOverlay(String itemId, double dxPt, double dyPt) {
    final index = _overlays.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    final page = _pagesInfo?.pageAt(_overlays[index].page) ?? PdfPagesInfo.a4;
    setState(() {
      _overlays[index] = OverlayMath.moveByPtDelta(
        _overlays[index],
        dxPt: dxPt,
        dyPt: dyPt,
        pageWidthMm: OverlayMath.pageWidthMm(page.widthPt),
        pageHeightMm: OverlayMath.pageHeightMm(page.heightPt),
      );
    });
  }

  void _removeOverlay(OverlayItem item) {
    setState(() {
      _overlays.removeWhere((existing) => existing.id == item.id);
      if (_selectedOverlayId == item.id) _selectedOverlayId = null;
    });
  }

  // ——— alur: submit ———

  /// Pesan nomor sekali sebelum pra-final (Fix C1) — nomor tercetak di
  /// PDF (teks `No. …` di atas QR default) & tampil di subjudul. Error
  /// diabaikan: endpoint idempoten dan backend ensureReserved tetap
  /// menjaga saat finalize; reissue selalu sudah bernomor.
  Future<void> _reserveNumberOnce() async {
    if (_reserveAttempted) return;
    _reserveAttempted = true;
    try {
      final result = await _service.reserveNumber(widget.documentId);
      final number = result['number']?.toString();
      if (number != null && number.isNotEmpty) {
        _reservedNumber = number;
      }
    } catch (_) {
      // Nomor menyusul via preFinal/finalize backend.
    }
  }

  /// Mode B: pra-final (stempel overlay ke PDF unggahan) → pratinjau.
  Future<void> _submitPreFinal() async {
    final pdf = _pdf;
    if (pdf == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _reserveNumberOnce();
      if (!mounted) return;
      setState(() {}); // nomor tampil di subjudul bila baru dipesan.
      final result = await _service.preFinal(
        widget.documentId,
        mode: 'b',
        pdfBase64: base64Encode(pdf.bytes),
        // Overlays kosong → tidak dikirim → server menempel QR default.
        overlays:
            _overlays.isEmpty ? null : OverlayPayloads.toRequest(_overlays),
      );
      final url = result['download_url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('URL pra-final tidak tersedia.');
      }
      final bytes = await _fetchUrl(url);
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _stage = _stagePreview;
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          ErrorUtils.sanitize(e, fallback: 'Gagal membuat pra-final.'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sharePreview() async {
    final bytes = _previewBytes;
    if (bytes == null) return;
    try {
      final file = await _writeTempFile(bytes, 'pra-final.pdf');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: widget.documentSubject,
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
            context, ErrorUtils.sanitize(e, fallback: 'Gagal membagikan.'));
      }
    }
  }

  /// Lanjutan C: PDF sudah diberi e-materai resmi/TTE di platform resmi —
  /// finalize metode c TANPA overlay (guard 409 ALREADY_SIGNED server).
  Future<void> _continueFinalC() async {
    if (_submitting) return;
    try {
      final picked = await _pickPdf();
      if (picked == null || !mounted) return;
      if (!_looksLikePdf(picked.bytes)) {
        showErrorSnackBar(
            context, 'Berkas bukan PDF valid (magic %PDF tidak ditemukan).');
        return;
      }
      setState(() => _submitting = true);
      final result = await _service.finalize(
        widget.documentId,
        method: 'c',
        pdfBase64: base64Encode(picked.bytes),
      );
      if (!mounted) return;
      await _showIssuedDialog(result);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          ErrorUtils.sanitize(e, fallback: 'Gagal menerbitkan surat.'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Lanjutan D: 3 foto = 3 halaman — finalizeManual multipart + note
  /// opsional (diterima backend, tidak dipersist).
  Future<void> _continueFinalD() async {
    if (_submitting) return;
    try {
      final photos = await _pickImages();
      if (photos.isEmpty || !mounted) return;
      final note = await _askNote(mandatory: false);
      if (note == null) return; // batal dialog.
      setState(() => _submitting = true);
      final files = <File>[];
      for (var i = 0; i < photos.length; i++) {
        final compressed = await _compressImage(photos[i].path) ??
            await File(photos[i].path).readAsBytes();
        files.add(await _writeTempFile(compressed, 'scan-${i + 1}.jpg'));
      }
      final result = await _service.finalizeManual(
        widget.documentId,
        files,
        note: note.trim().isEmpty ? null : note.trim(),
      );
      if (!mounted) return;
      await _showIssuedDialog(result);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          ErrorUtils.sanitize(e, fallback: 'Gagal menerbitkan surat.'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ——— reissue ———

  /// Reissue b: PDF baru + overlay → reissue note WAJIB.
  Future<void> _submitReissueB() async {
    final pdf = _pdf;
    if (pdf == null || _submitting) return;
    final note = await _askNote(mandatory: true);
    if (note == null || note.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final result = await _service.reissue(
        widget.documentId,
        method: 'b',
        note: note.trim(),
        pdfBase64: base64Encode(pdf.bytes),
        overlays:
            _overlays.isEmpty ? null : OverlayPayloads.toRequest(_overlays),
      );
      if (!mounted) return;
      await _showIssuedDialog(result);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          ErrorUtils.sanitize(e, fallback: 'Gagal menerbitkan ulang.'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Reissue c: PDF final ber-e-materai/TTE + note WAJIB.
  Future<void> _submitReissueC() async {
    if (_submitting) return;
    try {
      final picked = await _pickPdf();
      if (picked == null || !mounted) return;
      if (!_looksLikePdf(picked.bytes)) {
        showErrorSnackBar(
            context, 'Berkas bukan PDF valid (magic %PDF tidak ditemukan).');
        return;
      }
      final note = await _askNote(mandatory: true);
      if (note == null || note.trim().isEmpty) return;
      setState(() => _submitting = true);
      final result = await _service.reissue(
        widget.documentId,
        method: 'c',
        note: note.trim(),
        pdfBase64: base64Encode(picked.bytes),
      );
      if (!mounted) return;
      await _showIssuedDialog(result);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          ErrorUtils.sanitize(e, fallback: 'Gagal menerbitkan ulang.'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Reissue d: foto hasil ttd basah → kompresi JPEG → `images_base64`
  /// (reissue backend JSON, bukan multipart) + note WAJIB.
  Future<void> _submitReissueD() async {
    if (_submitting) return;
    if (_photos.isEmpty) {
      showErrorSnackBar(context, 'Pilih minimal satu foto/scan hasil.');
      return;
    }
    final note = await _askNote(mandatory: true);
    if (note == null || note.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final imagesBase64 = <String>[];
      for (final photo in _photos) {
        final compressed = await _compressImage(photo.path) ??
            await File(photo.path).readAsBytes();
        imagesBase64.add(base64Encode(compressed));
      }
      final result = await _service.reissue(
        widget.documentId,
        method: 'd',
        note: note.trim(),
        imagesBase64: imagesBase64,
      );
      if (!mounted) return;
      await _showIssuedDialog(result);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          ErrorUtils.sanitize(e, fallback: 'Gagal menerbitkan ulang.'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickReissuePhotos() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final photos = await _pickImages();
      if (!mounted) return;
      setState(() => _photos
        ..clear()
        ..addAll(photos));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Dialog catatan reissue (wajib) / finalize d (opsional).
  /// Return null bila dibatalkan; string (boleh kosong saat opsional).
  Future<String?> _askNote({required bool mandatory}) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _NoteDialog(mandatory: mandatory),
    );
  }

  /// Dialog sukses penerbitan: nomor + QR verifikasi (pola wizard task 20).
  /// Aksi "Lihat detail" (Task 11) membuka detail surat (lengkap tab
  /// Runutan) MENGGANTIKAN halaman ini di tumpukan.
  Future<void> _showIssuedDialog(Map<String, dynamic> result) async {
    final fromResponse = result['number']?.toString();
    // Nomor aktual dari response finalize/reissue (Fix C1: kini selalu
    // terisi); fallback nomor yang dipesan pra-final.
    final number = (fromResponse != null && fromResponse.isNotEmpty)
        ? fromResponse
        : (_reservedNumber ?? '');
    // Response finalize/reissue memuat verify_url absolut dari backend.
    final verifyUrl = result['verify_url']?.toString() ?? _verifyUrl;
    var navigatedToDetail = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _IssuedSuccessDialog(
        title: _isReissue ? 'Surat diterbitkan ulang' : 'Surat diterbitkan',
        number: number,
        verifyUrl: verifyUrl,
        onViewDetail: () {
          navigatedToDetail = true;
          Navigator.of(dialogContext).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => DocumentDetailPage(
                documentId: widget.documentId,
                service: _service,
              ),
            ),
          );
        },
      ),
    );
    // Bila detail sudah menggantikan halaman ini, state ter-dispose —
    // pop berikutnya justru akan menutup detail yang baru dibuka.
    if (mounted && !navigatedToDetail) Navigator.of(context).pop();
  }

  // ——— build ———

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: _isReissue ? 'Terbitkan Ulang' : 'Unggah Dokumen',
      bodyPadding: EdgeInsets.zero,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Subjudul nomor (Fix C1) — tampil begitu nomor dipesan.
            if (_reservedNumber != null)
              Padding(
                padding: AppSpacing.paddingHorizontalMD.copyWith(
                  top: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.tag_rounded,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Nomor surat: $_reservedNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildStage(context)),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    switch (_stage) {
      case _stagePick:
        return _buildPickStage(context);
      case _stagePlace:
        return _buildPlaceStage(context);
      default:
        return _buildPreviewStage(context);
    }
  }

  Widget _buildPickStage(BuildContext context) {
    if (_isReissue && _method == 'd') return _buildReissueDPick(context);
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        _InfoCard(
          icon: _method == 'c'
              ? Icons.app_registration_rounded
              : Icons.upload_file_rounded,
          title: _method == 'c'
              ? 'Unggah PDF final ber-e-materai/TTE resmi'
              : 'Unggah PDF surat sendiri',
          body: _method == 'c'
              ? 'Sematkan e-materai resmi atau tanda tangan elektronik '
                  'resmi di platform resmi atas pra-final surat ini, lalu '
                  'unggah berkas hasilnya di sini. Overlay tidak ditempel '
                  'ulang — berkas dipakai apa adanya.'
              : 'PDF milik Anda akan ditempel QR verifikasi pada posisi '
                  'yang Anda pilih, lalu dijadikan pra-final untuk '
                  'ditandatangani / dibagikan.${_isReissue ? ' Surat lama '
                      'dinonaktifkan dan issuance baru dibuat dengan alasan '
                      'yang Anda isi.' : ''}',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _picking || _submitting
              ? null
              : () => _method == 'c'
                  ? _submitReissueC()
                  : _pickAndLoadPdf(toPlacement: true),
          style: AppButtonStyle.filled(),
          icon: _picking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_pdf == null ? 'Pilih PDF' : 'Ganti PDF'),
        ),
        if (_pdf != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              '${_pdf!.name} • ${(_pdf!.bytes.length / 1024).round()} KB',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildReissueDPick(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        _InfoCard(
          icon: Icons.document_scanner_rounded,
          title: 'Pindai hasil tanda tangan basah',
          body: 'Cetak surat, tandatangani basah + meterai tempel, lalu '
              'pindai/foto setiap halaman. Tiap foto menjadi satu halaman '
              'PDF versi baru (urutan sesuai daftar).',
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _picking ? null : _pickReissuePhotos,
          icon: _picking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined),
          label: Text(_photos.isEmpty
              ? 'Pilih foto/scan (bisa banyak)'
              : 'Ganti pilihan foto'),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_photos.isEmpty)
          Text(
            'Belum ada foto dipilih.',
            style: textTheme.bodySmall,
          )
        else
          for (var i = 0; i < _photos.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(_photos[i].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
      ],
    );
  }

  Widget _buildPlaceStage(BuildContext context) {
    final pagesInfo = _pagesInfo ?? const PdfPagesInfo(pageCount: 1, pages: []);
    return StepOverlayPlacement(
      pagesInfo: pagesInfo,
      activePage: _activePage,
      onPageChanged: _onActivePageChanged,
      overlays: _overlays,
      selectedId: _selectedOverlayId,
      onSelectOverlay: (item) => setState(() => _selectedOverlayId = item.id),
      onUpdateOverlay: _updateOverlay,
      onDragOverlay: _dragOverlay,
      onRemoveOverlay: _removeOverlay,
      onAddQr: _addQrOverlay,
      onAddImage: _addImageOverlay,
      onAddSignature: _addStoredSignatureOverlay,
      addingImage: _addingImage,
      addingSignature: _addingSignature,
      pageImage: _pageImage,
    );
  }

  Widget _buildPreviewStage(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bytes = _previewBytes;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: AppSpacing.paddingMD,
            child: bytes == null
                ? const Center(child: CircularProgressIndicator())
                : _buildPreview(context, bytes),
          ),
        ),
        Expanded(
          child: ListView(
            padding: AppSpacing.paddingMD,
            children: [
              OutlinedButton.icon(
                onPressed: _submitting ? null : _sharePreview,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Bagikan / simpan pra-final'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Lanjutkan penerbitan',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cetak pra-final lalu pilih salah satu jalur penyelesaian:',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MethodCard(
                icon: Icons.app_registration_rounded,
                title: 'Sudah diberi e-materai resmi / TTE',
                subtitle: 'Unggah PDF final dari platform resmi — '
                    'diterbitkan apa adanya.',
                onTap: _submitting ? null : _continueFinalC,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MethodCard(
                icon: Icons.draw_rounded,
                title: 'Tanda tangan basah — pindai hasil',
                subtitle: 'Foto/scan semua halaman hasil — tiap foto '
                    'menjadi satu halaman PDF.',
                onTap: _submitting ? null : _continueFinalD,
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _stage = _stagePick),
                child: const Text('Ganti PDF / penempatan'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (_isReissue) {
      switch (_method) {
        case 'b':
          return Padding(
            padding: AppSpacing.paddingMD,
            child: FilledButton.icon(
              onPressed: _pdf == null || _submitting ? null : _submitReissueB,
              style: AppButtonStyle.filled(),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_rounded),
              label: const Text('Terbitkan ulang'),
            ),
          );
        case 'd':
          return Padding(
            padding: AppSpacing.paddingMD,
            child: FilledButton.icon(
              onPressed:
                  _photos.isEmpty || _submitting ? null : _submitReissueD,
              style: AppButtonStyle.filled(),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_rounded),
              label: const Text('Terbitkan ulang'),
            ),
          );
        default: // c — pick stage langsung submit; tanpa bottom bar.
          return const SizedBox.shrink();
      }
    }
    if (_stage == _stagePlace) {
      return Padding(
        padding: AppSpacing.paddingMD,
        child: FilledButton.icon(
          onPressed: _pdf == null || _submitting ? null : _submitPreFinal,
          style: AppButtonStyle.filled(),
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Buat pra-final'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Kartu instruksi ringkas di atas tiap tahap.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMD),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(body, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu aksi metode lanjutan (C/D).
class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMD,
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.paddingSM,
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog input catatan — controller dimiliki state sini (dipose bersama
/// dialog SELESAI animasi keluar; dispose di route-future menyebabkan
/// "used after disposed" saat exit animation, pola fix review task 20).
class _NoteDialog extends StatefulWidget {
  final bool mandatory;

  const _NoteDialog({required this.mandatory});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.mandatory ? 'Alasan terbitkan ulang' : 'Catatan (opsional)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.mandatory
              ? 'Alasan tercatat di riwayat penerbitan surat.'
              : 'Catatan tambahan untuk penerbitan manual ini.'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            maxLength: 255,
            decoration: const InputDecoration(
              hintText: 'Mis. salah isi pada versi sebelumnya',
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (widget.mandatory && value.isEmpty) {
              showWarningSnackBar(
                  context, 'Alasan wajib diisi (maks 255 karakter).');
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}

/// Dialog sukses penerbitan/terbitkan-ulang — nomor + QR verify_url
/// (bentuk sama dengan wizard task 20). Aksi opsional "Lihat detail"
/// (Task 11) membuka detail surat lengkap (termasuk tab Runutan).
class _IssuedSuccessDialog extends StatelessWidget {
  final String title;
  final String number;
  final String verifyUrl;
  final VoidCallback? onViewDetail;

  const _IssuedSuccessDialog({
    required this.title,
    required this.number,
    required this.verifyUrl,
    this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.verified_rounded, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number.isEmpty ? 'Nomor menyusul di arsip' : number,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (verifyUrl.isNotEmpty)
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: QrImageView(
                data: verifyUrl,
                size: 168,
                backgroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pindai QR untuk membuka halaman verifikasi surat.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (onViewDetail != null)
          TextButton.icon(
            onPressed: onViewDetail,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Lihat detail'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
