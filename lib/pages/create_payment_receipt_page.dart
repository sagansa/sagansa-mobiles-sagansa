import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import '../models/procurement_model.dart';
import '../services/closing_store_service.dart';
import '../services/image_service.dart';
import '../services/procurement_service.dart';
import '../services/supplier_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/supplier_payment_info_card.dart';
import '../widgets/supplier_picker_modal.dart';

/// Halaman buat Payment Receipt.
///
/// Mendukung 2 mode:
///  - Invoice procurement (default): user pilih supplier → pilih invoice.
///  - Daily Salary: menggunakan [dailySalaries] yang sudah dipilih dari
///    DailySalaryListPage (payment_for = 2), total auto-computed.
class CreatePaymentReceiptPage extends StatefulWidget {
  /// Pre-loaded invoices (dipakai saat user tap "Bayar" dari card invoice
  /// atau dari batch mode di workflow page). Bisa 1 atau banyak.
  final List<InvoicePurchase>? invoices;

  /// Pre-loaded daily salary (dipakai dari DailySalaryListPage). Payment
  /// receipt akan dibuat dengan payment_for = 2.
  final List<Map<String, dynamic>>? dailySalaries;

  const CreatePaymentReceiptPage(
      {super.key, this.invoices, this.dailySalaries});

  @override
  State<CreatePaymentReceiptPage> createState() =>
      _CreatePaymentReceiptPageState();
}

class _CreatePaymentReceiptPageState extends State<CreatePaymentReceiptPage> {
  final ClosingStoreService _service = ClosingStoreService();
  final ProcurementService _procurementService = ProcurementService();
  final SupplierService _supplierService = SupplierService();
  final _formKey = GlobalKey<FormState>();
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _notesController = TextEditingController();
  final _transferAmountController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingInvoices = false;
  String? _errorMessage;

  /// Mode daily salary = true kalau page dibuka dari DailySalaryListPage.
  late final bool _isDailySalaryMode;

  // Supplier state
  int? _selectedSupplierId;
  String _selectedSupplierName = '';
  Map<String, dynamic>? _selectedSupplier;

  // Invoice state — list invoice yang akan dibayar (bisa banyak).
  List<InvoicePurchase> _selectedInvoices = [];

  // Daily salary state — list daily salary yang akan dibayar (bisa banyak).
  List<Map<String, dynamic>> _selectedDailySalaries = [];

  // Image
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _isDailySalaryMode =
        widget.dailySalaries != null && widget.dailySalaries!.isNotEmpty;

    // Rebuild kartu QRIS supplier saat nominal transfer berubah
    // (QRIS dinamis menyisipkan nominal).
    _transferAmountController.addListener(() {
      if (mounted) setState(() {});
    });

    if (_isDailySalaryMode) {
      _selectedDailySalaries = List.from(widget.dailySalaries!);
      _recalculateTotal();
    } else if (widget.invoices != null && widget.invoices!.isNotEmpty) {
      _selectedInvoices = List.from(widget.invoices!);
      // Ambil supplier dari invoice pertama (semua invoice harus 1 supplier).
      _selectedSupplierId = _selectedInvoices.first.supplierId;
      _selectedSupplierName = _selectedInvoices.first.supplierName ?? '';
      _loadSupplierDetail();
      _recalculateTotal();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _transferAmountController.dispose();
    super.dispose();
  }

  /// Load detail supplier (untuk rekening/QRIS) berdasarkan _selectedSupplierId.
  Future<void> _loadSupplierDetail() async {
    if (_selectedSupplierId == null) return;
    try {
      final list = await _supplierService.getSuppliers();
      final match = list.where((s) => s.id == _selectedSupplierId).firstOrNull;
      if (!mounted) return;
      if (match == null) {
        setState(() {
          _selectedSupplier = null;
          _selectedSupplierName = 'Supplier tidak ditemukan';
        });
        return;
      }
      setState(() {
        _selectedSupplier = {
          'id': match.id,
          'name': match.name,
          'address': match.address,
          'no_telp': match.noTelp,
          'bank_name': match.bankName,
          'bank_account_name': match.bankAccountName,
          'bank_account_no': match.bankAccountNo,
          'qris': match.qris,
        };
        _selectedSupplierName = match.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedSupplier = null;
        _selectedSupplierName = 'Gagal memuat data supplier';
      });
    }
  }

