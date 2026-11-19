import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/procurement_model.dart';
import '../providers/auth_provider.dart';
import '../services/procurement_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/ios_segmented_control.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/procurement_batch_bottom_bar.dart';
import '../widgets/procurement_entity_card.dart';
import '../widgets/procurement_graph_view.dart';
import 'create_invoice_form_page.dart';
import 'create_invoice_page.dart';
import 'create_payment_receipt_page.dart';
import 'create_procurement_page.dart';
import 'invoice_detail_page.dart';
import 'payment_receipt_detail_page.dart';
import 'procurement_detail_page.dart';
import 'procurement_product_info_page.dart';

class ProcurementWorkflowPage extends StatefulWidget {
  const ProcurementWorkflowPage({super.key});

  @override
  State<ProcurementWorkflowPage> createState() => _ProcurementWorkflowPageState();
}

class _ProcurementWorkflowPageState extends State<ProcurementWorkflowPage> {
  final ProcurementService _service = ProcurementService();
  final ScrollController _scrollController = ScrollController();

  // Stage & sub-filter — tiap tab punya filter sendiri-sendiri.
  int _activeStage = 0; // 0=Request, 1=Invoice, 2=Payment
  // Request: status keterkaitan invoice + toko.
  int _subFilterRequest = 0; // 0=Semua, 1=SiapInvoice, 2=SudahJadiInvoice
  int? _storeRequestId; // null=Semua toko
  // Invoice: status bayar + status terima + supplier.
  int _subFilterInvoice = 0; // 0=Semua, 1=SiapDibayar, 2=Lunas
  int _subFilterOrder = 0; // 0=Semua, 1=BelumDiterima, 2=SudahDiterima, 3=Dikembalikan
  int? _supplierInvoiceId; // null=Semua supplier
  // Payment: supplier.
  int? _supplierPaymentId; // null=Semua supplier

  // Batch
  bool _batchMode = false;
  final Set<int> _selectedRequestIds = {};
  final Set<int> _selectedInvoiceIds = {};

