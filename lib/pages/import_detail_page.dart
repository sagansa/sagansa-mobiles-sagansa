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
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/image_utils.dart';
import '../utils/mete_pricing.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/import_blocked_dialog.dart';
import '../widgets/list_thumbnail.dart';
import '../widgets/modern_button.dart';
import '../widgets/status_badge.dart';
import 'import_form_page.dart';
import 'import_receive_page.dart';

/// Fase satu sesi upload dokumen pada halaman detail impor.
enum _UploadPhase { preparing, uploading, saving, error }

/// Sesi upload aktif — dirender sebagai kartu progres di seksi dokumen
/// agar proses (siapkan file → transfer → simpan) selalu terlihat.
class _UploadTask {
  _UploadTask({required this.type});

  final ImportDocumentType type;

  /// File lokal hasil picker — dipertahankan agar tombol "Ulangi" pada
  /// kartu error tidak perlu memilih ulang file.
  String? localPath;
  String fileName = '';
  bool isPdf = false;
  String? mimeType;
  int? sizeBytes;

  _UploadPhase phase = _UploadPhase.preparing;
  double? progress; // 0..1 saat uploading; null = indeterminate
  String? error;
}

/// Kebutuhan dokumen satu tahap — dipakai untuk mengelompokkan checklist
/// per tahap (Pembayaran, Pengiriman, ...) agar pembagian syarat terlihat
/// langsung tanpa harus memilih tipe dokumen di bagian atas.
class _StageDocGroup {
  _StageDocGroup({
    required this.stage,
    required this.label,
    required this.state,
    required this.documents,
  });

  final ImportStage stage;
  final String label;
  final String state;
  final List<ImportStageDocCheck> documents;

  int get requiredCount => documents.length;
  int get presentCount => documents.where((d) => d.present).length;
  bool get isComplete => presentCount == requiredCount;
  bool get isCurrent => state == 'current';
  bool get isDone => state == 'done';
}

/// Detail proses impor: stepper tahapan, kelengkapan dokumen (gambar/PDF),
/// ringkasan HPP estimate vs real, dan aksi lanjut-tahap / terima / finalisasi.
///
/// Seksi memakai [DetailSectionCard] + [DetailRow] — komponen standar
/// halaman detail (pola fuel service / procurement detail).
class ImportDetailPage extends StatefulWidget {
  final int importId;

  const ImportDetailPage({
    super.key,
    required this.importId,
  });

  @override
  State<ImportDetailPage> createState() => _ImportDetailPageState();
}

class _ImportDetailPageState extends State<ImportDetailPage> {
  final ImportService _service = ImportService();

  ImportPurchaseDetail? _detail;
  bool _isLoading = true;
  bool _busy = false;
  String? _error;
  _UploadTask? _uploadTask;

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
      // Konfigurasi persentase harga jual (bisa dioverride per produk,
      // tersimpan di perangkat) — dimuat sebelum render agar info harga
      // di tile langsung memakai nilai aktif.
      await MetePricingStore.instance.load();
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
    final invoiceNumber = d?.importPurchase.invoiceNumber?.trim() ?? '';

