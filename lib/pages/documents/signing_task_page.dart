import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../services/document/document_models.dart';
import '../../services/document/document_service.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_spacing.dart';
import '../../utils/error_utils.dart';
import '../../widgets/app_page_scaffold.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_state.dart';

/// Tugas Tanda Tangan — daftar `GET /signing-requests/mine?status=diminta`
/// milik user login (pull-to-refresh; push notifikasi = fase 2).
///
/// Tap kartu → halaman tindak: pratinjau PDF pra-final (preFinal mode a →
/// URL signed → bytes → pdfrx) + tombol Setujui/Tolak (+ catatan opsional)
/// → approveSigning/rejectSigning.
///
/// [service] seam test — produksi memakai `DocumentService()`;
/// [fetchUrl]/[pdfPreviewBuilder] seam injeksi test.
class SigningTaskPage extends StatefulWidget {
  final DocumentService? service;
  final Future<Uint8List> Function(String url)? fetchUrl;
  final Widget Function(BuildContext context, Uint8List bytes)?
      pdfPreviewBuilder;

  const SigningTaskPage({
    super.key,
    this.service,
    this.fetchUrl,
    this.pdfPreviewBuilder,
  });

  @override
  State<SigningTaskPage> createState() => _SigningTaskPageState();
}

class _SigningTaskPageState extends State<SigningTaskPage> {
  late final DocumentService _service = widget.service ?? DocumentService();
  static final DateFormat _dateFormatter =
      DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  List<SigningRequestModel> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  Future<void> _fetch() async {
    setState(() {
      _isLoading = _items.isEmpty;
      _errorMessage = null;
    });
    try {
      final result = await _service.mySigningRequests(status: 'diminta');
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorUtils.sanitize(e,
            fallback: 'Gagal memuat tugas tanda tangan.');
        _isLoading = false;
      });
    }
  }

  Future<void> _openTask(SigningRequestModel request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SigningTaskActionPage(
          request: request,
          service: _service,
          fetchUrl: widget.fetchUrl,
          pdfPreviewBuilder: widget.pdfPreviewBuilder,
        ),
      ),
    );
    if (mounted) _fetch();
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Tugas Tanda Tangan',
      bodyPadding: EdgeInsets.zero,
      body: SafeArea(
        top: true,
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: _errorMessage!,
                    subtitle: 'Terjadi kesalahan saat memuat tugas',
                    action: ElevatedButton.icon(
                      onPressed: _fetch,
                      style: AppButtonStyle.elevated(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: _items.isEmpty
                        ? ListView(
                            // Scrollable agar RefreshIndicator tetap hidup.
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height / 2,
                              ),
                              EmptyState(
                                icon: Icons.task_alt_rounded,
                                title: 'Tidak ada tugas tanda tangan.',
                                subtitle:
                                    'Tarik ke bawah untuk memeriksa tugas baru.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: AppSpacing.paddingMD,
                            itemCount: _items.length,
                            itemBuilder: (context, index) =>
                                _buildCard(context, _items[index]),
                          ),
                  ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, SigningRequestModel request) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final document = request.document;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () => _openTask(request),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document?.number ?? 'Belum bernomor',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      document?.subject ?? '(Tanpa perihal)',
                      style: textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 13, color: colorScheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            request.requestedAt != null
                                ? 'Diminta ${_dateFormatter.format(request.requestedAt!.toLocal())}'
                                : 'Diminta',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.draw_rounded, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halaman tindak satu tugas: pratinjau pra-final + Setujui/Tolak.
class _SigningTaskActionPage extends StatefulWidget {
  final SigningRequestModel request;
  final DocumentService service;
  final Future<Uint8List> Function(String url)? fetchUrl;
  final Widget Function(BuildContext context, Uint8List bytes)?
      pdfPreviewBuilder;

  const _SigningTaskActionPage({
    required this.request,
    required this.service,
    this.fetchUrl,
    this.pdfPreviewBuilder,
  });

  @override
  State<_SigningTaskActionPage> createState() => _SigningTaskActionPageState();
}

class _SigningTaskActionPageState extends State<_SigningTaskActionPage> {
  final TextEditingController _noteController = TextEditingController();

  Uint8List? _previewBytes;
  bool _building = false;
  String? _buildError;
  bool _acting = false;

  late final Future<Uint8List> Function(String url) _fetchUrl =
      widget.fetchUrl ?? _fetchUrlDefault;

  static Future<Uint8List> _fetchUrlDefault(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh berkas (${response.statusCode}).');
    }
    return response.bodyBytes;
  }

  @override
  void initState() {
    super.initState();
    _buildPreview();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// pre-final (mode a) → unduh bytes PDF dari URL signed (tanpa bearer).
  Future<void> _buildPreview() async {
    final documentId = widget.request.document?.id;
    if (documentId == null || documentId.isEmpty) return;
    setState(() {
      _building = true;
      _buildError = null;
    });
    try {
      final result = await widget.service.preFinal(documentId, mode: 'a');
      final url = result['download_url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('URL pratinjau tidak tersedia.');
      }
      final bytes = await _fetchUrl(url);
      if (!mounted) return;
      setState(() => _previewBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _buildError = ErrorUtils.sanitize(e, fallback: 'Gagal memuat pratinjau.'));
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  Future<void> _decide({required bool approve}) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final note =
          _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
      if (approve) {
        await widget.service.approveSigning(widget.request.id, note: note);
      } else {
        await widget.service.rejectSigning(widget.request.id, note: note);
      }
      if (!mounted) return;
      showSuccessSnackBar(
          context, approve ? 'Tanda tangan disetujui.' : 'Tanda tangan ditolak.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
        setState(() => _acting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final document = widget.request.document;
    return AppPageScaffold(
      titleText: 'Tugas Tanda Tangan',
      bodyPadding: EdgeInsets.zero,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppSpacing.paddingMD.copyWith(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document?.number ?? 'Belum bernomor',
                    style:
                        textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    document?.subject ?? '(Tanpa perihal)',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildPreviewArea(context)),
            Padding(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 1,
                    maxLength: 255,
                    enabled: !_acting,
                    decoration: const InputDecoration(
                      hintText: 'Catatan (opsional)',
                      isDense: true,
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _acting ? null : () => _decide(approve: false),
                          style: AppButtonStyle.outlined(),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _acting ? null : () => _decide(approve: true),
                          style: AppButtonStyle.filled(),
                          icon: _acting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final builder = widget.pdfPreviewBuilder;
    if (_previewBytes != null) {
      return Padding(
        padding: AppSpacing.paddingHorizontalMD,
        child: builder != null
            ? builder(context, _previewBytes!)
            : ClipRRect(
                borderRadius: AppSpacing.borderRadiusMD,
                child: PdfViewer.data(
                  _previewBytes!,
                  sourceName: 'pra-final.pdf',
                  params: PdfViewerParams(
                    backgroundColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
              ),
      );
    }
    return EmptyState(
      icon: Icons.picture_as_pdf_outlined,
      title: _building ? 'Menyiapkan pratinjau…' : 'Pratinjau pra-final',
      subtitle: _buildError ?? 'Periksa isi surat sebelum memutuskan.',
      action: _building
          ? const Center(child: CircularProgressIndicator())
          : OutlinedButton.icon(
              onPressed: _buildPreview,
              style: AppButtonStyle.outlined(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
    );
  }
}
