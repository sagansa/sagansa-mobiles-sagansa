import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../services/document/document_models.dart';
import '../../../services/document/document_service.dart';
import '../../../services/document/incoming_models.dart';
import '../../../services/document/incoming_service.dart';
import '../../../theme/app_spacing.dart';
import '../../../utils/error_utils.dart';
import '../../../widgets/app_page_scaffold.dart';
import '../../../widgets/app_snackbar.dart';
import '../document_upload_page.dart' show PickedPdf, PickedPhoto;
import 'incoming_list_section.dart' show IncomingDetailPlaceholderPage;

/// Induk runutan untuk mode "balasan eksternal" (Task 9 fase 1b) —
/// surat keluar yang dibalas pihak luar lewat surat masuk ini.
///
/// [id] dikirim sebagai `in_reply_to` (backend menautkan edge `balasan`
/// dalam transaksi registrasi); [partyName] = nama penerima surat keluar
/// → diprefill sebagai pengirim surat masuk; [subject] & [number] hanya
/// informasi banner.
class ReplyToDocument {
  final String id;
  final String partyName;
  final String? subject;
  final String? number;

  const ReplyToDocument({
    required this.id,
    required this.partyName,
    this.subject,
    this.number,
  });
}

/// Form pendaftaran surat masuk (Task 9 fase 1b) — dibuka FAB "Daftar
/// Surat Masuk" pada tab Masuk arsip surat.
///
/// - Pengirim: pilih dari buku pihak (sheet pencarian, pola `_PartySheet`
///   wizard fase 1) ATAU ketik bebas — nama bebas otomatis ditawarkan
///   `createParty` saat submit sehingga selalu tersimpan `party_id`.
/// - Scan: "Pilih PDF" (file_picker) ATAU "Foto/Scan" multi-pick +
///   kompresi pola Task 21 (sisi panjang ≤1920 px, JPEG q80) — foto
///   dikirim `scan_images[]` (ekstensi .jpg sesuai hasil kompresi),
///   estimasi halaman = jumlah foto. Minimal satu bentuk wajib.
/// - Mode balasan ([replyToDocument]): banner induk + prefill pengirim +
///   kirim `in_reply_to` (link dibuat backend, satu request).
///
/// [service], [documentService], dan seam picker/kompresi adalah injeksi
/// test — produksi memakai implementasi default di bawah.
class IncomingFormPage extends StatefulWidget {
  final IncomingService? service;
  final DocumentService? documentService;

  /// Mode "balasan eksternal" — null = pendaftaran biasa.
  final ReplyToDocument? replyToDocument;

  final Future<PickedPdf?> Function()? pickPdf;
  final Future<List<PickedPhoto>> Function()? pickImages;
  final Future<Uint8List?> Function(String path)? compressImage;

  const IncomingFormPage({
    super.key,
    this.service,
    this.documentService,
    this.replyToDocument,
    this.pickPdf,
    this.pickImages,
    this.compressImage,
  });

  @override
  State<IncomingFormPage> createState() => _IncomingFormPageState();
}

class _IncomingFormPageState extends State<IncomingFormPage> {
  late final IncomingService _service = widget.service ?? IncomingService();
  late final DocumentService _documentService =
      widget.documentService ?? DocumentService();
  late final Future<PickedPdf?> Function() _pickPdf =
      widget.pickPdf ?? _pickPdfDefault;
  late final Future<List<PickedPhoto>> Function() _pickImages =
      widget.pickImages ?? _pickImagesDefault;
  late final Future<Uint8List?> Function(String path) _compressImage =
      widget.compressImage ?? _compressImageDefault;

  final TextEditingController _senderController = TextEditingController();
  final TextEditingController _numberExternalController =
      TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _attachmentsNoteController =
      TextEditingController();

  final DateFormat _dateFormatter = DateFormat('d MMMM yyyy', 'id_ID');

  /// Pihak terpilih dari buku pihak — null = nama bebas (createParty saat
  /// submit). Sunting teks setelah memilih melepas pilihan (nama tak lagi
  /// cocok baris buku pihak).
  PartyModel? _selectedParty;

