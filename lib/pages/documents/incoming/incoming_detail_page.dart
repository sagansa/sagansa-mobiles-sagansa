import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../services/document/document_models.dart';
import '../../../services/document/document_service.dart';
import '../../../services/document/incoming_models.dart';
import '../../../services/document/incoming_service.dart';
import '../../../theme/app_button_style.dart';
import '../../../theme/app_spacing.dart';
import '../../../utils/error_utils.dart';
import '../../../widgets/app_page_scaffold.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/documents/letter_thread_timeline.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/status_badge.dart';
import '../document_create_wizard.dart';
import '../document_detail_page.dart';

/// Detail surat masuk (fase 1b) — header nomor agenda besar + badge sifat
/// & status, lalu 4 tab: **Info** (pengirim, nomor eksternal, tanggal,
/// perihal, lampiran, klasifikasi, integritas scan), **Scan** (viewer PDF
/// bytes dari `getIncomingScanBytes`), **Disposisi** (daftar + tambah dari
/// signer aktif + selesaikan; disposisi terakhir selesai → tawaran tandai
/// surat selesai), dan **Runutan** ([LetterThreadTimeline] embed detail,
/// node saat ini = surat ini; tap node lain membuka detail terkait).
///
/// Menu AppBar sesuai status (hanya maju terdaftar→diproses→selesai):
/// - "Balas surat ini" → wizard surat keluar mode balasan (Task 11:
///   prefill penerima = pengirim, perihal `Re: …`, paragraf pembuka di
///   editor, `in_reply_to` = surat ini) — pulang me-refresh detail;
/// - "Ubah" — disediakan namun dinonaktifkan (penyuntingan menyusul);
/// - "Tandai Diproses" (terdaftar) / "Tandai Selesai" (diproses).
///
/// [service] & [documentService] seam test — produksi memakai instance
/// default. [pdfPreviewBuilder] seam injeksi viewer di test.
class IncomingDetailPage extends StatefulWidget {
  final String letterId;
  final IncomingService? service;
  final DocumentService? documentService;

  final Widget Function(BuildContext context, Uint8List bytes)?
      pdfPreviewBuilder;

  const IncomingDetailPage({
    super.key,
    required this.letterId,
    this.service,
    this.documentService,
    this.pdfPreviewBuilder,
  });

  @override
  State<IncomingDetailPage> createState() => _IncomingDetailPageState();
}

