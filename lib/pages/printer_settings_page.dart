import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/printer_provider.dart';
import '../services/thermal_printer_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_app_bar.dart';

/// Halaman pengaturan printer thermal untuk cetak stiker.
///
/// Printer dihubungkan melalui **WiFi/jaringan** (ESC/POS over TCP, port 9100).
///
/// Pengguna dapat:
/// - Mengaktifkan/menonaktifkan fitur thermal printer
/// - Mengatur ukuran kertas stiker (mm)
/// - Mengatur IP & port printer + mengetes koneksi
/// - Mencetak halaman tes
class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final _service = ThermalPrinterService.instance;

  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isTestingConnection = false;
  bool _isTesting = false;
  bool? _lastConnectionResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncControllers();
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final p = context.read<PrinterProvider>();
    _widthController.text = p.widthMm.toStringAsFixed(0);
    _heightController.text = p.heightMm.toStringAsFixed(0);
    _ipController.text = p.ip;
    _portController.text = p.port.toString();
    _nameController.text = p.name;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _testConnection() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (ip.isEmpty || port == null) {
      _showSnackBar('IP dan port harus diisi dengan benar.', isError: true);
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _lastConnectionResult = null;
    });

    final ok = await _service.testConnection(ip: ip, port: port);

    if (!mounted) return;
    setState(() {
      _isTestingConnection = false;
      _lastConnectionResult = ok;
    });

    _showSnackBar(
      ok
          ? 'Koneksi berhasil ke $ip:$port.'
          : 'Gagal terhubung ke $ip:$port. Periksa jaringan WiFi.',
      isError: !ok,
    );

    if (ok) {
      context.read<PrinterProvider>().setConnected(true);
    }
  }

  Future<void> _saveNetworkConfig() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final name = _nameController.text.trim();

    if (ip.isEmpty || port == null) {
      _showSnackBar('IP dan port harus diisi dengan benar.', isError: true);
      return;
    }

    await context
        .read<PrinterProvider>()
        .setNetwork(ip: ip, port: port, name: name);

    if (!mounted) return;
    _showSnackBar('Konfigurasi jaringan disimpan.');
  }

  Future<void> _saveDimensions() async {
    final width = double.tryParse(_widthController.text.trim());
    final height = double.tryParse(_heightController.text.trim());

    if (width == null || height == null) {
      _showSnackBar('Ukuran tidak valid. Masukkan angka (mm).', isError: true);
      return;
    }

    await context.read<PrinterProvider>().setSize(widthMm: width, heightMm: height);

    if (!mounted) return;
    _showSnackBar('Ukuran stiker disimpan.');
  }

  Future<void> _testPrint() async {
    final provider = context.read<PrinterProvider>();

    setState(() => _isTesting = true);

    final data = StickerData(
      receiptNo: 'TEST-001',
      storeName: 'Toko Contoh',
      providerName: 'Provider Contoh',
      deliveryServiceName: 'Reguler',
      deliveryDate: DateTime.now().toIso8601String().split('T').first,
      receiverName: 'Penerima Tes',
      items: const [
        StickerItem(productName: 'Produk Demo A', quantity: '2', unit: 'pcs'),
        StickerItem(productName: 'Produk Demo B', quantity: '1'),
      ],
    );

    bool ok;
    String message;

    if (provider.isEnabled) {
      try {
        ok = await _service.printStickerViaWifi(
          data: data,
          ip: provider.ip,
          port: provider.port,
          copies: 1,
        );
        message = ok
            ? 'Tes cetak (WiFi) berhasil ke ${provider.formattedEndpoint}.'
            : 'Tes cetak gagal.';
      } catch (e) {
        ok = false;
        message = e.toString();
      }
    } else {
      ok = await _service.printStickerViaSpooler(
        data: data,
        widthMm: provider.widthMm,
        heightMm: provider.heightMm,
        fontSize: provider.fontSize,
        docName: 'tes-stiker',
      );
      message = ok ? 'Tes cetak (spooler) sudah dikirim.' : 'Tes cetak gagal.';
    }

    if (!mounted) return;
    setState(() => _isTesting = false);
    _showSnackBar(message, isError: !ok);
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    showAppSnackBar(
      context,
      message,
      background: isError ? AppColors.error : AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('PENGATURAN PRINTER STIKER')),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<PrinterProvider>(
          builder: (context, provider, _) {
            return ListView(
              padding: AppSpacing.paddingMD.copyWith(
                  top: AppBarInsets.top(context)),
              children: [
                _buildEnableSection(provider, colorScheme, textTheme),
                AppSpacing.gapVerticalMD,
                _buildNetworkSection(provider, colorScheme, textTheme),
                AppSpacing.gapVerticalMD,
                _buildSizeSection(provider, colorScheme, textTheme),
                AppSpacing.gapVerticalMD,
                _buildFontSizeSection(provider, colorScheme, textTheme),
                AppSpacing.gapVerticalMD,
                _buildCopiesSection(provider, colorScheme, textTheme),
                AppSpacing.gapVerticalLG,
                _buildTestButton(colorScheme, textTheme),
                AppSpacing.gapVerticalLG,
                _buildInfoCard(colorScheme, textTheme),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _buildEnableSection(PrinterProvider provider, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Row(
          children: [
            Icon(Icons.print, color: AppColors.info),
            AppSpacing.gapHorizontalSM,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cetak Stiker Thermal (WiFi)',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.gapVerticalXS,
                  Text(
                    'Aktifkan untuk mencetak resi berbentuk stiker via '
                    'thermal printer yang terhubung WiFi.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: provider.isEnabled,
              activeTrackColor: colorScheme.primary,
              onChanged: (v) => provider.setEnabled(v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSection(PrinterProvider provider, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: colorScheme.primary, size: 20),
                AppSpacing.gapHorizontalSM,
                Expanded(
                  child: Text(
                    'Koneksi Jaringan (WiFi)',
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                if (provider.isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: AppSpacing.borderRadiusSM,
                    ),
                    child: Text(
                      'Terhubung',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.gapVerticalXS,
            Text(
              'Masukkan IP address & port printer thermal. Port standar '
              'ESC/POS adalah 9100. Pastikan printer dan HP berada di WiFi '
              'yang sama.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            TextField(
              controller: _nameController,
              decoration: _fieldDecoration('Nama Printer (opsional)', colorScheme),
              style: textTheme.bodyLarge,
            ),
            AppSpacing.gapVerticalSM,
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('IP Address', colorScheme),
                    style: textTheme.bodyLarge,
                  ),
                ),
                AppSpacing.gapHorizontalSM,
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Port', colorScheme),
                    style: textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTestingConnection ? null : _testConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find, size: 18),
                    label: const Text('Tes Koneksi'),
                    style: AppButtonStyle.outlined(),
                  ),
                ),
                AppSpacing.gapHorizontalSM,
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveNetworkConfig,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan'),
                  ),
                ),
              ],
            ),
            if (_lastConnectionResult != null) ...[
              AppSpacing.gapVerticalSM,
              Row(
                children: [
                  Icon(
                    _lastConnectionResult!
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: _lastConnectionResult!
                        ? AppColors.success
                        : AppColors.error,
                    size: 16,
                  ),
                  AppSpacing.gapHorizontalSM,
                  Text(
                    _lastConnectionResult!
                        ? 'Printer dapat dijangkau.'
                        : 'Printer tidak dapat dijangkau.',
                    style: textTheme.labelSmall?.copyWith(
                      color: _lastConnectionResult!
                          ? AppColors.success
                          : colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection(PrinterProvider provider, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ukuran Stiker',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            AppSpacing.gapVerticalXS,
            Text(
              'Sesuaikan dengan media stiker (millimeter). '
              'Default: 100 x 150 mm (akan dikonfirmasi ulang).',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('Lebar (mm)', colorScheme),
                    style: textTheme.bodyLarge,
                  ),
                ),
                Padding(
                  padding: AppSpacing.paddingHorizontalSM,
                  child: Text('x', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('Tinggi (mm)', colorScheme),
                    style: textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saveDimensions,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Simpan Ukuran'),
                style: AppButtonStyle.outlined(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeSection(PrinterProvider provider, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ukuran Font Stiker',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            AppSpacing.gapVerticalSM,
            Row(
              children: [
                Text(
                  provider.fontSize.toStringAsFixed(0),
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Slider(
                    min: PrinterConstants.minFontSize,
                    max: PrinterConstants.maxFontSize,
                    divisions: (PrinterConstants.maxFontSize -
                            PrinterConstants.minFontSize)
                        .round(),
                    value: provider.fontSize,
                    activeColor: colorScheme.primary,
                    onChanged: (v) => provider.setFontSize(v.roundToDouble()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopiesSection(PrinterProvider provider, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Row(
          children: [
            Icon(Icons.copy_all, color: AppColors.info),
            AppSpacing.gapHorizontalSM,
            Expanded(
              child: Text(
                'Jumlah Rangkap',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Kurangi',
              icon: Icon(Icons.remove_circle_outline, color: AppColors.info),
              onPressed: provider.copies <= PrinterConstants.minCopies
                  ? null
                  : () => provider.setCopies(provider.copies - 1),
            ),
            Text(
              '${provider.copies}',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'Tambah',
              icon: Icon(Icons.add_circle_outline, color: AppColors.info),
              onPressed: provider.copies >= PrinterConstants.maxCopies
                  ? null
                  : () => provider.setCopies(provider.copies + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isTesting ? null : _testPrint,
        icon: _isTesting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.receipt_long),
        label: Text(_isTesting ? 'Mencetak tes...' : 'Cetak Tes Stiker'),
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.info, size: 18),
            AppSpacing.gapHorizontalSM,
            Expanded(
              child: Text(
                'Catatan: printer thermal hanya dapat dihubungkan via WiFi '
                '(ESC/POS port 9100). Fitur ini tambahan dan tidak menggantikan '
                'cetak A4 yang sudah ada. Ukuran stiker akan dikonfirmasi lagi '
                'setelah hardware tersedia.',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, ColorScheme colorScheme) {
    return InputDecoration(
      labelText: label,
    );
  }
}