  /// Tanggal surat (opsional — tidak semua surat pengirim bernomor/tanggal).
  DateTime? _letterDate;

  /// Tanggal diterima (WAJIB) — default hari ini.
  DateTime _receivedAt = DateTime.now();

  /// biasa | segera | rahasia.
  String _sifat = 'biasa';

  PickedPdf? _pdf;
  final List<PickedPhoto> _photos = [];

  bool _picking = false;
  bool _submitting = false;
  bool _senderMissing = false;
  bool _subjectMissing = false;

  static const List<String> _sifatOptions = ['biasa', 'segera', 'rahasia'];

  bool get _hasScan => _pdf != null || _photos.isNotEmpty;

  bool get _canSubmit =>
      !_submitting &&
      _senderController.text.trim().isNotEmpty &&
      _subjectController.text.trim().isNotEmpty &&
      _hasScan;

  @override
  void initState() {
    super.initState();
    _senderController.addListener(_onSenderChanged);
    final reply = widget.replyToDocument;
    if (reply != null) {
      // Prefill pengirim = penerima surat keluar; cocokkan best-effort ke
      // buku pihak (exact match) agar party_id terpakai tanpa duplikat
      // baru. Gagal/di luar buku → tetap nama bebas (createParty submit).
      _senderController.text = reply.partyName;
      _resolveReplyParty(reply.partyName);
    }
  }

  @override
  void dispose() {
    _senderController.dispose();
    _numberExternalController.dispose();
    _subjectController.dispose();
    _attachmentsNoteController.dispose();
    super.dispose();
  }

  void _onSenderChanged() {
    final party = _selectedParty;
    if (party != null && _senderController.text.trim() != party.name) {
      setState(() => _selectedParty = null);
    } else {
      setState(() {}); // refresh status tombol submit.
    }
  }

  Future<void> _resolveReplyParty(String name) async {
    try {
      final page = await _documentService.getParties(query: name);
      if (!mounted) return;
      final match = page.items
          .where((party) => party.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (match != null && _senderController.text.trim() == name) {
        setState(() => _selectedParty = match);
      }
    } catch (_) {
      // Buku pihak tak terjangkau → biarkan nama bebas (createParty nanti).
    }
  }

  // ——— implementasi default seam (produksi) ———

  Future<PickedPdf?> _pickPdfDefault() async {
    final file = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file.isEmpty) return null;
    return PickedPdf(
      name: file.first.name,
      bytes: await File(file.first.path!).readAsBytes(),
    );
  }

  Future<List<PickedPhoto>> _pickImagesDefault() async {
    // Multi-pick foto: image_picker pickMultiImage (galeri, pilih banyak
    // sekaligus) — file_picker 13 di sini tak punya flag allowMultiple.
    final files = await ImagePicker().pickMultiImage();
    return [
      for (final file in files) PickedPhoto(path: file.path, name: file.name),
    ];
  }

  /// Kompresi foto scan pola Task 21 (upload page): sisi panjang ≤1920 px,
  /// JPEG kualitas 80 — hasil SELALU JPEG sehingga nama berkas foto scan
  /// selalu `.jpg` (OPNOTE Task 7: ekstensi harus sesuai isi).
  Future<Uint8List?> _compressImageDefault(String path) {
    return FlutterImageCompress.compressWithFile(
      path,
      minWidth: 1920,
      minHeight: 1080,
      quality: 80,
      format: CompressFormat.jpeg,
    );
  }

  // ——— pengirim: buku pihak / ketik bebas ———

