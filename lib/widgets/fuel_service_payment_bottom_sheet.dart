import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/fuel_service_payment_provider.dart';
import '../services/image_service.dart';
import '../services/procurement_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/safe_bottom_bar.dart';
import 'app_snackbar.dart';

/// Bottom sheet untuk upload bukti transfer + catatan + submit
/// payment receipt bensin/servis.
///
/// Pakai FuelServicePaymentProvider untuk state (selected ids, image, notes).
/// Saat submit → call ProcurementService.createFuelServicePaymentReceipt.
class FuelServicePaymentBottomSheet extends StatefulWidget {
  const FuelServicePaymentBottomSheet({super.key});

  /// Tampilkan bottom sheet. Return true jika sukses submit.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FuelServicePaymentBottomSheet(),
    );
  }

  @override
  State<FuelServicePaymentBottomSheet> createState() =>
      _FuelServicePaymentBottomSheetState();
}

class _FuelServicePaymentBottomSheetState
    extends State<FuelServicePaymentBottomSheet> {
  final _procurementService = ProcurementService();
  final _notesController = TextEditingController();

  // QRIS state
  Map<String, dynamic>? _qrisData;
  bool _qrisLoading = false;
  String? _qrisError;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final photo = await ImageService.selectAndPickImage(context);
      if (photo != null && mounted) {
        context.read<FuelServicePaymentProvider>().setImageFile(photo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  Future<void> _loadQris() async {
    final supplier = context.read<FuelServicePaymentProvider>().supplier;
    if (supplier == null || _qrisLoading || _qrisData != null) return;

    setState(() {
      _qrisLoading = true;
      _qrisError = null;
    });

    try {
      final data = await _procurementService.getSupplierQrisDynamic(
        supplier.id,
        context.read<FuelServicePaymentProvider>().totalAmount,
      );
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

  Future<void> _submit() async {
    final provider = context.read<FuelServicePaymentProvider>();
    if (!provider.canSubmit) return;

    provider.setSubmitting(true);
    try {
      await _procurementService.createFuelServicePaymentReceipt(
        fuelServiceIds: provider.selectedFuelServiceIds,
        transferAmount: provider.totalAmount,
        notes: provider.notes.isNotEmpty ? provider.notes : null,
        image: provider.imageFile,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Payment receipt berhasil dibuat.',
        background: AppColors.success,
      );
      provider.clearSelection();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) provider.setSubmitting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = context.watch<FuelServicePaymentProvider>();
    final supplier = provider.supplier;
    final paddingBottom =
        MediaQuery.of(context).viewInsets.bottom + context.systemBottomInset;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: cs.surface.withValues(alpha: 0.85),
          child: Padding(
            padding: EdgeInsets.only(bottom: paddingBottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bukti Transfer Bensin/Servis',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${provider.selectedCount} item dipilih',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          FormatUtils.formatCurrency(provider.totalAmount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Supplier Section ──
                  if (supplier != null) ...[
                    _buildSupplierSection(theme, cs, supplier),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Tidak ada supplier tunggal (item bensin campur supplier
                    // / tanpa supplier) — pembayaran reimbursement ke rekening
                    // user pembuat item, bukan ke rekening supplier.
                    _buildReimbursementInfoSection(theme, cs, provider),
                    const SizedBox(height: 16),
                  ],

                  // Bukti transfer image
                  Text(
                    'Bukti Pembayaran (Opsional)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (provider.imageFile != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            provider.imageFile!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.6),
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 18, color: Colors.white),
                              onPressed: () => provider.setImageFile(null),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(
                        provider.imageFile == null
                            ? Icons.add_a_photo_rounded
                            : Icons.edit_rounded,
                        size: 18,
                      ),
                      label: Text(
                        provider.imageFile == null
                            ? 'Unggah Bukti Transfer'
                            : 'Ganti Foto Bukti',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (v) => provider.setNotes(v),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: provider.canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.gold,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMD),
                        ),
                      ),
                      child: provider.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            )
                          : Text(
                              'Buat Payment Receipt (${FormatUtils.formatCurrency(provider.totalAmount)})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu informasi untuk pembayaran tanpa supplier tunggal: item bensin
  /// yang dipilih berasal dari supplier berbeda / tanpa supplier, sehingga
  /// transfer difasilitasi ke rekening user pembuat item (reimbursement).
  /// Tidak ada QRIS/rekening supplier — user mengunggah bukti transfer manual.
  Widget _buildReimbursementInfoSection(
    ThemeData theme,
    ColorScheme cs,
    FuelServicePaymentProvider provider,
  ) {
    final supplierNames =
        provider.distinctSuppliers.map((s) => s.name).toList();
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.info,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pembayaran ke Rekening Pembuat',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              supplierNames.length > 1
                  ? 'Item bensin yang dipilih berasal dari ${supplierNames.length} supplier berbeda '
                      '(${supplierNames.join(', ')}). Transfer difasilitasi ke rekening '
                      'user pembuat item — unggah bukti transfer manual sebagai konfirmasi.'
                  : 'Item bensin yang dipilih dibayarkan ke rekening user pembuat item '
                      '(reimbursement) — unggah bukti transfer manual sebagai konfirmasi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSection(
    ThemeData theme,
    ColorScheme cs,
    SelectedSupplier supplier,
  ) {
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supplier header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.store,
                      color: AppColors.info, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Supplier',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow('Nama', supplier.name, theme),
            if (supplier.bankName != null) ...[
              const SizedBox(height: 6),
              _infoRow('Bank', supplier.bankName!, theme),
            ],
            if (supplier.bankAccountNo != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _infoRow('No. Rekening', supplier.bankAccountNo!, theme),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: supplier.bankAccountNo!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No. rekening disalin.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 16),
                  ),
                ],
              ),
            ],
            if (supplier.bankAccountName != null) ...[
              const SizedBox(height: 6),
              _infoRow('Atas Nama', supplier.bankAccountName!, theme),
            ],

            // Rekening & QRIS belum tersedia sama sekali — tetap lanjut,
            // user mengunggah bukti transfer manual.
            if (supplier.bankName == null &&
                supplier.bankAccountNo == null &&
                supplier.qris == null) ...[
              const SizedBox(height: 8),
              Text(
                'Rekening bank & QRIS belum tersedia untuk supplier ini. '
                'Lengkapi data supplier, atau lanjutkan dengan bukti transfer manual.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // QRIS section
            if (supplier.qris != null) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.qr_code_2_rounded,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'QRIS Supplier',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant,
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
                    size: 160,
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
                _infoRow(
                  'Nama Merchant',
                  _qrisData!['merchant_name']?.toString() ?? '-',
                  theme,
                ),
                const SizedBox(height: 4),
                _infoRow(
                  'NMID',
                  _qrisData!['merchant_nmid']?.toString() ?? '-',
                  theme,
                ),
                const SizedBox(height: 4),
                _infoRow(
                  'Nominal QRIS',
                  'Rp ${FormatUtils.formatNumber(_qrisData!['amount'])}',
                  theme,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _qrisData!['payload'] as String),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payload QRIS disalin.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