  // Data
  List<RequestPurchase> _requests = [];
  List<InvoicePurchase> _allInvoices = [];
  List<PaymentReceipt> _allReceipts = [];
  Map<int, List<InvoicePurchase>> _requestToInvoices = {};
  Map<int, PaymentReceipt> _invoiceToReceipt = {};
  Map<int, List<int>> _invoiceToRequestIds = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore && _hasMore && _activeStage == 0) {
      _loadMore();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _requests = [];
      _allInvoices = [];
      _allReceipts = [];
      _requestToInvoices = {};
      _invoiceToReceipt = {};
      _invoiceToRequestIds = {};
      _selectedRequestIds.clear();
      _selectedInvoiceIds.clear();
      _hasMore = true;
    });

    try {
      final requestResult = await _service.getRequestsPaged(page: _page, perPage: 30);
      final requests = requestResult['data'] as List<RequestPurchase>;

      List<InvoicePurchase> invoices = [];
      List<PaymentReceipt> receipts = [];
      try {
        invoices = (await _service.getInvoices(perPage: 100)).items;
      } catch (_) {}
      try {
        receipts = (await _service.getPaymentReceipts(perPage: 100)).items;
      } catch (_) {}

      // Build requestToInvoices (with dedup)
      final reqToInv = <int, List<InvoicePurchase>>{};
      for (var inv in invoices) {
        for (var detailItem in inv.detailInvoices) {
          if (detailItem.detailRequestId != null) {
            for (var req in requests) {
              if (req.detailRequests.any((dr) => dr.id == detailItem.detailRequestId)) {
                reqToInv.putIfAbsent(req.id, () => []).add(inv);
                break;
              }
            }
          }
        }
      }
      reqToInv.forEach((reqId, list) {
        final unique = <int, InvoicePurchase>{};
        for (var i in list) {
          unique[i.id] = i;
        }
        reqToInv[reqId] = unique.values.toList();
      });

      // Build invoiceToReceipt
      final invToRec = <int, PaymentReceipt>{};
      for (var rec in receipts) {
        for (var inv in rec.invoicePurchases) {
          invToRec[inv.id] = rec;
        }
      }

      // Build invoiceToRequestIds (inverse of reqToInv)
      final invToReqIds = <int, List<int>>{};
      reqToInv.forEach((reqId, invs) {
        for (var inv in invs) {
          invToReqIds.putIfAbsent(inv.id, () => []).add(reqId);
        }
      });

      if (!mounted) return;
      setState(() {
        _requests = requests;
        _allInvoices = invoices;
        _allReceipts = receipts;
        _requestToInvoices = reqToInv;
        _invoiceToReceipt = invToRec;
        _invoiceToRequestIds = invToReqIds;
        _hasMore = requestResult['has_more'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await _service.getRequestsPaged(page: nextPage, perPage: 30);
      final newRequests = result['data'] as List<RequestPurchase>;
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _requests.addAll(newRequests);
        _hasMore = result['has_more'] as bool;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ============ Filtering ============

  List<RequestPurchase> get _filteredRequests {
    var list = _requests.where((r) => r.detailRequests.isNotEmpty).toList();
    if (_storeRequestId != null) {
      list = list.where((r) => r.storeId == _storeRequestId).toList();
    }
    switch (_subFilterRequest) {
      case 1:
        return list.where((r) => !_requestToInvoices.containsKey(r.id)).toList();
      case 2:
        return list.where((r) => _requestToInvoices.containsKey(r.id)).toList();
      default:
        return list;
    }
  }

  List<InvoicePurchase> get _filteredInvoices {
    var list = _allInvoices;
    // Status bayar: 0=Semua, 1=Siap Dibayar (payment_status 1 saja —
    // status 3/Tidak Valid tidak ikut), 2=Lunas.
    switch (_subFilterInvoice) {
      case 1:
        list = list.where((i) => i.paymentStatus == '1').toList();
      case 2:
        list = list.where((i) => i.paymentStatus == '2').toList();
    }
    // Status terima: 0=Semua, 1/2/3 = order_status.
    if (_subFilterOrder > 0) {
      list = list
          .where((i) => i.orderStatus == _subFilterOrder.toString())
          .toList();
    }
    if (_supplierInvoiceId != null) {
      list = list.where((i) => i.supplierId == _supplierInvoiceId).toList();
    }
    return list;
  }

  List<PaymentReceipt> get _filteredReceipts {
    var list = _allReceipts;
    if (_supplierPaymentId != null) {
      list = list.where((r) => r.supplierId == _supplierPaymentId).toList();
    }
    return list;
  }

  int get _batchPaymentTotal {
    int total = 0;
    for (var id in _selectedInvoiceIds) {
      final inv = _allInvoices.firstWhere(
        (i) => i.id == id,
        orElse: () => InvoicePurchase(
          id: 0,
          storeId: 0,
          date: '',
          createdById: 0,
          storeName: '',
        ),
      );
      total += inv.totalPrice;
    }
    return total;
  }

  // ============ Filter methods ============

  /// Badge filter hanya menghitung filter milik tab aktif.
  int get _activeFilterCount {
    int count = 0;
    if (_activeStage == 0) {
      if (_subFilterRequest > 0) count++;
      if (_storeRequestId != null) count++;
    } else if (_activeStage == 1) {
      if (_subFilterInvoice > 0) count++;
      if (_subFilterOrder > 0) count++;
      if (_supplierInvoiceId != null) count++;
    } else {
      if (_supplierPaymentId != null) count++;
    }
    return count;
  }

  /// Opsi dropdown (id, nama) yang unik & terurut dari data yang dimuat.
  List<(int, String)> _distinctOptions(Iterable<(int?, String?)> entries) {
    final map = <int, String>{};
    for (final e in entries) {
      final id = e.$1;
      final name = (e.$2 ?? '').trim();
      if (id != null && name.isNotEmpty) map.putIfAbsent(id, () => name);
    }
    final list = map.entries.map((e) => (e.key, e.value)).toList();
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return list;
  }

  List<DropdownFilterField> _buildFilterFields() {
    if (_activeStage == 0) {
      return [
        DropdownFilterField<int>(
          label: 'Status Request',
          value: _subFilterRequest,
          options: const [
            (0, 'Semua'),
            (1, 'Siap Invoice'),
            (2, 'Sudah Jadi Invoice'),
          ],
        ),
        DropdownFilterField<int>(
          label: 'Toko',
          value: _storeRequestId,
          options: _distinctOptions(
              _requests.map((r) => (r.storeId, r.storeName))),
        ),
      ];
    } else if (_activeStage == 1) {
      return [
        DropdownFilterField<int>(
          label: 'Status Bayar',
          value: _subFilterInvoice,
          options: const [
            (0, 'Semua'),
            (1, 'Siap Dibayar'),
            (2, 'Lunas'),
          ],
        ),
        DropdownFilterField<int>(
          label: 'Status Terima',
          value: _subFilterOrder,
          options: const [
            (0, 'Semua'),
            (1, 'Belum Diterima'),
            (2, 'Sudah Diterima'),
            (3, 'Dikembalikan'),
          ],
        ),
        DropdownFilterField<int>(
          label: 'Supplier',
          value: _supplierInvoiceId,
          options: _distinctOptions(
              _allInvoices.map((i) => (i.supplierId, i.supplierName))),
        ),
      ];
    }
    return [
      DropdownFilterField<int>(
        label: 'Supplier',
        value: _supplierPaymentId,
        options: _distinctOptions(
            _allReceipts.map((r) => (r.supplierId, r.supplierName))),
      ),
    ];
  }

  void _openFilterSheet() {
    final fields = _buildFilterFields();
    if (fields.isEmpty) return;
    FilterBottomSheet.show(
      context,
      title: 'Filter ${['Request', 'Invoice', 'Payment'][_activeStage]}',
      fields: fields,
      onApply: (values) {
        setState(() {
          if (_activeStage == 0) {
            _subFilterRequest = values['Status Request'] as int? ?? 0;
            _storeRequestId = values['Toko'] as int?;
          } else if (_activeStage == 1) {
            _subFilterInvoice = values['Status Bayar'] as int? ?? 0;
            _subFilterOrder = values['Status Terima'] as int? ?? 0;
            _supplierInvoiceId = values['Supplier'] as int?;
          } else {
            _supplierPaymentId = values['Supplier'] as int?;
          }
        });
      },
      onReset: () {
        setState(() {
          if (_activeStage == 0) {
            _subFilterRequest = 0;
            _storeRequestId = null;
          } else if (_activeStage == 1) {
            _subFilterInvoice = 0;
            _subFilterOrder = 0;
            _supplierInvoiceId = null;
          } else {
            _supplierPaymentId = null;
          }
        });
      },
    );
  }

  Future<void> _openCreateForCurrentStage() async {
    if (_activeStage == 0) {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const CreateProcurementPage()),
      );
      if (created == true) _fetchData();
    } else if (_activeStage == 1) {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const CreateInvoiceFormPage()),
      );
      if (created == true) _fetchData();
    } else {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const CreatePaymentReceiptPage()),
      );
      if (created == true) _fetchData();
    }
  }

  // ============ Build ============

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final segments = {
      0: 'Request (${_requests.length})',
      1: 'Invoice (${_allInvoices.length})',
      2: 'Payment (${_allReceipts.length})',
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        title: const Text('Procurement'),
        centerTitle: true,
        actions: [
          BarButtonCluster(actions: [
            BarButtonSpec(
              icon: Icons.tune,
              tooltip: 'Filter',
              badgeCount: _activeFilterCount,
              onTap: _openFilterSheet,
            ),
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: _activeStage == 0
                  ? 'Tambah Request'
                  : _activeStage == 1
                      ? 'Tambah Invoice'
                      : 'Tambah Payment',
              onTap: _openCreateForCurrentStage,
            ),
            BarButtonSpec(
              icon: Icons.more_vert,
              tooltip: 'Opsi lainnya',
              popupItems: [
                if (isAdmin)
                  const PopupMenuItem(
                      value: 'purchase_info',
                      child: Text('📊 Info Beli Bahan Baku')),
                const PopupMenuItem(
                    value: 'graph',
                    child: Text('🌳 Grafik Many-to-Many')),
                const PopupMenuItem(
                    value: 'refresh', child: Text('🔄 Refresh')),
                PopupMenuItem(
                  value: 'batch',
                  child: Text(
                      _batchMode ? '☑️ Exit Mode Batch' : '☑️ Mode Batch'),
                ),
              ],
              onPopupSelected: (val) async {
                if (val == 'purchase_info') {
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProcurementProductInfoPage()),
                  );
                } else if (val == 'graph') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _GraphPage(
                        requests: _requests,
                        invoices: _allInvoices,
                        receipts: _allReceipts,
                        requestToInvoices: _requestToInvoices,
                        invoiceToReceipt: _invoiceToReceipt,
                      ),
                    ),
                  );
                  _fetchData();
                } else if (val == 'refresh') {
                  _fetchData();
                } else if (val == 'batch') {
                  setState(() {
                    _batchMode = !_batchMode;
                    _selectedRequestIds.clear();
                    _selectedInvoiceIds.clear();
                  });
                }
              },
            ),
          ]),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: IosSegmentedControl<int>(
            segments: segments,
            groupValue: _activeStage,
            onValueChanged: (v) => setState(() {
              _activeStage = v;
              _selectedRequestIds.clear();
              _selectedInvoiceIds.clear();
            }),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      AppSpacing.gapVerticalMD,
                      ElevatedButton(
                        onPressed: _fetchData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: Stack(
                    children: [
                      IndexedStack(
                        index: _activeStage,
                        children: [
                          _buildRequestList(),
                          _buildInvoiceList(),
                          _buildReceiptList(),
                        ],
                      ),
                      if (_buildBottomBar() != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: ModernBottomNav.clearance(context),
                          child: _buildBottomBar()!,
                        ),
                    ],
                  ),
                ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 3, // Transaction dashboard tab
        onTap: (index) {
          if (index != 3) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildRequestList() {
    final list = _filteredRequests;
    if (list.isEmpty) return _buildEmpty('Tidak ada request', Icons.shopping_bag_outlined);
    final topPadding = AppBarInsets.top(context, bottom: 52) + 8;
    final bottomPadding = ModernBottomNav.clearance(context) + 16;
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.paddingMD.copyWith(
        top: topPadding,
        bottom: bottomPadding,
      ),
      itemCount: list.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == list.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final req = list[i];
        final linked = _requestToInvoices[req.id] ?? [];
        final isSel = _selectedRequestIds.contains(req.id);
        return ProcurementEntityCard.requestMode(
          request: req,
          linkedInvoices: linked,
          isSelected: isSel,
          showCheckbox: _batchMode,
          checkboxValue: isSel,
          onCheckboxChanged: (v) => setState(() {
            if (v) {
              _selectedRequestIds.add(req.id);
            } else {
              _selectedRequestIds.remove(req.id);
            }
          }),
          onTapCard: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProcurementDetailPage(requestId: req.id),
              ),
            );
            _fetchData();
          },
          onTapCreateInvoice: () async {
            final created = await Navigator.push<int>(
              context,
              MaterialPageRoute(
                builder: (_) => CreateInvoicePage(requestId: req.id, requestIds: [req.id]),
              ),
            );
            if (created != null && created > 0) _fetchData();
          },
          onTapLinkInvoice: (inv) async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailPage(invoiceId: inv.id),
              ),
            );
            _fetchData();
          },
        );
      },
    );
  }

  Widget _buildInvoiceList() {
    final list = _filteredInvoices;
    if (list.isEmpty) return _buildEmpty('Tidak ada invoice', Icons.receipt_long_outlined);
    final topPadding = AppBarInsets.top(context, bottom: 52) + 8;
    final bottomPadding = ModernBottomNav.clearance(context) + 16;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.paddingMD.copyWith(
        top: topPadding,
        bottom: bottomPadding,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final inv = list[i];
        final reqIds = _invoiceToRequestIds[inv.id] ?? [];
        final isSel = _selectedInvoiceIds.contains(inv.id);
        final canBayar = inv.paymentStatus != '2';
        // Receipt yang melunasi invoice ini (kalau sudah paid).
        final receipt = _invoiceToReceipt[inv.id];
        // Invoice lain yang dibayar di receipt yg sama.
        final linkedInSameReceipt = receipt?.invoicePurchases ?? const [];
        // Thumbnail utama selalu gambar invoice; kwitansi (kalau paid & ada)
        // ditampilkan sebagai thumbnail sekunder agar keduanya tetap terlihat.
        final thumbUrl = inv.imageUrl;
        final kwitansiUrl = (inv.paymentStatus == '2' && receipt?.imageUrl != null)
            ? receipt!.imageUrl
            : null;
        return ProcurementEntityCard.invoiceMode(
          invoice: inv,
          linkedRequestIds: reqIds,
          paymentReceipt: receipt,
          linkedInvoicesInSameReceipt: linkedInSameReceipt,
          showCheckbox: _batchMode && canBayar,
          checkboxValue: isSel,
          onCheckboxChanged: (v) => setState(() {
            if (v) {
              _selectedInvoiceIds.add(inv.id);
            } else {
              _selectedInvoiceIds.remove(inv.id);
            }
          }),
          onTapThumbnail: thumbUrl != null
              ? () => ImagePreviewDialog.show(
                    context,
                    thumbUrl,
                    title: 'Invoice #${inv.id}',
                  )
              : null,
          onTapSecondaryThumbnail: kwitansiUrl != null
              ? () => ImagePreviewDialog.show(
                    context,
                    kwitansiUrl,
                    title: 'Kwitansi #${receipt!.id}',
                  )
              : null,
          onTapLinkedInvoice: (otherInv) async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailPage(invoiceId: otherInv.id),
              ),
            );
            _fetchData();
          },
          onTapCard: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailPage(invoiceId: inv.id),
              ),
            );
            _fetchData();
          },
          onTapBayar: canBayar
              ? () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePaymentReceiptPage(invoices: [inv]),
                    ),
                  );
                  if (created == true) _fetchData();
                }
              : null,
        );
      },
    );
  }

  Widget _buildReceiptList() {
    final list = _filteredReceipts;
    if (list.isEmpty) return _buildEmpty('Tidak ada payment receipt', Icons.payment_outlined);
    final topPadding = AppBarInsets.top(context, bottom: 52) + 8;
    final bottomPadding = ModernBottomNav.clearance(context) + 16;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.paddingMD.copyWith(
        top: topPadding,
        bottom: bottomPadding,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final rec = list[i];
        // Semua payment receipt adalah transfer (tunai langsung ke closing store).
        return ProcurementEntityCard.paymentMode(
          receipt: rec,
          isTunai: false,
          onTapThumbnail: rec.imageUrl != null
              ? () => ImagePreviewDialog.show(
                    context,
                    rec.imageUrl!,
                    title: 'Kwitansi #${rec.id}',
                  )
              : null,
          onTapCard: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentReceiptDetailPage(receiptId: rec.id),
              ),
            );
            _fetchData();
          },
        );
      },
    );
  }

  Widget _buildEmpty(String text, IconData icon) {
    final topPadding = AppBarInsets.top(context, bottom: 52) + 8;
    final bottomPadding = ModernBottomNav.clearance(context) + 16;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 54,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                AppSpacing.gapVerticalMD,
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar() {
    if (_batchMode && _activeStage == 0 && _selectedRequestIds.isNotEmpty) {
      return ProcurementBatchBottomBar.requestMode(
        selectedCount: _selectedRequestIds.length,
        onClear: () => setState(() {
          _selectedRequestIds.clear();
        }),
        onAction: () async {
          final ids = _selectedRequestIds.toList();
          final created = await Navigator.push<int>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateInvoicePage(requestId: ids.first, requestIds: ids),
            ),
          );
          if (created != null && created > 0) {
            setState(() {
              _selectedRequestIds.clear();
              _batchMode = false;
            });
            _fetchData();
          }
        },
      );
    }
    if (_batchMode && _activeStage == 1 && _selectedInvoiceIds.isNotEmpty) {
      return ProcurementBatchBottomBar.invoiceMode(
        selectedCount: _selectedInvoiceIds.length,
        totalAmount: _batchPaymentTotal,
        onClear: () => setState(() {
          _selectedInvoiceIds.clear();
        }),
        onAction: () async {
          final selected = _allInvoices
              .where((i) => _selectedInvoiceIds.contains(i.id))
              .toList();
          if (selected.isEmpty) return;
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePaymentReceiptPage(invoices: selected),
            ),
          );
          if (created == true) {
            setState(() {
              _selectedInvoiceIds.clear();
              _batchMode = false;
            });
            _fetchData();
          }
        },
      );
    }
    return null;
  }
}

/// Wrapper page untuk GraphView (dipanggil dari menu ⋮).
class _GraphPage extends StatelessWidget {
  final List<RequestPurchase> requests;
  final List<InvoicePurchase> invoices;
  final List<PaymentReceipt> receipts;
  final Map<int, List<InvoicePurchase>> requestToInvoices;
  final Map<int, PaymentReceipt> invoiceToReceipt;

  const _GraphPage({
    required this.requests,
    required this.invoices,
    required this.receipts,
    required this.requestToInvoices,
    required this.invoiceToReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Grafik Many-to-Many')),
      body: ProcurementGraphView(
        requests: requests,
        invoices: invoices,
        receipts: receipts,
        requestToInvoices: requestToInvoices,
        invoiceToReceipt: invoiceToReceipt,
        onTapRequest: (r) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProcurementDetailPage(requestId: r.id),
          ),
        ),
        onTapInvoice: (i) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailPage(invoiceId: i.id),
          ),
        ),
        onTapReceipt: (r) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentReceiptDetailPage(receiptId: r.id),
          ),
        ),
      ),
    );
  }
}