class _IncomingDetailPageState extends State<IncomingDetailPage>
    with SingleTickerProviderStateMixin {
  late final IncomingService _service = widget.service ?? IncomingService();
  late final DocumentService _documentService =
      widget.documentService ?? DocumentService();

  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );
  static final DateFormat _dateFormatter = DateFormat('d MMM yyyy', 'id_ID');

  IncomingLetterModel? _letter;
  bool _isLoading = true;
  String? _errorMessage;
  bool _acting = false;

  // ——— tab Scan ———
  Uint8List? _scanBytes;
  bool _scanLoading = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = _letter == null;
      _errorMessage = null;
    });
    try {
      final detail = await _service.getIncomingDetail(widget.letterId);
      if (!mounted) return;
      setState(() {
        _letter = detail;
        _isLoading = false;
        // Scan mungkin berubah (surat lain setelah navigasi runutan) —
        // muat ulang bila pengguna kembali ke tab Scan.
        _scanBytes = null;
        _scanError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorUtils.sanitize(e,
            fallback: 'Gagal memuat detail surat masuk.');
        _isLoading = false;
      });
    }
  }

  IncomingLetterModel? get _doc => _letter;

  // ——— aksi status (hanya maju) ———

  /// Terdaftar → diproses, diproses → selesai; surat selesai tidak
  /// menawarkan apa pun (mundur/berulang → 409 backend).
  Future<void> _advanceStatus() async {
    final letter = _doc;
    if (letter == null || _acting) return;
    final next = letter.status == 'terdaftar' ? 'diproses' : 'selesai';
    setState(() => _acting = true);
    try {
      await _service.markIncomingStatus(letter.id, next);
      if (!mounted) return;
      showSuccessSnackBar(
          context, 'Surat ditandai ${IncomingLetterModel.statusLabelOf(next)}.');
      await _loadDetail();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  // ——— disposisi ———

  /// Sheet tambah disposisi: pilih signer aktif (dropdown) + instruksi
  /// multiline wajib. Sheet mem-pop hasil; service dipanggil di sini agar
  /// loading/error/refresh terpusat.
  Future<void> _openAddDisposition() async {
    final letter = _doc;
    if (letter == null || _acting) return;
    final result = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddDispositionSheet(
        fetchSigners: _documentService.getSigners,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _acting = true);
    try {
      await _service.addDisposition(
        letter.id,
        toUserId: result.$1,
        instruction: result.$2,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Disposisi ditambahkan.');
      await _loadDetail();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  /// Selesaikan disposisi (konfirmasi ringan). Bila itu disposisi TERAKHIR
  /// yang terbuka, tawarkan menandai surat selesai sekalian.
  Future<void> _completeDisposition(DispositionModel disposition) async {
    if (_acting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selesaikan disposisi?'),
        content: Text(
          'Disposisi kepada ${disposition.toUserLabel} akan ditandai '
          'selesai dan tidak bisa dibuka kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      await _service.completeDisposition(disposition.id);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Disposisi selesai.');
      await _loadDetail();

      // Disposisi terakhir barusan selesai & surat belum selesai → tawarkan
      // menaikkan status surat (tetap opsional; pengguna boleh menolak).
      final letter = _doc;
      if (letter == null || !mounted) return;
      final hasOpen = letter.dispositions.any((d) => !d.isCompleted);
      if (!hasOpen &&
          letter.dispositions.isNotEmpty &&
          letter.status != 'selesai') {
        final markSelesai = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.task_alt_rounded, size: 40),
            title: const Text('Semua disposisi selesai'),
            content: const Text(
              'Tandai surat ini selesai? Surat selesai tidak bisa diubah '
              'atau menerima disposisi baru.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Nanti'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Tandai Selesai'),
              ),
            ],
          ),
        );
        if (markSelesai == true && mounted) {
          await _service.markIncomingStatus(letter.id, 'selesai');
          if (!mounted) return;
          showSuccessSnackBar(context, 'Surat ditandai Selesai.');
          await _loadDetail();
        }
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  // ——— tab Scan ———

  /// Muat bytes scan (bearer) untuk viewer PDF.
  Future<void> _loadScan() async {
    final letter = _doc;
    if (letter == null || _scanLoading) return;
    setState(() {
      _scanLoading = true;
      _scanError = null;
    });
    try {
      final bytes =
          Uint8List.fromList(await _service.getIncomingScanBytes(letter.id));
      if (!mounted) return;
      setState(() {
        _scanBytes = bytes;
        _scanLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanError =
            ErrorUtils.sanitize(e, fallback: 'Gagal memuat berkas scan.');
        _scanLoading = false;
      });
    }
  }

  // ——— runutan ———

  /// Tap node runutan → detail terkait. Node masuk lain membuka detail
  /// masuk; node keluar membuka detail surat keluar (fase 1 — kini lengkap
  /// tab Runutan, service surat masuk diteruskan). Node saat ini diabaikan
  /// (halaman ini sudah menampilkannya).
  Future<void> _onThreadNodeTap(ThreadNodeModel node) async {
    if (node.type == 'incoming_letter') {
      if (node.id == widget.letterId) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingDetailPage(
            letterId: node.id,
            service: _service,
            documentService: _documentService,
            pdfPreviewBuilder: widget.pdfPreviewBuilder,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailPage(
            documentId: node.id,
            service: _documentService,
            incomingService: _service,
          ),
        ),
      );
    }
    if (mounted) _loadDetail();
  }

  // ——— build ———

  @override
  Widget build(BuildContext context) {
    final letter = _letter;
    return AppPageScaffold(
      titleText: 'Detail Surat Masuk',
      bodyPadding: EdgeInsets.zero,
      actions: [
        if (letter != null)
          PopupMenuButton<String>(
            tooltip: 'Aksi Surat Masuk',
            enabled: !_acting,
            onSelected: (value) {
              switch (value) {
                case 'reply':
                  _openReplyWizard();
                case 'status':
                  _advanceStatus();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reply',
                child: Text('Balas surat ini'),
              ),
              // Penyuntingan surat masuk menyusul (fase berikutnya) —
              // selalu nonaktif agar posisi menu stabil.
              const PopupMenuItem(
                value: 'edit',
                enabled: false,
                child: Text('Ubah (penyuntingan menyusul)'),
              ),
              if (letter.status != 'selesai')
                PopupMenuItem(
                  value: 'status',
                  child: Text(
                      letter.status == 'terdaftar'
                          ? 'Tandai Diproses'
                          : 'Tandai Selesai'),
                ),
            ],
          ),
      ],
      body: SafeArea(
        top: true,
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: _errorMessage!,
                    subtitle: 'Terjadi kesalahan saat memuat surat masuk',
                    action: ElevatedButton.icon(
                      onPressed: _loadDetail,
                      style: AppButtonStyle.elevated(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  )
                : letter == null
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          _buildHeader(context, letter),
                          TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'Info'),
                              Tab(text: 'Scan'),
                              Tab(text: 'Disposisi'),
                              Tab(text: 'Runutan'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _InfoTab(
                                  letter: letter,
                                  dateFormatter: _dateFormatter,
                                ),
                                _ScanTab(
                                  bytes: _scanBytes,
                                  loading: _scanLoading,
                                  error: _scanError,
                                  onLoad: _loadScan,
                                  sourceName: letter.agendaNumber,
                                  previewBuilder: widget.pdfPreviewBuilder,
                                ),
                                _DispositionsTab(
                                  letter: letter,
                                  acting: _acting,
                                  dateFormatter: _dateFormatter,
                                  onAdd: _openAddDisposition,
                                  onComplete: _completeDisposition,
                                ),
                                _ThreadTab(
                                  letter: letter,
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

  /// Wizard balasan surat keluar atas surat masuk ini (Task 11): wizard
  /// mode `replyTo` — banner "Membalas", prefill penerima = pengirim,
  /// perihal `Re: …`, paragraf pembuka di editor, createDraft mengirim
  /// `in_reply_to {type: incoming_letter, id: surat ini}`. Pulang dari
  /// wizard (biasa maupun "Lihat runutan" yang menggantikan wizard dengan
  /// detail surat baru) → detail dimuat ulang: runutan bisa bertambah.
  Future<void> _openReplyWizard() async {
    final letter = _doc;
    if (letter == null || _acting) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCreateWizard(
          service: _documentService,
          replyTo: letter,
        ),
      ),
    );
    if (mounted) _loadDetail();
  }

  Widget _buildHeader(BuildContext context, IncomingLetterModel letter) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: AppSpacing.paddingMD,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            letter.agendaNumber,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _buildSifatBadge(letter),
              const SizedBox(width: AppSpacing.sm),
              _buildStatusBadge(letter),
            ],
          ),
        ],
      ),
    );
  }

  /// Pemetaan warna badge sama persis kartu buku agenda (fase 1b Task 8).
  Widget _buildSifatBadge(IncomingLetterModel letter) {
    final type = switch (letter.sifat) {
      'rahasia' => StatusType.error,
      'segera' => StatusType.warning,
      _ => StatusType.neutral,
    };
    return StatusBadge(label: letter.sifatLabel, type: type);
  }

  Widget _buildStatusBadge(IncomingLetterModel letter) {
    final type = switch (letter.status) {
      'selesai' => StatusType.success,
      'diproses' => StatusType.warning,
      _ => StatusType.neutral,
    };
    return StatusBadge(label: letter.statusLabel, type: type);
  }
}

