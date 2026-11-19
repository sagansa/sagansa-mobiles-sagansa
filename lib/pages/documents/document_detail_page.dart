import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/document/document_models.dart';
import '../../services/document/document_service.dart';
import '../../services/document/incoming_models.dart';
import '../../services/document/incoming_service.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/error_utils.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_page_scaffold.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/documents/document_status_badge.dart';
import '../../widgets/documents/issuance_timeline.dart';
import '../../widgets/documents/letter_action_sheet.dart';
import '../../widgets/documents/letter_thread_timeline.dart';
import '../../widgets/empty_state.dart';
import 'document_create_wizard.dart';
import 'document_upload_page.dart';
import 'incoming/incoming_detail_page.dart';
import 'incoming/incoming_form_page.dart';

/// Detail surat — tab Info (metadata + penandatangan + lampiran + isi
/// draft), Terbitan ([IssuanceTimeline]), PDF (berkas terbitan aktif /
/// pra-final draft), Verifikasi (QR + URL), dan Runutan (fase 1b Task 11 —
/// [LetterThreadTimeline] via `IncomingService.getThread('document', id)`;
/// tap node membuka detail terkait, node saat ini no-op).
///
/// Header menampilkan chip "Membalas: {nomor/agenda}" bila surat ini
/// balasan/tindak lanjut surat lain (`in_reply_to` detail) — tap membuka
/// detail surat induk.
///
/// Aksi sesuai status (menu AppBar):
/// - draft|menunggu_ttd → "Edit" (wizard membuka draf yang sama),
///   "Batalkan surat" (alasan wajib → voidDocument);
/// - terbit → "Terbitkan ulang…" (sheet metode b/c/d → DocumentUploadPage
///   mode reissue), "Batalkan surat", bila jenis KUA → "Cabut kuasa"
///   (alasan + tanggal → revoke), dan "Daftarkan surat masuk (balasan
///   pihak luar)" → `IncomingFormPage` mode balasan eksternal (Task 11 —
///   surat masuk baru menjadi ANAK surat ini: parent=document ini,
///   child=incoming, relation=balasan; arah link dibuat backend benar).
///
/// [service] & [incomingService] seam test — produksi memakai instance
/// default. [fetchUrl]/[launchUrlImpl]/[pdfPreviewBuilder] seam injeksi
/// test.
class DocumentDetailPage extends StatefulWidget {
  final String documentId;
  final DocumentService? service;

  /// Runutan (fase 1b) — thread lintas jenis + detail surat masuk saat
  /// node runutan/chip induk dibuka.
  final IncomingService? incomingService;

  final Future<Uint8List> Function(String url)? fetchUrl;
  final Future<bool> Function(Uri url)? launchUrlImpl;
  final Widget Function(BuildContext context, Uint8List bytes)?
      pdfPreviewBuilder;

  const DocumentDetailPage({
    super.key,
    required this.documentId,
    this.service,
    this.incomingService,
    this.fetchUrl,
    this.launchUrlImpl,
    this.pdfPreviewBuilder,
  });

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage>
    with SingleTickerProviderStateMixin {
  late final DocumentService _service = widget.service ?? DocumentService();
  late final IncomingService _incomingService =
      widget.incomingService ?? IncomingService();
  late final Future<Uint8List> Function(String url) _fetchUrl =
      widget.fetchUrl ?? _fetchUrlDefault;
  late final Future<bool> Function(Uri url) _launchUrl =
      widget.launchUrlImpl ?? _launchUrlDefault;

  /// Index tab Runutan (paling belakang — Info, PDF, Verifikasi, Runutan;
  /// riwayat penerbitan kini seksi di tab Info).
  static const int _runutanTabIndex = 3;

  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );
  static final DateFormat _dateFormatter = DateFormat('d MMM yyyy', 'id_ID');

  DocumentModel? _document;
  bool _isLoading = true;
  String? _errorMessage;
  bool _acting = false;

  // ——— tab PDF ———
  Uint8List? _pdfBytes;
  bool _pdfLoading = false;
  String? _pdfError;

  // ——— tab Runutan (fase 1b) ———
  ThreadModel? _thread;
  bool _threadLoading = false;
  String? _threadError;
  bool _threadLoaded = false;

  // ——— implementasi default seam (produksi) ———

