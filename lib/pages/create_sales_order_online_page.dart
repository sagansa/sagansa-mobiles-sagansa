import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../models/import_model.dart';
import '../models/sales_order_online_model.dart';
import '../models/store_model.dart';
import '../services/image_service.dart';
import '../services/import_service.dart';
import '../services/sales_order_service.dart';
import '../services/store_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/mete_pricing.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/forms/form_image_tile.dart';
import '../widgets/forms/form_item_card.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_date_field.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/modern_text_form_field.dart';

class CreateSalesOrderOnlinePage extends StatefulWidget {
  const CreateSalesOrderOnlinePage({
    super.key,
    this.storeService,
    this.salesOrderService,
  });

  /// Seam untuk test — null → instance default.
  final StoreService? storeService;
  final SalesOrderService? salesOrderService;

  @override
  State<CreateSalesOrderOnlinePage> createState() =>
      _CreateSalesOrderOnlinePageState();
}

class _CreateSalesOrderOnlinePageState
    extends State<CreateSalesOrderOnlinePage> {
  late final StoreService _storeService;
  late final SalesOrderService _salesOrderService;

  /// Idempotency key per sesi form: dibuat SEKALI dan dipakai ulang di
  /// setiap percobaan submit (termasuk retry setelah timeout & konfirmasi
  /// resi duplikat) — backend mengenali retry dan mengembalikan order
  /// existing alih-alih membuat double order.
  late final String _idempotencyKey;

  final TextEditingController _receiptNoController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<StoreModel> _stores = [];
  List<SalesOrderOnlineProduct> _products = [];
  List<OnlineShopProvider> _providers = [];
  List<DeliveryServiceOption> _deliveryServices = [];

  StoreModel? _selectedStore;
  OnlineShopProvider? _selectedProvider;
  DeliveryServiceOption? _selectedDeliveryService;
  DateTime _selectedDate = DateTime.now();
  File? _imageResi;

  /// HPP pembelian impor terbaru per grade (base name) — dasar info harga
  /// jual mete pada pilihan produk. Fase informasi: tidak tersimpan.
  final Map<String, double> _hppByBase = {};

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  /// Baris item: setiap map berisi produk terpilih, controller quantity, dan
  /// controller unit price. Subtotal dihitung dinamis.
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _storeService = widget.storeService ?? StoreService();
    _salesOrderService = widget.salesOrderService ?? SalesOrderService();
    _idempotencyKey = const Uuid().v4();
    _loadInitialData();
  }

  @override
  void dispose() {
    _receiptNoController.dispose();
    for (final item in _items) {
      (item['qtyController'] as TextEditingController).dispose();
      (item['priceController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _storeService.getStores(),
        _salesOrderService.getOnlineProducts(),
        _salesOrderService.getOnlineShopProviders(),
        _salesOrderService.getDeliveryServices(),
      ]);

      if (!mounted) return;
      setState(() {
        _stores = results[0] as List<StoreModel>;
        _products = results[1] as List<SalesOrderOnlineProduct>;
        _providers = results[2] as List<OnlineShopProvider>;
        _deliveryServices = results[3] as List<DeliveryServiceOption>;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data: $e';
        _isLoadingData = false;
      });
    }

    // Info harga jual dari trend impor — kegagalan memuatnya tidak boleh
    // menghalangi form Penjualan.
    unawaited(_loadSellingPriceInfo());
  }

  /// Titik trend mana yang lebih baru: tanggal belakang menang; tanggal
  /// sama → yang sudah terealisasi menang.
  bool _isLaterPoint(ImportPriceTrendPoint a, ImportPriceTrendPoint b) {
    final ad = a.date ?? DateTime(1900);
    final bd = b.date ?? DateTime(1900);
    if (ad.isAtSameMomentAs(bd)) return a.isRealized && !b.isRealized;
    return ad.isAfter(bd);
  }

  Future<void> _loadSellingPriceInfo() async {
    try {
      // Persentase harga (bisa dioverride per produk) + trend HPP impor.
      await MetePricingStore.instance.load();
      final trends = await ImportService().getPriceTrends();
      if (!mounted) return;

      final bestByBase = <String, ImportPriceTrendPoint>{};
      for (final trend in trends) {
        for (final point in trend.points) {
          if (point.unitPriceIdr <= 0) continue;
          final base = meteBaseName(trend.productName);
          final prev = bestByBase[base];
          if (prev == null || _isLaterPoint(point, prev)) {
            bestByBase[base] = point;
          }
        }
      }

      setState(() {
        _hppByBase
          ..clear()
          ..addAll({
            for (final e in bestByBase.entries) e.key: e.value.unitPriceIdr,
          });
      });
    } catch (_) {
      // Info harga bersifat pelengkap — biarkan subtitle produk tanpa harga.
    }
  }

  /// Subtitle produk Penjualan: satuan + harga jual info (konfigurasi mete
  /// per grade atas HPP impor terbaru) bila tersedia.
  String _productSubtitle(SalesOrderOnlineProduct p) {
    final base = meteBaseName(p.name);
    final hpp = _hppByBase[base] ?? 0;
    final config = MetePricingStore.instance.configFor(base);
    final price = hpp > 0 ? meteInfoPrice(hpp, p.name, config) : 0;
    if (price <= 0) return p.unit;
    return '${p.unit} • Rp ${FormatUtils.formatAmount(price.round())}/unit';
  }

  void _addItem() {
    setState(() {
      _items.add({
        'product': null as SalesOrderOnlineProduct?,
        'qtyController': TextEditingController(text: '1'),
        'priceController': TextEditingController(text: '0'),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      final item = _items.removeAt(index);
      (item['qtyController'] as TextEditingController).dispose();
      (item['priceController'] as TextEditingController).dispose();
    });
  }

  int get _totalPrice {
    var total = 0;
    for (final item in _items) {
      final qty =
          int.tryParse((item['qtyController'] as TextEditingController).text) ??
              0;
      final price = parseAmountInt(
          (item['priceController'] as TextEditingController).text);
      total += qty * price;
    }
    return total;
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    try {
      // Pipeline standar: pick native terkompresi (lihat ImageService).
      final photo = await ImageService.pickAndResizeImage(source: source);
      if (photo != null && mounted) {
        setState(() => _imageResi = photo);
      }
    } catch (e) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      showAppSnackBar(
        context,
        'Gagal mengambil foto: $e',
        background: cs.error,
      );
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _BarcodeScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _receiptNoController.text = result);
    }
  }

  Future<void> _submit({bool confirmDuplicateReceipt = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStore == null ||
        _selectedProvider == null ||
        _selectedDeliveryService == null) {
      _showError(
          'Lengkapi semua field wajib (toko, provider, delivery service).');
      return;
    }
    if (_items.isEmpty) {
      _showError('Tambahkan minimal 1 item produk.');
      return;
    }

    // Validasi setiap item punya produk terpilih.
    for (final item in _items) {
      if (item['product'] == null) {
        _showError('Setiap item harus memilih produk.');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final items = _items.map((item) {
        final product = item['product'] as SalesOrderOnlineProduct;
        final qty = int.tryParse(
                (item['qtyController'] as TextEditingController).text) ??
            1;
        final price = parseAmountInt(
            (item['priceController'] as TextEditingController).text);
        return SalesOrderItemRequest(
          productId: product.id,
          quantity: qty,
          unitPrice: price,
        );
      }).toList();

      // Retry in-place: seluruh siklus (dialog konfirmasi + percobaan ulang)
      // berada dalam SATU pemanggilan _submit, sehingga _isSubmitting tetap
      // true selama request retry berjalan — tombol tidak bisa memicu submit
      // kedua atau menumpuk dialog konfirmasi ganda.
      var confirm = confirmDuplicateReceipt;
      while (true) {
        try {
          await _salesOrderService.createOnlineOrder(
            selectedStore: _selectedStore!,
            deliveryDate:
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
            onlineShopProviderId: _selectedProvider!.id,
            deliveryServiceId: _selectedDeliveryService!.id,
            receiptNo: _receiptNoController.text.trim(),
            items: items,
            imagePayment: _imageResi,
            imagePaymentBytes: null,
            idempotencyKey: _idempotencyKey,
            confirmDuplicateReceipt: confirm,
          );
          break;
        } on DuplicateReceiptException catch (e) {
          if (!mounted) return;
          // Dialog memutuskan: false=Batal (hentikan tanpa order),
          // true=Tetap Simpan (loop ulang — key SAMA dikirim ulang).
          final retry = await _confirmDuplicateDialog(e);
          if (!retry) return; // Batal — finally reset _isSubmitting.
          confirm = true;
        }
      }

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Sales order online berhasil dibuat.',
        background: AppColors.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // Timeout/jaringan lambat: order BISA JADI sudah terkirim di server.
      // Jangan mengundang retry buta — arahkan cek daftar order.
      final message = e.toString().replaceAll('Exception: ', '');
      final isTimeout = message.contains('TimeoutException') ||
          message.contains('Connection');
      _showError(isTimeout
          ? 'Koneksi lambat — order mungkin sudah terkirim. Periksa daftar order sebelum mengirim ulang.\n\n$message'
          : message);
    } finally {
      // Reset sekali, HANYA setelah seluruh alur (dialog + retry) selesai —
      // tidak pernah saat request retry masih berjalan.
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Dialog konfirmasi resi duplikat: return true bila [Tetap Simpan]
  /// (pemanggil loop melanjutkan retry dengan confirmDuplicateReceipt=true,
  /// idempotency key SAMA), false bila [Batal] atau dialog tertutup tanpa
  /// pilihan. Pemanggil yang menangani retry — tombol di sini tidak pernah
  /// memicu _submit lagi.
  Future<bool> _confirmDuplicateDialog(DuplicateReceiptException e) async {
    final price = e.totalPrice == null
        ? ''
        : ' • Total Rp ${_formatCurrency(e.totalPrice!)}';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Resi Sudah Tercatat'),
        content: Text(
          '${e.message}\n\n'
          'Toko: ${e.storeNickname ?? '-'}$price\n'
          'Tgl order: ${e.existingCreatedAt ?? '-'}\n\n'
          'Bila ini order yang sama, pilih Batal. Bila memang order baru '
          'dengan resi sama, pilih Tetap Simpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tetap Simpan'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gagal',
            style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
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

  String _formatCurrency(int value) {
    return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)}.');
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
      appBar: GlassAppBar(title: const Text('Tambah Sales Order Online')),
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
                            style: TextStyle(color: colorScheme.error),
                            textAlign: TextAlign.center),
                        AppSpacing.gapVerticalMD,
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoadingData = true;
                              _errorMessage = null;
                            });
                            _loadInitialData();
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.translucent,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ).copyWith(top: AppBarInsets.top(context)),
                      children: [
                        // === Header fields ===
                        FormSectionCard(
                          title: 'Informasi Order',
                          icon: Icons.receipt_long_outlined,
                          children: [
                            ModernDropdown<StoreModel>(
                              labelText: 'Toko',
                              hint: 'Pilih toko...',
                              isRequired: true,
                              prefixIcon:
                                  const Icon(Icons.storefront, size: 20),
                              value: _selectedStore,
                              items: _stores,
                              getLabel: (s) => s.nickname,
                              onChanged: (v) =>
                                  setState(() => _selectedStore = v),
                              validator: (v) => v == null ? 'Pilih toko' : null,
                            ),
                            ModernDropdown<OnlineShopProvider>(
                              labelText: 'Online Shop Provider',
                              hint: 'Pilih provider...',
                              isRequired: true,
                              prefixIcon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 20),
                              value: _selectedProvider,
                              items: _providers,
                              getLabel: (p) => p.name,
                              onChanged: (v) =>
                                  setState(() => _selectedProvider = v),
                              validator: (v) =>
                                  v == null ? 'Pilih provider' : null,
                            ),
                            ModernDropdown<DeliveryServiceOption>(
                              labelText: 'Delivery Service',
                              hint: 'Pilih kurir...',
                              isRequired: true,
                              prefixIcon: const Icon(
                                  Icons.local_shipping_outlined,
                                  size: 20),
                              value: _selectedDeliveryService,
                              items: _deliveryServices,
                              getLabel: (d) => d.name,
                              onChanged: (v) =>
                                  setState(() => _selectedDeliveryService = v),
                              validator: (v) =>
                                  v == null ? 'Pilih delivery service' : null,
                            ),
                            ModernDateField(
                              labelText: 'Tanggal Pengiriman',
                              isRequired: true,
                              value: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              onChanged: (d) {
                                if (d != null) {
                                  setState(() => _selectedDate = d);
                                }
                              },
                            ),
                            ModernTextFormField(
                              controller: _receiptNoController,
                              labelText: 'Nomor Resi',
                              isRequired: true,
                              prefixIcon:
                                  const Icon(Icons.receipt_outlined, size: 20),
                              suffixIcon: IconButton(
                                icon:
                                    const Icon(Icons.qr_code_scanner, size: 20),
                                tooltip: 'Scan Barcode / QR',
                                onPressed: _scanBarcode,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Nomor resi wajib diisi';
                                }
                                return null;
                              },
                            ),
                            FormImageTile(
                              imageFile: _imageResi,
                              label: 'Foto Bukti Resi',
                              hint: 'Lampirkan label pengiriman / resi paket',
                              onPick: _pickImage,
                              onRemove: _imageResi != null
                                  ? () => setState(() => _imageResi = null)
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // === Items ===
                        FormSectionCard(
                          title: 'Detail Item',
                          icon: Icons.inventory_2_outlined,
                          trailing: FormAddButton(
                            label: 'Tambah',
                            onPressed: _addItem,
                          ),
                          children: [
                            if (_items.isEmpty)
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: AppSpacing.borderRadiusMD,
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.shopping_bag_outlined,
                                        size: 32,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5)),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Belum ada item produk',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tekan tombol "Tambah" di atas untuk menambah item.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._items.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                final product =
                                    item['product'] as SalesOrderOnlineProduct?;
                                return FormItemCard(
                                  index: idx,
                                  onDelete: () => _removeItem(idx),
                                  productField:
                                      ModernDropdown<SalesOrderOnlineProduct>(
                                    labelText: 'Produk',
                                    hint: 'Pilih produk...',
                                    value: product,
                                    items: _products,
                                    getLabel: (p) => p.name,
                                    getSubtitle: _productSubtitle,
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          item['product'] = v;
                                          item['product_id'] = v.id;
                                        });
                                      }
                                    },
                                  ),
                                  qtyField: TextFormField(
                                    controller: item['qtyController']
                                        as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    onTap: () {
                                      final ctrl = item['qtyController']
                                          as TextEditingController;
                                      ctrl.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: ctrl.text.length,
                                      );
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Qty',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 9,
                                      ),
                                      suffixText: product?.unit,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  priceField: TextFormField(
                                    controller: item['priceController']
                                        as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: rupiahInputFormatters,
                                    onTap: () {
                                      final ctrl = item['priceController']
                                          as TextEditingController;
                                      ctrl.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: ctrl.text.length,
                                      );
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Harga Satuan',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 9,
                                      ),
                                      prefixText: 'Rp ',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  subtotalText:
                                      'Rp ${_formatCurrency(_itemSubtotal(item))}',
                                );
                              }),

                            // Total summary strip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withValues(alpha: 0.35),
                                borderRadius: AppSpacing.borderRadiusMD,
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.payments_outlined,
                                          size: 18, color: colorScheme.primary),
                                      AppSpacing.gapHorizontalSM,
                                      Text(
                                        'Total Nilai Order',
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Rp ${_formatCurrency(_totalPrice)}',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapVerticalMD,
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return GlassContainer.bottomBar(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.lg),
      child: ModernButton(
        text: 'Simpan Sales Order',
        onPressed: _isSubmitting ? null : () => _submit(),
        isLoading: _isSubmitting,
      ),
    );
  }

  int _itemSubtotal(Map<String, dynamic> item) {
    final qty =
        int.tryParse((item['qtyController'] as TextEditingController).text) ??
            0;
    final price =
        parseAmountInt((item['priceController'] as TextEditingController).text);
    return qty * price;
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  MobileScannerController? _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      _hasScanned = true;
      Navigator.pop(context, barcode.rawValue);
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      // Pipeline standar untuk pilih gambar; barcode detection MLKit
      // bekerja pada file 1024px — resolusi cukup untuk QR/resi.
      final photo =
          await ImageService.pickAndResizeImage(source: ImageSource.gallery);
      if (photo == null) return;
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
      final result = await controller.analyzeImage(photo.path);
      await controller.dispose();
      final barcode = result?.barcodes.firstOrNull;
      if (barcode != null && barcode.rawValue != null) {
        if (mounted) Navigator.pop(context, barcode.rawValue);
      } else {
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          showAppSnackBar(
            context,
            'Tidak ditemukan barcode/QR pada gambar.',
            background: cs.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        showAppSnackBar(
          context,
          'Gagal memproses gambar: $e',
          background: cs.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Scan Resi / Barcode / QR'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller!,
            builder: (context, state, child) {
              return BarButtonCluster(
                actions: [
                  BarButtonSpec(
                    icon: Icons.photo_library,
                    tooltip: 'Ambil dari Galeri',
                    onTap: _scanFromGallery,
                  ),
                  BarButtonSpec(
                    icon: state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                    tooltip: 'Senter',
                    onTap: () => _controller!.toggleTorch(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 280,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.surface, width: 2),
                borderRadius: AppSpacing.borderRadiusLG,
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke QR code atau Barcode resi',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.surface.withValues(alpha: 0.8),
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