  Future<void> _openPartySheet() async {
    final party = await showModalBottomSheet<PartyModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _SenderPartySheet(
        onSearch: (query) async =>
            (await _documentService.getParties(query: query)).items,
      ),
    );
    if (party == null || !mounted) return;
    setState(() {
      _selectedParty = party;
      _senderController.text = party.name;
      _senderMissing = false;
    });
  }

  // ——— scan: PDF / foto ———

  Future<void> _pickScanPdf() async {
    if (_picking || _submitting) return;
    setState(() => _picking = true);
    try {
      final picked = await _pickPdf();
      if (picked == null) return;
      if (!_looksLikePdf(picked.bytes)) {
        if (mounted) {
          showErrorSnackBar(
              context, 'Berkas bukan PDF valid (magic %PDF tidak ditemukan).');
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _pdf = picked;
        _photos.clear(); // scan hanya boleh satu bentuk.
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
            context, ErrorUtils.sanitize(e, fallback: 'Gagal memilih PDF.'));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickScanPhotos() async {
    if (_picking || _submitting) return;
    setState(() => _picking = true);
    try {
      final picked = await _pickImages();
      if (picked.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _photos.addAll(picked);
        _pdf = null; // scan hanya boleh satu bentuk.
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
            context, ErrorUtils.sanitize(e, fallback: 'Gagal memilih foto.'));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  static bool _looksLikePdf(List<int> bytes) =>
      bytes.length >= 5 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';

  /// Nama berkas foto scan jalur FALLBACK (kompresi gagal → bytes asli
  /// dikirim apa adanya) — ekstensi asal dipakai bila dikenal backend
  /// (png/jpg), selain itu `.jpg`. Jalur utama (kompresi berhasil) selalu
  /// `.jpg` karena hasil kompresi selalu JPEG (lihat [_submit]).
  String _photoFileName(int index, String originalName) {
    final dot = originalName.lastIndexOf('.');
    final ext = dot < 0 ? '' : originalName.substring(dot + 1).toLowerCase();
    return 'halaman-${index + 1}.${ext == 'png' ? 'png' : 'jpg'}';
  }

  /// Nama berkas scan PDF — `.pdf` selalu (kompresi/picking PDF murni).
  String get _pdfFileName =>
      (_pdf!.name.toLowerCase().endsWith('.pdf') ? _pdf!.name : 'scan.pdf');

  // ——— tanggal ———

  Future<void> _pickLetterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _letterDate ?? _receivedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _letterDate = picked);
  }

  Future<void> _pickReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _receivedAt = picked);
  }

  // ——— submit ———

  Future<void> _submit() async {
    final sender = _senderController.text.trim();
    final subject = _subjectController.text.trim();

    var valid = true;
    if (sender.isEmpty) {
      valid = false;
      setState(() => _senderMissing = true);
    }
    if (subject.isEmpty) {
      valid = false;
      setState(() => _subjectMissing = true);
    }
    if (!valid) {
      showErrorSnackBar(context, 'Lengkapi kolom wajib sebelum mendaftar.');
      return;
    }
    if (!_hasScan) {
      // Tombol submit dinonaktifkan tanpa scan — jalur ini murni defensif.
      showErrorSnackBar(context, 'Scan wajib: pilih PDF atau foto scan.');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Pengirim bebas → daftarkan ke buku pihak dulu agar selalu ada
      // party_id (backend hanya menerima sender_party_id terdaftar).
      var partyId = _selectedParty?.id;
      partyId ??= (await _documentService.createParty(name: sender)).id;

      final scanImages = <IncomingScanImage>[];
      if (_photos.isNotEmpty) {
        for (var i = 0; i < _photos.length; i++) {
          // Kompresi pola Task 21; gagal → bytes asli (fallback pola
          // ImageUtils, alur tidak putus). Kompresi berhasil = isi SELALU
          // JPEG → nama `.jpg` (OPNOTE Task 7: ekstensi sesuai isi);
          // ekstensi asal hanya dipakai jalur fallback.
          final compressed = await _compressImage(_photos[i].path);
          final bytes =
              compressed ?? await File(_photos[i].path).readAsBytes();
          scanImages.add(IncomingScanImage(
            bytes: bytes,
            fileName: compressed != null
                ? 'halaman-${i + 1}.jpg'
                : _photoFileName(i, _photos[i].name),
          ));
        }
      }

      final reply = widget.replyToDocument;
      final letter = await _service.createIncoming(
        senderPartyId: partyId,
        numberExternal: _trimmedOrNull(_numberExternalController),
        letterDate: _letterDate,
        receivedAt: _receivedAt,
        subject: subject,
        sifat: _sifat,
        attachmentsNote: _trimmedOrNull(_attachmentsNoteController),
        scanBytes: _pdf?.bytes,
        scanFileName: _pdf != null ? _pdfFileName : null,
        scanImages: scanImages.isEmpty ? null : scanImages,
        inReplyToType: reply != null ? 'document' : null,
        inReplyToId: reply?.id,
        inReplyToRelation: reply != null ? 'balasan' : null,
      );
      if (!mounted) return;
      await _showSuccessDialog(letter);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context,
            ErrorUtils.sanitize(e, fallback: 'Gagal mendaftarkan surat masuk.'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String? _trimmedOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  /// Dialog sukses: agenda number (di-generate backend) + jalan pintas
  /// detail (placeholder Task 10) atau selesai kembali ke buku agenda
  /// (pemanggil me-refresh).
  Future<void> _showSuccessDialog(IncomingLetterModel letter) async {
    final viewDetail = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_rounded, size: 40),
        title: const Text('Surat masuk terdaftar'),
        content: Text(
          'Nomor agenda: ${letter.agendaNumber}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Selesai'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lihat detail'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (viewDetail == true) {
      // TODO(Task 10): ganti placeholder dengan halaman detail penuh.
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingDetailPlaceholderPage(letter: letter),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  // ——— build ———

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reply = widget.replyToDocument;

    return AppPageScaffold(
      titleText: 'Daftar Surat Masuk',
      bodyPadding: EdgeInsets.zero,
      body: _buildBody(context, colorScheme, reply),
      bottomAction: _submitting
          // Tanpa spinner indeterminat agar alur pumpAndSettle test selesai
          // bersama dialog sukses; status cukup lewat label.
          ? const FilledButton(
              onPressed: null,
              child: Text('Mendaftarkan…'),
            )
          : FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('Daftarkan Surat Masuk'),
            ),
    );
  }

  Widget _buildBody(
      BuildContext context, ColorScheme colorScheme, ReplyToDocument? reply) {
    return SafeArea(
      top: false,
      child: ListView(
        // Body menjorok di balik appbar kaca (extendBodyBehindAppBar) —
        // padding atas = status bar + toolbar + jarak konten: baris pertama
        // (judul seksi + tombol "Buku pihak") harus DI BAWAH appbar agar
        // tidak tertutup kaca & tetap bisa di-tap; konten berikutnya tetap
        // melewati balik kaca saat digulir.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          MediaQuery.paddingOf(context).top + kToolbarHeight + AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          if (reply != null) ...[
            _buildReplyBanner(colorScheme, reply),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildSenderSection(colorScheme),
          const SizedBox(height: AppSpacing.lg),
          _section(context, 'Nomor & tanggal'),
          TextField(
            controller: _numberExternalController,
            decoration: const InputDecoration(
              labelText: 'Nomor surat pengirim (opsional)',
              helperText: 'Nomor eksternal tertera pada surat fisik.',
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _dateField(
            label: 'Tanggal surat (opsional)',
            icon: Icons.event_rounded,
            value: _letterDate,
            onTap: _pickLetterDate,
            onClear: _letterDate == null
                ? null
                : () => setState(() => _letterDate = null),
          ),
          const SizedBox(height: AppSpacing.md),
          _dateField(
            label: 'Tanggal diterima *',
            icon: Icons.event_available_rounded,
            value: _receivedAt,
            onTap: _pickReceivedDate,
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(context, 'Perihal & sifat'),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Perihal *',
              errorText: _subjectMissing ? 'Perihal wajib diisi.' : null,
              isDense: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_subjectMissing) setState(() => _subjectMissing = false);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: [
              for (final sifat in _sifatOptions)
                ButtonSegment(
                  value: sifat,
                  label: Text(IncomingLetterModel.sifatLabelOf(sifat)),
                ),
            ],
            selected: {_sifat},
            onSelectionChanged: (selection) =>
                setState(() => _sifat = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          _section(context, 'Uraian lampiran (opsional)'),
          TextField(
            controller: _attachmentsNoteController,
            decoration: const InputDecoration(
              hintText: 'Mis. 2 berkas proposal, 1 lembar peta',
              isDense: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildScanSection(context, colorScheme),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

  Widget _buildReplyBanner(ColorScheme colorScheme, ReplyToDocument reply) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.reply_rounded, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mendaftarkan balasan atas surat keluar: '
                  '${reply.number ?? '—'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold),
                ),
                if (reply.subject != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Perihal: ${reply.subject}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.onSecondaryContainer),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _section(context, 'Pengirim')),
            TextButton.icon(
              onPressed: _submitting ? null : _openPartySheet,
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Buku pihak'),
            ),
          ],
        ),
        TextField(
          controller: _senderController,
          decoration: InputDecoration(
            labelText: 'Nama pengirim *',
            errorText: _senderMissing ? 'Pengirim wajib diisi.' : null,
            helperText: _selectedParty != null
                ? 'Terpilih dari buku pihak (#${_selectedParty!.id}).'
                : 'Ketik bebas (disimpan ke buku pihak) atau pilih dari buku pihak.',
            prefixIcon: Icon(
              _selectedParty != null
                  ? Icons.person_search_rounded
                  : Icons.person_outline_rounded,
            ),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required IconData icon,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusMD,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          isDense: true,
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: 'Hapus tanggal',
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          value == null ? 'Pilih tanggal' : _dateFormatter.format(value),
        ),
      ),
    );
  }

  Widget _buildScanSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context, 'Scan surat *'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _picking || _submitting ? null : _pickScanPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: const Text('Pilih PDF'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _picking || _submitting ? null : _pickScanPhotos,
                icon: const Icon(Icons.photo_camera_rounded, size: 20),
                label: const Text('Foto/Scan'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_picking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_pdf != null)
          _buildPdfTile(colorScheme)
        else if (_photos.isNotEmpty)
          _buildPhotoGrid(colorScheme)
        else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Scan wajib — pilih berkas PDF atau foto minimal satu halaman '
              'sebelum mendaftarkan.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfTile(ColorScheme colorScheme) {
    final pdf = _pdf!;
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_rounded,
              size: 36, color: colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pdf.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_formatBytes(pdf.bytes.length)} • PDF',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Hapus scan',
            onPressed: _submitting ? null : () => setState(() => _pdf = null),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < _photos.length; i++)
              _buildPhotoThumb(colorScheme, i),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Perkiraan ${_photos.length} halaman — foto dikompres & digabung '
          'menjadi satu PDF saat didaftarkan.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildPhotoThumb(ColorScheme colorScheme, int index) {
    final photo = _photos[index];
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppSpacing.borderRadiusMD,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image_outlined,
                    size: 28, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: InkWell(
            onTap: _submitting
                ? null
                : () => setState(() => _photos.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 14, color: colorScheme.onError),
            ),
          ),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

/// Sheet pencarian buku pihak untuk pengirim — pola `_PartySheet` wizard
/// fase 1 (controller search dimiliki di sini, debounce 400 ms, hasil
/// live; pilih mem-pop [PartyModel]).
class _SenderPartySheet extends StatefulWidget {
  final Future<List<PartyModel>> Function(String query) onSearch;

  const _SenderPartySheet({required this.onSearch});

  @override
  State<_SenderPartySheet> createState() => _SenderPartySheetState();
}

class _SenderPartySheetState extends State<_SenderPartySheet> {
  static const _sheetHeightFactor = 0.7;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<PartyModel> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSearch();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.onSearch(_controller.text.trim());
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * _sheetHeightFactor,
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.paddingMD,
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cari nama / NIK pengirim di buku pihak…',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _results.isEmpty
                          ? const Center(
                              child: Text('Tidak ada pihak yang cocok.'),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final party = _results[index];
                                return ListTile(
                                  leading:
                                      const Icon(Icons.person_outline_rounded),
                                  title: Text(party.name),
                                  subtitle: party.identityNo != null
                                      ? Text('NIK ${party.identityNo}')
                                      : null,
                                  onTap: () =>
                                      Navigator.of(context).pop(party),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
