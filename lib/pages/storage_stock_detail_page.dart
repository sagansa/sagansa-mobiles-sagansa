import 'package:flutter/material.dart';
import '../models/storage_stock_model.dart';
import '../services/storage_stock_service.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/status_badge.dart';
import 'create_storage_stock_page.dart';

class StorageStockDetailPage extends StatefulWidget {
  final int reportId;

  /// Injection untuk widget test; null = pakai service sungguhan.
  final StorageStockService? service;

  const StorageStockDetailPage({
    super.key,
    required this.reportId,
    this.service,
  });

  @override
  State<StorageStockDetailPage> createState() => _StorageStockDetailPageState();
}

class _StorageStockDetailPageState extends State<StorageStockDetailPage> {
  late final StorageStockService _service;
  StorageStockModel? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StorageStockService();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _service.getStorageStock(widget.reportId);
      if (!mounted) return;
      setState(() {
        _report = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateStorageStockPage(reportForEdit: _report),
      ),
    );
    if (result == true) {
      _fetchDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Detail Stok Gudang'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: colorScheme.error),
                        AppSpacing.gapVerticalMD,
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton.icon(
                          onPressed: _fetchDetail,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _report == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _fetchDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppBarInsets.top(context) + AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.xl +
                              (_report!.canBeEdited
                                  ? (76 + context.systemBottomInset)
                                  : context.systemBottomInset + 16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Hero Card
                            _buildHeroHeader(colorScheme, textTheme),
                            AppSpacing.gapVerticalMD,

                            // Metadata Section
                            DetailSectionCard(
                              icon: Icons.info_outline_rounded,
                              title: 'Informasi Opname',
                              children: [
                                DetailRow(
                                  label: 'Tanggal',
                                  value: _report!.date,
                                  isBold: true,
                                ),
                                DetailRow(
                                  label: 'Dilaporkan oleh',
                                  value: _report!.createdByName,
                                ),
                                if (_report!.updatedByName != null)
                                  DetailRow(
                                    label: 'Diperbarui oleh',
                                    value: _report!.updatedByName!,
                                  ),
                                DetailRow(
                                  label: 'Total Jenis Item',
                                  value: '${_report!.details.length} produk',
                                ),
                              ],
                            ),
                            AppSpacing.gapVerticalLG,

                            // Items List Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Item Stok Opname',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: AppSpacing.borderRadiusMD,
                                  ),
                                  child: Text(
                                    '${_report!.details.length} item',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.gapVerticalSM,

                            // Items List
                            ..._report!.details.map(
                              (item) => _buildItemCard(
                                  item, colorScheme, textTheme),
                            ),
                          ],
                        ),
                      ),
                    ),
      bottomNavigationBar: _report?.canBeEdited == true
          ? SafeBottomBar(
              child: ModernButton(
                text: 'Edit Laporan',
                icon: Icons.edit_rounded,
                onPressed: _openEditPage,
                height: 52,
              ),
            )
          : null,
    );
  }

  Widget _buildHeroHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusMD,
            ),
            child: Icon(
              Icons.warehouse_rounded,
              size: 26,
              color: colorScheme.primary,
            ),
          ),
          AppSpacing.gapHorizontalMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _report!.storeName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                AppSpacing.gapVerticalXS,
                Text(
                  'Stok Opname #${_report!.id}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: _report!.statusText,
            type: _report!.isPending
                ? StatusType.warning
                : StatusType.success,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ProductStorageStockModel item, ColorScheme colorScheme,
      TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: AppSpacing.paddingSM,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: AppSpacing.borderRadiusSM,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          AppSpacing.gapHorizontalMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.unitName.isNotEmpty) ...[
                  AppSpacing.gapVerticalXS,
                  Text(
                    'Satuan: ${item.unitName}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: AppSpacing.borderRadiusSM,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              '${FormatUtils.formatNumber(item.quantity)} ${item.unitName}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
