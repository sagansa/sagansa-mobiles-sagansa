import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/enums/import_document_type.dart';
import '../models/enums/import_stage.dart';
import '../models/import_model.dart';
import '../services/image_service.dart';
import '../services/image_upload_service.dart';
import '../services/import_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/list_thumbnail.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'import_form_page.dart';
import 'import_receive_page.dart';

/// Detail proses impor: stepper tahapan, kelengkapan dokumen (gambar/PDF),
/// ringkasan HPP estimate vs real, dan aksi lanjut-tahap / terima / finalisasi.
class ImportDetailPage extends StatefulWidget {
  final int importId;

  const ImportDetailPage({super.key, required this.importId});

  @override
  State<ImportDetailPage> createState() => _ImportDetailPageState();
}

class _ImportDetailPageState extends State<ImportDetailPage> {
  final ImportService _service = ImportService();
  final NumberFormat _money = NumberFormat('#,##0.##');

  ImportPurchaseDetail? _detail;
  bool _isLoading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _service.getDetail(widget.importId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;

    return AppPageScaffold(
      titleText: 'Detail Impor #${widget.importId}',
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      actions: [
        if (d != null && !d.importPurchase.stage.isTerminal)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: _openEdit,
          ),
      ],
      body: d == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildHeader(d.importPurchase),
                  AppSpacing.gapVerticalMD,
                  _buildStepper(d),
                  AppSpacing.gapVerticalMD,
                  _buildHppSummary(d),
                  AppSpacing.gapVerticalMD,
                  _buildItemsSection(d),
                  AppSpacing.gapVerticalMD,
                  _buildCostsSection(d.importPurchase),
                  AppSpacing.gapVerticalMD,
                  _buildDocumentsSection(d),
                  AppSpacing.gapVerticalXL,
                ],
              ),
            ),
      bottomAction: (_detail == null || _busy)
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.md),
              child: _buildActions(_detail!),
            ),
    );
  }

  Widget _buildHeader(ImportPurchase import) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: import.supplierName,
      icon: Icons.public_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: import.stage.displayLabel,
                type: import.stage.badgeType,
                size: BadgeSize.medium,
              ),
              AppSpacing.gapHorizontalSM,
              Text(
                'Kurs ${_money.format(import.exchangeRate)} / ${import.currency}',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (import.notes?.isNotEmpty == true) ...[
            AppSpacing.gapVerticalSM,
            Text(import.notes!, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildStepper(ImportPurchaseDetail d) {
    final colorScheme = Theme.of(context).colorScheme;
    final flow = ImportStage.flow;
    final currentIdx = d.importPurchase.stage.flowIndex;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: flow.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final stage = flow[i];
          final done = currentIdx >= 0 && i < currentIdx;
          final current = i == currentIdx;
          final color = done
              ? AppColors.success
              : current
                  ? colorScheme.primary
                  : colorScheme.outlineVariant;

          return SizedBox(
            width: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done || current
                        ? color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    done ? Icons.check : _stageIcon(stage),
                    size: 17,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stage.displayLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: current ? FontWeight.bold : null,
                        color: current
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _stageIcon(ImportStage stage) {
    return switch (stage) {
      ImportStage.draft => Icons.edit_note,
      ImportStage.payment => Icons.payments_outlined,
      ImportStage.shipment => Icons.directions_boat_outlined,
      ImportStage.customs => Icons.gavel_outlined,
      ImportStage.arrival => Icons.anchor_outlined,
      ImportStage.receiving => Icons.scale_outlined,
      ImportStage.finalized => Icons.verified_outlined,
      ImportStage.cancelled => Icons.block_outlined,
      ImportStage.unknown => Icons.help_outline,
    };
  }

  Widget _buildHppSummary(ImportPurchaseDetail d) {
    final hpp = d.hpp;
    final colorScheme = Theme.of(context).colorScheme;
    final variance = hpp.variance;

    return SectionCard(
      title: 'Ringkasan Biaya & HPP',
      icon: Icons.calculate_outlined,
      child: Column(
        children: [
          _summaryRow('Nilai barang', 'Rp ${_money.format(hpp.goodsTotal)}'),
          _summaryRow(
              'Pajak (estimasi)', 'Rp ${_money.format(hpp.taxTotalEstimate)}'),
          _summaryRow('Bank (estimasi)',
              'Rp ${_money.format(hpp.bankTotalEstimate)}'),
          const Divider(),
          _summaryRow('Total Estimasi',
              'Rp ${_money.format(hpp.totalEstimate)}', bold: true),
          _summaryRow(
              'Total Realisasi', 'Rp ${_money.format(hpp.totalReal)}',
              bold: true),
          _summaryRow(
            'Selisih',
            'Rp ${_money.format(variance)}'
            '${hpp.variancePercent != null ? ' (${hpp.variancePercent!.toStringAsFixed(1)}%)' : ''}',
            valueColor: variance > 0 ? colorScheme.error : Colors.green,
          ),
          _summaryRow('HPP Pajak (est − pajak − bank)',
              'Rp ${_money.format(hpp.hppPajak)}'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: textTheme.bodySmall),
          ),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(ImportPurchaseDetail d) {
    final import = d.importPurchase;

    return SectionCard(
      title: 'Produk & Harga Satuan',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          for (final item in import.items)
            _buildItemTile(d, item),
        ],
      ),
    );
  }

  Widget _buildItemTile(ImportPurchaseDetail d, ImportItem item) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    ImportHppItemRow? row;
    for (final r in d.hpp.items) {
      if (r.id == item.id) {
        row = r;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style:
                textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapVerticalXS,
          Text(
            'Beli: ${_money.format(item.quantity)} ${item.unitName} × '
            '${_money.format(item.unitPriceForeign)} ${d.importPurchase.currency} = '
            'Rp ${_money.format(row?.goodsValue ?? 0)}',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          AppSpacing.gapVerticalXS,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Diterima: ${item.quantityReceived == null ? '—' : _money.format(item.quantityReceived!)}',
                  style: textTheme.bodySmall,
                ),
              ),
              Text(
                'HPP/unit est ${_money.format(row?.hppEstimateUnit ?? 0)} • '
                'real ${_money.format(row?.hppRealUnit ?? 0)}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildCostsSection(ImportPurchase import) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'Biaya (Estimasi vs Real)',
      icon: Icons.request_quote_outlined,
      child: import.costs.isEmpty
          ? Text('Belum ada biaya dicatat.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant))
          : Column(
              children: [
                for (final cost in import.costs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cost.name,
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                '${cost.categoryLabel}'
                                '${cost.taxRate != null ? ' • ${_money.format(cost.taxRate!)}% nilai barang' : ''}'
                                '${cost.isForeignCurrency ? ' • valuta ${_money.format(cost.amountForeign ?? 0)}' : ''}',
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Rp ${_money.format(cost.amountEstimate)}',
                                style: textTheme.bodySmall),
                            Text(
                              cost.amountReal == null
                                  ? '—'
                                  : 'Rp ${_money.format(cost.amountReal!)}',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDocumentsSection(ImportPurchaseDetail d) {
    final import = d.importPurchase;

    return SectionCard(
      title: 'Kelengkapan Dokumen',
      icon: Icons.folder_outlined,
      actions: [
        if (!import.stage.isTerminal)
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Upload dokumen',
            onPressed: _busy ? null : () => _pickAndUploadDocument(d),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checklist per tahap (hanya tahap dengan dokumen terkait).
          for (final check in d.checklist)
            if (check.documents.isNotEmpty && !check.isDone)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        check.label,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: check.isCurrent
                                      ? FontWeight.bold
                                      : null,
                                ),
                      ),
                    ),
                    for (final doc in check.documents)
                      Tooltip(
                        message: doc.present
                            ? 'Sudah diupload'
                            : (doc.required ? 'Wajib — belum ada' : 'Opsional'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: AppSpacing.borderRadiusXL,
                            color: doc.present
                                ? Colors.green.withValues(alpha: 0.12)
                                : doc.required
                                    ? Theme.of(context)
                                        .colorScheme
                                        .errorContainer
                                        .withValues(alpha: 0.4)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                doc.present
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 13,
                                color: doc.present
                                    ? Colors.green
                                    : doc.required
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                doc.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: doc.present
                                          ? Colors.green
                                          : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          if (import.documents.isNotEmpty) ...[
            const Divider(),
            for (final doc in import.documents)
              _buildDocumentTile(d, doc),
          ] else
            Text(
              'Belum ada dokumen. Tekan ikon upload di kanan atas seksi ini.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(ImportPurchaseDetail d, ImportDocumentModel doc) {
    final url = doc.fileUrl ?? ImageService.buildUrl(doc.filePath);
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: doc.isPdf
          ? Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: const Icon(Icons.picture_as_pdf_outlined),
            )
          : ListThumbnail(
              imageUrl: ImageService.buildUrl(doc.filePath),
              size: 44,
            ),
      title: Text(doc.type.displayLabel, style: textTheme.bodyMedium),
      subtitle: Text(
        doc.originalName ?? (doc.isPdf ? 'Dokumen PDF' : 'Gambar'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            tooltip: 'Buka',
            onPressed: url == null
                ? null
                : () => launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication),
          ),
          if (!d.importPurchase.stage.isTerminal)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Hapus',
              onPressed: _busy ? null : () => _deleteDocument(d, doc),
            ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------------- ACTIONS */

  Widget _buildActions(ImportPurchaseDetail d) {
    final stage = d.importPurchase.stage;

    if (stage.isTerminal) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.verified_outlined),
        label: Text(stage.isCancelled
            ? 'Proses dibatalkan'
            : 'Proses final — HPP produk sudah diperbarui'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _cancel(d),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Batalkan'),
          ),
        ),
        AppSpacing.gapHorizontalMD,
        Expanded(
          flex: 2,
          child: _primaryAction(d, stage),
        ),
      ],
    );
  }

  /// Aksi utama sesuai tahap:
  /// - arrival → buka form penerimaan (qty diterima + biaya real);
  /// - receiving → finalisasi (edit penerimaan tetap lewat ikon edit/ulang);
  /// - tahap lain → lanjut tahap berikutnya (gerbang dokumen dicek backend).
  Widget _primaryAction(ImportPurchaseDetail d, ImportStage stage) {
    if (stage == ImportStage.arrival || stage == ImportStage.receiving) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _openReceive(d),
              icon: const Icon(Icons.scale_outlined),
              label: const Text('Terima'),
            ),
          ),
          AppSpacing.gapHorizontalSM,
          Expanded(
            child: FilledButton.icon(
              onPressed: stage == ImportStage.receiving && !_busy
                  ? () => _finalize(d)
                  : null,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Finalisasi'),
            ),
          ),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _busy ? null : () => _advance(d),
      icon: const Icon(Icons.arrow_forward),
      label: Text('Lanjut: ${stage.next?.displayLabel ?? ''}'),
    );
  }

  Future<void> _setBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        showErrorDialog(
            context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance(ImportPurchaseDetail d) async {
    await _setBusy(() async {
      await _service.advance(widget.importId);
      await _load();
    });
  }

  Future<void> _cancel(ImportPurchaseDetail d) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Batalkan proses impor?',
      content:
          'Proses tidak dapat dilanjutkan setelah dibatalkan. Data & dokumen tetap tersimpan untuk arsip.',
      confirmText: 'Batalkan Proses',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _setBusy(() async {
      await _service.cancel(widget.importId);
      await _load();
    });
  }

  Future<void> _finalize(ImportPurchaseDetail d) async {
    // Tampilkan review HPP per produk sebelum konfirmasi.
    final buffer = StringBuffer();
    for (final item in d.importPurchase.items) {
      ImportHppItemRow? row;
      for (final r in d.hpp.items) {
        if (r.id == item.id) {
          row = r;
          break;
        }
      }
      buffer.writeln(
        '${item.productName}: Rp ${_money.format(row?.hppRealUnit ?? 0)}/'
        '${item.unitName.isEmpty ? 'unit' : item.unitName}',
      );
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Finalisasi HPP?',
      content:
          'Harga satuan final per produk (meng-update HPP di master produk):\n\n'
          '${buffer.toString()}',
      confirmText: 'Finalisasi',
    );
    if (!confirmed) return;

    await _setBusy(() async {
      await _service.finalize(widget.importId);
      await _load();
    });
  }

  Future<void> _openReceive(ImportPurchaseDetail d) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportReceivePage(detail: d),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openEdit() async {
    final d = _detail;
    if (d == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportFormPage(existing: d.importPurchase),
      ),
    );
    if (changed == true) _load();
  }

  /* ----------------------------------------------------------- DOCUMENTS */

  Future<void> _pickAndUploadDocument(ImportPurchaseDetail d) async {
    // 1) Pilih tipe dokumen.
    final ImportDocumentType? type = await _pickDocumentType();
    if (type == null || !mounted) return;

    // 2) Pilih sumber: kamera / galeri / PDF.
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sumber Dokumen'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'camera'),
            child: const Row(children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 10),
              Text('Kamera (foto dokumen)'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'gallery'),
            child: const Row(children: [
              Icon(Icons.photo_library),
              SizedBox(width: 10),
              Text('Galeri (gambar/scan)'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'pdf'),
            child: const Row(children: [
              Icon(Icons.picture_as_pdf_outlined),
              SizedBox(width: 10),
              Text('File PDF'),
            ]),
          ),
        ],
      ),
    );
    if (source == null) return;

    String? path;
    String? originalName;
    String? mimeType;
    int? sizeBytes;

    if (source == 'pdf') {
      // file_picker ≥13: pickFiles static, return List (kosong = batal).
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final localPath = file.path;
      if (localPath == null) return;
      path = await ImageUploadService.uploadPdf(
        File(localPath),
        directory: 'documents/ImportPurchase',
      );
      originalName = file.name;
      mimeType = 'application/pdf';
      // file_picker 13: ukuran via length() (async, fallback baca file).
      sizeBytes = await file.length();
    } else {
      final image = await ImageService.pickAndResizeImage(
        source:
            source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (image == null) return;
      path = await ImageUploadService.upload(
        image,
        directory: 'documents/ImportPurchase',
      );
      originalName = image.path.split('/').last;
      mimeType = 'image/webp';
      sizeBytes = await image.length();
    }

    if (path == null) {
      if (mounted) showErrorDialog(context, 'Upload gagal — coba lagi.');
      return;
    }

    await _setBusy(() async {
      await _service.attachDocument(
        widget.importId,
        type: type.toApi(),
        filePath: path!,
        originalName: originalName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
      );
      await _load();
    });
  }

  Future<ImportDocumentType?> _pickDocumentType() {
    return showModalBottomSheet<ImportDocumentType>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('Tipe Dokumen',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final t in ImportDocumentType.values)
              ListTile(
                leading: Icon(t.icon),
                title: Text(t.displayLabel),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDocument(
      ImportPurchaseDetail d, ImportDocumentModel doc) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus dokumen?',
      content:
          '${doc.type.displayLabel} akan dihapus. Bila wajib, proses tidak bisa lanjut tahap sebelum di-upload ulang.',
      isDestructive: true,
      confirmText: 'Hapus',
    );
    if (!confirmed) return;
    await _setBusy(() async {
      await _service.deleteDocument(widget.importId, doc.id);
      await _load();
    });
  }
}
