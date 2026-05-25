import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:io';
import '../utils/themes.dart';
import '../services/presence_service.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  // Theme Colors (Matte Black & Gold referenced from AppTheme)
  static const Color primaryDark = AppTheme.primaryDark;
  static const Color cardDark = AppTheme.cardDark;
  static const Color goldAccent = AppTheme.goldAccent;
  static const Color textLight = AppTheme.textLight;
  static const Color textMuted = AppTheme.textMuted;

  final TextEditingController _receiptController = TextEditingController();
  final TextEditingController _receiverController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingSearch = false;
  bool _isLoadingSubmit = false;
  bool _isLoadingReadyToShip = false;
  bool _isPrintingPaymentProof = false;
  bool _isLoadingList = false;

  Map<String, dynamic>? _selectedOrder;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _orders = [];
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadInitialOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _receiptController.dispose();
    _receiverController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadInitialOrders() async {
    if (_isLoadingList) return;
    setState(() {
      _isLoadingList = true;
      _currentPage = 1;
      _orders.clear();
      _hasMore = true;
    });

    try {
      final result = await PresenceService.getSalesOrders(page: 1, perPage: 10);
      if (!mounted) return;
      if (result['success'] == true) {
        final List<dynamic> fetchedOrders = result['data'] ?? [];
        final Map<String, dynamic> meta = result['meta'] ?? {};
        final int lastPage = meta['last_page'] ?? 1;

        setState(() {
          _orders = fetchedOrders;
          _hasMore = _currentPage < lastPage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat list order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingList = false;
        });
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingList || !_hasMore) return;
    setState(() {
      _isLoadingList = true;
    });

    final nextPage = _currentPage + 1;

    try {
      final result =
          await PresenceService.getSalesOrders(page: nextPage, perPage: 10);
      if (!mounted) return;
      if (result['success'] == true) {
        final List<dynamic> fetchedOrders = result['data'] ?? [];
        final Map<String, dynamic> meta = result['meta'] ?? {};
        final int lastPage = meta['last_page'] ?? 1;

        setState(() {
          _currentPage = nextPage;
          _orders.addAll(fetchedOrders);
          _hasMore = _currentPage < lastPage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data lanjutan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingList = false;
        });
      }
    }
  }

  Future<void> _searchOrder() async {
    final receiptNo = _receiptController.text.trim();
    if (receiptNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan nomor resi terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingSearch = true;
      _imageFile = null;
      _receiverController.clear();
    });

    try {
      final result = await PresenceService.searchSalesOrder(receiptNo);
      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _selectedOrder = result['data'];
          if (_selectedOrder?['received_by'] != null) {
            _receiverController.text = _selectedOrder!['received_by'];
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Order tidak ditemukan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSearch = false;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );

      if (!mounted) return;
      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitDelivery() async {
    if (_selectedOrder == null) return;

    final receiptNo = _selectedOrder!['receipt_no'];
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap ambil foto bukti pengiriman terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingSubmit = true;
    });

    try {
      final result = await PresenceService.updateDeliveryStatus(
        receiptNo: receiptNo,
        imageFile: _imageFile!,
        receivedBy: _receiverController.text.trim(),
      );

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result['message'] ?? 'Status pengiriman berhasil diperbarui.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedOrder = null;
          _imageFile = null;
          _receiptController.clear();
          _receiverController.clear();
        });
        _loadInitialOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memperbarui pengiriman.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSubmit = false;
        });
      }
    }
  }

  Future<void> _markReadyToShip() async {
    if (_selectedOrder == null) return;

    final receiptNo = _selectedOrder!['receipt_no'];
    if (receiptNo == null || receiptNo.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor resi tidak tersedia.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingReadyToShip = true;
    });

    try {
      final result = await PresenceService.markReadyToShip(
        receiptNo: receiptNo.toString(),
      );

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result['message'] ?? 'Order berhasil ditandai siap dikirim.'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedOrder = {
            ..._selectedOrder!,
            'delivery_status': result['data']?['delivery_status'] ?? 4,
          };
        });
        _loadInitialOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ??
                'Gagal mengubah status menjadi siap dikirim.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReadyToShip = false;
        });
      }
    }
  }

  bool _canPrintPaymentProof(Map<String, dynamic> order) {
    return order['delivery_status'] == 1 &&
        order['image_payment_url'] != null &&
        order['image_payment_url'].toString().trim().isNotEmpty;
  }

  Future<Uint8List> _downloadImageBytes(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode != 200) {
      throw Exception('Gagal memuat gambar bukti pembayaran.');
    }

    return response.bodyBytes;
  }

  Future<void> _printPaymentProofs(List<Map<String, dynamic>> orders) async {
    final printableOrders = orders.where(_canPrintPaymentProof).toList();

    if (printableOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tidak ada bukti pembayaran status belum dikirim untuk diprint.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPrintingPaymentProof = true;
    });

    try {
      final document = pw.Document();

      for (final order in printableOrders) {
        final imageBytes =
            await _downloadImageBytes(order['image_payment_url'].toString());
        final image = pw.MemoryImage(imageBytes);

        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Bukti Pembayaran Online',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text('Resi: ${order['receipt_no'] ?? '-'}'),
                            pw.Text('Toko: ${order['store_name'] ?? '-'}'),
                            pw.Text(
                                'Provider: ${order['provider_name'] ?? '-'}'),
                            pw.Text(
                                'Jasa Kirim: ${order['delivery_service_name'] ?? '-'}'),
                            pw.Text(
                                'Tanggal Kirim: ${order['delivery_date'] ?? '-'}'),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.orange50,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          'Belum Dikirim',
                          style: pw.TextStyle(
                            color: PdfColors.orange800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Expanded(
                    child: pw.Container(
                      width: double.infinity,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        name: 'bukti-pembayaran-online.pdf',
        onLayout: (_) async => document.save(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingPaymentProof = false;
        });
      }
    }
  }

  Future<void> _printAllPendingPaymentProofs() async {
    final List<Map<String, dynamic>> allOrders = [];
    var page = 1;
    var lastPage = 1;

    try {
      do {
        final result =
            await PresenceService.getSalesOrders(page: page, perPage: 100);
        if (result['success'] != true) {
          throw Exception(
              result['message'] ?? 'Gagal memuat daftar pengiriman.');
        }

        final fetchedOrders = (result['data'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        allOrders.addAll(fetchedOrders);

        final meta = result['meta'] as Map<String, dynamic>? ?? {};
        lastPage = meta['last_page'] ?? page;
        page += 1;
      } while (page <= lastPage);

      await _printPaymentProofs(allOrders);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getDeliveryStatusText(int? status) {
    switch (status) {
      case 1:
        return 'Belum Dikirim';
      case 2:
        return 'Valid (Terkunci)';
      case 3:
        return 'Sudah Dikirim';
      case 4:
        return 'Siap Dikirim';
      case 5:
        return 'Perbaiki';
      case 6:
        return 'Dikembalikan';
      default:
        return 'Tidak Diketahui';
    }
  }

  Color _getDeliveryStatusColor(int? status) {
    switch (status) {
      case 2:
        return Colors.green;
      case 3:
        return goldAccent;
      case 1:
      case 4:
        return Colors.orangeAccent;
      case 5:
      case 6:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildGoldTextField({
    required String labelText,
    required TextEditingController controller,
    required IconData prefixIcon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(prefixIcon, color: goldAccent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: goldAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: primaryDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryDark,
          foregroundColor: goldAccent,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedOrder == null ? 'PENGIRIMAN ONLINE' : 'DETAIL PENGIRIMAN',
            style: const TextStyle(
                fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          leading: _selectedOrder != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: goldAccent),
                  onPressed: () {
                    setState(() {
                      _selectedOrder = null;
                      _imageFile = null;
                      _receiverController.clear();
                    });
                  },
                )
              : null,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: goldAccent,
            backgroundColor: cardDark,
            onRefresh: _loadInitialOrders,
            child: _selectedOrder != null
                ? _buildOrderDetailView()
                : _buildOrderListView(),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderListView() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Search Bar
        Card(
          color: cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: goldAccent.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cari Resi Spesifik',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: goldAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildGoldTextField(
                        labelText: 'Nomor Resi / QR',
                        controller: _receiptController,
                        prefixIcon: Icons.qr_code_scanner,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 55,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!_isLoadingSearch) {
                            _searchOrder();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goldAccent,
                          foregroundColor: primaryDark,
                          minimumSize: const Size(55, 50),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoadingSearch
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: primaryDark,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search,
                                fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Pengiriman',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textLight),
            ),
            if (_isLoadingList && _currentPage == 1)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: goldAccent, strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed:
              _isPrintingPaymentProof ? null : _printAllPendingPaymentProofs,
          icon: _isPrintingPaymentProof
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: primaryDark,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.print, color: primaryDark),
          label: Text(
            _isPrintingPaymentProof
                ? 'Menyiapkan Print...'
                : 'Print Semua Bukti Pembayaran Belum Dikirim',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: goldAccent,
            foregroundColor: primaryDark,
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_orders.isEmpty && !_isLoadingList)
          _buildEmptyState()
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orders.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _orders.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: CircularProgressIndicator(color: goldAccent),
                  ),
                );
              }

              final order = _orders[index];
              final int? status = order['delivery_status'];

              return Card(
                color: cardDark,
                margin: const EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: goldAccent.withOpacity(0.1)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedOrder = order;
                      _imageFile = null;
                      _receiverController.clear();
                      if (order['received_by'] != null) {
                        _receiverController.text = order['received_by'];
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                order['receipt_no'] ?? 'Tanpa Resi',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textLight,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getDeliveryStatusColor(status)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getDeliveryStatusText(status),
                                style: TextStyle(
                                  color: _getDeliveryStatusColor(status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: Colors.white10),
                        Row(
                          children: [
                            const Icon(Icons.storefront,
                                size: 16, color: goldAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order['store_name'] ?? '-',
                                style: const TextStyle(
                                    fontSize: 13, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 16, color: goldAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${order['provider_name'] ?? '-'} • ${order['delivery_service_name'] ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        if (order['delivery_date'] != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: goldAccent),
                              const SizedBox(width: 8),
                              Text(
                                order['delivery_date'],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                        if (_canPrintPaymentProof(
                            Map<String, dynamic>.from(order))) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isPrintingPaymentProof
                                ? null
                                : () => _printPaymentProofs([
                                      Map<String, dynamic>.from(order),
                                    ]),
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Print Bukti Pembayaran'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: goldAccent,
                              side: BorderSide(
                                  color: goldAccent.withOpacity(0.5)),
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOrderDetailView() {
    final order = _selectedOrder!;
    final int deliveryStatus = order['delivery_status'] ?? 1;
    final bool isLocked = deliveryStatus == 2 || deliveryStatus == 3;
    final bool canMarkReadyToShip = deliveryStatus == 1;
    final bool canSubmitDelivery = !isLocked && !canMarkReadyToShip;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Back Assist Card
          InkWell(
            onTap: () {
              setState(() {
                _selectedOrder = null;
                _imageFile = null;
                _receiverController.clear();
              });
            },
            child: Card(
              color: cardDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: goldAccent.withOpacity(0.3)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16, color: goldAccent),
                    SizedBox(width: 8),
                    Text(
                      'Kembali ke Daftar Pengiriman',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: goldAccent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: cardDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: goldAccent.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Resi: ${order['receipt_no']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textLight,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              _getDeliveryStatusColor(order['delivery_status'])
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDeliveryStatusText(order['delivery_status']),
                          style: TextStyle(
                            color: _getDeliveryStatusColor(
                                order['delivery_status']),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  _buildDetailRow('Toko', order['store_name'] ?? '-'),
                  _buildDetailRow(
                      'Online Provider', order['provider_name'] ?? '-'),
                  _buildDetailRow(
                      'Jasa Kirim', order['delivery_service_name'] ?? '-'),
                  _buildDetailRow(
                      'Tanggal Kirim', order['delivery_date'] ?? '-'),
                  if (isLocked)
                    _buildDetailRow('Penerima', order['received_by'] ?? '-'),
                  const SizedBox(height: 16),
                  const Text(
                    'Detail Produk:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: goldAccent),
                  ),
                  const SizedBox(height: 8),
                  if (order['items'] != null &&
                      (order['items'] as List).isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (order['items'] as List).length,
                      itemBuilder: (context, index) {
                        final item = order['items'][index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 6, color: goldAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item['product_name']} x ${item['quantity']} ${item['product_unit'] ?? ''}',
                                  style: const TextStyle(
                                      color: textMuted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    const Text('Tidak ada rincian produk.',
                        style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (order['image_payment_url'] != null) ...[
            Card(
              color: cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: goldAccent.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payment, color: goldAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Foto Bukti Pembayaran',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: goldAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  InteractiveViewer(
                                    child: Image.network(
                                      order['image_payment_url'],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.white, size: 30),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Image.network(
                              order['image_payment_url'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  color: Colors.white10,
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image,
                                          color: Colors.redAccent, size: 36),
                                      SizedBox(height: 8),
                                      Text(
                                        'Gagal memuat gambar',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Container(
                              width: double.infinity,
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: const Text(
                                'Klik untuk memperbesar gambar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_canPrintPaymentProof(order)) ...[
            ElevatedButton.icon(
              onPressed: _isPrintingPaymentProof
                  ? null
                  : () => _printPaymentProofs([
                        Map<String, dynamic>.from(order),
                      ]),
              icon: _isPrintingPaymentProof
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: primaryDark,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.print, color: primaryDark),
              label: Text(
                _isPrintingPaymentProof
                    ? 'Menyiapkan Print...'
                    : 'Print Bukti Pembayaran',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: goldAccent,
                foregroundColor: primaryDark,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (order['image_delivery_url'] != null) ...[
            Card(
              color: cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: goldAccent.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo, color: goldAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Foto Bukti Pengiriman',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: goldAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  InteractiveViewer(
                                    child: Image.network(
                                      order['image_delivery_url'],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.white, size: 30),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Image.network(
                              order['image_delivery_url'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  color: Colors.white10,
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image,
                                          color: Colors.redAccent, size: 36),
                                      SizedBox(height: 8),
                                      Text(
                                        'Gagal memuat gambar',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Container(
                              width: double.infinity,
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: const Text(
                                'Klik untuk memperbesar gambar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (canMarkReadyToShip) ...[
            Card(
              color: cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.orangeAccent.withOpacity(0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Order Belum Siap Dikirim',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tandai order ini sebagai siap dikirim sebelum mengunggah bukti pengiriman.',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed:
                          _isLoadingReadyToShip ? null : _markReadyToShip,
                      icon: _isLoadingReadyToShip
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: primaryDark,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.local_shipping,
                              color: primaryDark),
                      label: Text(
                        _isLoadingReadyToShip
                            ? 'Memproses...'
                            : 'Tandai Siap Dikirim',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldAccent,
                        foregroundColor: primaryDark,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (canSubmitDelivery) ...[
            Card(
              color: cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: goldAccent.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kirim Bukti Pengiriman',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: goldAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGoldTextField(
                      labelText: 'Nama Penerima (Opsional)',
                      controller: _receiverController,
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    if (_imageFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: Text(
                        _imageFile == null
                            ? 'Ambil Foto Bukti Pengiriman'
                            : 'Ambil Ulang Foto',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: goldAccent.withOpacity(0.4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _imageFile == null
                          ? null
                          : () {
                              if (!_isLoadingSubmit) {
                                _submitDelivery();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldAccent,
                        foregroundColor: primaryDark,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoadingSubmit
                          ? const CircularProgressIndicator(color: primaryDark)
                          : const Text(
                              'Kirim Bukti Pengiriman',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Builder(builder: (context) {
              final isStatusTwo = deliveryStatus == 2;
              return Card(
                color: isStatusTwo
                    ? const Color(0xFF142B1A)
                    : const Color(0xFF1F2E35),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isStatusTwo ? Colors.green : goldAccent,
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        isStatusTwo ? Icons.check_circle : Icons.local_shipping,
                        color: isStatusTwo ? Colors.green : goldAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isStatusTwo
                              ? 'Orderan ini sudah divalidasi oleh admin dan tidak dapat diubah lagi.'
                              : 'Orderan ini sudah dikirim.',
                          style: TextStyle(
                            color: isStatusTwo ? Colors.green : goldAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: goldAccent.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Data Pengiriman',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: goldAccent,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Silakan ketik atau scan nomor resi pesanan di kolom pencarian di atas untuk memuat rincian pesanan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: textLight),
            ),
          ),
        ],
      ),
    );
  }
}
