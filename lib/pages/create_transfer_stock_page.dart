import 'package:flutter/material.dart';

import '../models/store_model.dart';
import '../models/transfer_stock_model.dart';
import '../services/store_service.dart';
import '../services/transfer_stock_service.dart';
import '../services/user_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/safe_bottom_bar.dart';

class CreateTransferStockPage extends StatefulWidget {
  const CreateTransferStockPage({super.key});

  @override
  State<CreateTransferStockPage> createState() =>
      _CreateTransferStockPageState();
}

class _CreateTransferStockPageState extends State<CreateTransferStockPage> {
  final StoreService _storeService = StoreService();
  final TransferStockService _transferStockService = TransferStockService();
  final UserService _userService = UserService();
  final _notesController = TextEditingController();

  List<StoreModel> _stores = [];
  List<TransferStockProduct> _products = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingData = true;
  String? _errorMessage;

  StoreModel? _selectedFromStore;
  StoreModel? _selectedToStore;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _selectedSender;
  Map<String, dynamic>? _selectedReceiver;
  final List<Map<String, dynamic>> _items = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var item in _items) {
      (item['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _storeService.getStores(),
        _transferStockService.getProducts(),
        _userService.getUsers(role: 'staff'),
      ]);

      setState(() {
        _stores = results[0] as List<StoreModel>;
        _products = results[1] as List<TransferStockProduct>;
        _users = results[2] as List<Map<String, dynamic>>;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data awal: $e';
        _isLoadingData = false;
      });
    }
  }

  void _addItem() {
    if (_products.isEmpty) return;

    final controller = TextEditingController(text: '0');
    controller.addListener(() {
      final text = controller.text;
      if (text.startsWith('0') && text.length > 1) {
        controller.text = text.substring(1);
        controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length));
      }
    });

    setState(() {
      _items.add({
        'product_id': null,
        'productName': null,
        'unitName': null,
        'controller': controller,
      });
    });
  }

  void _removeItem(int index) {
    (_items[index]['controller'] as TextEditingController).dispose();
    setState(() {
      _items.removeAt(index);
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gagal Menyimpan',
            style: Theme.of(ctx)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(ctx).colorScheme.error)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitTransfer() async {
    if (_selectedFromStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih toko asal.')),
      );
      return;
    }
    if (_selectedToStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih toko tujuan.')),
      );
      return;
    }
    if (_selectedFromStore!.id == _selectedToStore!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toko asal dan tujuan tidak boleh sama.')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item produk.')),
      );
      return;
    }

    for (var item in _items) {
      if (item['product_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih produk untuk semua item.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final itemsApi = _items.map((item) {
        final ctrl = item['controller'] as TextEditingController;
        return {
          'product_id': item['product_id'],
          'quantity': double.tryParse(ctrl.text) ?? 0.0,
        };
      }).toList();

      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      await _transferStockService.createTransferStock(
        fromStoreId: _selectedFromStore!.id,
        toStoreId: _selectedToStore!.id,
        date: dateStr,
        items: itemsApi,
        sentById: _selectedSender?['id'],
        receivedById: _selectedReceiver?['id'],
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer stok berhasil diajukan.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      // extendBody tetap false: jika true, konten bawah form tertutup bar aksi
      // (bar sudah meng-handle system inset sendiri lewat SafeBottomBar).
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Text('Transfer Stok Baru'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!,
                            style: textTheme.bodyLarge
                                ?.copyWith(color: colorScheme.error)),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton(
                          onPressed: _loadInitialData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppBarInsets.top(context),
                    AppSpacing.md,
                    AppSpacing.md + context.systemBottomInset + 72,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormSectionCard(
                        title: 'Rute Transfer',
                        subtitle: 'Toko/gudang asal pengiriman dan tujuan',
                        icon: Icons.swap_horiz_rounded,
                        children: [
                          ModernDropdown<StoreModel>(
                            labelText: 'Toko Asal',
                            hint: 'Pilih toko asal...',
                            isRequired: true,
                            prefixIcon: const Icon(Icons.storefront, size: 20),
                            value: _selectedFromStore,
                            items: _stores
                                .where((s) =>
                                    _selectedToStore == null ||
                                    s.id != _selectedToStore!.id)
                                .toList(),
                            getLabel: (s) => s.nickname,
                            getSubtitle: (s) => '',
                            onChanged: (val) {
                              setState(() => _selectedFromStore = val);
                            },
                          ),
                          ModernDropdown<StoreModel>(
                            labelText: 'Toko Tujuan',
                            hint: 'Pilih toko tujuan...',
                            isRequired: true,
                            prefixIcon: const Icon(Icons.store, size: 20),
                            value: _selectedToStore,
                            items: _stores
                                .where((s) =>
                                    _selectedFromStore == null ||
                                    s.id != _selectedFromStore!.id)
                                .toList(),
                            getLabel: (s) => s.nickname,
                            getSubtitle: (s) => '',
                            onChanged: (val) {
                              setState(() => _selectedToStore = val);
                            },
                          ),
                        ],
                      ),
                      AppSpacing.gapVerticalMD,
                      FormSectionCard(
                        title: 'Waktu & Petugas',
                        subtitle: 'Tanggal mutasi stok serta staf penanggung jawab',
                        icon: Icons.schedule_rounded,
                        children: [
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: AppSpacing.borderRadiusMD,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Tanggal Transfer',
                                prefixIcon: const Icon(Icons.calendar_today, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: AppSpacing.borderRadiusMD,
                                  borderSide: BorderSide(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              child: Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          ModernDropdown<int>(
                            labelText: 'Staf Pengirim',
                            hint: 'Pilih pengirim...',
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            value: _selectedSender?['id'] is int
                                ? _selectedSender!['id']
                                : int.tryParse(_selectedSender?['id']?.toString() ?? ''),
                            items: _users
                                .map<int>((u) => u['id'] is int
                                    ? u['id']
                                    : int.parse(u['id'].toString()))
                                .toList(),
                            getLabel: (val) {
                              final u = _users.firstWhere(
                                  (e) => e['id'] == val,
                                  orElse: () => {});
                              return u['name']?.toString() ?? '';
                            },
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _selectedSender =
                                  _users.firstWhere((u) => u['id'] == val));
                            },
                          ),
                          ModernDropdown<int>(
                            labelText: 'Staf Penerima',
                            hint: 'Pilih penerima...',
                            prefixIcon: const Icon(Icons.person, size: 20),
                            value: _selectedReceiver?['id'] is int
                                ? _selectedReceiver!['id']
                                : int.tryParse(_selectedReceiver?['id']?.toString() ?? ''),
                            items: _users
                                .map<int>((u) => u['id'] is int
                                    ? u['id']
                                    : int.parse(u['id'].toString()))
                                .toList(),
                            getLabel: (val) {
                              final u = _users.firstWhere(
                                  (e) => e['id'] == val,
                                  orElse: () => {});
                              return u['name']?.toString() ?? '';
                            },
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _selectedReceiver =
                                  _users.firstWhere((u) => u['id'] == val));
                            },
                          ),
                        ],
                      ),
                      AppSpacing.gapVerticalMD,
                      FormSectionCard(
                        title: 'Item Produk Transfer',
                        subtitle: 'Daftar produk dan jumlah yang dipindahkan',
                        icon: Icons.inventory_2_outlined,
                        trailing: FormAddButton(
                          label: 'Tambah Item',
                          onPressed: _addItem,
                        ),
                        children: [
                          if (_items.isEmpty)
                            InkWell(
                              onTap: _addItem,
                              borderRadius: AppSpacing.borderRadiusMD,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                                  borderRadius: AppSpacing.borderRadiusMD,
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.add_shopping_cart_rounded,
                                        size: 32, color: colorScheme.primary),
                                    AppSpacing.gapVerticalXS,
                                    Text(
                                      'Belum ada item ditambahkan',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Ketuk untuk memilih produk yang akan ditransfer',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ..._items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return FormSectionCard(
                              title: item['productName'] ?? 'Item #${idx + 1}',
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: Colors.red),
                                onPressed: () => _removeItem(idx),
                              ),
                              children: [
                                ModernDropdown<int>(
                                  labelText: 'Produk',
                                  hint: 'Pilih produk...',
                                  value: item['product_id'] as int?,
                                  items: _products.map((p) => p.id).toList(),
                                  getLabel: (val) {
                                    final p = _products.firstWhere(
                                        (e) => e.id == val,
                                        orElse: () => TransferStockProduct(
                                            id: 0, name: '', unitName: ''));
                                    return p.name;
                                  },
                                  getSubtitle: (val) {
                                    final p = _products.firstWhere(
                                        (e) => e.id == val,
                                        orElse: () => TransferStockProduct(
                                            id: 0, name: '', unitName: ''));
                                    return p.unitName;
                                  },
                                  onChanged: (val) {
                                    if (val == null) return;
                                    final product = _products.firstWhere(
                                        (p) => p.id == val,
                                        orElse: () => TransferStockProduct(
                                            id: 0, name: '', unitName: ''));
                                    setState(() {
                                      item['product_id'] = val;
                                      item['productName'] = product.name;
                                      item['unitName'] = product.unitName;
                                    });
                                  },
                                ),
                                if (item['product_id'] != null)
                                  TextFormField(
                                    controller: item['controller'],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Kuantitas',
                                      suffixText: item['unitName'],
                                      border: OutlineInputBorder(
                                        borderRadius: AppSpacing.borderRadiusMD,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                    ),
                                    onTap: () {
                                      final ctrl = item['controller'] as TextEditingController;
                                      ctrl.selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset: ctrl.text.length);
                                    },
                                  ),
                              ],
                            );
                          }),
                        ],
                      ),
                      AppSpacing.gapVerticalMD,
                      FormSectionCard(
                        title: 'Catatan Tambahan',
                        icon: Icons.notes_rounded,
                        children: [
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: 'Catatan (opsional)',
                              hintText: 'Keterangan mutasi stok...',
                              border: OutlineInputBorder(
                                borderRadius: AppSpacing.borderRadiusMD,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeBottomBar(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ModernButton(
            text: 'Ajukan Transfer Stok',
            onPressed: _isSubmitting ? null : _submitTransfer,
            isLoading: _isSubmitting,
          ),
        ),
      ),
    );
  }
}
