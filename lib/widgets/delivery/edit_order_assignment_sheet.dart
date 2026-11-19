import 'package:flutter/material.dart';

import '../../models/store_model.dart';
import '../../providers/delivery_provider.dart';
import '../../services/store_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/status_mappers.dart';
import '../../widgets/modern_dropdown.dart';
import '../app_snackbar.dart';
import '../safe_bottom_bar.dart';

/// Bottom sheet untuk admin menetapkan status bayar &/atau toko pada order
/// direct (for=1) yang dibuat tanpa store. Menggantikan alur lama "hubungi
/// admin backend" dari mobile.
class EditOrderAssignmentSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final DeliveryProvider provider;

  const EditOrderAssignmentSheet({
    super.key,
    required this.order,
    required this.provider,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> order,
    required DeliveryProvider provider,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          EditOrderAssignmentSheet(order: order, provider: provider),
    );
  }

  @override
  State<EditOrderAssignmentSheet> createState() =>
      _EditOrderAssignmentSheetState();
}

class _EditOrderAssignmentSheetState extends State<EditOrderAssignmentSheet> {
  final StoreService _storeService = StoreService();

  List<StoreModel> _stores = [];
  bool _isLoadingStores = true;
  String? _loadError;
  String? _paymentStatus;
  StoreModel? _store;
  bool _isSaving = false;

  String? get _currentPaymentStatus =>
      widget.order['payment_status']?.toString();
  int? get _currentStoreId => widget.order['store_id'] as int?;

  @override
  void initState() {
    super.initState();
    _paymentStatus = _currentPaymentStatus;
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoadingStores = true;
      _loadError = null;
    });
    try {
      final stores = await _storeService.getStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _isLoadingStores = false;
        _store = _stores
            .where((s) => s.id == _currentStoreId)
            .firstOrNull;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStores = false;
        _loadError = 'Gagal memuat daftar toko: $e';
      });
    }
  }

  bool get _hasChanges {
    final paymentChanged =
        _paymentStatus != _currentPaymentStatus;
    final storeChanged = _store?.id != _currentStoreId;
    return paymentChanged || storeChanged;
  }

  String get _changesSummary {
    final changes = <String>[];
    if (_paymentStatus != _currentPaymentStatus) {
      changes.add(
        'Status Bayar: ${StatusMappers.paymentLabel(_currentPaymentStatus)} → '
        '${StatusMappers.paymentLabel(_paymentStatus)}',
      );
    }
    if (_store?.id != _currentStoreId) {
      changes.add(
        'Toko: ${widget.order['store_name']?.toString() ?? '-'} → '
        '${_store?.nickname ?? '-'}',
      );
    }
    return changes.join('\n');
  }

  Future<void> _save() async {
    final orderId = int.tryParse(widget.order['id'].toString());
    if (orderId == null) {
      _showSnack('ID order tidak tersedia.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apakah yakin?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anda akan mengubah penetapan order ini:'),
            AppSpacing.gapVerticalSM,
            Text(_changesSummary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await widget.provider.updateAssignment(
        orderId: orderId,
        paymentStatus: _paymentStatus,
        storeId: _store?.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnackBar(
        context,
        'Toko & status bayar berhasil diperbarui.',
        background: AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSnack(String message) {
    showAppSnackBar(context, message, background: AppColors.error);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom +
        context.systemBottomInset;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Padding(
            padding: AppSpacing.paddingMD,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: colorScheme.primary, size: 20),
                    AppSpacing.gapHorizontalSM,
                    Expanded(
                      child: Text(
                        'Tetapkan Toko & Status Bayar • Order #${widget.order['id']}',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ModernDropdown<String>(
                        value: _paymentStatus,
                        hint: 'Pilih status bayar',
                        labelText: 'Status Bayar',
                        items: const ['1', '2', '3', '4'],
                        getLabel: StatusMappers.paymentLabel,
                        onChanged: (value) =>
                            setState(() => _paymentStatus = value),
                      ),
                      AppSpacing.gapVerticalMD,
                      if (_isLoadingStores)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_loadError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              Text(_loadError!,
                                  style: textTheme.bodySmall
                                      ?.copyWith(color: colorScheme.error)),
                              AppSpacing.gapVerticalSM,
                              OutlinedButton.icon(
                                onPressed: _loadStores,
                                icon:
                                    const Icon(Icons.refresh, size: 18),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      else
                        ModernDropdown<StoreModel>(
                          value: _store,
                          hint: 'Pilih toko (opsional)',
                          labelText: 'Toko',
                          items: _stores,
                          getLabel: (store) => store.nickname,
                          searchable: true,
                          onChanged: (value) =>
                              setState(() => _store = value),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                FilledButton.icon(
                  onPressed: (_isSaving || !_hasChanges) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Simpan'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}