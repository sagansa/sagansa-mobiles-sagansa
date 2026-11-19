import 'package:flutter/material.dart';
import '../models/transfer_stock_model.dart';
import '../services/transfer_stock_service.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/status_badge.dart';

class TransferStockDetailPage extends StatefulWidget {
  final int transferId;

  const TransferStockDetailPage({super.key, required this.transferId});

  @override
  State<TransferStockDetailPage> createState() =>
      _TransferStockDetailPageState();
}

class _TransferStockDetailPageState extends State<TransferStockDetailPage> {
  final TransferStockService _service = TransferStockService();
  TransferStockModel? _transfer;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _service.getTransferStock(widget.transferId);
      if (!mounted) return;
      setState(() {
        _transfer = data;
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

  StatusType _statusBadgeType(int status) {
    switch (status) {
      case 1:
        return StatusType.warning;
      case 2:
        return StatusType.success;
      case 3:
        return StatusType.neutral;
      case 4:
        return StatusType.error;
      default:
        return StatusType.neutral;
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
        title: const Text('Detail Transfer Stok'),
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
              : _transfer == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _fetchDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppBarInsets.top(context),
                          AppSpacing.md,
                          AppSpacing.xl + context.systemBottomInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Route Card (Asal -> Tujuan)
                            _buildRouteCard(colorScheme, textTheme),
                            AppSpacing.gapVerticalMD,

                            // Metadata Section Card
                            DetailSectionCard(
                              icon: Icons.local_shipping_outlined,
                              title: 'Informasi Pengiriman',
                              children: [
                                DetailRow(
                                  label: 'Tanggal Transfer',
                                  value: _transfer!.date,
                                  isBold: true,
                                ),
                                DetailRow(
                                  label: 'Toko Asal',
                                  value: _transfer!.fromStoreName,
                                ),
                                DetailRow(
                                  label: 'Toko Tujuan',
                                  value: _transfer!.toStoreName,
                                ),
                                DetailRow(
                                  label: 'Dikirim oleh',
                                  value: _transfer!.sentByName,
                                ),
                                if (_transfer!.receivedByName != null)
                                  DetailRow(
                                    label: 'Diterima oleh',
                                    value: _transfer!.receivedByName!,
                                  ),
                                if (_transfer!.notes != null &&
                                    _transfer!.notes!.isNotEmpty)
                                  DetailRow(
                                    label: 'Catatan',
                                    value: _transfer!.notes!,
                                  ),
                              ],
                            ),
                            AppSpacing.gapVerticalLG,

                            // Items Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Item Transfer',
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
                                    '${_transfer!.details.length} item',
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
                            ..._transfer!.details.map(
                              (item) => _buildItemCard(
                                  item, colorScheme, textTheme),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildRouteCard(ColorScheme colorScheme, TextTheme textTheme) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transfer #${_transfer!.id}',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(
                label: _transfer!.statusText,
                type: _statusBadgeType(_transfer!.status),
              ),
            ],
          ),
          AppSpacing.gapVerticalMD,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DARI',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    AppSpacing.gapVerticalXS,
                    Text(
                      _transfer!.fromStoreName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: AppSpacing.paddingSM,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'KE',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    AppSpacing.gapVerticalXS,
                    Text(
                      _transfer!.toStoreName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ProductTransferStockModel item, ColorScheme colorScheme,
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
              Icons.move_to_inbox_outlined,
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
