import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/enums/import_document_type.dart';
import '../models/enums/import_stage.dart';
import '../models/import_model.dart';
import '../services/image_service.dart';
import '../services/image_upload_service.dart';
import '../services/import_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/import_blocked_dialog.dart';
import '../widgets/list_thumbnail.dart';
import '../widgets/modern_button.dart';
import '../widgets/status_badge.dart';
import 'import_form_page.dart';
import 'import_receive_page.dart';

/// Detail proses impor: stepper tahapan, kelengkapan dokumen (gambar/PDF),
/// ringkasan HPP estimate vs real, dan aksi lanjut-tahap / terima / finalisasi.
///
/// Seksi memakai [DetailSectionCard] + [DetailRow] — komponen standar
/// halaman detail (pola fuel service / procurement detail).
class ImportDetailPage extends StatefulWidget {
  final int importId;

  const ImportDetailPage({super.key, required this.importId});

  @override
  State<ImportDetailPage> createState() => _ImportDetailPageState();
}

class _ImportDetailPageState extends State<ImportDetailPage> {
  final ImportService _service = ImportService();

  ImportPurchaseDetail? _detail;
  bool _isLoading = true;
  bool _busy = false;
  String? _error;

  /// Rupiah utuh bergaya Indonesia ("Rp 417.099.315").
  String _rp(num v) => FormatUtils.formatRupiah(v);

