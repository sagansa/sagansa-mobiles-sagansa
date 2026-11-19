import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/procurement_model.dart';
import '../../services/image_service.dart';
import '../../services/procurement_service.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/format_utils.dart';
import '../../widgets/app_bar_insets.dart';
import '../../widgets/procurement/sales_order_link_card.dart';
import '../../widgets/procurement/sales_order_picker_sheet.dart';
import '../../widgets/safe_bottom_bar.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/glass_app_bar.dart';
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
  // Penjualan Terkait hanya untuk storage-staff & admin (lihat
  // _buildSalesOrderLinkSection dan guard sales_order_id di backend).
  bool _canManageSalesLink = false;

  /// Foto invoice dikunci ketika sudah final: SUDAH DIBAYAR (payment '2')
  /// DAN SUDAH DITERIMA (order '2') — sinkron dengan guard backend
  /// updateInvoiceImage.
  bool get _photoLocked =>
      _invoice != null &&
      _invoice!.paymentStatus == '2' &&
      _invoice!.orderStatus == '2';
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
      _canManageSalesLink = _isAdmin || roles.contains('storage-staff');
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
      showAppSnackBar(
        context,
        e.toString().replaceAll('Exception: ', ''),
        background: Theme.of(context).colorScheme.error,
      );
    }
  }

  /// Section "Penjualan Terkait": kaitan invoice → penjualan. Aksi
  /// link/unlink hanya aktif bila [canEdit] (status '1' + berhak edit).
  Widget _buildSalesOrderLinkSection() {
    final canEdit =
        (_invoice!.paymentStatus == '1' || _invoice!.paymentStatus == '2') &&
            _canManageSalesLink;
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
      onLoad: _procurementService.getSalesOrderLinkCandidates,
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
      showAppSnackBar(
        context,
        e.toString().replaceAll('Exception: ', ''),
        background: Theme.of(context).colorScheme.error,
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text(
          'Detail Invoice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          BarButtonCluster(actions: [
            if (_invoice != null &&
                _invoice!.paymentStatus == '1' &&
                (_isAdmin ||
                    _isStaff ||
                    _invoice!.createdById == _currentUserId))
              BarButtonSpec(
                icon: Icons.edit_note_outlined,
                iconSize: 28,
                tooltip: 'Edit Invoice',
                onTap: _navigateToEdit,
              ),
            if (_isAdmin)
              BarButtonSpec(
                icon: Icons.delete_outline,
                iconSize: 24,
                tooltip: 'Hapus Invoice',
                onTap: _isDeleting ? null : _deleteInvoice,
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
                        12,
                        AppBarInsets.top(context),
                        12,
                        200 + context.systemBottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Informasi Utama Invoice
                        DetailSectionCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'INV #${_invoice!.id}',
                          trailing: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _paymentStatusColor(_invoice!.paymentStatus)
                                      .withValues(alpha: 0.12),
                                  borderRadius: AppSpacing.borderRadiusSM,
                                  border: Border.all(
                                    color: _paymentStatusColor(_invoice!.paymentStatus)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  _invoice!.paymentStatusText,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _paymentStatusColor(_invoice!.paymentStatus),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _orderStatusColor(_invoice!.orderStatus)
                                      .withValues(alpha: 0.12),
                                  borderRadius: AppSpacing.borderRadiusSM,
                                  border: Border.all(
                                    color: _orderStatusColor(_invoice!.orderStatus)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  _invoice!.orderStatusText,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _orderStatusColor(_invoice!.orderStatus),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            DetailRow(
                              label: 'Toko / Cabang',
                              value: _invoice!.storeName,
                              isBold: true,
                            ),
                            DetailRow(
                              label: 'Tanggal',
                              value: _invoice!.date,
                            ),
                            if (_invoice!.supplierName != null)
                              DetailRow(
                                label: 'Supplier',
                                value: _invoice!.supplierName!,
                                isBold: true,
                              ),
                            DetailRow(
                              label: 'Dibuat Oleh',
                              value: _invoice!.createdByName,
                            ),
                            DetailRow(
                              label: 'Tipe Pembayaran',
                              value: _invoice!.paymentTypeText,
                            ),
                            if (_invoice!.isCash)
                              DetailRow(
                                label: 'Closing Terkait',
                                value: _invoice!.closingStores.isNotEmpty
                                    ? _invoice!.closingStores
                                        .map((c) => '#${c.id} (${c.date})')
                                        .join(', ')
                                    : 'Belum terkait closing',
                              ),
                          ],
                        ),
                        AppSpacing.gapVerticalMD,

                        // Kartu Penjualan Terkait: referensi invoice ke
                        // penjualan (link/unlink sales order). Hanya tampil
                        // untuk storage-staff & admin.
                        if (_canManageSalesLink)
                          _buildSalesOrderLinkSection(),

                        if (_invoice!.imageUrl != null &&
                            _invoice!.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          DetailSectionCard(
                            icon: Icons.image_outlined,
                            title: 'Foto Invoice',
                            trailing: (_isAdmin || _isStaff) && !_photoLocked
                                ? TextButton.icon(
                                    onPressed: _replaceInvoiceImage,
                                    style: AppButtonStyle.text(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                    ),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 14),
                                    label: const Text('Ganti Foto'),
                                  )
                                : null,
                            child: DetailImageView(
                              imageUrl: _invoice!.imageUrl!,
                              fallbackImageUrl: _imageUrl(_invoice!.image),
                              height: 190,
                              previewTitle: 'Foto Invoice',
                            ),
                          ),
                        ] else if ((_isAdmin || _isStaff) &&
                            !_photoLocked) ...[
                          const SizedBox(height: 10),
                          // Belum ada foto invoice: entry point unggah foto
                          // PERTAMA (admin/staff), mis. supplier mengirim
                          // invoice setelah invoice dibayar.
                          DetailSectionCard(
                            icon: Icons.add_a_photo_outlined,
                            title: 'Foto Invoice',
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _replaceInvoiceImage,
                                icon: const Icon(Icons.add_a_photo_rounded,
                                    size: 18),
                                label: const Text('Unggah Foto Invoice'),
                              ),
                            ),
                          ),
                        ],
                        AppSpacing.gapVerticalMD,

                        // Card 2: Daftar Item Konsolidasi
                        // Item dirender flat (tanpa kartu bersarang) supaya
                        // konten sejajar dengan baris detail lain di kartu —
                        // nested card membuat inset ganda & padding terasa
                        // terlalu lebar dari tepi layar.
                        DetailSectionCard(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Item Pembelian',
                          trailing: Text(
                            '${_invoice!.detailInvoices.length} Item',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          children: [
                            if (_invoice!.detailInvoices.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 24.0),
                                child: Center(
                                  child: Text(
                                    'Belum ada item dalam invoice ini.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              )
                            else
                              // Column murni (bukan ListView) — item invoice
                              // selikit jumlahnya dan ListView bershrinkWrap
                              // pernah menyisakan ruang kosong tak terduga
                              // di sejumlah perangkat.
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0;
                                      i < _invoice!.detailInvoices.length;
                                      i++) ...[
                                    if (i > 0)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Divider(
                                          height: 1,
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                    _buildItemRow(
                                      _invoice!.detailInvoices[i],
                                      theme,
                                      colorScheme,
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                        AppSpacing.gapVerticalMD,

                        // Card 3: Rincian Tagihan
                        DetailSectionCard(
                          icon: Icons.calculate_outlined,
                          title: 'Rincian Tagihan',
                          children: [
                            DetailRow(
                              label: 'Pajak',
                              value: 'Rp ${_invoice!.taxes != 0 ? FormatUtils.formatNumber(_invoice!.taxes) : '0'}',
                            ),
                            DetailRow(
                              label: 'Diskon',
                              value: 'Rp ${_invoice!.discounts != 0 ? FormatUtils.formatNumber(_invoice!.discounts) : '0'}',
                            ),
                            AppSpacing.gapVerticalSM,
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.07),
                                borderRadius: AppSpacing.borderRadiusMD,
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOTAL AKHIR',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    FormatUtils.formatCurrency(_invoice!.totalPrice),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          DetailSectionCard(
                            icon: Icons.notes_outlined,
                            title: 'Catatan',
                            children: [
                              Text(
                                FormatUtils.stripHtml(_invoice!.notes!),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Bukti Pembayaran / Lampiran (jika ada)
                        if (_invoice!.paymentStatus == '2' &&
                            _paymentReceipts.isNotEmpty) ...[
                          AppSpacing.gapVerticalMD,
                          ..._paymentReceipts.map((receipt) {
                            final multi = receipt.invoicePurchases.length > 1;
                            return DetailSectionCard(
                              icon: Icons.check_circle_outline,
                              title: 'Transaksi Pembayaran Sukses',
                              trailing: _isAdmin
                                  ? IconButton(
                                      icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18),
                                      tooltip: 'Edit Payment Receipt',
                                      visualDensity: VisualDensity.compact,
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
                                    )
                                  : null,
                              children: [
                                if (receipt.image != null &&
                                    receipt.image!.isNotEmpty) ...[
                                  DetailImageView(
                                    imageUrl: _imageUrl(receipt.image),
                                    height: 180,
                                    previewTitle: 'Bukti Pembayaran',
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                DetailRow(
                                  label: 'Jumlah Transfer',
                                  value: FormatUtils.formatCurrency(receipt.transferAmount),
                                  isBold: true,
                                ),
                                DetailRow(
                                  label: 'Tanggal Verifikasi',
                                  value: receipt.createdAt.length >= 10
                                      ? receipt.createdAt.substring(0, 10)
                                      : receipt.createdAt,
                                ),
                                if (multi) ...[
                                  AppSpacing.gapVerticalSM,
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
                            borderRadius: AppSpacing.borderRadiusMD,
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
                                if (result != null) {
                                  _fetchDetail();
                                }
                              },
                              borderRadius: AppSpacing.borderRadiusMD,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.payments,
                                        color: Colors.white, size: 20),
                                    AppSpacing.gapHorizontalSM,
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
                            borderRadius: AppSpacing.borderRadiusMD,
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
                              borderRadius: AppSpacing.borderRadiusMD,
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
                                          AppSpacing.gapHorizontalSM,
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

  /// Kartu tujuan pembayaran untuk invoice tipe transfer: rekening bank
  /// dan/atau QRIS dinamis milik supplier (nominal = total invoice).
  Widget _buildTransferPaymentCard(ThemeData theme, ColorScheme colorScheme) {
    final invoice = _invoice!;
    return DetailSectionCard(
      icon: Icons.account_balance,
      title: 'Pembayaran Transfer',
      trailing: Text(
        'Total: Rp ${FormatUtils.formatNumber(invoice.totalPrice)}',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invoice.hasSupplierBankAccount) ...[
            _buildBankAccountSection(theme, colorScheme),
            if (invoice.supplierHasQris) ...[
              AppSpacing.gapVerticalMD,
              Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              AppSpacing.gapVerticalMD,
            ],
          ],
          if (invoice.supplierHasQris)
            _buildQrisSection(theme)
          else if (!invoice.hasSupplierBankAccount)
            Text(
              'Supplier belum memiliki data QRIS / rekening bank. Lengkapi field QRIS di form supplier terlebih dahulu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
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
        AppSpacing.gapVerticalSM,
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
                    borderRadius: AppSpacing.borderRadiusMD,
                    child: Icon(Icons.copy_rounded,
                        size: 15, color: colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalSM,
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
          AppSpacing.gapVerticalSM,
          _buildInfoRow(
              'Merchant', _qrisData!['merchant_name']?.toString() ?? '-', theme),
          AppSpacing.gapVerticalSM,
          _buildInfoRow(
              'NMID', _qrisData!['merchant_nmid']?.toString() ?? '-', theme),
          AppSpacing.gapVerticalSM,
          _buildInfoRow(
              'Nominal QRIS',
              'Rp ${FormatUtils.formatNumber(_qrisData!['amount'])}',
              theme),
          AppSpacing.gapVerticalSM,
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
          AppSpacing.gapVerticalSM,
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

  /// Satu baris item pembelian (flat, tanpa kartu bersarang): nama produk,
  /// subtotal, chip qty & harga satuan, plus riwayat harga untuk admin.
  Widget _buildItemRow(
    DetailInvoiceItem item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final subtotal = FormatUtils.formatNumber(item.subtotalInvoice);
    final currentPrice = FormatUtils.formatNumber(item.unitPrice);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.productName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Rp $subtotal',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        AppSpacing.gapVerticalSM,
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _itemMetaChip(
              icon: Icons.inventory_2_outlined,
              label:
                  '${item.quantityProduct.toStringAsFixed(0)} ${item.unitName}',
              color: colorScheme.secondary,
            ),
            _itemMetaChip(
              icon: Icons.sell_outlined,
              label: 'Rp $currentPrice / ${item.unitName}',
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        if (_isAdmin && item.lastPurchasePrices.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: AppSpacing.borderRadiusSM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history,
                        size: 14, color: AppColors.info),
                    const SizedBox(width: 6),
                    Text(
                      'Harga beli sebelumnya',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...item.lastPurchasePrices.asMap().entries.map((entry) {
                  final lp = entry.value;
                  final price = FormatUtils.formatNumber(lp.unitPrice);
                  final date = lp.date != null
                      ? lp.date!.toLocal().toString().split(' ').first
                      : '-';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${entry.key + 1}. Rp $price/${item.unitName} • ${lp.supplierName ?? 'Supplier tidak diketahui'} • $date',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
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
        borderRadius: AppSpacing.borderRadiusSM,
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
