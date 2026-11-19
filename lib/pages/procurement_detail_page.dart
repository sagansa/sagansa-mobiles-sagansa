import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/procurement_model.dart';
import '../../services/procurement_service.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/status_mappers.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/status_badge.dart';
import 'create_invoice_page.dart';
import 'invoice_detail_page.dart';

class ProcurementDetailPage extends StatefulWidget {
  final int requestId;

  const ProcurementDetailPage({super.key, required this.requestId});

  @override
  State<ProcurementDetailPage> createState() => _ProcurementDetailPageState();
}

class _ProcurementDetailPageState extends State<ProcurementDetailPage> {
  final ProcurementService _procurementService = ProcurementService();
  RequestPurchase? _request;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  bool _isActionLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndDetail();
  }

  Future<void> _loadUserRoleAndDetail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        final userRoles = List<String>.from(userData['roles'] ?? []);
        setState(() {
          _isAdmin =
              userRoles.contains('admin') || userRoles.contains('super_admin');
          _isSuperAdmin = userRoles.contains('super_admin');
        });
      }
    } catch (_) {}
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _procurementService.getRequestDetail(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat detail request: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveItem(int itemId) async {
    setState(() => _isActionLoading = true);
    try {
      await _procurementService.approveItem(itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item request disetujui.')),
      );
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyetujui item: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _rejectItem(int itemId) async {
    setState(() => _isActionLoading = true);
    try {
      await _procurementService.rejectItem(itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item request ditolak.')),
      );
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menolak item: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _cancelItem(int itemId) async {
    setState(() => _isActionLoading = true);
    try {
      await _procurementService.cancelItem(itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item request ditandai tidak digunakan.')),
      );
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menandai tidak digunakan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _navigateToCreateInvoice() async {
    if (_request == null) return;

    final approvedItems = _request!.detailRequests
        .where((item) => item.statusEnum.isApproved)
        .toList();

    if (approvedItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Tidak ada item yang disetujui untuk dibuat invoice.')),
      );
      return;
    }

    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateInvoicePage(
          requestId: widget.requestId,
          approvedItems: approvedItems,
        ),
      ),
    );

    if (result != null && result > 0) {
      _fetchDetail();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceDetailPage(invoiceId: result),
        ),
      ).then((_) => _fetchDetail());
    }
  }

  Future<bool?> _confirmDeleteRequest() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Request'),
        content: const Text(
          'Hapus request ini secara permanen beserta seluruh itemnya? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: AppButtonStyle.filled(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest() async {
    final confirmed = await _confirmDeleteRequest();
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isDeleting = true);
    try {
      await _procurementService.deleteRequest(widget.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request berhasil dihapus.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '1': // process
        return AppColors.warning;
      case '2': // done
        return AppColors.success;
      case '3': // reject
        return AppColors.error;
      case '4': // approved
        return AppColors.info;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasApprovedItems = _request?.detailRequests
            .any((item) => item.statusEnum.isPartiallyApproved) ??
        false;

    // Guard hapus (sinkron dengan backend destroyRequest): request yang
    // sudah punya invoice tidak boleh dihapus kecuali oleh super_admin.
    // Tombol tetap tampil namun disabled agar jelas aksinya ada tapi
    // terkunci.
    final deleteLocked =
        _request?.hasInvoices == true && !_isSuperAdmin;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Detail Request'),
        actions: [
          BarButtonCluster(actions: [
            if (_isAdmin)
              BarButtonSpec(
                icon: Icons.delete_outline,
                tooltip: deleteLocked
                    ? 'Hapus tidak tersedia — request sudah menjadi invoice'
                    : 'Hapus Request',
                onTap: _isDeleting || deleteLocked ? null : _deleteRequest,
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
                        Text(_errorMessage!,
                            style: TextStyle(color: colorScheme.error)),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton(
                          onPressed: _fetchDetail,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Builder(
                  builder: (bodyContext) => SafeArea(
                    top: false,
                    bottom: true,
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: AppSpacing.paddingMD.copyWith(
                              top: AppBarInsets.top(bodyContext)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Info Card using DetailSectionCard
                            DetailSectionCard(
                              icon: Icons.assignment_outlined,
                              iconColor: AppColors.warning,
                              title: 'REQ #${_request!.id}',
                              trailing: StatusBadge(
                                text: _request!.overallStatusText,
                                type: StatusMappers.procurementGlobalStatus(
                                    _request!.overallStatusText),
                              ),
                              children: [
                                DetailRow(
                                  label: 'Toko / Outlet',
                                  value: _request!.storeName,
                                ),
                                DetailRow(
                                  label: 'Tanggal Request',
                                  value: _request!.date,
                                ),
                                DetailRow(
                                  label: 'Diminta Oleh',
                                  value: _request!.userName,
                                ),
                                DetailRow(
                                  label: 'Total Item',
                                  value: '${_request!.detailRequests.length} item',
                                ),
                              ],
                            ),
                            AppSpacing.gapVerticalLG,

                            // Header Item Belanja
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daftar Item Belanja',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: AppSpacing.borderRadiusMD,
                                  ),
                                  child: Text(
                                    '${_request!.detailRequests.length} Item',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.gapVerticalSM,

                            // Items List
                            ..._request!.detailRequests.map((item) {
                              final statusColor = _getStatusColor(item.status);
                              final isCash = item.paymentTypeId == 2;
                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: AppSpacing.itemGap),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: AppSpacing.borderRadiusLG,
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.shadow
                                          .withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.productName,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          AppSpacing.gapHorizontalSM,
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  AppSpacing.borderRadiusSM,
                                            ),
                                            child: Text(
                                              '${item.quantityPlan.toStringAsFixed(0)} ${item.unitName}',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  AppSpacing.borderRadiusSM,
                                              border: Border.all(
                                                color: statusColor
                                                    .withValues(alpha: 0.3),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              item.statusText,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (item.paymentTypeId != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.5),
                                                borderRadius:
                                                    AppSpacing.borderRadiusSM,
                                              ),
                                              child: Text(
                                                isCash
                                                    ? (item.statusEnum.isPending
                                                        ? 'Tunai (Perlu Approval)'
                                                        : 'Tunai')
                                                    : 'Transfer',
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: (isCash &&
                                                          item.statusEnum
                                                              .isPending)
                                                      ? AppColors.warning
                                                      : colorScheme
                                                          .onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      // Admin Actions inline (Approve, Reject, Tidak Digunakan)
                                      if (_isAdmin &&
                                          (item.statusEnum.isPending ||
                                              item.statusEnum
                                                  .isPartiallyApproved)) ...[
                                        const SizedBox(height: 12),
                                        Divider(
                                          height: 1,
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (item.statusEnum.isPending) ...[
                                              OutlinedButton.icon(
                                                onPressed: _isActionLoading
                                                    ? null
                                                    : () =>
                                                        _rejectItem(item.id),
                                                style: AppButtonStyle.outlined(
                                                  foregroundColor:
                                                      colorScheme.error,
                                                  borderColor: colorScheme.error
                                                      .withValues(
                                                          alpha: 0.5),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  minimumSize:
                                                      const Size(0, 32),
                                                ),
                                                icon: const Icon(Icons.close,
                                                    size: 14),
                                                label: Text(
                                                  'Reject',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall,
                                                ),
                                              ),
                                              AppSpacing.gapHorizontalSM,
                                              FilledButton.icon(
                                                onPressed: _isActionLoading
                                                    ? null
                                                    : () =>
                                                        _approveItem(item.id),
                                                style: AppButtonStyle.filled(
                                                  backgroundColor:
                                                      AppColors.success,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 4),
                                                  minimumSize:
                                                      const Size(0, 32),
                                                ),
                                                icon: const Icon(Icons.check,
                                                    size: 14),
                                                label: Text(
                                                  'Approve',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                ),
                                              ),
                                              AppSpacing.gapHorizontalSM,
                                            TextButton.icon(
                                              onPressed: _isActionLoading
                                                  ? null
                                                  : () => _cancelItem(item.id),
                                              style: AppButtonStyle.text(
                                                foregroundColor:
                                                    AppColors.warning,
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                                minimumSize:
                                                    const Size(0, 32),
                                              ),
                                              icon: const Icon(Icons.block,
                                                  size: 14),
                                              label: Text(
                                                'Tidak Digunakan',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                            ),
                                          ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                      if (_isActionLoading)
                        Container(
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
      bottomSheet: hasApprovedItems
          ? SafeBottomBar(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isActionLoading ? null : _navigateToCreateInvoice,
                  style: AppButtonStyle.filled(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: Text(
                    'Buat Invoice',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
