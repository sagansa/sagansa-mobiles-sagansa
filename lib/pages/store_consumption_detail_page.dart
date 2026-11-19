import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store_consumption_model.dart';
import '../providers/auth_provider.dart';
import '../services/store_consumption_service.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/status_badge.dart';
import 'create_store_consumption_page.dart';

class StoreConsumptionDetailPage extends StatefulWidget {
  final int consumptionId;

  const StoreConsumptionDetailPage({super.key, required this.consumptionId});

  @override
  State<StoreConsumptionDetailPage> createState() =>
      _StoreConsumptionDetailPageState();
}

class _StoreConsumptionDetailPageState
    extends State<StoreConsumptionDetailPage> {
  final StoreConsumptionService _service = StoreConsumptionService();
  StoreConsumptionModel? _item;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAdmin = false;
  bool _canManage = false;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _isAdmin = auth.isAdmin;
    _canManage =
        auth.hasAnyRole(['admin', 'super_admin', 'supervisor', 'staff']);
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final data = await _service.getStoreConsumption(widget.consumptionId);
      if (!mounted) return;
      setState(() {
        _item = data;
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

  void _openEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateStoreConsumptionPage(consumption: _item)),
    );
    if (result == true) _fetchDetail();
  }

  Future<void> _updateStatus(int status, String label) async {
    final isValid = status == 2;
    final confirmed = await showConfirmDialog(
      context,
      title: isValid ? 'Set Status Valid?' : 'Set Status Perbaiki?',
      content: isValid
          ? 'Konsumsi toko akan ditandai VALID dan terkunci dari perubahan.'
          : 'Konsumsi toko akan ditandai DIPERBAIKI.',
      confirmText: isValid ? 'Valid' : 'Perbaiki',
    );
    if (!confirmed) return;

    setState(() => _isUpdatingStatus = true);
    try {
      await _service.updateStatus(widget.consumptionId, status);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Status konsumsi toko diubah ke "$label".');
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  StatusType _statusType(int status) {
    switch (status) {
      case 2:
        return StatusType.success;
      case 3:
        return StatusType.warning;
      case 4:
        return StatusType.error;
      default:
        return StatusType.warning;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final hasBottomBar = _item != null &&
        (_isAdmin || (_canManage && _item!.status != 2));

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Detail Konsumsi Toko'),
        actions: [
          BarButtonCluster(actions: [
            if (_canManage && _item != null && _item!.status != 2)
              BarButtonSpec(
                icon: Icons.edit_rounded,
                tooltip: 'Edit Konsumsi',
                onTap: _openEdit,
              ),
          ]),
        ],
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
              : _item == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _fetchDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppBarInsets.top(context),
                          AppSpacing.md,
                          AppSpacing.xl +
                              (hasBottomBar ? 80 : context.systemBottomInset),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero Store Card
                            _buildHeroHeader(colorScheme, textTheme),
                            AppSpacing.gapVerticalMD,

                            // Metadata Card
                            DetailSectionCard(
                              icon: Icons.info_outline_rounded,
                              title: 'Informasi Konsumsi',
                              children: [
                                DetailRow(
                                  label: 'Tanggal',
                                  value: _formatDate(_item!.date),
                                  isBold: true,
                                ),
                                DetailRow(
                                  label: 'Dilaporkan oleh',
                                  value: _item!.createdByName,
                                ),
                                DetailRow(
                                  label: 'Total Jenis Item',
                                  value: '${_item!.details.length} jenis',
                                ),
                              ],
                            ),
                            AppSpacing.gapVerticalLG,

                            // Items Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Item Konsumsi',
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
                                    '${_item!.details.length} item',
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
                            ..._item!.details.map(
                              (detail) => _buildItemCard(
                                  detail, colorScheme, textTheme),
                            ),
                          ],
                        ),
                      ),
                    ),
      bottomNavigationBar: _buildBottomBar(colorScheme),
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
              Icons.storefront_rounded,
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
                  _item!.storeName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                AppSpacing.gapVerticalXS,
                Text(
                  'Konsumsi Toko #${_item!.id}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: _item!.statusText,
            type: _statusType(_item!.status),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ProductStoreConsumptionModel item,
      ColorScheme colorScheme, TextTheme textTheme) {
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

  Widget? _buildBottomBar(ColorScheme colorScheme) {
    if (_item == null) return null;

    if (_isAdmin) {
      return SafeBottomBar(
        child: Row(
          children: [
            Expanded(
              child: ModernButton(
                text: 'Set Valid',
                icon: Icons.verified_rounded,
                variant: _item!.status == 2
                    ? ModernButtonVariant.outlined
                    : ModernButtonVariant.filled,
                onPressed: _isUpdatingStatus || _item!.status == 2
                    ? null
                    : () => _updateStatus(2, 'Valid'),
                height: 48,
              ),
            ),
            AppSpacing.gapHorizontalMD,
            Expanded(
              child: ModernButton(
                text: 'Set Perbaiki',
                icon: Icons.build_rounded,
                variant: ModernButtonVariant.outlined,
                onPressed: _isUpdatingStatus || _item!.status == 3
                    ? null
                    : () => _updateStatus(3, 'Diperbaiki'),
                height: 48,
              ),
            ),
          ],
        ),
      );
    }

    if (_canManage && _item!.status != 2) {
      return SafeBottomBar(
        child: ModernButton(
          text: 'Edit Konsumsi',
          icon: Icons.edit_rounded,
          onPressed: _openEdit,
          height: 50,
        ),
      );
    }

    return null;
  }
}