  /// Hitung ulang total nominal dari invoice/daily salary yang dipilih.
  void _recalculateTotal() {
    final total = _isDailySalaryMode
        ? _selectedDailySalaries.fold<int>(0, (sum, s) {
            final amount = double.tryParse(s['amount'].toString()) ?? 0;
            return sum + amount.toInt();
          })
        : _selectedInvoices.fold<int>(0, (sum, inv) => sum + inv.totalPrice);
    _transferAmountController.text = total.toString();
    setState(() {});
  }

  Future<void> _pickSupplier() async {
    List<dynamic> suppliers;
    try {
      final list = await _supplierService.getSuppliers();
      suppliers = list
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'address': s.address,
                'no_telp': s.noTelp,
                'bank_name': s.bankName,
                'bank_account_name': s.bankAccountName,
                'bank_account_no': s.bankAccountNo,
                'qris': s.qris,
              })
          .toList();
    } catch (_) {
      suppliers = [];
    }

    if (suppliers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada supplier tersedia.')),
      );
      return;
    }

    if (!mounted) return;
    final result = await SupplierPickerModal.show(
      context: context,
      suppliers: suppliers,
      selectedSupplierId: _selectedSupplierId,
    );
    if (result != null) {
      setState(() {
        _selectedSupplierId = result['id'];
        _selectedSupplierName = result['name'];
        _selectedSupplier = result;
        // Reset invoice selection kalau supplier ganti (invoice harus 1 supplier).
        _selectedInvoices = [];
      });
      _recalculateTotal();
    }
  }

  /// Bottom sheet yang menampilkan semua invoice siap bayar (unpaid) dari
  /// supplier yang dipilih. User bisa pilih beberapa.
  Future<void> _pickInvoices() async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih supplier terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isLoadingInvoices = true);
    try {
      // Fetch unpaid invoices (payment_status='1') lalu filter by supplier.
      final result = await _procurementService.getInvoices(
        paymentStatus: '1',
        perPage: 100,
      );
      final allUnpaid = result.items
          .where((inv) => inv.supplierId == _selectedSupplierId)
          .toList();

      if (!mounted) return;
      if (allUnpaid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tidak ada invoice siap bayar dari supplier ini.')),
        );
        return;
      }

      // Copy current selection supaya bisa toggle di sheet.
      final tempSelection = Map<int, InvoicePurchase>.fromEntries(
        _selectedInvoices.map((inv) => MapEntry(inv.id, inv)),
      );
      for (final inv in allUnpaid) {
        tempSelection.putIfAbsent(inv.id, () => inv);
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                // + inset sistem bawah (home indicator / gesture bar).
                padding: EdgeInsets.only(
                  left: 20,
                  top: 20,
                  right: 20,
                  bottom: 20 + ctx.systemBottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pilih Invoice',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Supplier: $_selectedSupplierName • ${allUnpaid.length} invoice siap bayar',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              final allSelected = tempSelection.values
                                      .where((inv) =>
                                          allUnpaid.any((u) => u.id == inv.id))
                                      .length >=
                                  allUnpaid.length;
                              if (allSelected) {
                                // Unset semua dari allUnpaid.
                                for (final inv in allUnpaid) {
                                  // Hanya hapus kalau bukan dari pre-loaded.
                                  final isPreloaded = widget.invoices
                                          ?.any((pre) => pre.id == inv.id) ??
                                      false;
                                  if (!isPreloaded) {
                                    tempSelection.remove(inv.id);
                                  }
                                }
                              } else {
                                for (final inv in allUnpaid) {
                                  tempSelection[inv.id] = inv;
                                }
                              }
                            });
                          },
                          child: Text(
                            tempSelection.values
                                        .where((inv) => allUnpaid
                                            .any((u) => u.id == inv.id))
                                        .length >=
                                    allUnpaid.length
                                ? 'Batal Semua'
                                : 'Pilih Semua',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allUnpaid.length,
                        itemBuilder: (ctx, i) {
                          final inv = allUnpaid[i];
                          final isSelected = tempSelection.containsKey(inv.id);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isSelected,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  tempSelection[inv.id] = inv;
                                } else {
                                  tempSelection.remove(inv.id);
                                }
                              });
                            },
                            title: Text(
                              'Invoice #${inv.id}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${inv.storeName} • ${currencyFormatter.format(inv.totalPrice)}',
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Filter hanya invoice dari supplier ini yang dipilih.
                          final selected = tempSelection.values
                              .where((inv) =>
                                  inv.supplierId == _selectedSupplierId &&
                                  tempSelection.containsKey(inv.id))
                              .toList();
                          Navigator.pop(ctx, selected);
                        },
                        icon: const Icon(Icons.check),
                        label: Text(
                          'Pilih ${tempSelection.length} Invoice',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ).then((result) {
        if (result is List<InvoicePurchase>) {
          setState(() {
            _selectedInvoices = result;
          });
          _recalculateTotal();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat invoice: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  void _removeInvoice(int id) {
    setState(() {
      _selectedInvoices.removeWhere((inv) => inv.id == id);
    });
    _recalculateTotal();
  }

  void _removeDailySalary(int id) {
    setState(() {
      _selectedDailySalaries.removeWhere((s) => s['id'] == id);
    });
    _recalculateTotal();
  }

  Future<void> _pickImage() async {
    try {
      final photo = await ImageService.selectAndPickImage(context);
      if (photo != null && mounted) {
        setState(() => _selectedImage = photo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isDailySalaryMode) {
      if (_selectedDailySalaries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih minimal 1 daily salary.')),
        );
        return;
      }
    } else if (_selectedInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 invoice.')),
      );
      return;
    }

    final transferAmount = int.tryParse(_transferAmountController.text) ?? 0;
    if (transferAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah transfer harus lebih dari 0.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final data = <String, dynamic>{
        'payment_for': _isDailySalaryMode ? 2 : 3,
        'transfer_amount': transferAmount,
      };

      if (_isDailySalaryMode) {
        data['daily_salary_ids'] =
            _selectedDailySalaries.map((s) => s['id']).toList();
      } else {
        data['invoice_ids'] = _selectedInvoices.map((inv) => inv.id).toList();
        if (_selectedSupplierId != null) {
          data['supplier_id'] = _selectedSupplierId;
        }
      }

      if (_notesController.text.isNotEmpty) {
        data['notes'] = _notesController.text;
      }

      await _service.createPaymentReceipt(data, imageFile: _selectedImage);

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Payment receipt berhasil dibuat.',
        background: AppColors.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      showAppSnackBar(
        context,
        e.toString().replaceAll('Exception: ', ''),
        background: cs.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final totalNominal = int.tryParse(_transferAmountController.text) ?? 0;

    return Scaffold(
      // extendBody tetap false: jika true, konten bawah form tertutup bar aksi
      // (bar sudah meng-handle system inset sendiri lewat SafeBottomBar).
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(_isDailySalaryMode
            ? 'Buat Payment Receipt Gaji'
            : 'Buat Payment Receipt'),
        elevation: 0,
      ),
      body: _errorMessage != null
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
                        style: TextStyle(color: colorScheme.error)),
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.paddingMD
                    .copyWith(top: AppBarInsets.top(context)),
                children: [
                  if (_isDailySalaryMode)
                    _buildDailySalarySection(isDark, theme)
                  else ...[
                    // === Supplier Picker ===
                    _sectionContainer(
                      isDark: isDark,
                      theme: theme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supplier',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          AppSpacing.gapVerticalSM,
                          InkWell(
                            onTap: _pickSupplier,
                            borderRadius: AppSpacing.borderRadiusSM,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Pilih Supplier *',
                                suffixIcon: Icon(Icons.search),
                                isDense: true,
                              ),
                              child: Text(
                                _selectedSupplierName,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _selectedSupplierName.isEmpty
                                      ? colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          if (_selectedSupplier != null) ...[
                            AppSpacing.gapVerticalSM,
                            SupplierPaymentInfoCard(
                              selectedSupplier: _selectedSupplier,
                              // QRIS dinamis: nominal ikut total transfer.
                              amount:
                                  int.tryParse(_transferAmountController.text),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AppSpacing.gapVerticalMD,

                    // === Invoices Picker ===
                    _sectionContainer(
                      isDark: isDark,
                      theme: theme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Invoice Terpilih (${_selectedInvoices.length})',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              FormAddButton(
                                label: 'Pilih Invoice',
                                onPressed:
                                    _isLoadingInvoices ? null : _pickInvoices,
                                isLoading: _isLoadingInvoices,
                              ),
                            ],
                          ),
                          if (_selectedInvoices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _selectedSupplierId == null
                                    ? 'Pilih supplier dulu untuk menampilkan invoice.'
                                    : 'Belum ada invoice dipilih. Tap "Pilih Invoice".',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            )
                          else ...[
                            AppSpacing.gapVerticalSM,
                            ..._selectedInvoices.map((inv) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Invoice #${inv.id} • ${inv.storeName}',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            currencyFormatter
                                                .format(inv.totalPrice),
                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                              color: isDark
                                                  ? AppColors.gold
                                                  : AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => _removeInvoice(inv.id),
                                      tooltip: 'Hapus',
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                  AppSpacing.gapVerticalMD,

                  // === Detail Transfer & Notes & Bukti ===
                  _sectionContainer(
                    isDark: isDark,
                    theme: theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Transfer & Catatan',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        AppSpacing.gapVerticalMD,
                        // Total Transfer Highlight
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.secondaryContainer
                                    .withValues(alpha: 0.3),
                            borderRadius:
                                AppSpacing.borderRadiusSM,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Transfer:',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                FormatUtils.formatCurrency(totalNominal),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.gold
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapVerticalMD,
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Catatan / Deskripsi',
                            hintText: 'Masukkan catatan bukti transfer...',
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                        AppSpacing.gapVerticalMD,

                        // Bukti Pembayaran label
                        Text(
                          'Bukti Pembayaran (Opsional)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_selectedImage != null) ...[
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    AppSpacing.borderRadiusMD,
                                child: kIsWeb
                                    ? Image.network(
                                        _selectedImage!.path,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        _selectedImage!,
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
                                    tooltip: 'Hapus',
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18, color: Colors.white),
                                    onPressed: () =>
                                        setState(() => _selectedImage = null),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapVerticalSM,
                        ],
                        // Tombol Bukti Transfer → full width seperti Submit.
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: Icon(
                              _selectedImage == null
                                  ? Icons.add_a_photo_rounded
                                  : Icons.edit_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _selectedImage == null
                                  ? 'Unggah Bukti Transfer'
                                  : 'Ganti Foto Bukti',
                            ),
                            style: AppButtonStyle.outlined(
                              foregroundColor:
                                  isDark ? AppColors.gold : AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      // Tombol submit dipatok di bawah (tidak ikut scroll) — pola standar
      // SafeBottomBar + ModernButton seperti halaman create lainnya.
      bottomNavigationBar: _errorMessage != null
          ? null
          : SafeBottomBar(
              child: ModernButton(
                text: 'Buat Payment Receipt',
                onPressed: _isSubmitting ? null : _submit,
                isLoading: _isSubmitting,
              ),
            ),
    );
  }

  /// Section khusus daily salary: menampilkan list daily salary terpilih
  /// (dari DailySalaryListPage) tanpa perlu pilih supplier/invoice.
  Widget _buildDailySalarySection(bool isDark, ThemeData theme) {
    return _sectionContainer(
      isDark: isDark,
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Salary Terpilih (${_selectedDailySalaries.length})',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapVerticalSM,
          if (_selectedDailySalaries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada daily salary dipilih.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            ..._selectedDailySalaries.map((s) {
              final employeeName = s['created_by']?['name'] ?? 'Staff';
              final storeName =
                  s['store']?['nickname'] ?? s['store']?['name'] ?? '-';
              final date = s['date'] ?? '';
              final amount = double.tryParse(s['amount'].toString()) ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$employeeName • $storeName',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$date • ${currencyFormatter.format(amount)}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color:
                                  isDark ? AppColors.gold : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeDailySalary(s['id']),
                      tooltip: 'Hapus',
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Container berisi section dengan border + padding konsisten.
  Widget _sectionContainer({
    required bool isDark,
    required ThemeData theme,
    required Widget child,
  }) {
    return Container(
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
      child: child,
    );
  }
}