  Future<Uint8List> _fetchUrlDefault(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh berkas (${response.statusCode}).');
    }
    return response.bodyBytes;
  }

  Future<bool> _launchUrlDefault(Uri url) {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = _document == null;
      _errorMessage = null;
    });
    try {
      final detail = await _service.getDetail(widget.documentId);
      if (!mounted) return;
      setState(() {
        _document = detail;
        _isLoading = false;
        _pdfBytes = null; // berkas mungkin berubah (reissue/void) — muat ulang.
        _pdfError = null;
      });
      // Muat runutan surat otomatis saat detail dibuka agar timeline langsung siap
      _loadThread(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            ErrorUtils.sanitize(e, fallback: 'Gagal memuat detail surat.');
        _isLoading = false;
      });
    }
  }

  // ——— runutan (fase 1b) ———

  /// Muat thread saat tab Runutan dibuka (malas — hemat request; pola
  /// lazy tab Scan/Task 10). Reentry-safe.
  void _onTabChanged() {
    if (_tabController.index == _runutanTabIndex) _loadThread();
  }

  /// Buka tab Runutan dari header/Info — jalan pintas agar timeline
  /// balasan tidak "tersembunyi" di tab terakhir.
  void _openThreadTab() {
    _tabController.animateTo(_runutanTabIndex);
    _loadThread();
  }

  Future<void> _loadThread({bool force = false}) async {
    if (_threadLoading) return;
    if (_threadLoaded && !force) return;
    setState(() {
      _threadLoading = true;
      _threadError = null;
    });
    try {
      final thread =
          await _incomingService.getThread('document', widget.documentId);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _threadLoading = false;
        _threadLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _threadError =
            ErrorUtils.sanitize(e, fallback: 'Gagal memuat runutan surat.');
        _threadLoading = false;
      });
    }
  }

  /// Tap node runutan → detail terkait (pola simetris `_onThreadNodeTap`
  /// detail masuk Task 10): node keluar lain membuka detail surat keluar,
  /// node masuk membuka detail surat masuk. Node saat ini diabaikan
  /// (halaman ini sudah menampilkannya) — guard dokumen kini simetris
  /// dengan guard surat masuk (OPNOTE Task 10).
  Future<void> _onThreadNodeTap(ThreadNodeModel node) async {
    if (node.isIncomingLetter) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingDetailPage(
            letterId: node.id,
            service: _incomingService,
            documentService: _service,
            pdfPreviewBuilder: widget.pdfPreviewBuilder,
          ),
        ),
      );
    } else {
      if (node.id == widget.documentId) return; // node saat ini — no-op.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailPage(
            documentId: node.id,
            service: _service,
            incomingService: _incomingService,
            fetchUrl: widget.fetchUrl,
            launchUrlImpl: widget.launchUrlImpl,
            pdfPreviewBuilder: widget.pdfPreviewBuilder,
          ),
        ),
      );
    }
    if (mounted) _loadDetail(); // runutan/detail bisa berubah di sana.
  }

  /// Buka detail surat induk (`in_reply_to`) — dipanggil chip header.
  Future<void> _openInReplyTo(InReplyToRef ref) async {
    if (ref.isIncomingLetter) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingDetailPage(
            letterId: ref.id,
            service: _incomingService,
            documentService: _service,
            pdfPreviewBuilder: widget.pdfPreviewBuilder,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailPage(
            documentId: ref.id,
            service: _service,
            incomingService: _incomingService,
            fetchUrl: widget.fetchUrl,
            launchUrlImpl: widget.launchUrlImpl,
            pdfPreviewBuilder: widget.pdfPreviewBuilder,
          ),
        ),
      );
    }
    if (mounted) _loadDetail();
  }

  /// "Daftarkan surat masuk (balasan pihak luar)" — form registrasi mode
  /// balasan eksternal: surat masuk baru jadi ANAK surat ini (backend
  /// menautkan edge balasan dari `in_reply_to` dalam transaksi registrasi,
  /// Task 9). Prefill pengirim = penerima surat ini bila tersedia di
  /// metadata.
  Future<void> _registerExternalReply() async {
    final doc = _doc;
    if (doc == null || _acting) return;
    final recipient = doc.metadata?['recipient'];
    final partyName =
        recipient is Map ? (recipient['name']?.toString() ?? '') : '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingFormPage(
          service: _incomingService,
          documentService: _service,
          replyToDocument: ReplyToDocument(
            id: doc.id,
            partyName: partyName,
            subject: doc.subject,
            number: doc.number,
          ),
        ),
      ),
    );
    if (mounted) _loadDetail(); // runutan bertambah setelah balasan.
  }

  DocumentModel? get _doc => _document;

  bool get _isTerbit => _doc?.status == 'terbit';
  bool get _isEditable =>
      _doc != null &&
      (_doc!.status == 'draft' || _doc!.status == 'menunggu_ttd');
  bool get _isKua => _doc?.letterType?.code == 'KUA';

  /// URL halaman verifikasi publik — UUID surat, tanpa auth.
  String get _verifyUrl =>
      '${ApiConstants.documentBaseUrl}/verify/${widget.documentId}';

  // ——— aksi sesuai status ———

  /// Edit draf/menunggu_ttd — wizard membuka draf yang sama (param
  /// documentId, task 22) lalu detail dimuat ulang setelah kembali.
  Future<void> _editDraft() async {
    final doc = _doc;
    if (doc == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCreateWizard(
          service: _service,
          documentId: doc.id,
        ),
      ),
    );
    if (mounted) _loadDetail();
  }

  /// Terbitkan ulang — sheet pilih metode b/c/d → DocumentUploadPage mode
  /// reissue (alasan dikumpulkan di sana sebelum submit).
  Future<void> _reissue() async {
    final doc = _doc;
    if (doc == null) return;
    const methodTitles = {
      'b': (
        'Unggah PDF — tempel QR verifikasi',
        'PDF baru ditempel QR pada posisi pilihan Anda.'
      ),
      'c': (
        'Unggah PDF ber-e-materai / TTE resmi',
        'PDF final dari platform resmi, dipakai apa adanya.'
      ),
      'd': (
        'Pindai hasil tanda tangan basah',
        'Foto/scan tiap halaman hasil ttd basah + meterai tempel.'
      ),
    };
    final method = await showModalBottomSheet<String>(
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
                  'Terbitkan ulang "${doc.subject}"',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final entry in methodTitles.entries)
                ListTile(
                  leading: const Icon(Icons.publish_rounded),
                  title: Text(entry.value.$1),
                  subtitle: Text(entry.value.$2),
                  onTap: () => Navigator.of(sheetContext).pop(entry.key),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
    if (method == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentUploadPage(
          documentId: doc.id,
          documentSubject: doc.subject,
          mode: DocumentUploadMode.reissue,
          reissueMethod: method,
          service: _service,
        ),
      ),
    );
    if (mounted) _loadDetail();
  }

  /// Hapus draf permanen — hanya status draft (menu disembunyikan untuk
  /// status lain; backend tetap menjaga 409). Draf + lampiran + runutan
  /// bersih; berbeda dari "Batalkan surat" yang hanya menandai void.
  Future<void> _deleteDraft() async {
    final doc = _doc;
    if (doc == null || _acting || doc.status != 'draft') return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus draf',
      content: 'Draf "${doc.subject}" dihapus permanen beserta lampirannya '
          'dan tidak bisa dikembalikan. Lanjutkan?',
      confirmText: 'Hapus',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _acting = true);
    try {
      await _service.deleteDraft(doc.id);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Draf surat dihapus.');
      Navigator.of(context).pop(true); // kembali ke arsip (list refresh).
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
        setState(() => _acting = false);
      }
    }
  }

  /// Batalkan surat (semua jenis; draft|menunggu_ttd|terbit) — alasan wajib.
  Future<void> _voidDocument() async {
    final doc = _doc;
    if (doc == null || _acting) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ReasonDialog(
        title: 'Batalkan surat',
        message: 'Surat "${doc.subject}" berstatus ${doc.statusLabel} dan '
            'tidak bisa digunakan lagi setelah dibatalkan.',
        actionLabel: 'Batalkan',
      ),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    setState(() => _acting = true);
    try {
      await _service.voidDocument(doc.id, reason: reason.trim());
      if (!mounted) return;
      showSuccessSnackBar(context, 'Surat dibatalkan.');
      _loadDetail();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  /// Cabut kuasa — HANYA jenis KUA & status terbit (guard backend);
  /// alasan + tanggal pencabutan (default hari ini).
  Future<void> _revoke() async {
    final doc = _doc;
    if (doc == null || _acting) return;
    final result = await showDialog<(String, DateTime)>(
      context: context,
      builder: (dialogContext) => _RevokeDialog(),
    );
    if (result == null || !mounted) return;

    setState(() => _acting = true);
    try {
      await _service.revoke(
        doc.id,
        reason: result.$1,
        revokedAt: result.$2,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Kuasa dicabut.');
      _loadDetail();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  // ——— tab PDF ———

  /// Muat berkas terbitan aktif (endpoint publik verify/{id}/file, tanpa
  /// bearer) atau pra-final draft (preFinal mode a → URL signed).
  Future<void> _loadPdf() async {
    final doc = _doc;
    if (doc == null || _pdfLoading) return;
    setState(() {
      _pdfLoading = true;
      _pdfError = null;
    });
    try {
      final Uint8List bytes;
      if (doc.activeIssuance != null) {
        bytes = await _fetchUrl('$_verifyUrl/file');
      } else {
        final result = await _service.preFinal(doc.id, mode: 'a');
        final url = result['download_url']?.toString();
        if (url == null || url.isEmpty) {
          throw Exception('URL pratinjau tidak tersedia.');
        }
        bytes = await _fetchUrl(url);
      }
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _pdfLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfError = ErrorUtils.sanitize(e, fallback: 'Gagal memuat berkas.');
        _pdfLoading = false;
      });
    }
  }

  // ——— build ———

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    return AppPageScaffold(
      titleText: 'Detail Surat',
      bodyPadding: EdgeInsets.zero,
      actions: [
        // Menu aksi sebagai tombol ⋮ (tooltip "Aksi Surat") yang membuka
        // bottom sheet berikon — aksi destruktif terpisah & berkonfirmasi.
        if (doc != null && !_acting)
          LetterActionMenuButton(
            tooltip: 'Aksi Surat',
            onTap: () => _openActions(doc),
          ),
      ],
      body: SafeArea(
        top: true,
        // bottom: true — konten tab tidak tertutup home indicator.
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: _errorMessage!,
                    subtitle: 'Terjadi kesalahan saat memuat detail surat',
                    action: ElevatedButton.icon(
                      onPressed: _loadDetail,
                      style: AppButtonStyle.elevated(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  )
                : doc == null
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          _buildHeader(context, doc),
                          // 4 tab — label seluruhnya utuh di lebar ponsel
                          // tanpa scroll. Riwayat penerbitan pindah ke
                          // seksi tab Info.
                          TabBar(
                            controller: _tabController,
                            isScrollable: false,
                            tabs: [
                              const Tab(text: 'Info'),
                              const Tab(text: 'PDF'),
                              const Tab(text: 'Verifikasi'),
                              Tab(
                                text:
                                    _thread != null && _thread!.nodes.length > 1
                                        ? 'Runutan (${_thread!.nodes.length})'
                                        : 'Runutan',
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _InfoTab(
                                  document: doc,
                                  dateFormatter: _dateFormatter,
                                  onOpenAttachment: _openAttachment,
                                  thread: _thread,
                                  threadLoading: _threadLoading,
                                  threadError: _threadError,
                                  onLoadThread: _loadThread,
                                  onOpenThreadTab: _openThreadTab,
                                  onNodeTap: _onThreadNodeTap,
                                  onRegisterReply: _registerExternalReply,
                                ),
                                _PdfTab(
                                  document: doc,
                                  bytes: _pdfBytes,
                                  loading: _pdfLoading,
                                  error: _pdfError,
                                  onLoad: _loadPdf,
                                  previewBuilder: widget.pdfPreviewBuilder,
                                ),
                                _VerifyTab(
                                  verifyUrl: _verifyUrl,
                                  hasActiveIssuance: doc.activeIssuance != null,
                                  onCopyUrl: _copyVerifyUrl,
                                  onOpenUrl: () => _openUrl(_verifyUrl),
                                ),
                                _ThreadTab(
                                  documentId: widget.documentId,
                                  thread: _thread,
                                  loading: _threadLoading,
                                  error: _threadError,
                                  onRetry: _loadThread,
                                  onNodeTap: _onThreadNodeTap,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  List<LetterAction> _letterActions(DocumentModel doc) {
    final isDraft = doc.status == 'draft';
    return [
      if (_isEditable)
        const LetterAction(
          value: 'edit',
          label: 'Edit',
          description: 'Lanjutkan mengisi draf di wizard.',
          icon: Icons.edit_note_rounded,
        ),
      // Hapus permanen hanya untuk draft (belum diajukan/ternomor).
      if (isDraft)
        const LetterAction(
          value: 'delete',
          label: 'Hapus draf…',
          description: 'Draf dihapus permanen beserta lampirannya.',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      if (_isTerbit)
        const LetterAction(
          value: 'register_reply',
          label: 'Daftarkan surat masuk (balasan pihak luar)',
          description: 'Catat surat dari pihak luar sebagai balasan surat ini.',
          icon: Icons.move_to_inbox_rounded,
        ),
      if (_isTerbit)
        const LetterAction(
          value: 'reissue',
          label: 'Terbitkan ulang…',
          description: 'Terbitkan ulang dengan PDF/QR atau hasil pindai baru.',
          icon: Icons.publish_rounded,
        ),
      if (_isTerbit && _isKua)
        const LetterAction(
          value: 'revoke',
          label: 'Cabut kuasa',
          description: 'Tandai surat kuasa tidak berlaku lagi.',
          icon: Icons.gavel_rounded,
        ),
      // Void HANYA untuk surat yang sudah diajukan/terbit — draf cukup
      // dihapus (koreksi review: draft tanpa "Batalkan"); dicabut/
      // dibatalkan tidak menawarkan apa pun.
      if (_isTerbit || doc.status == 'menunggu_ttd')
        const LetterAction(
          value: 'void',
          label: 'Batalkan surat',
          description: 'Surat ditandai batal dan tidak bisa dipakai lagi.',
          icon: Icons.cancel_outlined,
          destructive: true,
        ),
    ];
  }

  /// Bottom sheet aksi surat (ikon + keterangan + area ketuk besar) —
  /// pengganti popup menu teks polos agar aksi destruktif tidak mudah
  /// salah ketuk.
  Future<void> _openActions(DocumentModel doc) async {
    final value = await showLetterActionSheet(
      context,
      title: doc.subject,
      subtitle: [doc.number, doc.statusLabel].whereType<String>().join(' • '),
      actions: _letterActions(doc),
    );
    if (!mounted || value == null) return;
    switch (value) {
      case 'edit':
        await _editDraft();
      case 'delete':
        await _deleteDraft();
      case 'reissue':
        await _reissue();
      case 'revoke':
        await _revoke();
      case 'void':
        await _voidDocument();
      case 'register_reply':
        await _registerExternalReply();
    }
  }

  Widget _buildHeader(BuildContext context, DocumentModel doc) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final type = doc.letterType;
    final hasThread = (_thread?.nodes.length ?? 0) > 1;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (type != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: AppSpacing.borderRadiusSM,
                  ),
                  child: Text(
                    type.code,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  type?.name ?? 'Surat Perusahaan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DocumentStatusBadge(document: doc),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            doc.subject,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            children: [
              Icon(Icons.tag_rounded,
                  size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: InkWell(
                  onTap: doc.number != null
                      ? () {
                          Clipboard.setData(ClipboardData(text: doc.number!));
                          showInfoSnackBar(context, 'Nomor surat disalin');
                        }
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          doc.number ?? 'Belum bernomor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (doc.number != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.copy_rounded,
                            size: 12, color: colorScheme.onSurfaceVariant),
                      ],
                    ],
                  ),
                ),
              ),
              if (doc.date != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '• ${_dateFormatter.format(doc.date!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (doc.inReplyTo != null)
                _InReplyToChip(ref: doc.inReplyTo!, onTap: _openInReplyTo),
              ActionChip(
                avatar: Icon(
                  Icons.alt_route_rounded,
                  size: 16,
                  color: hasThread
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                backgroundColor: hasThread
                    ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                    : null,
                side: hasThread
                    ? BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.3))
                    : null,
                label: Text(
                  hasThread
                      ? '${_thread!.nodes.length} Surat dalam runutan'
                      : 'Lihat runutan',
                  style: TextStyle(
                    fontWeight: hasThread ? FontWeight.bold : FontWeight.normal,
                    color: hasThread ? colorScheme.primary : null,
                  ),
                ),
                onPressed: _openThreadTab,
                visualDensity: VisualDensity.compact,
              ),
              if (doc.status == 'terbit')
                ActionChip(
                  avatar: Icon(
                    Icons.move_to_inbox_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  label: const Text('Catat balasan masuk'),
                  onPressed: _registerExternalReply,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ——— helper URL ———

  Future<void> _openAttachment(AttachmentModel attachment) async {
    // Endpoint publik stream lampiran — hanya tersedia untuk surat terbit.
    await _openUrl('$_verifyUrl/attachments/${attachment.id}');
  }

  Future<void> _openUrl(String url) async {
    try {
      final ok = await _launchUrl(Uri.parse(url));
      if (!ok && mounted) {
        showWarningSnackBar(context, 'Tidak ada aplikasi untuk membuka URL.');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _copyVerifyUrl() async {
    await Clipboard.setData(ClipboardData(text: _verifyUrl));
    if (mounted) showInfoSnackBar(context, 'URL verifikasi disalin.');
  }
}

// ——— tab Info ———

class _InfoTab extends StatelessWidget {
  final DocumentModel document;
  final DateFormat dateFormatter;
  final void Function(AttachmentModel attachment) onOpenAttachment;
  final ThreadModel? thread;
  final bool threadLoading;
  final String? threadError;
  final VoidCallback onLoadThread;
  final VoidCallback onOpenThreadTab;
  final ValueChanged<ThreadNodeModel> onNodeTap;
  final VoidCallback? onRegisterReply;

  const _InfoTab({
    required this.document,
    required this.dateFormatter,
    required this.onOpenAttachment,
    required this.thread,
    required this.threadLoading,
    required this.threadError,
    required this.onLoadThread,
    required this.onOpenThreadTab,
    required this.onNodeTap,
    this.onRegisterReply,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        _runutanSection(context),
        _section(context, 'Ringkas', [
          _row(context, 'Jenis', document.letterType?.name),
          _row(context, 'Klasifikasi', document.classificationLabel),
          _row(context, 'Unit', document.unit),
          _row(
              context,
              'Tanggal',
              document.date != null
                  ? dateFormatter.format(document.date!)
                  : null),
          if (document.createdBy != null)
            _row(context, 'Pembuat', 'Pengguna #${document.createdBy}'),
        ]),
        ..._metadataSections(context),
        _signersSection(context),
        _attachmentsSection(context),
        // Riwayat penerbitan (eks-tab Terbitan): sekadar riwayat — cukup
        // sebagai seksi di Info agar tab utama tetap 4 dan label utuh.
        if (document.issuances.isNotEmpty) ...[
          _section(context, 'Riwayat penerbitan', [
            IssuanceTimeline(issuances: document.issuances),
          ]),
        ],
        ..._bodySection(context),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// Ringkasan runutan di tab Info — timeline balasan tidak lagi hanya
  /// tersembunyi di tab terakhir. Dimuat atas permintaan (lazy) agar detail
  /// surat berdiri sendiri tidak menambah request.
  Widget _runutanSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final nodes = thread?.nodes ?? const <ThreadNodeModel>[];
    final hasThread = nodes.length > 1;

    return _section(context, 'Runutan surat', [
      if (threadLoading)
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Memuat runutan surat…', style: textTheme.bodySmall),
          ],
        )
      else if (threadError != null) ...[
        Text(
          threadError!,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onLoadThread,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi'),
          ),
        ),
      ] else if (thread == null) ...[
        Text(
          'Surat ini bisa jadi bagian dari rangkaian balasan. Tampilkan '
          'runutan untuk melihat surat yang dibalas dan balasan '
          'berikutnya dalam satu garis waktu.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onLoadThread,
            icon: const Icon(Icons.alt_route_rounded, size: 18),
            label: const Text('Tampilkan runutan'),
          ),
        ),
      ] else if (!hasThread) ...[
        Text(
          'Surat ini berdiri sendiri — belum ada surat balasan atau tindak lanjut yang tertaut.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            if (document.status == 'terbit' && onRegisterReply != null)
              FilledButton.tonalIcon(
                onPressed: onRegisterReply,
                icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                label: const Text('Catat balasan pihak luar'),
              ),
            TextButton.icon(
              onPressed: onOpenThreadTab,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Buka tab Runutan'),
            ),
          ],
        ),
      ] else ...[
        Text(
          '${nodes.length} surat dalam satu runutan. Ketuk surat untuk '
          'membuka detailnya.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        LetterThreadTimeline(
          thread: thread!,
          currentNodeType: 'document',
          currentNodeId: document.id,
          onNodeTap: onNodeTap,
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenThreadTab,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Buka tab Runutan'),
          ),
        ),
      ],
    ]);
  }

  /// Render map metadata backend (`recipient` / `specific` / `validity` +
  /// key lain apa pun) menjadi baris key-value ramah.
  List<Widget> _metadataSections(BuildContext context) {
    final metadata = document.metadata;
    if (metadata == null || metadata.isEmpty) return const [];

    final widgets = <Widget>[];

    final recipient = metadata['recipient'];
    if (recipient is Map) {
      widgets.add(_section(context, 'Penerima', [
        _row(context, 'Nama', recipient['name']?.toString()),
        _row(context, 'Jabatan/instansi', recipient['title']?.toString()),
        _row(context, 'No. identitas', recipient['identity_no']?.toString()),
        _row(context, 'Alamat', recipient['address']?.toString()),
      ]));
    }

    final specific = metadata['specific'];
    if (specific is Map && specific.isNotEmpty) {
      widgets.add(_section(context, 'Keterangan khusus', [
        for (final entry in specific.entries)
          _row(context, _humanizeKey(entry.key), entry.value?.toString()),
      ]));
    }

    final validity = metadata['validity'];
    if (validity is Map) {
      final mode = validity['mode']?.toString();
      final untilDate = validity['until_date']?.toString();
      final parsed = untilDate == null ? null : DateTime.tryParse(untilDate);
      final label = mode == 'until_date' && parsed != null
          ? 'Sampai ${parsed.day}/${parsed.month}/${parsed.year}'
          : 'Tanpa batas';
      widgets.add(
          _section(context, 'Masa berlaku', [_row(context, 'Berlaku', label)]));
    }

    // Key tak dikenal ditampilkan apa adanya (tidak menyembunyikan data).
    final known = {'recipient', 'specific', 'validity'};
    final others = metadata.entries.where((e) => !known.contains(e.key));
    if (others.isNotEmpty) {
      widgets.add(_section(context, 'Metadata lain', [
        for (final entry in others)
          _row(context, _humanizeKey(entry.key), entry.value?.toString()),
      ]));
    }
    return widgets;
  }

  Widget _signersSection(BuildContext context) {
    final requests = document.signingRequests;
    return _section(context, 'Penandatangan', [
      if (requests.isEmpty)
        Text(
          'Belum ada permintaan tanda tangan.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        )
      else
        for (final request in requests)
          _SignerRow(request: request, dateFormatter: dateFormatter),
    ]);
  }

  Widget _attachmentsSection(BuildContext context) {
    final attachments = document.attachments;
    return _section(context, 'Lampiran', [
      if (attachments.isEmpty)
        Text(
          'Tidak ada lampiran.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        )
      else
        for (final attachment in attachments)
          _AttachmentRow(
            attachment: attachment,
            canOpen: document.status == 'terbit',
            onOpen: () => onOpenAttachment(attachment),
          ),
    ]);
  }

  /// Isi surat — hanya untuk draft|menunggu_ttd (backend menyertakan
  /// body_html kondisional); surat terbit menampilkan isi lewat tab PDF.
  List<Widget> _bodySection(BuildContext context) {
    final bodyHtml = document.bodyHtml;
    if (bodyHtml == null || !document.isEditable) return const [];
    final plain = letterHtmlToPlainText(bodyHtml);
    return [
      _section(context, 'Isi surat (draf)', [
        SelectableText(
          plain.isEmpty ? '(Belum ada isi)' : plain,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
      ]),
    ];
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  static String _humanizeKey(String key) => key.isEmpty
      ? key
      : '${key[0].toUpperCase()}${key.substring(1)}'.replaceAll('_', ' ');
}

class _SignerRow extends StatelessWidget {
  final SigningRequestModel request;
  final DateFormat dateFormatter;

  const _SignerRow({required this.request, required this.dateFormatter});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final signer = request.signer;
    final time = request.actedAt ?? request.requestedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(
              request.isPending
                  ? Icons.hourglass_top_rounded
                  : request.status == 'disetujui'
                      ? Icons.check_rounded
                      : Icons.close_rounded,
              size: 16,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signer?.displayName ?? 'Penandatangan tidak diketahui',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    signer?.roleLabel,
                    if (time != null) dateFormatter.format(time.toLocal()),
                  ].whereType<String>().join(' • '),
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            request.statusLabel,
            style: textTheme.labelMedium?.copyWith(
              color: request.status == 'ditolak' ? colorScheme.error : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final AttachmentModel attachment;
  final bool canOpen;
  final VoidCallback onOpen;

  const _AttachmentRow({
    required this.attachment,
    required this.canOpen,
    required this.onOpen,
  });

  static String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = _formatSize(attachment.size);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.attach_file_rounded,
              size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              size.isEmpty ? attachment.label : '${attachment.label} • $size',
              style: textTheme.bodyMedium,
            ),
          ),
          // Unduhan lampiran publik hanya tersedia untuk surat terbit
          // (endpoint verify butuh uuid dokumen terbit).
          if (canOpen)
            IconButton(
              tooltip: 'Buka lampiran',
              iconSize: 20,
              onPressed: onOpen,
              icon: Icon(Icons.open_in_new_rounded, color: colorScheme.primary),
            ),
        ],
      ),
    );
  }
}

// Riwayat penerbitan kini seksi di tab Info (eks-tab Terbitan) —
// _IssuancesTab dihapus.

// ——— tab PDF ———

class _PdfTab extends StatelessWidget {
  final DocumentModel document;
  final Uint8List? bytes;
  final bool loading;
  final String? error;
  final VoidCallback onLoad;
  final Widget Function(BuildContext context, Uint8List bytes)? previewBuilder;

  const _PdfTab({
    required this.document,
    required this.bytes,
    required this.loading,
    required this.error,
    required this.onLoad,
    this.previewBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIssued = document.activeIssuance != null;

    // Dicabut/dibatalkan (tanpa terbitan aktif & tidak lagi editable): tidak
    // ada berkas yang bisa dimuat — pra-final dijamin 422 dari server, jadi
    // tampilkan empty state TANPA tombol pratinjau.
    if (!isIssued && !document.isEditable) {
      return const EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: 'Berkas tidak tersedia untuk dokumen ini',
        subtitle: 'Berkas hanya tersedia untuk draf dan surat yang masih '
            'diterbitkan.',
      );
    }

    if (bytes != null) {
      final builder = previewBuilder;
      return Padding(
        padding: AppSpacing.paddingMD,
        child: builder != null
            ? builder(context, bytes!)
            : ClipRRect(
                borderRadius: AppSpacing.borderRadiusMD,
                child: PdfViewer.data(
                  bytes!,
                  sourceName: isIssued
                      ? (document.number ?? 'terbitan.pdf')
                      : 'pra-final.pdf',
                  params: PdfViewerParams(
                    backgroundColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
              ),
      );
    }

    return EmptyState(
      icon: Icons.picture_as_pdf_outlined,
      title: loading
          ? 'Memuat berkas…'
          : isIssued
              ? 'Berkas terbitan'
              : 'Pratinjau pra-final',
      subtitle: error ??
          (isIssued
              ? 'Berkas PDF versi terbitan yang berlaku.'
              : 'Render isi draf menjadi PDF pra-final (belum final).'),
      action: loading
          ? const Center(child: CircularProgressIndicator())
          : OutlinedButton.icon(
              onPressed: onLoad,
              style: AppButtonStyle.outlined(),
              icon: const Icon(Icons.download_rounded),
              label: Text(isIssued ? 'Muat berkas' : 'Pratinjau pra-final'),
            ),
    );
  }
}

// ——— tab Verifikasi ———

class _VerifyTab extends StatelessWidget {
  final String verifyUrl;
  final bool hasActiveIssuance;
  final VoidCallback onCopyUrl;
  final VoidCallback onOpenUrl;

  const _VerifyTab({
    required this.verifyUrl,
    required this.hasActiveIssuance,
    required this.onCopyUrl,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    if (!hasActiveIssuance) {
      return const EmptyState(
        icon: Icons.qr_code_rounded,
        title: 'QR verifikasi tersedia setelah surat diterbitkan.',
        subtitle: 'Halaman verifikasi publik memuat status terkini surat.',
      );
    }
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        Center(
          child: Container(
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppSpacing.borderRadiusLG,
            ),
            child: QrImageView(
              data: verifyUrl,
              size: 264,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'Pindai QR untuk membuka halaman verifikasi surat.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SelectableText(
          verifyUrl,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopyUrl,
                style: AppButtonStyle.outlined(),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Salin URL'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: onOpenUrl,
                style: AppButtonStyle.filled(),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Buka'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ——— chip induk runutan (fase 1b) ———

/// Chip "Membalas: {nomor/agenda}" di header detail surat keluar — tap
/// membuka detail surat induk (warna wadah chip Masuk timeline: induk
/// balasan paling sering surat masuk).
class _InReplyToChip extends StatelessWidget {
  final InReplyToRef ref;
  final ValueChanged<InReplyToRef> onTap;

  const _InReplyToChip({required this.ref, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => onTap(ref),
        borderRadius: AppSpacing.borderRadiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: AppSpacing.borderRadiusFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply_rounded,
                  size: 14, color: colorScheme.onSecondaryContainer),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${ref.relationLabel}: ${ref.numberOrAgenda ?? ref.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 14, color: colorScheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// ——— tab Runutan (fase 1b) ———

/// Tab Runutan surat keluar — [LetterThreadTimeline] dimuat malas saat
/// tab dibuka (`getThread('document', id)`), node saat ini = surat ini.
class _ThreadTab extends StatelessWidget {
  final String documentId;
  final ThreadModel? thread;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<ThreadNodeModel> onNodeTap;

  const _ThreadTab({
    required this.documentId,
    required this.thread,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onNodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: error!,
        subtitle: 'Terjadi kesalahan saat memuat runutan surat',
        action: ElevatedButton.icon(
          onPressed: onRetry,
          style: AppButtonStyle.elevated(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba Lagi'),
        ),
      );
    }
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        LetterThreadTimeline(
          thread:
              thread ?? const ThreadModel(rootType: '', rootId: '', nodes: []),
          currentNodeType: 'document',
          currentNodeId: documentId,
          onNodeTap: onNodeTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Tap surat pada runutan untuk membuka detailnya.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ——— dialog alasan ———

/// Dialog alasan wajib (batalkan surat). Controller dimiliki state dialog
/// dan dipose bersama dialog (pola _NoteDialog task 21).
class _ReasonDialog extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;

  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            maxLength: 255,
            decoration: const InputDecoration(
              hintText: 'Alasan (wajib)',
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
            if (value.isEmpty) {
              showWarningSnackBar(context, 'Alasan wajib diisi.');
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

/// Dialog cabut kuasa — alasan wajib + tanggal pencabutan (default hari ini).
/// Return (alasan, tanggal) atau null bila dibatalkan.
class _RevokeDialog extends StatefulWidget {
  @override
  State<_RevokeDialog> createState() => _RevokeDialogState();
}

class _RevokeDialogState extends State<_RevokeDialog> {
  final TextEditingController _controller = TextEditingController();
  DateTime _date = DateTime.now();

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cabut kuasa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Kuasa yang dicabut tidak berlaku lagi; tanggal & alasan '
              'tercatat di halaman verifikasi publik.'),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            borderRadius: AppSpacing.borderRadiusMD,
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tanggal pencabutan',
                suffixIcon: Icon(Icons.calendar_month_rounded),
                isDense: true,
              ),
              child: Text(_formatDate(_date)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            maxLength: 255,
            decoration: const InputDecoration(
              hintText: 'Alasan pencabutan (wajib)',
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
            if (value.isEmpty) {
              showWarningSnackBar(context, 'Alasan wajib diisi.');
              return;
            }
            Navigator.of(context).pop((value, _date));
          },
          child: const Text('Cabut'),
        ),
      ],
    );
  }
}

/// HTML isi surat → teks polos untuk tampilan read-only draf (render HTML
/// minimal & jujur: blok jadi baris, list jadi butir, tag lain dibuang,
/// entitas umum didekode — bukan renderer HTML penuh).
String letterHtmlToPlainText(String html) {
  var text = html
      .replaceAll(RegExp(r'<(br|BR)\s*/?>'), '\n')
      .replaceAllMapped(
          RegExp(r'</(p|div|h[1-6]|li|tr)>', caseSensitive: false), (_) => '\n')
      .replaceAllMapped(RegExp(r'<li[^>]*>', caseSensitive: false), (_) => '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // Rapikan spasi & baris kosong berlebih.
  text = text
      .split('\n')
      .map((line) => line.trim().replaceAll(RegExp(r'\s{2,}'), ' '))
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return text;
}
