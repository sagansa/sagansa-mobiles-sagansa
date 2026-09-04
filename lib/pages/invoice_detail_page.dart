import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/procurement_model.dart';
import '../../services/image_service.dart';
import '../../services/procurement_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/format_utils.dart';
import '../../widgets/procurement/sales_order_link_card.dart';
import '../../widgets/procurement/sales_order_picker_sheet.dart';
import '../../widgets/safe_bottom_bar.dart';
import 'create_payment_receipt_page.dart';
import 'edit_invoice_page.dart';
import 'edit_payment_receipt_page.dart';

class InvoiceDetailPage extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  final ProcurementService _procurementService = ProcurementService();
  InvoicePurchase? _invoice;
  bool _isLoading = true;
  bool _isAdmin = false;
  int _currentUserId = 0;
  String? _errorMessage;
  List<PaymentReceipt> _paymentReceipts = [];
  bool _canReceive = false;
  bool _isReceiving = false;
  bool _isDeleting = false;
  bool _isStaff = false;
  bool _qrisLoading = false;
  Map<String, dynamic>? _qrisData;
  String? _qrisError;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      final userData = json.decode(userString);
      final roles = List<String>.from(userData['roles'] ?? []);
      _isAdmin = roles.contains('admin') || roles.contains('super_admin');
      _isStaff = roles.contains('staff');
      _currentUserId = userData['id'] ?? 0;
      _canReceive =
          roles.any((r) => ['staff', 'admin', 'super_admin'].contains(r));
    }
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _qrisData = null;
      _qrisError = null;
    });

    try {
      final invoice =
          await _procurementService.getInvoiceDetail(widget.invoiceId);
      if (!mounted) return;

      List<PaymentReceipt> receipts = [];
      if (invoice.paymentStatus == '2') {
        try {
          final result = await _procurementService.getPaymentReceipts(
            invoiceId: invoice.id,
            perPage: 50,
          );
          receipts = result.items;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _paymentReceipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat detail invoice: $e';
        _isLoading = false;
      });
    }
  }

  /// QRIS dinamis supplier dengan nominal total invoice. Di-load saat
  /// tombol "Tampilkan Kode QRIS" ditekan (lazy) supaya tidak membebani
  /// pembukaan halaman detail.
  Future<void> _loadQris() async {
    if (_qrisLoading || _qrisData != null) return;
    setState(() {
      _qrisLoading = true;
      _qrisError = null;
    });
    try {
      final data = await _procurementService.getInvoiceQris(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _qrisData = data;
        _qrisLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qrisLoading = false;
        _qrisError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _navigateToEdit() async {
    if (_invoice == null) return;
    await Navigator.push<InvoicePurchase>(
      context,
      MaterialPageRoute(
        builder: (context) => EditInvoicePage(invoice: _invoice!),
      ),
    );
    // Selalu refresh detail setelah kembali dari halaman edit, karena
    // perubahan (mis. tipe pembayaran tunai→transfer) baru terlihat di
    // server. Sebelumnya hanya refresh bila result != null sehingga detail
    // tetap menampilkan data lama sampai di-refresh manual.
    if (mounted) {
      _fetchDetail();
    }
  }

  /// Ganti foto invoice (admin/staff) — endpoint khusus yang berlaku di
  /// semua payment_status tanpa membuka edit penuh invoice.
  Future<void> _replaceInvoiceImage() async {
    final photo = await ImageService.selectAndPickImage(context);
    if (photo == null || !mounted) return;
    try {
      await _procurementService
          .updateInvoiceImage(widget.invoiceId, photo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto invoice berhasil diperbarui.')));
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  /// Section "Penjualan Terkait": kaitan invoice → penjualan. Aksi
  /// link/unlink hanya aktif bila [canEdit] (status '1' + berhak edit).
  Widget _buildSalesOrderLinkSection() {
    final canEdit = _invoice!.paymentStatus == '1' &&
        (_isAdmin || _isStaff || _invoice!.createdById == _currentUserId);
    return SalesOrderLinkCard(
      invoice: _invoice!,
      canEdit: canEdit,
      onLink: _pickSalesOrder,
      onUnlink: () => _setSalesOrderLink(clear: true),
    );
  }

  Future<void> _pickSalesOrder() async {
    final candidate = await SalesOrderPickerSheet.show(
      context,
      onSearch: _procurementService.searchSalesOrderCandidates,
    );
    if (candidate == null || !mounted) return;
    await _setSalesOrderLink(salesOrderId: candidate.id);
  }

  Future<void> _setSalesOrderLink(
      {int? salesOrderId, bool clear = false}) async {
    try {
      await _procurementService.updateInvoice(
        widget.invoiceId,
        salesOrderId: salesOrderId,
        clearSalesOrderLink: clear,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaitan penjualan disimpan.')));
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _markAsReceived() async {
    if (_invoice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai Sudah Diterima'),
        content: const Text(
          'Tandai invoice ini sudah diterima? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Tandai'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isReceiving = true);
    try {
      await _procurementService.receiveInvoice(widget.invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice ditandai sudah diterima.')),
      );
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isReceiving = false);
      }
    }
  }

  Future<bool?> _confirmDeleteInvoice() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Invoice'),
        content: const Text(
          'Hapus invoice ini secara permanen? Tindakan ini tidak dapat dibatalkan.',
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

  Future<void> _deleteInvoice() async {
    final confirmed = await _confirmDeleteInvoice();
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isDeleting = true);
    try {
      await _procurementService.deleteInvoice(widget.invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice berhasil dihapus.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus invoice: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Color _paymentStatusColor(String status) {
    switch (status) {
      case '1':
        return AppColors.warning;
      case '2':
        return AppColors.success;
      case '3':
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case '1':
        return AppColors.warning;
      case '2':
        return AppColors.success;
      case '3':
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  Widget _buildDashedLine(Color color) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color.withValues(alpha: 0.5)),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Invoice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_invoice != null &&
              _invoice!.paymentStatus == '1' &&
              (_isAdmin ||
                  _isStaff ||
                  _invoice!.createdById == _currentUserId))
            IconButton(
              icon: const Icon(Icons.edit_note_outlined, size: 28),
              onPressed: _navigateToEdit,
              tooltip: 'Edit Invoice',
            ),
          if (_isAdmin)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 24,
                color: colorScheme.error,
              ),
              onPressed: _isDeleting ? null : _deleteInvoice,
              tooltip: 'Hapus Invoice',
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
                        Icon(Icons.error_outline,
                            size: 48, color: colorScheme.error),
                        AppSpacing.gapVerticalMD,
                        Text(_errorMessage!,
                            style: TextStyle(color: colorScheme.error),
                            textAlign: TextAlign.center),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton.icon(
                          onPressed: _fetchDetail,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  top: false,
                  bottom: true,
                  child: RefreshIndicator(
                  onRefresh: _fetchDetail,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        12, 12, 12, 200 + context.systemBottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Informasi Utama Invoice (Digital Ticket/Voucher Style)
                        Card(
                          color: colorScheme.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'INVOICE PEMBELIAN',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Wrap(
                                            alignment: WrapAlignment.end,
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _paymentStatusColor(
                                                          _invoice!
                                                              .paymentStatus)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: _paymentStatusColor(
                                                              _invoice!
                                                                  .paymentStatus)
                                                          .withValues(
                                                              alpha: 0.2)),
                                                ),
                                                child: Text(
                                                  _invoice!.paymentStatusText,
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: _paymentStatusColor(
                                                        _invoice!
                                                            .paymentStatus),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _orderStatusColor(
                                                          _invoice!.orderStatus)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: _orderStatusColor(
                                                              _invoice!
                                                                  .orderStatus)
                                                          .withValues(
                                                              alpha: 0.2)),
                                                ),
                                                child: Text(
                                                  _invoice!.orderStatusText,
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: _orderStatusColor(
                                                        _invoice!.orderStatus),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _invoice!.storeName,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildDashedLine(
                                    colorScheme.outlineVariant),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildInfoRow(
                                        'Tanggal', _invoice!.date, theme),
                                    const SizedBox(height: 8),
                                    if (_invoice!.supplierName != null) ...[
                                      _buildInfoRow('Supplier',
                                          _invoice!.supplierName!, theme),
                                      const SizedBox(height: 8),
                                    ],
                                    _buildInfoRow('Dibuat Oleh',
                                        _invoice!.createdByName, theme),
                                    const SizedBox(height: 8),
                                    _buildInfoRow('Tipe Pembayaran',
                                        _invoice!.paymentTypeText, theme),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapVerticalMD,

                        // Kartu Penjualan Terkait: referensi invoice ke
                        // penjualan (link/unlink sales order).
                        _buildSalesOrderLinkSection(),

                        if (_invoice!.imageUrl != null &&
                            _invoice!.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Card(
                            clipBehavior: Clip.antiAlias,
                            color: colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5)),
                            ),
                            child: InkWell(
                              onTap: () =>
                                  _showReceiptImage(_invoice!.imageUrl!),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.image_outlined,
                                            size: 18,
                                            color: colorScheme.primary),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text('Foto Invoice',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                        ),
                                        if (_isAdmin || _isStaff)
                                          TextButton.icon(
                                            onPressed: _replaceInvoiceImage,
                                            style: TextButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: const EdgeInsets
                                                  .symmetric(horizontal: 6),
                                            ),
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 14),
                                            label: const Text(
                                                'Ganti Foto Invoice'),
                                          ),
                                        Text('Perbesar',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 190,
                                    child: _buildInvoiceImage(
                                        _invoice!.image!, colorScheme),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (_isAdmin || _isStaff) ...[
                          const SizedBox(height: 10),
                          // Belum ada foto invoice: entry point unggah foto
                          // PERTAMA (admin/staff), mis. supplier mengirim
                          // invoice setelah invoice dibayar.
                          Card(
                            clipBehavior: Clip.antiAlias,
                            color: colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.image_outlined,
                                          size: 18, color: colorScheme.primary),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text('Foto Invoice',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _replaceInvoiceImage,
                                      icon: const Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 18),
                                      label: const Text('Unggah Foto Invoice'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        AppSpacing.gapVerticalMD,

                        // Card 2: Daftar Item Konsolidasi
                        Card(
                          color: colorScheme.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.shopping_bag_outlined,
                                          color: colorScheme.primary, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Item Pembelian',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                    height: 1,
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                if (_invoice!.detailInvoices.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 24.0),
                                    child: Center(
                                      child: Text(
                                        'Belum ada item dalam invoice ini.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _invoice!.detailInvoices.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                            height: 24,
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.2)),
                                    itemBuilder: (context, index) {
                                      final item =
                                          _invoice!.detailInvoices[index];
                                      final unitPrice = item.unitPrice;
                                      final subtotal = item.subtotalInvoice
                                          .toStringAsFixed(0)
                                          .replaceAllMapped(
                                              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                                              (m) => '${m.group(1)}.');
                                      final currentPrice = unitPrice
                                          .toStringAsFixed(0)
                                          .replaceAllMapped(
                                              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                                              (m) => '${m.group(1)}.');
                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: colorScheme.outlineVariant
                                                  .withValues(alpha: 0.45)),
                                        ),
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
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Rp $subtotal',
                                                  style: theme
                                                      .textTheme.titleSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                _itemMetaChip(
                                                  icon: Icons
                                                      .inventory_2_outlined,
                                                  label:
                                                      '${item.quantityProduct.toStringAsFixed(0)} ${item.unitName}',
                                                  color: colorScheme.secondary,
                                                ),
                                                _itemMetaChip(
                                                  icon: Icons.sell_outlined,
                                                  label:
                                                      'Rp $currentPrice / ${item.unitName}',
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ],
                                            ),
                                            if (_isAdmin &&
                                                item.lastPurchasePrices
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.info
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.history,
                                                            size: 15,
                                                            color:
                                                                AppColors.info),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          'Harga beli sebelumnya',
                                                          style: theme.textTheme
                                                              .labelMedium
                                                              ?.copyWith(
                                                            color:
                                                                AppColors.info,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ...item.lastPurchasePrices
                                                        .asMap()
                                                        .entries
                                                        .map((entry) {
                                                      final lp = entry.value;
                                                      final price = lp.unitPrice
                                                          .toStringAsFixed(0)
                                                          .replaceAllMapped(
                                                              RegExp(
                                                                  r'(\d)(?=(\d{3})+(?!\d))'),
                                                              (m) =>
                                                                  '${m.group(1)}.');
                                                      final date =
                                                          lp.date != null
                                                              ? lp.date!
                                                                  .toLocal()
                                                                  .toString()
                                                                  .split(' ')
                                                                  .first
                                                              : '-';
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 3),
                                                        child: Text(
                                                          '${entry.key + 1}. Rp $price/${item.unitName} • ${lp.supplierName ?? 'Supplier tidak diketahui'} • $date',
                                                          style: theme.textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                  color:
                                                                      AppColors
                                                                          .info),
                                                        ),
                                                      );
                                                    }),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        AppSpacing.gapVerticalMD,

                        // Card 3: Rincian Tagihan (Checkout Slip Style)
                        Card(
                          color: colorScheme.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blue.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.receipt_long,
                                          color: Colors.blue, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Rincian Tagihan',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                    height: 1,
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                    'Pajak',
                                    'Rp ${_invoice!.taxes != 0 ? _invoice!.taxes.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)}.') : '0'}',
                                    theme),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                    'Diskon',
                                    'Rp ${_invoice!.discounts != 0 ? _invoice!.discounts.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)}.') : '0'}',
                                    theme),
                                const SizedBox(height: 16),
                                _buildDashedLine(colorScheme.outlineVariant),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TOTAL AKHIR',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${_invoice!.totalPrice != 0 ? _invoice!.totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)}.') : '0'}',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Kartu Pembayaran Transfer: QRIS / rekening supplier.
                        // Hanya untuk invoice tipe transfer dan bukan staff
                        // (konsisten dengan policy QRIS payment receipt).
                        if (_invoice!.isTransfer && !_isStaff) ...[
                          AppSpacing.gapVerticalMD,
                          _buildTransferPaymentCard(theme, colorScheme),
                        ],

                        // Catatan (jika ada)
                        if (_invoice!.notes != null &&
                            _invoice!.notes!.isNotEmpty) ...[
                          AppSpacing.gapVerticalMD,
                          Card(
                            color: colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.notes,
                                          color: colorScheme.primary, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Catatan',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    FormatUtils.stripHtml(_invoice!.notes!),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Bukti Pembayaran / Lampiran (jika ada)
                        if (_invoice!.paymentStatus == '2' &&
                            _paymentReceipts.isNotEmpty) ...[
                          AppSpacing.gapVerticalMD,
                          ..._paymentReceipts.map((receipt) {
                            final multi = receipt.invoicePurchases.length > 1;
                            return Card(
                              color: colorScheme.surface,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: AppColors.success
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.check_circle,
                                                size: 20,
                                                color: AppColors.success),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Transaksi Pembayaran Sukses',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_isAdmin)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 20),
                                            tooltip: 'Edit Payment Receipt',
                                            onPressed: () async {
                                              final updated =
                                                  await Navigator.push<
                                                      PaymentReceipt>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      EditPaymentReceiptPage(
                                                          receipt: receipt),
                                                ),
                                              );
                                              if (updated != null) {
                                                _fetchDetail();
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                    if (receipt.image != null &&
                                        receipt.image!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: GestureDetector(
                                          onTap: () => _showReceiptImage(
                                              _imageUrl(receipt.image)),
                                          child: Stack(
                                            alignment: Alignment.bottomCenter,
                                            children: [
                                              Image.network(
                                                _imageUrl(receipt.image),
                                                height: 180,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox.shrink(),
                                                loadingBuilder:
                                                    (_, child, progress) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    height: 180,
                                                    color: colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.3),
                                                    child: const Center(
                                                        child:
                                                            CircularProgressIndicator()),
                                                  );
                                                },
                                              ),
                                              Container(
                                                width: double.infinity,
                                                color: Colors.black
                                                    .withValues(alpha: 0.6),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.zoom_in,
                                                        color: Colors.white,
                                                        size: 16),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Ketuk untuk memperbesar gambar',
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.white),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    _buildInfoRow(
                                        'Jumlah Transfer',
                                        'Rp ${FormatUtils.formatNumber(receipt.transferAmount)}',
                                        theme),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                        'Tanggal Verifikasi',
                                        receipt.createdAt.substring(0, 10),
                                        theme),
                                    if (multi) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Tergabung dalam pembayaran ${receipt.invoicePurchases.length} invoice',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                ),
      bottomSheet: (_invoice != null &&
                  _invoice!.paymentStatus != '2' &&
                  _isAdmin) ||
              (_invoice != null && _invoice!.orderStatus == '1' && _canReceive)
          ? SafeBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                      // Buat Payment Receipt (admin + invoice belum lunas)
                      if (_invoice != null &&
                          _invoice!.paymentStatus != '2' &&
                          _isAdmin) ...[
                        Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreatePaymentReceiptPage(
                                      invoices: [_invoice!],
                                    ),
                                  ),
                                );
                                if (result == true || result != null) {
                                  _fetchDetail();
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.payments,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Buat Payment Receipt',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.gapVerticalSM,
                      ],
                      // New: Tandai Sudah Diterima (staff/admin/super_admin + order_status 1)
                      if (_invoice != null &&
                          _invoice!.orderStatus == '1' &&
                          _canReceive)
                        Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isReceiving ? null : _markAsReceived,
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: _isReceiving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Tandai Sudah Diterima',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
            )
          : null,
    );
  }

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '${ApiConstants.baseUrl}/media/$path';
  }

  Widget _buildInvoiceImage(String path, ColorScheme colorScheme) {
    final primaryUrl = _invoice?.imageUrl ?? '';
    final fallbackUrl = _imageUrl(path);
    return Image.network(
      primaryUrl,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, __, ___) => Image.network(
        fallbackUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.broken_image_outlined,
              size: 42, color: colorScheme.outline),
        ),
      ),
    );
  }

  void _showReceiptImage(String url) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.87),
            iconTheme: IconThemeData(color: colorScheme.surface),
            title: Text('Bukti Pembayaran',
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

  /// Kartu tujuan pembayaran untuk invoice tipe transfer: rekening bank
  /// dan/atau QRIS dinamis milik supplier (nominal = total invoice).
  Widget _buildTransferPaymentCard(ThemeData theme, ColorScheme colorScheme) {
    final invoice = _invoice!;
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance,
                      color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pembayaran Transfer',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  'Total: Rp ${FormatUtils.formatNumber(invoice.totalPrice)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            if (invoice.hasSupplierBankAccount) ...[
              _buildBankAccountSection(theme, colorScheme),
              if (invoice.supplierHasQris) ...[
                const SizedBox(height: 16),
                Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
              ],
            ],
            if (invoice.supplierHasQris)
              _buildQrisSection(theme)
            else if (!invoice.hasSupplierBankAccount)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Supplier belum memiliki data QRIS / rekening bank. Lengkapi data supplier terlebih dahulu.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAccountSection(ThemeData theme, ColorScheme colorScheme) {
    final invoice = _invoice!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.credit_card,
                size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Rekening Supplier',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildInfoRow('Bank', invoice.supplierBankName ?? '-', theme),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'No. Rekening',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      invoice.supplierBankAccountNo ?? '-',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _copyToClipboard(
                      invoice.supplierBankAccountNo!,
                      label: 'Nomor rekening',
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(Icons.copy_rounded,
                        size: 15, color: colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildInfoRow('Atas Nama', invoice.supplierBankAccountName ?? '-', theme),
      ],
    );
  }

  Widget _buildQrisSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.qr_code_2_rounded,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'QRIS Supplier',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_qrisData != null) ...[
          Center(
            child: QrImageView(
              data: _qrisData!['payload'] as String,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
              'Merchant', _qrisData!['merchant_name']?.toString() ?? '-', theme),
          const SizedBox(height: 8),
          _buildInfoRow(
              'Nominal QRIS',
              'Rp ${FormatUtils.formatNumber(_qrisData!['amount'])}',
              theme),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _copyToClipboard(_qrisData!['payload'] as String,
                      label: 'Payload QRIS'),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Payload QRIS'),
            ),
          ),
        ] else if (_qrisLoading) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ] else if (_qrisError != null) ...[
          Text(
            _qrisError!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadQris,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadQris,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Tampilkan Kode QRIS'),
            ),
          ),
        ],
      ],
    );
  }

  void _copyToClipboard(String text, {required String label}) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label disalin')),
    );
  }

  Widget _itemMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
