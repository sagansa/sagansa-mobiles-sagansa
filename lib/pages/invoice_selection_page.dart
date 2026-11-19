import 'package:flutter/material.dart';

import '../../models/procurement_model.dart';
import '../../services/procurement_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/format_utils.dart';
import '../../widgets/list_thumbnail.dart';
import '../../widgets/modern_button.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';
import 'create_payment_receipt_page.dart';

class InvoiceSelectionPage extends StatefulWidget {
  final Set<int> initialSelectedIds;

  const InvoiceSelectionPage({
    super.key,
    this.initialSelectedIds = const {},
  });

  @override
  State<InvoiceSelectionPage> createState() => _InvoiceSelectionPageState();
}

class _InvoiceSelectionPageState extends State<InvoiceSelectionPage> {
  final ProcurementService _procurementService = ProcurementService();
  List<InvoicePurchase> _invoices = [];
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _procurementService.getInvoices(
        paymentStatus: '1',
        perPage: 50,
      );
      if (!mounted) return;
      setState(() {
        _invoices =
            result.items.where((inv) => inv.paymentTypeId == 1).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat invoice: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _invoices.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _invoices.map((i) => i.id).toSet();
      }
    });
  }

  void _proceed() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu invoice')),
      );
      return;
    }
    final selected =
        _invoices.where((inv) => _selectedIds.contains(inv.id)).toList();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePaymentReceiptPage(invoices: selected),
      ),
    );
  }

  int get _selectedTotalAmount {
    return _invoices
        .where((inv) => _selectedIds.contains(inv.id))
        .fold(0, (sum, inv) => sum + inv.totalPrice);
  }

  void _showImageFullscreen(String url) {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
          appBar: GlassAppBar(
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.87),
            foregroundColor: colorScheme.surface,
            title: Text('Bukti Invoice',
                style: TextStyle(color: colorScheme.surface)),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: colorScheme.surface.withValues(alpha: 0.54),
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final isAllSelected =
        _invoices.isNotEmpty && _selectedIds.length == _invoices.length;

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Pilih Invoice Transfer'),
        actions: [
          if (_invoices.isNotEmpty)
            TextButton.icon(
              onPressed: _toggleSelectAll,
              icon: Icon(
                isAllSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                size: 18,
                color: isDark ? AppColors.gold : AppColors.primary,
              ),
              label: Text(
                isAllSelected ? 'Batal Semua' : 'Pilih Semua',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.gold : AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: _isLoading
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
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: _fetchInvoices,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _invoices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          AppSpacing.gapVerticalMD,
                          Text(
                            'Tidak ada invoice Transfer yang belum dibayar.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Selection info bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs),
                          color: isDark
                              ? theme.cardColor
                              : AppColors.surfaceVariant.withValues(alpha: 0.4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedIds.length} dari ${_invoices.length} invoice dipilih',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_selectedIds.isNotEmpty)
                                Text(
                                  FormatUtils.formatCurrency(
                                      _selectedTotalAmount),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.gold
                                        : AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Invoice list
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchInvoices,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              itemCount: _invoices.length,
                              itemBuilder: (context, idx) {
                                final inv = _invoices[idx];
                                final selected = _selectedIds.contains(inv.id);

                                return Container(
                                  margin: const EdgeInsets.only(
                                      bottom: AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? theme.cardColor
                                        : AppColors.surface,
                                    borderRadius: AppSpacing.borderRadiusMD,
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.gold
                                          : (isDark
                                              ? Colors.white12
                                              : AppColors.secondaryContainer
                                                  .withValues(alpha: 0.4)),
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: AppSpacing.borderRadiusMD,
                                    child: InkWell(
                                      borderRadius: AppSpacing.borderRadiusMD,
                                      onTap: () => _toggleSelection(inv.id),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.all(AppSpacing.md),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: selected,
                                              activeColor: AppColors.gold,
                                              checkColor: Colors.black,
                                              onChanged: (_) =>
                                                  _toggleSelection(inv.id),
                                            ),
                                            AppSpacing.gapHorizontalXS,
                                            ListThumbnail(
                                              imageUrl: inv.imageUrl,
                                              placeholderIcon:
                                                  Icons.receipt_long_rounded,
                                              onTap: inv.imageUrl != null
                                                  ? () => _showImageFullscreen(
                                                      inv.imageUrl!)
                                                  : null,
                                            ),
                                            AppSpacing.gapHorizontalSM,
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    inv.storeName,
                                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${inv.supplierName ?? "-"} • ${inv.date}',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              FormatUtils.formatCurrency(
                                                  inv.totalPrice),
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? AppColors.gold
                                                    : AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Bottom Floating Action Button Container
                        SafeBottomBar(
                          child: SizedBox(
                            width: double.infinity,
                            child: ModernButton(
                              text: _selectedIds.isEmpty
                                  ? 'Pilih Minimal 1 Invoice'
                                  : 'Buat Payment Receipt (${_selectedIds.length})',
                              onPressed: _selectedIds.isEmpty ? null : _proceed,
                              icon: Icons.payments_rounded,
                              height: 52,
                            ),
                          ),
                        ),
                      ],
                    ),
      ),
    );
  }
}