    return AppPageScaffold(
      titleText: invoiceNumber.isNotEmpty
          ? invoiceNumber
          : 'Detail Impor #${widget.importId}',
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
                    _buildPaymentsSection(d),
                    AppSpacing.gapVerticalMD,
                    _buildItemsSection(d),
                    AppSpacing.gapVerticalMD,
                    _buildCostsSection(d),
                    AppSpacing.gapVerticalMD,
                    _buildNotulSection(d),
                    AppSpacing.gapVerticalMD,
                    _buildDocumentsSection(d),
                    AppSpacing.gapVerticalXL,
                  ],
                ),
              ),
            ),
      bottomAction: (_detail == null) ? null : _buildActions(_detail!),
    );
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }

  Widget _buildHeader(ImportPurchase import) {
    return DetailSectionCard(
      icon: Icons.public_outlined,
      title: import.supplierName,
      trailing: StatusBadge(
        label: import.stage.displayLabel,
        type: import.stage.badgeType,
      ),
      children: [
        DetailRow(
          label: 'Tanggal Impor',
          value: _dateLabel(import.purchaseDate),
        ),
        DetailRow(
          label: 'No. Invoice',
          value: (import.invoiceNumber?.isNotEmpty ?? false)
              ? import.invoiceNumber!
              : '—',
          isBold: true,
        ),
        DetailRow(
          label: 'Kurs',
          value: 'Rp ${_num(import.exchangeRate)} / ${import.currency}',
        ),
        DetailRow(
          label: 'Produk',
          value: '${import.items.length} item',
        ),
        DetailRow(
          label: 'Dokumen',
          value: '${import.documents.length} file',
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

  /// Ringkasan biaya: baris rincian [DetailRow] + satu angka total —
  /// realisasi bila sudah tersedia, estimasi sebagai fallback selama
  /// belum (tanpa perbandingan keduanya maupun selisih).
  Widget _buildHppSummary(ImportPurchaseDetail d) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hpp = d.hpp;
    final hasReal = hpp.totalReal > 0;

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

        // Perbandingan inti sheet HPP: estimasi vs realisasi berdampingan,
        // realisasi ditonjolkan; selisih nominal & persen di bawahnya.
        if (hasReal && hpp.totalEstimate > 0) ...[
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _totalTile(
                  theme,
                  cs,
                  label: 'Total Realisasi',
                  value: _rp(hpp.totalReal),
                  emphasized: true,
                ),
              ),
            ],
          ),
          Builder(builder: (context) {
            final diff = hpp.totalReal - hpp.totalEstimate;
            final diffPct = diff / hpp.totalEstimate * 100;
            final over = diff > 0;
            final sign = over ? '+' : '';
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Selisih vs estimasi: $sign${_rp(diff.abs())} '
                '($sign${_num(diffPct.abs(), decimals: 1)}%)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: diff == 0
                      ? cs.onSurfaceVariant
                      : over
                          ? cs.error
                          : AppColors.success,
                ),
              ),
            );
          }),
        ] else
          _totalTile(
            theme,
            cs,
            label: hasReal ? 'Total Realisasi' : 'Total Estimasi',
            value: _rp(hasReal ? hpp.totalReal : hpp.totalEstimate),
            emphasized: true,
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

    final hppUnit = (row?.hppRealUnit ?? 0) > 0
        ? row!.hppRealUnit
        : (row?.hppEstimateUnit ?? 0);
    // Harga jual info dari konfigurasi mete (bisa dioverride per produk):
    // jangkar 10kg dari HPP item (realisasi, fallback estimasi), kemasan
    // lain persentase dari jangkar. Murni informasi — tidak tersimpan ke
    // server, tidak mengubah master produk.
    final config = MetePricingStore.instance
        .configFor(meteBaseName(item.productName));
    final prices = metePriceList(hppUnit, config);
    final hasPrices = hppUnit > 0;

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

          // Dua statistik kunci: diterima + HPP per satuan (realisasi,
          // fallback estimasi selama belum tersedia).
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
                  label: 'HPP',
                  value: _num(hppUnit, decimals: 0),
                  emphasized: true,
                ),
              ),
            ],
          ),

          // Harga jual per kemasan — grid 2×2, jangkar 10kg ditonjolkan;
          // persentase mengikuti konfigurasi aktif produk ini.
          // IntrinsicHeight: Row+stretch butuh tinggi terukur agar kotak
          // kemasan sama tinggi (ListView memberi tinggi tak terbatas).
          if (hasPrices) ...[
            AppSpacing.gapVerticalXS,
            for (var i = 0; i < kMetePackOrder.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = 0; j < 2; j++)
                        Expanded(
                          child: _packMiniTile(
                            textTheme,
                            colorScheme,
                            pack: kMetePackOrder[i + j],
                            price: prices[kMetePackOrder[i + j]] ?? 0,
                            config: config,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          const Divider(height: 1),
        ],
      ),
    );
  }

  /// Kotak harga satu kemasan — bahasa visual sama dengan halaman Harga
  /// Jual: jangkar 10kg tint primary, kemasan turunan outline halus.
  Widget _packMiniTile(
    TextTheme textTheme,
    ColorScheme colorScheme, {
    required String pack,
    required double price,
    required MetePricingConfig config,
  }) {
    final isAnchor = pack == '10kg';
    final accent = colorScheme.primary;

    return Container(
      margin: EdgeInsets.only(
        left: isAnchor ? 0 : AppSpacing.xs,
        right: isAnchor ? AppSpacing.xs : 0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: isAnchor ? accent.withValues(alpha: 0.08) : null,
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(
          color: isAnchor
              ? accent.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kMetePackLabel(pack),
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isAnchor ? accent : colorScheme.onSurfaceVariant,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              price > 0 ? FormatUtils.formatRupiah(price) : '—',
              maxLines: 1,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isAnchor ? accent : colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            isAnchor
                ? 'HPP +${FormatUtils.formatAmount(config.anchorMarginPercent, decimals: 0)}%'
                : '${FormatUtils.formatAmount(config.ratioPercent(pack), decimals: 0)}% dari 10kg',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
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
    final costs = import.manualCosts;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final headerStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return DetailSectionCard(
      icon: Icons.request_quote_outlined,
      title: 'Biaya',
      // Input realisasi nominal tersedia sejak draft; jumlah diterima baru
      // relevan ketika barang tiba.
      trailing: Tooltip(
        message: import.stage.canRealizeCosts
            ? 'Isi nominal real biaya (bertahap) & jumlah diterima'
            : 'Tidak tersedia untuk proses final/dibatalkan',
        child: TextButton.icon(
          onPressed:
              import.stage.canRealizeCosts ? () => _openReceive(d) : null,
          icon: const Icon(Icons.edit_square, size: 18),
          label: const Text('Realisasi'),
          style: AppButtonStyle.text(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: costs.isEmpty
          ? Text('Belum ada biaya dicatat.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Satu kolom nominal: realisasi bila tersedia, fallback
                // estimasi — tanpa membandingkan keduanya.
                Row(
                  children: [
                    const Expanded(flex: 5, child: SizedBox()),
                    Expanded(
                      flex: 3,
                      child: Text('Nominal (Rp)',
                          textAlign: TextAlign.end, style: headerStyle),
                    ),
                  ],
                ),
                for (final cost in costs)
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
                            _num(
                              cost.amountReal ?? cost.amountEstimate,
                              decimals: 0,
                            ),
                            textTheme.bodySmall?.copyWith(
                              fontWeight: cost.amountReal == null
                                  ? null
                                  : FontWeight.bold,
                              color: cost.amountReal == null
                                  ? colorScheme.onSurface
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

  Widget _buildPaymentsSection(ImportPurchaseDetail d) {
    final payments = d.importPurchase.payments;
    if (payments.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = payments.fold<double>(0, (sum, p) => sum + p.amount);

    return DetailSectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Pembayaran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${payments.length} tranche',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Text(
                FormatUtils.formatRupiah(total),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.md),
          for (var i = 0; i < payments.length; i++)
            _paymentTile(payments[i], i + 1),
        ],
      ),
    );
  }

  Widget _paymentTile(ImportPayment payment, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final proofUrl = ImageService.buildUrl(payment.proofPath);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tranche $index',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _dateLabel(payment.paidAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                FormatUtils.formatRupiah(payment.amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          if ((payment.note ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                payment.note!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          if (proofUrl != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ImagePreviewDialog.show(
                  context,
                  proofUrl,
                  title: 'Bukti Pembayaran Tranche $index',
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Lihat bukti'),
                style: AppButtonStyle.text(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotulSection(ImportPurchaseDetail d) {
    final notuls = d.importPurchase.notuls;
    if (notuls.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DetailSectionCard(
      icon: Icons.gavel_outlined,
      title: 'Notul',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PPh/PPN notul terbaru menggantikan angka final. Denda dan biaya '
            'lain dijumlahkan.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          for (var i = 0; i < notuls.length; i++) _notulTile(notuls[i], i + 1),
        ],
      ),
    );
  }

  Widget _notulTile(ImportNotul notul, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final documentUrl = ImageService.buildUrl(notul.documentPath);
    final total = notul.pphAmount +
        notul.ppnAmount +
        notul.penaltyAmount +
        notul.otherAmount;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (notul.number ?? '').isNotEmpty
                          ? notul.number!
                          : 'Notul $index',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _dateLabel(notul.date),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                FormatUtils.formatRupiah(total),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _notulAmountLine('PPh Impor', notul.pphAmount),
          _notulAmountLine('PPN Impor', notul.ppnAmount),
          if (notul.penaltyAmount > 0)
            _notulAmountLine('Denda administrasi', notul.penaltyAmount),
          if (notul.otherAmount > 0)
            _notulAmountLine(
              (notul.otherDescription ?? '').isNotEmpty
                  ? notul.otherDescription!
                  : 'Biaya lain',
              notul.otherAmount,
            ),
          if (documentUrl != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ImagePreviewDialog.show(
                  context,
                  documentUrl,
                  title: 'Dokumen Notul',
                ),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Lihat dokumen'),
                style: AppButtonStyle.text(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notulAmountLine(String label, double amount) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            FormatUtils.formatRupiah(amount),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(ImportPurchaseDetail d) {
    final import = d.importPurchase;
    final task = _uploadTask;
    final groups = _collectStageGroups(d);
    final requiredTypes = {
      for (final group in groups)
        for (final doc in group.documents) doc.typeEnum,
    };
    // Upload dokumen bebas (tombol kanan atas) tidak punya baris tahap —
    // progresnya tetap tampil di atas daftar file.
    final floatingTask = task != null && !requiredTypes.contains(task.type);

    return DetailSectionCard(
      icon: Icons.folder_outlined,
      title: 'Kelengkapan Dokumen',
      trailing: !import.stage.isTerminal
          ? IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Upload dokumen lain',
              onPressed: (_busy || task != null)
                  ? null
                  : () => _pickAndUploadDocument(d),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (groups.isNotEmpty) ...[
            _buildRequirementProgress(groups),
            for (var i = 0; i < groups.length; i++) ...[
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _buildStageGroup(d, groups[i]),
              ),
            ],
          ],
          if (floatingTask)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _buildUploadingRow(task),
            ),
          if (import.documents.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'File terunggah',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '${import.documents.length} file',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final doc in import.documents) _buildDocumentTile(d, doc),
          ],
          if (groups.isEmpty && import.documents.isEmpty && task == null)
            Text(
              'Belum ada dokumen wajib pada proses ini. Gunakan tombol upload '
              'di kanan atas untuk menambahkan dokumen lain.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }

  /// Kelompokkan dokumen wajib per tahap — hanya tipe wajib yang masuk
  /// kelompok agar tiap tahap terbaca sebagai satu paket syarat.
  List<_StageDocGroup> _collectStageGroups(ImportPurchaseDetail d) {
    final groups = <_StageDocGroup>[];
    for (final check in d.checklist) {
      final documents =
          check.documents.where((doc) => doc.required).toList(growable: false);
      if (documents.isEmpty) continue;
      groups.add(
        _StageDocGroup(
          stage: check.stage,
          label: check.label,
          state: check.state,
          documents: documents,
        ),
      );
    }
    return groups;
  }

  Widget _buildRequirementProgress(List<_StageDocGroup> groups) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final required = groups.fold<int>(0, (sum, g) => sum + g.requiredCount);
    final present = groups.fold<int>(0, (sum, g) => sum + g.presentCount);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppSpacing.borderRadiusFull,
            child: LinearProgressIndicator(
              value: required == 0 ? 1 : present / required,
              minHeight: 5,
              backgroundColor:
                  cs.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$present/$required wajib',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStageGroup(ImportPurchaseDetail d, _StageDocGroup group) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final completed = group.isComplete;
    final color = completed
        ? AppColors.success
        : group.isCurrent
            ? _stageColor(group.stage)
            : cs.onSurfaceVariant;

    final StatusType badgeType;
    final String badgeLabel;
    if (completed) {
      badgeType = StatusType.success;
      badgeLabel = 'Lengkap';
    } else if (group.isDone) {
      badgeType = StatusType.warning;
      badgeLabel = 'Dilewati';
    } else if (group.isCurrent) {
      badgeType = StatusType.info;
      badgeLabel = 'Berjalan';
    } else {
      badgeType = StatusType.neutral;
      badgeLabel = 'Berikutnya';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: Icon(_stageIcon(group.stage), size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${group.presentCount}/${group.requiredCount} wajib',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            StatusBadge(label: badgeLabel, type: badgeType),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final doc in group.documents) _buildStageDocRow(d, doc, group),
      ],
    );
  }

  Widget _buildStageDocRow(
    ImportPurchaseDetail d,
    ImportStageDocCheck doc,
    _StageDocGroup group,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final task = _uploadTask;
    final files = d.importPurchase.documents
        .where((file) => file.type == doc.typeEnum)
        .toList(growable: false);
    final present = doc.present || files.isNotEmpty;
    final latest = files.isNotEmpty ? files.last : null;
    final latestUrl = latest == null
        ? null
        : latest.fileUrl ?? ImageService.buildUrl(latest.filePath);
    final isTarget = task != null && task.type == doc.typeEnum;
    final busy = _busy || task != null;
    final color = present
        ? AppColors.success
        : group.isDone
            ? AppColors.warning
            : cs.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 6, bottom: 6),
          child: Row(
            children: [
              Icon(
                present
                    ? Icons.check_circle_rounded
                    : group.isDone
                        ? Icons.warning_amber_rounded
                        : Icons.radio_button_unchecked,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doc.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: present ? null : FontWeight.w600,
                      ),
                    ),
                    if (present && latest != null)
                      Text(
                        files.length > 1
                            ? '${files.length} file terunggah'
                            : 'Sudah terunggah',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (isTarget && task.phase != _UploadPhase.error)
                Text(
                  task.progress == null
                      ? '…'
                      : '${(task.progress! * 100).round()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                )
              else if (!present)
                TextButton.icon(
                  key: ValueKey('upload-${doc.type}'),
                  onPressed: busy
                      ? null
                      : () => _pickAndUploadDocument(
                            d,
                            presetType: doc.typeEnum,
                          ),
                  icon: const Icon(Icons.upload_rounded, size: 17),
                  label: const Text('Upload'),
                  style: AppButtonStyle.text(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (latest != null && latestUrl != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          latest.isPdf
                              ? Icons.open_in_new
                              : Icons.visibility_outlined,
                          size: 19,
                        ),
                        tooltip: latest.isPdf
                            ? 'Buka ${doc.label}'
                            : 'Lihat ${doc.label}',
                        onPressed: () => _openDocument(latest, latestUrl),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.upload_file_outlined, size: 19),
                      tooltip: 'Tambah file ${doc.label}',
                      onPressed: busy
                          ? null
                          : () => _pickAndUploadDocument(
                                d,
                                presetType: doc.typeEnum,
                              ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (isTarget)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 4),
            child: _buildUploadingRow(task),
          ),
      ],
    );
  }

  /// Kartu status upload aktif / gagal — progres byte, nama file, pesan
  /// error, dan aksi ulang/buang. Sebelumnya proses upload tidak terlihat.
  Widget _buildUploadingRow(_UploadTask task) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isError = task.phase == _UploadPhase.error;
    final showPercent =
        task.phase == _UploadPhase.uploading && task.progress != null;

    final title = switch (task.phase) {
      _UploadPhase.preparing => 'Menyiapkan ${task.type.displayLabel}…',
      _UploadPhase.uploading => 'Mengunggah ${task.type.displayLabel}…',
      _UploadPhase.saving => 'Menyimpan ${task.type.displayLabel}…',
      _UploadPhase.error => '${task.type.displayLabel} gagal diunggah',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: isError
            ? cs.errorContainer.withValues(alpha: 0.18)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isError
              ? cs.error.withValues(alpha: 0.45)
              : cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: isError
                ? Icon(Icons.cloud_off_outlined, size: 24, color: cs.error)
                : const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isError ? cs.error : cs.onSurface,
                        ),
                      ),
                    ),
                    if (showPercent)
                      Text(
                        '${(task.progress! * 100).round()}%',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                if (task.fileName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (isError) ...[
                  if (task.error != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _executeUpload(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Ulangi'),
                          style: AppButtonStyle.text(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _uploadTask = null),
                          style: AppButtonStyle.text(
                            foregroundColor: cs.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Buang'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.xs + 2),
                  ClipRRect(
                    borderRadius: AppSpacing.borderRadiusFull,
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value:
                            showPercent ? task.progress!.clamp(0.0, 1.0) : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// PDF tidak bisa dirender oleh [ImagePreviewDialog] (Image.network), jadi
  /// buka lewat aplikasi viewer eksternal — sama seperti tombol "Buka".
  Future<void> _openDocument(ImportDocumentModel doc, String url) async {
    if (!doc.isPdf) {
      if (!mounted) return;
      await ImagePreviewDialog.show(
        context,
        url,
        title: doc.type.displayLabel,
      );
      return;
    }

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showErrorSnackBar(
        context,
        'Tidak ada aplikasi yang bisa membuka PDF ini.',
      );
    }
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
              onPressed: url == null ? null : () => _openDocument(doc, url),
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
  ///
  /// Saat dokumen wajib tahap berikutnya belum lengkap, tombol bergaya
  /// peringatan + ringkasan jumlah yang kurang — state terlihat TANPA
  /// perlu tap; bypass tetap tersedia via dialog penolakan.
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

    final label = 'Lanjut: ${stage.next?.displayLabel ?? ''}';
    if (d.missingRequiredForNextStage.isEmpty) {
      return ModernButton(
        text: label,
        icon: Icons.arrow_forward_rounded,
        isLoading: _busy,
        onPressed: _busy ? null : () => _advance(d),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gateWarning(d.missingRequiredForNextStage.length, stage),
        AppSpacing.gapVerticalSM,
        ModernButton(
          text: label,
          icon: Icons.warning_amber_rounded,
          variant: ModernButtonVariant.outlined,
          foregroundColor: Theme.of(context).colorScheme.error,
          isLoading: _busy,
          onPressed: _busy ? null : () => _advance(d),
        ),
      ],
    );
  }

  /// Ringkasan syarat belum lengkap di atas tombol lanjut — idiom banner
  /// yang sama dengan "Proses dibatalkan" (tint errorContainer + ikon).
  Widget _gateWarning(int missingCount, ImportStage stage) {
    final cs = Theme.of(context).colorScheme;
    final nextLabel = stage.next?.displayLabel ?? 'berikutnya';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.15),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$missingCount dokumen wajib untuk tahap $nextLabel '
              'belum diupload — lengkapi dulu, atau tetap lanjut tanpa dokumen.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
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
        final nextLabel =
            d.importPurchase.stage.next?.displayLabel ?? 'Berikutnya';
        final bypass = await showImportBlockedDialog(
          context,
          title: 'Syarat Tahap $nextLabel Belum Terpenuhi',
          blockers: e.blockers,
          allowBypass: e.canBypassDocuments,
        );
        if (!bypass) return;
        try {
          await _service.advance(widget.importId, bypassDocuments: true);
        } on ImportBlockedException catch (e2) {
          // Bypass masih ditolak setelah flag dikirim. Bila blocker yang
          // balas masih murni dokumen, server jelas mengabaikan flag —
          // versi server lama; beri diagnosisnya, jangan dialog "Gagal".
          if (!mounted) return;
          await showImportBlockedDialog(
            context,
            title: 'Syarat Tahap $nextLabel Masih Belum Terpenuhi',
            blockers: e2.blockers,
            note: e2.canBypassDocuments
                ? 'Lanjut tanpa dokumen sudah dikirim tetapi server masih '
                    'menolak — server perlu diperbarui ke versi terbaru.'
                : null,
          );
        }
      }
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
          'dokumen — dihapus permanen dan tidak dapat dikembalikan.',
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

  Future<void> _pickAndUploadDocument(
    ImportPurchaseDetail d, {
    ImportDocumentType? presetType,
  }) async {
    // 1) Tipe dokumen sudah pasti saat upload dari baris tahap; pemilih tipe
    //    hanya muncul untuk unggahan bebas dari tombol kanan atas.
    final ImportDocumentType? type = presetType ?? await _pickDocumentType();
    if (type == null || !mounted) return;

    // 2) Pilih sumber: kamera / galeri / PDF.
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Upload ${type.displayLabel}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'camera'),
            child: const Row(children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 10),
              Expanded(child: Text('Kamera (foto dokumen)')),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'gallery'),
            child: const Row(children: [
              Icon(Icons.photo_library),
              SizedBox(width: 10),
              Expanded(child: Text('Galeri (gambar/scan)')),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'file'),
            child: const Row(children: [
              Icon(Icons.folder_open),
              SizedBox(width: 10),
              Expanded(child: Text('File / Google Drive (PDF/gambar)')),
            ]),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    // 3) Tampilkan kartu progres sejak awal — fase menyiapkan file pun
    //    terlihat, bukan hanya saat transfer berjalan.
    final task = _UploadTask(type: type);
    setState(() => _uploadTask = task);

    if (source == 'file') {
      // file_picker ≥13: pickFiles static, return List (kosong = batal).
      // UIDocumentPicker di iOS menampilkan Files termasuk Google Drive.
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
      );
      if (files.isEmpty) {
        _discardUploadTask();
        return;
      }
      final file = files.first;
      final localPath = file.path;
      if (localPath == null) {
        _discardUploadTask();
        return;
      }

      // Ekstensi bisa hilang pada file hasil cache cloud (Google Drive/iCloud),
      // jadi cek nama, path, lalu magic bytes sebagai sumber kebenaran.
      final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
      final pathExt = localPath.split('.').last.toLowerCase();
      final isPdf =
          ext == 'pdf' || pathExt == 'pdf' || await ImageUtils.isPdf(localPath);
      task.fileName = file.name;
      if (isPdf) {
        task
          ..localPath = localPath
          ..isPdf = true
          ..mimeType = 'application/pdf'
          // file_picker 13: ukuran via length() (async, fallback baca file).
          ..sizeBytes = await file.length();
      } else {
        // Kompres gambar dari Drive/Files sebelum upload.
        final image = await ImageUtils.compressImage(localPath);
        task
          ..localPath = image.path
          ..isPdf = false
          ..mimeType = image.path.toLowerCase().endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg'
          ..sizeBytes = await image.length();
      }
    } else {
      final image = await ImageService.pickAndResizeImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (image == null) {
        _discardUploadTask();
        return;
      }
      task
        ..fileName = image.path.split('/').last
        ..localPath = image.path
        ..isPdf = false
        ..mimeType = 'image/webp'
        ..sizeBytes = await image.length();
    }

    if (!mounted) return;
    setState(() {}); // tampilkan nama file pada kartu progres
    await _executeUpload();
  }

  void _discardUploadTask() {
    if (mounted) setState(() => _uploadTask = null);
  }

  /// Upload file lokal ke img service (dengan progres byte), lampirkan ke
  /// proses impor, lalu muat ulang detail. Kegagalan fase mana pun berakhir
  /// sebagai kartu error dengan tombol ulang — file lokal dipakai ulang
  /// tanpa memilih ulang.
  Future<void> _executeUpload() async {
    final task = _uploadTask;
    if (task == null || task.localPath == null) return;

    void onProgress(int sent, int total) {
      if (!mounted || task.phase != _UploadPhase.uploading) return;
      setState(() {
        task.progress = total > 0 ? (sent / total).clamp(0.0, 1.0) : null;
      });
    }

    try {
      setState(() {
        task.phase = _UploadPhase.uploading;
        task.progress = null;
        task.error = null;
      });

      final path = task.isPdf
          ? await ImageUploadService.uploadPdf(
              File(task.localPath!),
              directory: 'documents/ImportPurchase',
              filename: task.fileName.isEmpty ? null : task.fileName,
              onProgress: onProgress,
            )
          : await ImageUploadService.upload(
              File(task.localPath!),
              directory: 'documents/ImportPurchase',
              filename: task.fileName.isEmpty ? null : task.fileName,
              onProgress: onProgress,
            );
      if (path == null) throw Exception('Upload gagal — coba lagi.');

      if (!mounted) return;
      setState(() => task.phase = _UploadPhase.saving);
      await _service.attachDocument(
        widget.importId,
        type: task.type.toApi(),
        filePath: path,
        originalName: task.fileName.isEmpty ? null : task.fileName,
        mimeType: task.mimeType,
        sizeBytes: task.sizeBytes,
      );
      await _load();

      if (!mounted) return;
      setState(() => _uploadTask = null);
      showSuccessSnackBar(
        context,
        '${task.type.displayLabel} berhasil ditambahkan.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        task.phase = _UploadPhase.error;
        task.error = e.toString().replaceFirst('Exception: ', '');
      });
    }
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
