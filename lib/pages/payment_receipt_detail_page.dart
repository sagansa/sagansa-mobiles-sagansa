import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/procurement_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/procurement_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/format_utils.dart';
import '../../widgets/app_bar_insets.dart';
import '../../widgets/ticket_card_container.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/glass_app_bar.dart';
import 'edit_payment_receipt_page.dart';

class PaymentReceiptDetailPage extends StatefulWidget {
  final int receiptId;

  const PaymentReceiptDetailPage({super.key, required this.receiptId});

  @override
  State<PaymentReceiptDetailPage> createState() =>
      _PaymentReceiptDetailPageState();
}

class _PaymentReceiptDetailPageState extends State<PaymentReceiptDetailPage> {
  final ProcurementService _procurementService = ProcurementService();
  final UserService _userService = UserService();
  PaymentReceipt? _receipt;
  bool _isLoading = true;
  String? _errorMessage;
  bool _qrisLoading = false;
  Map<String, dynamic>? _qrisData;
  String? _qrisError;
  bool _isStaff = false;
  bool _isAdmin = false;

  // Rekening pegawai penerima (receipt gaji harian) dari profil.
  Map<String, dynamic>? _employeeBank;
  bool _bankLoading = false;

  @override
  void initState() {
    super.initState();
    _isStaff = Provider.of<AuthProvider>(context, listen: false)
        .hasAnyRole(['staff', 'storage-staff']);
    _isAdmin = Provider.of<AuthProvider>(context, listen: false)
        .hasAnyRole(['admin', 'super_admin']);
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final receipt =
          await _procurementService.getPaymentReceiptDetail(widget.receiptId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _isLoading = false;
      });
      // Receipt gaji harian tidak memakai QRIS — transfer langsung ke
      // rekening pegawai penerima (diambil dari profil).
      if (_isAdmin && receipt.paymentFor == '2') {
        _loadEmployeeBank();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat detail: $e';
        _isLoading = false;
      });
    }
  }

  /// Hapus receipt gaji harian. Backend mengembalikan status semua daily
  /// salary ter-attach menjadi siap dibayar; pop(true) agar caller refresh.
  Future<void> _confirmDelete() async {
    final receipt = _receipt;
    if (receipt == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Payment Receipt'),
        content: const Text(
            'Yakin ingin menghapus payment receipt ini? Semua daily salary ter-attach akan dikembalikan menjadi "Siap Dibayar".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: AppButtonStyle.filled(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _procurementService.deletePaymentReceipt(receipt.id);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Payment receipt dihapus. Status gaji dikembalikan.',
        background: AppColors.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  String _formatAmount(int amount) {
    return FormatUtils.formatCurrency(amount);
  }

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '${ApiConstants.baseUrl}/media/$path';
  }

  Future<void> _shareImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('download failed');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/payment_receipt_${widget.receiptId}.jpg');
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Bukti Pembayaran Sagansa #${widget.receiptId}',
        ),
      );
    } catch (_) {
      if (mounted) {
        await SharePlus.instance.share(ShareParams(text: url));
      }
    }
  }

  void _showImageFullscreen(String url) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: GlassAppBar(
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.9),
            foregroundColor: colorScheme.surface,
            title: Text(
              'Bukti Pembayaran',
              style: TextStyle(color: colorScheme.surface),
            ),
            actions: [
              BarButtonCluster(actions: [
                BarButtonSpec(
                  icon: Icons.share_rounded,
                  tooltip: 'Bagikan',
                  onTap: () => _shareImage(url),
                ),
              ]),
            ],
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_rounded,
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

  Future<void> _loadQris() async {
    if (_qrisLoading || _qrisData != null) return;
    setState(() {
      _qrisLoading = true;
      _qrisError = null;
    });
    try {
      final data =
          await _procurementService.getPaymentReceiptQris(widget.receiptId);
      if (mounted) {
        setState(() {
          _qrisData = data;
          _qrisLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qrisLoading = false;
          _qrisError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// Ambil rekening pegawai penerima dari profil (DB recruitment).
  /// Penerima = created_by item gaji (satu karyawan per receipt).
  Future<void> _loadEmployeeBank() async {
    final userId = _receipt?.dailySalaries.firstOrNull?.createdById;
    if (userId == null) return;
    setState(() => _bankLoading = true);
    try {
      final data = await _userService.getAdminProfileByUser(userId);
      if (!mounted) return;
      setState(() {
        _employeeBank = data?['details'] as Map<String, dynamic>?;
        _bankLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _bankLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Detail Payment Receipt'),
        elevation: 0,
        actions: [
          BarButtonCluster(actions: [
            // Tombol Edit untuk admin (semua jenis payment receipt).
            if (_isAdmin && _receipt != null)
              BarButtonSpec(
                icon: Icons.edit_rounded,
                tooltip: 'Edit',
                onTap: () async {
                  final updated = await Navigator.push<PaymentReceipt>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditPaymentReceiptPage(receipt: _receipt!),
                    ),
                  );
                  if (updated != null && mounted) {
                    setState(() => _receipt = updated);
                  }
                },
              ),
            // Hapus (hanya receipt gaji harian) — status gaji dikembalikan.
            if (_isAdmin && _receipt?.paymentFor == '2')
              BarButtonSpec(
                icon: Icons.delete_rounded,
                tooltip: 'Hapus',
                onTap: _confirmDelete,
              ),
            if (_receipt?.image != null && _receipt!.image!.isNotEmpty)
              BarButtonSpec(
                icon: Icons.share_rounded,
                tooltip: 'Bagikan Bukti',
                onTap: () => _shareImage(_imageUrl(_receipt!.image)),
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
                            style: TextStyle(color: colorScheme.error),
                            textAlign: TextAlign.center),
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
                  child: RefreshIndicator(
                    onRefresh: _fetchDetail,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md)
                          .copyWith(top: AppBarInsets.top(context)),
                      child: Column(
                      children: [
                        // Ticket Receipt Main Header Container
                        _buildTicketHeader(theme, isDark),

                        // Bukti Pembayaran Image Section
                        if (_receipt!.image != null && _receipt!.image!.isNotEmpty)
                          _buildImageCard(theme, isDark),

                        // QRIS Section (bukan untuk receipt gaji harian —
                        // transfer gaji langsung ke rekening pegawai) dan
                        // hanya jika receipt punya supplier (QRIS tergantung
                        // ketersediaan data supplier).
                        if (!_isStaff &&
                            _receipt!.paymentFor != '2' &&
                            _receipt!.supplierId != null)
                          _buildQrisCard(theme, isDark),

                        // Catatan Card
                        if (_receipt!.notes != null &&
                            _receipt!.notes!.trim().isNotEmpty)
                          _buildNotesCard(theme, isDark),

                        // Fuel & Service Itemized List (payment_for == '1')
                        if (_receipt!.paymentFor == '1' &&
                            _receipt!.fuelServices.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_gas_station_outlined,
                                    size: 18, color: AppColors.secondary),
                                AppSpacing.gapHorizontalSM,
                                Text(
                                  'Item Bensin & Servis (${_receipt!.fuelServices.length})',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._receipt!.fuelServices.map(
                            (fs) => _buildFuelServiceCard(fs, theme, isDark),
                          ),
                        ],

                        // Daily Salary Itemized List (payment_for == '2')
                        if (_receipt!.paymentFor == '2' &&
                            _receipt!.dailySalaries.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payments_outlined,
                                    size: 18, color: AppColors.secondary),
                                AppSpacing.gapHorizontalSM,
                                Text(
                                  'Item Gaji Harian (${_receipt!.dailySalaries.length})',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._receipt!.dailySalaries.map(
                            (ds) => _buildDailySalaryCard(ds, theme, isDark),
                          ),

                          // Rekening pegawai penerima (admin only).
                          if (_receipt!.paymentFor == '2' && _isAdmin)
                            _buildEmployeeBankCard(theme, isDark),
                        ],

                        // Invoices Itemized List
                        if (_receipt!.invoicePurchases.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined,
                                    size: 18, color: AppColors.secondary),
                                AppSpacing.gapHorizontalSM,
                                Text(
                                  'Invoice Terkait (${_receipt!.invoicePurchases.length})',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._receipt!.invoicePurchases.map(
                            (inv) => _buildInvoiceCard(inv, theme, isDark),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildTicketHeader(ThemeData theme, bool isDark) {
    final formattedDate = _receipt!.createdAt.length >= 10
        ? _receipt!.createdAt.substring(0, 10)
        : _receipt!.createdAt;

    return TicketCardContainer(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          // Receipt Top Title & ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BUKTI PEMBAYARAN',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? AppColors.gold : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#REC-${_receipt!.id}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusXL,
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: AppColors.success),
                    AppSpacing.gapHorizontalXS,
                    Text(
                      'Terdata',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const DashedDivider(),
          const SizedBox(height: AppSpacing.md),

          // Nominal Transfer Highlight
          Text(
            'TOTAL TRANSFER',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapVerticalXS,
          Text(
            _formatAmount(_receipt!.transferAmount),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.gold : AppColors.primary,
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          const DashedDivider(),
          const SizedBox(height: AppSpacing.md),

          // Details List
          if (_receipt!.supplierName != null &&
              _receipt!.supplierName!.isNotEmpty)
            _ticketInfoRow('Supplier', _receipt!.supplierName!, theme),
          _ticketInfoRow(
            'Jenis Pembayaran',
            _receipt!.paymentFor == '1'
                ? 'Fuel Service'
                : _receipt!.paymentFor == '2'
                    ? 'Gaji Harian'
                    : 'Invoice Supplier',
            theme,
          ),
          _ticketInfoRow('Tanggal Buat', formattedDate, theme),
          if (_receipt!.totalAmount > 0)
            _ticketInfoRow(
              'Total Tagihan Invoice',
              _formatAmount(_receipt!.totalAmount),
              theme,
            ),
        ],
      ),
    );
  }

  Widget _ticketInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(ThemeData theme, bool isDark) {
    final url = _imageUrl(_receipt!.image);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.secondaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined,
                  size: 20, color: AppColors.info),
              AppSpacing.gapHorizontalSM,
              Text(
                'Bukti Transfer Gambar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DetailImageView(
            imageUrl: url,
            // Viewer custom dipertahankan karena punya tombol bagikan.
            onTap: () => _showImageFullscreen(url),
          ),
        ],
      ),
    );
  }

  Widget _buildQrisCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.secondaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  size: 20, color: AppColors.gold),
              AppSpacing.gapHorizontalSM,
              Text(
                'QRIS Validasi',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.sm),
            _qrRow('Merchant', _qrisData!['merchant_name'] as String?, theme),
            _qrRow('NMID', _qrisData!['merchant_nmid']?.toString(), theme),
            _qrRow(
                'Nominal QRIS',
                _formatAmount(_qrisData!['amount'] as int),
                theme),
            AppSpacing.gapVerticalSM,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: _qrisData!['payload'] as String,
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payload QRIS disalin')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Salin Payload QRIS'),
              ),
            ),
          ] else if (_qrisLoading) ...[
            const Center(
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (_qrisError != null) ...[
            Text(
              _qrisError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
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
      ),
    );
  }

  /// Kartu rekening pegawai penerima receipt gaji harian — pengganti QRIS:
  /// transfer gaji langsung ke rekening yang diambil dari profil pegawai.
  Widget _buildEmployeeBankCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.secondaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  size: 20, color: AppColors.gold),
              AppSpacing.gapHorizontalSM,
              Text(
                'Rekening Pegawai',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_bankLoading)
            const Center(
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: CircularProgressIndicator(),
              ),
            )
          else if (_employeeBank != null) ...[
            _qrRow('Bank', _employeeBank!['bank_name']?.toString(), theme),
            _qrRow('No. Rekening',
                _employeeBank!['bank_account_number']?.toString(), theme),
            _qrRow('Atas Nama',
                _employeeBank!['bank_account_name']?.toString(), theme),
            AppSpacing.gapVerticalSM,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final accountNumber =
                      _employeeBank!['bank_account_number']?.toString();
                  if (accountNumber == null || accountNumber.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: accountNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nomor rekening disalin')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Salin No. Rekening'),
              ),
            ),
          ] else ...[
            Text(
              'Rekening pegawai belum tersedia di profil.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            AppSpacing.gapVerticalSM,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadEmployeeBank,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qrRow(String label, String? val, ThemeData theme) {
    if (val == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(val,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNotesCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.secondaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded,
                  size: 18, color: AppColors.secondary),
              AppSpacing.gapHorizontalSM,
              Text(
                'Catatan Pembayaran',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            FormatUtils.stripHtml(_receipt!.notes!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelServiceCard(
      FuelServiceItem fs, ThemeData theme, bool isDark) {
    final isFuel = fs.fuelService == 1;
    final typeColor = isFuel ? AppColors.success : AppColors.warning;
    final vehicle = fs.vehicleRegister ?? 'Kendaraan';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.secondaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.borderRadiusSM,
                      ),
                      child: Text(
                        fs.typeLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '$vehicle (KM: ${fs.km})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatAmount(fs.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Tgl: ${fs.date}'
            '${fs.supplierName != null && fs.supplierName!.isNotEmpty ? ' | Supplier: ${fs.supplierName}' : ''}'
            '${fs.createdByName != null && fs.createdByName!.isNotEmpty ? ' | Oleh: ${fs.createdByName}' : ''}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySalaryCard(
      DailySalaryReceiptItem ds, ThemeData theme, bool isDark) {
    final employeeName =
        ds.createdByName != null && ds.createdByName!.isNotEmpty
            ? ds.createdByName!
            : 'Gaji Harian';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.secondaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  employeeName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatAmount(ds.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Tgl: ${ds.date}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(
      InvoicePurchase inv, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.secondaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  inv.storeName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatAmount(inv.totalPrice),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Tgl: ${inv.date}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (inv.detailInvoices.isNotEmpty) ...[
            AppSpacing.gapVerticalSM,
            const Divider(height: 1),
            AppSpacing.gapVerticalSM,
            // Header row untuk tabel item
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Produk',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Subtotal',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...inv.detailInvoices.map(
                  (item) {
                    final unitPrice = item.unitPrice;
                    final priceStr = unitPrice
                        .toStringAsFixed(0)
                        .replaceAllMapped(
                            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.');
                    final subtotalStr = item.subtotalInvoice
                        .toStringAsFixed(0)
                        .replaceAllMapped(
                            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '${item.quantityProduct.toStringAsFixed(0)} ${item.unitName}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Rp $subtotalStr',
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Rp $priceStr /${item.unitName}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ],
        ],
      ),
    );
  }
}