// ——— tab Info ———

class _InfoTab extends StatelessWidget {
  final IncomingLetterModel letter;
  final DateFormat dateFormatter;

  const _InfoTab({required this.letter, required this.dateFormatter});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        _section(context, 'Perihal', [
          Text(letter.subject,
              style: Theme.of(context).textTheme.bodyLarge),
        ]),
        _section(context, 'Pengirim & tanggal', [
          _row(context, 'Pengirim', letter.senderParty?.name),
          _row(context, 'Alamat pengirim', letter.senderParty?.address),
          _row(context, 'Nomor eksternal', letter.numberExternal),
          _row(
              context,
              'Tanggal surat',
              letter.letterDate != null
                  ? dateFormatter.format(letter.letterDate!)
                  : null),
          _row(
              context,
              'Diterima',
              letter.receivedAt != null
                  ? dateFormatter.format(letter.receivedAt!)
                  : null),
          _row(context, 'Klasifikasi', letter.classificationLabel),
          _row(context, 'Uraian lampiran', letter.attachmentsNote),
        ]),
        _scanIntegritySection(context),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// Metadata integritas scan — sha256 pendek 8 karakter (full disalin via
  /// long-press, pola IssuanceTimeline) + ukuran + jumlah halaman.
  Widget _scanIntegritySection(BuildContext context) {
    final hasMeta =
        letter.scanSha256 != null || letter.scanSize != null || letter.scanPages != null;
    return _section(context, 'Integritas scan', [
      if (!hasMeta)
        Text(
          'Metadata scan tidak tersedia.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        )
      else
        Row(
          children: [
            Icon(Icons.fingerprint_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: GestureDetector(
                onLongPress: letter.scanSha256 == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                            ClipboardData(text: letter.scanSha256!));
                        if (context.mounted) {
                          showInfoSnackBar(
                              context, 'SHA-256 lengkap disalin.');
                        }
                      },
                child: Text(
                  [
                    if (letter.scanSha256 != null)
                      'SHA-256 ${_shortHash(letter.scanSha256!)}',
                    if (letter.scanSize != null)
                      _formatBytes(letter.scanSize!),
                    if (letter.scanPages != null)
                      '${letter.scanPages} halaman',
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
          ],
        ),
    ]);
  }

  static String _shortHash(String hash) =>
      hash.length <= 8 ? hash : '${hash.substring(0, 8)}…';

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
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
            width: 120,
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
}

// ——— tab Scan ———

class _ScanTab extends StatelessWidget {
  final Uint8List? bytes;
  final bool loading;
  final String? error;
  final VoidCallback onLoad;
  final String sourceName;
  final Widget Function(BuildContext context, Uint8List bytes)? previewBuilder;

  const _ScanTab({
    required this.bytes,
    required this.loading,
    required this.error,
    required this.onLoad,
    required this.sourceName,
    this.previewBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  sourceName: '$sourceName.pdf',
                  params: PdfViewerParams(
                    backgroundColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
              ),
      );
    }

    return EmptyState(
      icon: Icons.document_scanner_rounded,
      title: loading ? 'Memuat scan…' : 'Berkas scan surat',
      subtitle: error ??
          'Scan asli surat fisik sebagaimana diterima (PDF dari server).',
      action: loading
          ? const Center(child: CircularProgressIndicator())
          : OutlinedButton.icon(
              onPressed: onLoad,
              style: AppButtonStyle.outlined(),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Muat scan'),
            ),
    );
  }
}

// ——— tab Disposisi ———

class _DispositionsTab extends StatelessWidget {
  final IncomingLetterModel letter;
  final bool acting;
  final DateFormat dateFormatter;
  final VoidCallback onAdd;
  final ValueChanged<DispositionModel> onComplete;

  const _DispositionsTab({
    required this.letter,
    required this.acting,
    required this.dateFormatter,
    required this.onAdd,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final dispositions = letter.dispositions;
    return Column(
      children: [
        Expanded(
          child: dispositions.isEmpty
              ? const EmptyState(
                  icon: Icons.assignment_ind_rounded,
                  title: 'Belum ada disposisi.',
                  subtitle: 'Catatan pengarahan untuk signer aktif muncul '
                      'di sini.',
                )
              : ListView(
                  padding: AppSpacing.paddingMD,
                  children: [
                    for (final disposition in dispositions)
                      _DispositionCard(
                        disposition: disposition,
                        dateFormatter: dateFormatter,
                        acting: acting,
                        letterSelesai: letter.status == 'selesai',
                        onComplete: () => onComplete(disposition),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
        ),
        // Surat `selesai` = arsip final (keputusan #9 fase 1b):
        // DispositionController menolak tambah disposisi dengan 409
        // INCOMING_LOCKED, jadi tombol hanya tampil selama surat masih
        // terbuka (terdaftar/diproses) — UI dan backend sepakat.
        if (letter.status != 'selesai')
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: acting ? null : onAdd,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Tambah Disposisi'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DispositionCard extends StatelessWidget {
  final DispositionModel disposition;
  final DateFormat dateFormatter;
  final bool acting;
  final bool letterSelesai;
  final VoidCallback onComplete;

  const _DispositionCard({
    required this.disposition,
    required this.dateFormatter,
    required this.acting,
    required this.letterSelesai,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = disposition.isCompleted;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isCompleted
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.secondaryContainer,
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : Icons.assignment_outlined,
                  size: 16,
                  color: isCompleted
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disposition.toUserLabel,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      [
                        if (disposition.actedAt != null)
                          'Diselesaikan ${dateFormatter.format(disposition.actedAt!.toLocal())}',
                        if (disposition.createdAt != null)
                          'Dibuat ${dateFormatter.format(disposition.createdAt!.toLocal())}',
                      ].join(' • '),
                      style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: disposition.statusLabel,
                type: isCompleted ? StatusType.success : StatusType.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(disposition.instruction, style: textTheme.bodyMedium),
          if (!isCompleted)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: acting ? null : onComplete,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Selesaikan'),
              ),
            ),
        ],
      ),
    );
  }
}

// ——— tab Runutan ———

class _ThreadTab extends StatelessWidget {
  final IncomingLetterModel letter;
  final ValueChanged<ThreadNodeModel> onNodeTap;

  const _ThreadTab({required this.letter, required this.onNodeTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        LetterThreadTimeline(
          thread: letter.thread ??
              const ThreadModel(rootType: '', rootId: '', nodes: []),
          currentNodeType: 'incoming_letter',
          currentNodeId: letter.id,
          onNodeTap: onNodeTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Tap surat pada runutan untuk membuka detailnya.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ——— sheet tambah disposisi ———

/// Sheet tambah disposisi — signer aktif dimuat saat sheet dibuka
/// (`DocumentService.getSigners`), dropdown penerima + instruksi multiline
/// wajib. Mem-pop `(toUserId, instruction)` atau null.
class _AddDispositionSheet extends StatefulWidget {
  final Future<List<SignerModel>> Function() fetchSigners;

  const _AddDispositionSheet({required this.fetchSigners});

  @override
  State<_AddDispositionSheet> createState() => _AddDispositionSheetState();
}

class _AddDispositionSheetState extends State<_AddDispositionSheet> {
  final TextEditingController _instructionController = TextEditingController();

  List<SignerModel> _signers = [];
  bool _loading = true;
  String? _error;
  SignerModel? _selected;
  bool _instructionMissing = false;

  @override
  void initState() {
    super.initState();
    _loadSigners();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _loadSigners() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final signers = await widget.fetchSigners();
      if (!mounted) return;
      setState(() {
        _signers = signers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.sanitize(e,
            fallback: 'Gagal memuat daftar signer.');
        _loading = false;
      });
    }
  }

  void _submit() {
    final instruction = _instructionController.text.trim();
    final signer = _selected;
    if (signer == null) {
      showWarningSnackBar(context, 'Pilih penerima disposisi.');
      return;
    }
    if (instruction.isEmpty) {
      setState(() => _instructionMissing = true);
      return;
    }
    Navigator.of(context).pop((signer.id, instruction));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: AppSpacing.paddingMD,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah Disposisi',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Penerima harus signer aktif; surat otomatis naik status ke '
              'Diproses saat disposisi pertama ditambahkan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: AppSpacing.paddingMD,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                  TextButton.icon(
                    onPressed: _loadSigners,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba lagi'),
                  ),
                ],
              )
            else if (_signers.isEmpty)
              Text(
                'Tidak ada signer aktif. Hubungi admin untuk menambahkan '
                'penandatangan aktif.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else ...[
              DropdownButtonFormField<SignerModel>(
                initialValue: _selected,
                isExpanded: true,
                items: [
                  for (final signer in _signers)
                    DropdownMenuItem(
                      value: signer,
                      child: Text(
                        '${signer.displayName} (${signer.roleLabel})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selected = value),
                decoration: const InputDecoration(
                  labelText: 'Penerima disposisi',
                  prefixIcon: Icon(Icons.how_to_reg_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _instructionController,
                maxLines: 4,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Instruksi disposisi',
                  hintText: 'Mis. Mohon dipelajari dan dipersiapkan '
                      'tanggapan sebelum rapat',
                  errorText: _instructionMissing
                      ? 'Instruksi wajib diisi.'
                      : null,
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_instructionMissing) {
                    setState(() => _instructionMissing = false);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Kirim Disposisi'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