  /// Angka tanpa satuan, desimal dibuang bila nol ("19.500" / "0,78").
  String _num(num v, {int decimals = 2}) =>
      FormatUtils.formatAmount(v, decimals: decimals);

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
        if (d != null && d.importPurchase.stage != ImportStage.finalized)
          BarButtonCluster(actions: [
            if (!d.importPurchase.stage.isTerminal)
              BarButtonSpec(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: _openEdit,
              ),
            if (!d.importPurchase.stage.isTerminal)
              BarButtonSpec(
                icon: Icons.block_outlined,
                tooltip: 'Batalkan proses',
                onTap: () => _cancel(d),
              ),
            BarButtonSpec(
              icon: Icons.delete_outline,
              tooltip: 'Hapus permanen',
              onTap: () => _delete(d),
            ),
          ]),
      ],
      bodyPadding: EdgeInsets.zero,
      body: d == null
          ? const SizedBox.shrink()
          : Builder(
              // Konteks di dalam body Scaffold: MediaQuery padding bawah
              // memuat tinggi bar aksi (extendBody) — konten terakhir tidak
              // lagi tertutup bar "Proses dibatalkan" dsb.
              builder: (bodyContext) => RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.screenPadding.copyWith(
                    top: AppBarInsets.top(bodyContext),
                    bottom: MediaQuery.paddingOf(bodyContext).bottom +
                        AppSpacing.md,
                  ),
                  children: [
                    _buildHeader(d.importPurchase),
                    AppSpacing.gapVerticalMD,
                    _buildStepper(d),
                    AppSpacing.gapVerticalMD,
                    _buildHppSummary(d),
                    AppSpacing.gapVerticalMD,
                    _buildItemsSection(d),
                    AppSpacing.gapVerticalMD,
                    _buildCostsSection(d),
                    AppSpacing.gapVerticalMD,
                    _buildDocumentsSection(d),
                    AppSpacing.gapVerticalXL,
                  ],
                ),
              ),
            ),
      bottomAction: (_detail == null)
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.md),
              child: _buildActions(_detail!),
            ),
    );
  }

  Widget _buildHeader(ImportPurchase import) {
    final textTheme = Theme.of(context).textTheme;

    return DetailSectionCard(
      icon: Icons.public_outlined,
      title: import.supplierName,
      trailing: StatusBadge(
        label: import.stage.displayLabel,
        type: import.stage.badgeType,
      ),
      children: [
        DetailRow(
          label: 'Kurs',
          value: 'Rp ${_num(import.exchangeRate)} / ${import.currency}',
          isBold: true,
        ),
        DetailRow(
          label: 'Produk',
          value: '${import.items.length} item',
        ),
        DetailRow(
          label: 'Dokumen',
          value: '${import.documents.length} file',
        ),
        if (import.notes?.isNotEmpty == true)
          Text(
            import.notes!,
            style: textTheme.bodySmall,
          ),
      ],
    );
  }

  /// Timeline alur 7 tahap: simpul ikon + konektor; tahap selesai terisi
  /// hijau dengan centang, tahap aktif diberi ring warna tahapnya.
  /// Proses dibatalkan tidak punya posisi alur — tampilkan banner arsip.
  Widget _buildStepper(ImportPurchaseDetail d) {
    final colorScheme = Theme.of(context).colorScheme;
    final flow = ImportStage.flow;
    final currentIdx = d.importPurchase.stage.flowIndex;

    if (d.importPurchase.stage.isCancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.15),
          borderRadius: AppSpacing.borderRadiusMD,
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.block_outlined, size: 18, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Proses dibatalkan — data & dokumen tersimpan sebagai arsip.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: flow.length,
          // Index separator = index simpul sebelum konektor; terisi bila
          // simpul tersebut sudah dilewati.
          separatorBuilder: (_, i) => Container(
            width: 14,
            height: 2,
            margin: const EdgeInsets.only(bottom: 26),
            color: currentIdx >= 0 && i < currentIdx
                ? AppColors.success
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          itemBuilder: (context, i) {
            final stage = flow[i];
            final done = currentIdx >= 0 && i < currentIdx;
            final current = i == currentIdx;
            final color = done
                ? AppColors.success
                : current
                    ? _stageColor(stage)
                    : colorScheme.outlineVariant;

            return SizedBox(
              width: 84,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.success
                          : current
                              ? color.withValues(alpha: 0.15)
                              : Colors.transparent,
                      border: Border.all(
                        color: color,
                        width: current ? 2.5 : 2,
                      ),
                    ),
                    child: Icon(
                      done ? Icons.check : _stageIcon(stage),
                      size: 15,
                      color: done ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(height: 5),
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

  Color _stageColor(ImportStage stage) {
    final cs = Theme.of(context).colorScheme;
    return switch (stage.badgeType) {
      StatusType.success => AppColors.success,
      StatusType.warning => AppColors.warning,
      StatusType.error => cs.error,
      StatusType.info => AppColors.info,
      StatusType.neutral => AppColors.onSurfaceVariant,
    };
  }

  /// Ringkasan biaya: baris rincian [DetailRow], lalu penanda Estimasi vs
  /// Realisasi berdampingan dengan selisih & persentase.
  Widget _buildHppSummary(ImportPurchaseDetail d) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hpp = d.hpp;
    final variance = hpp.variance;
    final hasReal = hpp.totalReal > 0;
    final overBudget = variance > 0;

    return DetailSectionCard(
      icon: Icons.calculate_outlined,
      title: 'Ringkasan Biaya & HPP',
      children: [
        DetailRow(
          label: 'Nilai barang',
          value: _rp(hpp.goodsTotal),
          labelWidth: 150,
        ),
        DetailRow(
          label: 'Pajak (estimasi)',
          value: _rp(hpp.taxTotalEstimate),
          labelWidth: 150,
        ),
        DetailRow(
          label: 'Bank (estimasi)',
          value: _rp(hpp.bankTotalEstimate),
          labelWidth: 150,
        ),
        DetailRow(
          label: 'Tanpa pajak & bank',
          value: _rp(hpp.hppPajak),
          labelWidth: 150,
        ),

        // Dua kotak penanda: Estimasi vs Realisasi.
        Row(
          children: [
            Expanded(
              child: _totalTile(
                theme,
                cs,
                label: 'Total Estimasi',
                value: _rp(hpp.totalEstimate),
              ),
            ),
            AppSpacing.gapHorizontalMD,
            Expanded(
              child: _totalTile(
                theme,
                cs,
                label: 'Total Realisasi',
                value: hasReal ? _rp(hpp.totalReal) : '—',
                emphasized: hasReal,
                emphasisColor: overBudget ? cs.error : AppColors.success,
              ),
            ),
          ],
        ),

        if (hasReal)
          Row(
            children: [
              Icon(
                overBudget
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 16,
                color: overBudget ? cs.error : AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Selisih ${overBudget ? ' lebih' : ' lebih hemat'} '
                  '${_rp(variance.abs())}'
                  '${hpp.variancePercent != null ? ' (${_num(hpp.variancePercent!, decimals: 1)}%)' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: overBudget ? cs.error : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _totalTile(
    ThemeData theme,
    ColorScheme cs, {
    required String label,
    required String value,
    bool emphasized = false,
    Color? emphasisColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: emphasized
            ? (emphasisColor ?? cs.primary).withValues(alpha: 0.08)
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: emphasized
              ? (emphasisColor ?? cs.primary).withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          // Nominal menyusut alih-alih membungkus saat mencapai miliar.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    emphasized ? (emphasisColor ?? cs.primary) : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(ImportPurchaseDetail d) {
    final import = d.importPurchase;

    return DetailSectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Produk & Harga Satuan',
      children: [
        for (final item in import.items) _buildItemTile(d, item),
      ],
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Beli: ${_num(item.quantity, decimals: 3)} ${item.unitName} × '
            '${_num(item.unitPriceForeign)} ${d.importPurchase.currency} = '
            '${_rp(row?.goodsValue ?? 0)}',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          AppSpacing.gapVerticalXS,

          // Tiga statistik sebaris: diterima + HPP estimasi vs realisasi.
          Row(
            children: [
              Expanded(
                child: _itemStat(
                  textTheme,
                  colorScheme,
                  label: 'Diterima',
                  value: item.quantityReceived == null
                      ? '—'
                      : _num(item.quantityReceived!, decimals: 3),
                ),
              ),
              Expanded(
                child: _itemStat(
                  textTheme,
                  colorScheme,
                  label: 'HPP Est.',
                  value: _num(row?.hppEstimateUnit ?? 0, decimals: 0),
                ),
              ),
              Expanded(
                child: _itemStat(
                  textTheme,
                  colorScheme,
                  label: 'HPP Real',
                  value: _num(row?.hppRealUnit ?? 0, decimals: 0),
                  emphasized: true,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _itemStat(
    TextTheme textTheme,
    ColorScheme colorScheme, {
    required String label,
    required String value,
    bool emphasized = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: emphasized ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// Sel nominal kolom biaya: rata kanan, menyusut bila terlalu panjang
  /// (bukan membungkus ke baris kedua).
  Widget _amountCell(String text, TextStyle? style) {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }

  Widget _buildCostsSection(ImportPurchaseDetail d) {
    final import = d.importPurchase;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final headerStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return DetailSectionCard(
      icon: Icons.request_quote_outlined,
      title: 'Biaya (Estimasi vs Real)',
      // Input realisasi (nominal real + qty diterima) tersedia mulai tahap
      // Kedatangan — tombol ini membuat jalurnya mudah ditemukan.
      trailing: Tooltip(
        message: import.stage.canReceive
            ? 'Isi nominal real biaya & jumlah diterima'
            : 'Tersedia mulai tahap Kedatangan',
        child: TextButton.icon(
          onPressed: import.stage.canReceive ? () => _openReceive(d) : null,
          icon: const Icon(Icons.edit_square, size: 18),
          label: const Text('Realisasi'),
          style: AppButtonStyle.text(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: import.costs.isEmpty
          ? Text('Belum ada biaya dicatat.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dua kolom nominal (rupiah) — kolom fleksibel agar
                // nominal miliar tetap satu baris.
                Row(
                  children: [
                    const Expanded(flex: 5, child: SizedBox()),
                    Expanded(
                      flex: 3,
                      child: Text('Estimasi (Rp)',
                          textAlign: TextAlign.end, style: headerStyle),
                    ),
                    AppSpacing.gapHorizontalSM,
                    Expanded(
                      flex: 3,
                      child: Text('Realisasi (Rp)',
                          textAlign: TextAlign.end, style: headerStyle),
                    ),
                  ],
                ),
                for (final cost in import.costs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cost.name,
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                '${cost.categoryLabel}'
                                '${cost.taxRate != null ? ' • ${_num(cost.taxRate!, decimals: 3)}% nilai barang' : ''}'
                                '${cost.isForeignCurrency ? ' • ${import.currency} ${_num(cost.amountForeign ?? 0)}' : ''}',
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _amountCell(
                            _num(cost.amountEstimate, decimals: 0),
                            textTheme.bodySmall,
                          ),
                        ),
                        AppSpacing.gapHorizontalSM,
                        Expanded(
                          flex: 3,
                          child: _amountCell(
                            cost.amountReal == null
                                ? '—'
                                : _num(cost.amountReal!, decimals: 0),
                            textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cost.amountReal == null
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.primary,
                            ),
                          ),
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

    return DetailSectionCard(
      icon: Icons.folder_outlined,
      title: 'Kelengkapan Dokumen',
      trailing: !import.stage.isTerminal
          ? IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Upload dokumen',
              onPressed: _busy ? null : () => _pickAndUploadDocument(d),
            )
          : null,
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight:
                                  check.isCurrent ? FontWeight.bold : null,
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
                                ? AppColors.success.withValues(alpha: 0.12)
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
                                    ? AppColors.success
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
                                          ? AppColors.success
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
            const Divider(height: 1),
            for (final doc in import.documents) _buildDocumentTile(d, doc),
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

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: doc.isPdf
            ? Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              )
            : ListThumbnail(
                imageUrl: ImageService.buildUrl(doc.filePath),
                size: 40,
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
      ),
    );
  }

  /* ------------------------------------------------------------- ACTIONS */

  Widget _buildActions(ImportPurchaseDetail d) {
    final stage = d.importPurchase.stage;

    if (stage.isTerminal) {
      return ModernButton(
        text: stage.isCancelled
            ? 'Proses dibatalkan'
            : 'Proses final — HPP produk sudah diperbarui',
        variant: ModernButtonVariant.outlined,
        onPressed: null,
      );
    }

    return _primaryAction(d, stage);
  }

  /// Aksi utama sesuai tahap:
  /// - arrival → input realisasi (qty diterima + nominal real biaya);
  /// - receiving → finalisasi (realisasi tetap bisa diulang via tombol
  ///   Realisasi di seksi biaya);
  /// - tahap lain → lanjut tahap berikutnya (gerbang dokumen dicek backend).
  Widget _primaryAction(ImportPurchaseDetail d, ImportStage stage) {
    if (stage == ImportStage.arrival) {
      return ModernButton(
        text: 'Input Realisasi',
        icon: Icons.scale_outlined,
        isLoading: _busy,
        onPressed: _busy ? null : () => _openReceive(d),
      );
    }
    if (stage == ImportStage.receiving) {
      return Row(
        children: [
          Expanded(
            child: ModernButton(
              text: 'Realisasi',
              variant: ModernButtonVariant.outlined,
              onPressed: _busy ? null : () => _openReceive(d),
            ),
          ),
          AppSpacing.gapHorizontalSM,
          Expanded(
            child: ModernButton(
              text: 'Finalisasi',
              isLoading: _busy,
              onPressed: _busy ? null : () => _finalize(d),
            ),
          ),
        ],
      );
    }
    return ModernButton(
      text: 'Lanjut: ${stage.next?.displayLabel ?? ''}',
      icon: Icons.arrow_forward_rounded,
      isLoading: _busy,
      onPressed: _busy ? null : () => _advance(d),
    );
  }

  Future<void> _setBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance(ImportPurchaseDetail d) async {
    await _setBusy(() async {
      try {
        await _service.advance(widget.importId);
      } on ImportBlockedException catch (e) {
        if (!mounted) return;
        final bypass = await showImportBlockedDialog(
          context,
          title:
              'Syarat Tahap ${d.importPurchase.stage.next?.displayLabel ?? 'Berikutnya'} '
              'Belum Terpenuhi',
          blockers: e.blockers,
          allowBypass: e.canBypassDocuments,
        );
        if (!bypass) return;
        await _service.advance(widget.importId, bypassDocuments: true);
      }
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

  /// Hapus permanen proses impor (item + biaya + dokumen). Ditolak server
  /// bila sudah final; proses dibatalkan boleh dihapus untuk bersih-bersih.
  Future<void> _delete(ImportPurchaseDetail d) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus proses impor?',
      content:
          'Seluruh data proses impor #${widget.importId} — produk, biaya, dan '
          'dokumen — dihapus permanen dan tidak dapat dikembalikan. Gunakan '
          '"Batalkan proses" bila hanya ingin mengarsipkan.',
      confirmText: 'Hapus Permanen',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _setBusy(() async {
      await _service.deleteImport(widget.importId);
      if (!mounted) return;
      Navigator.pop(context, true);
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
        '${item.productName}: ${_rp(row?.hppRealUnit ?? 0)}/'
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
      try {
        await _service.finalize(widget.importId);
      } on ImportBlockedException catch (e) {
        if (!mounted) return;
        await showImportBlockedDialog(
          context,
          title: 'Finalisasi Belum Dapat Dilakukan',
          blockers: e.blockers,
        );
        return;
      }
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
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
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
