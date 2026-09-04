import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/procurement_model.dart';
import '../../services/procurement_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/status_mappers.dart';
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
            style: FilledButton.styleFrom(
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Request'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: colorScheme.error,
              ),
              onPressed: _isDeleting ? null : _deleteRequest,
              tooltip: 'Hapus Request',
            ),
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
              : SafeArea(
                  top: false,
                  bottom: true,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: AppSpacing.paddingMD,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Info Card
                                  Card(
                                    child: Padding(
                                      padding: AppSpacing.paddingMD,
                                      child: Column(
                                        children: [
                                          _buildInfoRow('Toko / Outlet',
                                              _request!.storeName, theme),
                                          const Divider(height: 20),
                                          _buildInfoRow('Tanggal Request',
                                              _request!.date, theme),
                                          const Divider(height: 20),
                                          _buildInfoRow('Diminta Oleh',
                                              _request!.userName, theme),
                                          const Divider(height: 20),
                                          _buildInfoRow(
                                              'Status Global',
                                              _request!.overallStatusText,
                                              theme,
                                              isStatus: true),
                                        ],
                                      ),
                                    ),
                                  ),
                                  AppSpacing.gapVerticalLG,
                                  Text(
                                    'Daftar Item Belanja',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  AppSpacing.gapVerticalSM,
                                  ..._request!.detailRequests.map((item) {
                                    return Card(
                                      margin: const EdgeInsets.only(
                                          bottom: AppSpacing.itemGap),
                                      child: Padding(
                                        padding: AppSpacing.cardPadding,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.productName,
                                                    style: theme
                                                        .textTheme.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${item.quantityPlan.toStringAsFixed(0)} ${item.unitName}',
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            AppSpacing.gapVerticalSM,
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: AppSpacing.sm,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                            item.status)
                                                        .withValues(alpha: 0.1),
                                                    borderRadius: AppSpacing
                                                        .borderRadiusMD,
                                                  ),
                                                  child: Text(
                                                    item.statusText,
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: _getStatusColor(
                                                          item.status),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (item.paymentTypeId != null)
                                                  Text(
                                                    item.paymentTypeId == 2
                                                        ? (item.statusEnum
                                                                .isPending
                                                            ? 'Tunai (Butuh Approval)'
                                                            : 'Tunai (Langsung)')
                                                        : 'Transfer (Langsung)',
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color:
                                                          (item.paymentTypeId ==
                                                                      2 &&
                                                                  item.statusEnum
                                                                      .isPending)
                                                              ? AppColors
                                                                  .warning
                                                              : AppColors
                                                                  .success,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            // Admin Actions inline (Approve, Reject, Tidak Digunakan)
                                            if (_isAdmin &&
                                                (item.statusEnum.isPending ||
                                                    item.statusEnum
                                                        .isPartiallyApproved)) ...[
                                              const Divider(height: 20),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  if (item.statusEnum
                                                      .isPending) ...[
                                                    OutlinedButton.icon(
                                                      onPressed:
                                                          _isActionLoading
                                                              ? null
                                                              : () =>
                                                                  _rejectItem(
                                                                      item.id),
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        foregroundColor:
                                                            colorScheme.error,
                                                        side: BorderSide(
                                                            color: colorScheme
                                                                .error),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    AppSpacing
                                                                        .md),
                                                      ),
                                                      icon: const Icon(
                                                          Icons.close,
                                                          size: 16),
                                                      label:
                                                          const Text('Reject'),
                                                    ),
                                                    AppSpacing.gapHorizontalSM,
                                                    ElevatedButton.icon(
                                                      onPressed:
                                                          _isActionLoading
                                                              ? null
                                                              : () =>
                                                                  _approveItem(
                                                                      item.id),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    AppSpacing
                                                                        .md),
                                                      ),
                                                      icon: const Icon(
                                                          Icons.check,
                                                          size: 16),
                                                      label:
                                                          const Text('Approve'),
                                                    ),
                                                    AppSpacing.gapHorizontalSM,
                                                  ],
                                                  OutlinedButton.icon(
                                                    onPressed: _isActionLoading
                                                        ? null
                                                        : () => _cancelItem(
                                                            item.id),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          AppColors.warning,
                                                      side: BorderSide(
                                                          color: AppColors
                                                              .warning),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                              AppSpacing.md),
                                                    ),
                                                    icon: const Icon(
                                                        Icons.block,
                                                        size: 16),
                                                    label: const Text(
                                                        'Tidak Digunakan'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  SizedBox(height: AppSpacing.xxl),
                                ],
                              ),
                            ),
                          ),
                        ],
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
      bottomSheet: hasApprovedItems
          ? SafeBottomBar(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading ? null : _navigateToCreateInvoice,
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    'Buat Invoice',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme,
      {bool isStatus = false}) {
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isStatus ? _statusColor(value, colorScheme) : null,
          ),
        ),
      ],
    );
  }

  /// Warna nilai status global mengikuti konvensi dashboard procurement
  /// (Pending Approval=warning, Partially Approved/Approved=info,
  /// Done=success, Rejected=error) — bukan colorScheme.primary.
  Color _statusColor(String label, ColorScheme colorScheme) {
    switch (StatusMappers.procurementGlobalStatus(label)) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.error:
        return AppColors.error;
      case StatusType.info:
        return AppColors.info;
      case StatusType.neutral:
        return colorScheme.primary;
    }
  }
}
