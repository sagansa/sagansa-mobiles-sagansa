import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/import_model.dart';
import '../services/import_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/ios_segmented_control.dart';
import '../widgets/section_card.dart';

/// Tiga kondisi tampilan trend: IDR memakai HPP (nilai barang + biaya);
/// USD/VND memakai harga kontrak invoice per satuan — pembelian beda
/// valuta dikonversi agar setiap seri bisa dibandingkan langsung.
enum _PriceMode { idr, usd, vnd }

/// Trend harga satuan setiap produk dari seluruh proses impor (kecuali
/// dibatalkan). Titik memakai HPP realisasi bila sudah diterima, fallback
/// estimasi.
///
/// Valuta tiap pembelian bisa berbeda (sebagian kontrak USD, sebagian
/// VND). Konversi USD↔VND memakai kurs TERPUSAT dari endpoint
/// /currency-rates: tiap pembelian di-resolve memakai kurs pada
/// tanggalnya (manual admin > referensi publik tanggal itu > publik
/// terdekat > terkini) — server yang mengambil dan meng-cache referensi
/// publik, sehingga konsisten di semua perangkat. Kurs manual diinput
/// lewat tabel kurs dan tersimpan di server. Konversi hanya untuk
/// analisa — data pembelian tidak berubah.
class ImportPriceTrendPage extends StatefulWidget {
  const ImportPriceTrendPage({super.key});

  @override
  State<ImportPriceTrendPage> createState() => _ImportPriceTrendPageState();
}

class _ImportPriceTrendPageState extends State<ImportPriceTrendPage> {
  final ImportService _service = ImportService();

  List<ImportProductPriceTrend> _trends = [];
  bool _isLoading = true;
  String? _error;
  _PriceMode _mode = _PriceMode.idr;

  // Kurs USD → VND dari backend TERPUSAT (endpoint /currency-rates):
  // server me-resolve manual > publik tanggal itu > publik terdekat >
  // terkini, sekaligus mengambil/meng-cache referensi publik ke tabel
  // currency_rates — konsisten di semua perangkat.
  CurrencyRatesResult? _rates;
  bool _ratesLoading = false;
  String? _ratesError;

  /// Penanda versi tabel kurs — bottom sheet tabel mendengarkan ini agar
  /// baris ikut segar saat hasil server tiba.
  final _ratesVersion = ValueNotifier<int>(0);

  void _bumpRates() => _ratesVersion.value++;

  String get _modeCurrency => switch (_mode) {
        _PriceMode.idr => 'IDR',
        _PriceMode.usd => 'USD',
        _PriceMode.vnd => 'VND',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refreshRate = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final trends = await _service.getPriceTrends();
      if (!mounted) return;
      setState(() {
        _trends = [...trends]..sort(_compareByLatestData);
        _isLoading = false;
      });
      if (refreshRate) {
        // Pull-to-refresh: tunggu kurs ikut segar.
        await _fetchRates();
      } else {
        // Buka pertama: kartu tampil dulu; kurs menyusul tanpa menahan
        // render (mode awal IDR tidak butuh kurs).
        unawaited(_fetchRates());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Ambil kurs dari backend untuk tanggal yang butuh konversi pada mode
  /// saat ini — atau semua tanggal valuta bila [allDates] (tabel kurs).
  Future<void> _fetchRates({bool allDates = false}) async {
    final dates = <String>{
      if (allDates)
        ..._foreignDates.keys
      else if (_mode != _PriceMode.idr)
        for (final trend in _trends)
          for (final point in trend.points)
            if (point.currency.toUpperCase() != _modeCurrency &&
                point.date != null)
              _dayKey(point.date!),
    };
    setState(() {
      _ratesLoading = true;
      _ratesError = null;
    });
    try {
      final result = await _service.getUsdVndRates(dates);
      if (!mounted) return;
      setState(() {
        _rates = result;
        _ratesLoading = false;
      });
      _bumpRates();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ratesLoading = false;
        _ratesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Kurs satu titik: resolved per tanggal dari server, jatuh ke kurs
  /// terkini bila tanggalnya tanpa data.
  double? _rateForDate(DateTime? date) {
    final rates = _rates;
    if (rates == null) return null;
    if (date == null) return rates.latestRate;
    return rates.rates[_dayKey(date)]?.rate ?? rates.latestRate;
  }

  /// Simpan/hapus kurs manual satu tanggal ke server ([rate] 0 = hapus,
  /// kembali ke referensi publik). Optimis: tabel ikut segera, kondisi
  /// dikembalikan bila server menolak.
  Future<void> _saveManualRate(String dayKey, double rate) async {
    final previous = _rates;
    try {
      final entry = rate > 0
          ? await _service.saveUsdVndRate(dayKey, rate)
          : await _service.deleteUsdVndRate(dayKey);
      if (!mounted) return;
      setState(() => _rates =
          (previous ?? const CurrencyRatesResult()).withEntry(dayKey, entry));
      _bumpRates();
    } catch (e) {
      if (!mounted) return;
      setState(() => _rates = previous);
      _bumpRates();
      showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Kurs melekat (transaksi) untuk satu tanggal — transaksi pertama
  /// tanggal itu yang punya kurs; null bila semua tanpa kurs.
  double? _embeddedRateForDay(String dayKey) {
    for (final trend in _trends) {
      for (final point in trend.points) {
        if (point.date == null || _dayKey(point.date!) != dayKey) continue;
        final rate = point.usdVndRate;
        if (rate != null && rate > 0) return rate;
      }
    }
    return null;
  }

  /// Kurs efektif + label sumbernya untuk satu baris tabel kurs.
  (double, String) _effectiveRateForDay(String dayKey) {
    final embedded = _embeddedRateForDay(dayKey);
    if (embedded != null) return (embedded, 'Dari transaksi');
    final entry = _rates?.rates[dayKey];
    if (entry != null && entry.rate > 0) {
      final label = switch (entry.source) {
        'manual' => 'Manual',
        'latest' => 'Terkini',
        _ => entry.sourceDate == dayKey ? 'Publik' : 'Publik · terdekat',
      };
      return (entry.rate, label);
    }
    final latest = _rates?.latestRate;
    if (latest != null && latest > 0) return (latest, 'Terkini');
    return (0, '—');
  }

  /// Tanggal-tanggal pembelian valuta USD/VND beserta valuta yang muncul
  /// — baris-baris tabel kurs.
  Map<String, Set<String>> get _foreignDates {
    final map = <String, Set<String>>{};
    for (final trend in _trends) {
      for (final point in trend.points) {
        final currency = point.currency.toUpperCase();
        if ((currency != 'USD' && currency != 'VND') || point.date == null) {
          continue;
        }
        (map[_dayKey(point.date!)] ??= {}).add(currency);
      }
    }
    return map;
  }

  Future<void> _openRateTable() async {
    // Lengkapi kurs semua tanggal valuta (kedua arah) untuk tabel.
    unawaited(_fetchRates(allDates: true));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RateTableSheet(host: this),
    );
  }

  /// Harga kontrak satu titik dalam valuta mode USD/VND, memakai kurs
  /// pada tanggal pembelian tersebut. Null bila titik tidak bisa
  /// dikonversi (beda valuta tanpa kurs sama sekali / valuta di luar
  /// USD-VND) — titik itu dilewati dari seri, bukan dicampur mentah.
  double? _foreignValue(ImportPriceTrendPoint point) {
    final target = _modeCurrency;
    final currency = point.currency.toUpperCase();
    if (currency == target) return point.unitPriceForeign;
    // Kurs yang melekat pada transaksi (diinput saat create) menang
    // atas referensi per tanggal.
    final embedded = point.usdVndRate;
    final rate =
        embedded != null && embedded > 0 ? embedded : _rateForDate(point.date);
    if (rate == null || rate <= 0) return null;
    if (currency == 'USD' && target == 'VND') {
      return point.unitPriceForeign * rate;
    }
    if (currency == 'VND' && target == 'USD') {
      return point.unitPriceForeign / rate;
    }
    return null;
  }

  /// Jumlah titik yang tersembunyi pada mode valuta karena kurs belum
  /// tersedia — ditampilkan sebagai catatan agar tidak terkesan hilang.
  int get _skippedForeignPoints => _mode == _PriceMode.idr
      ? 0
      : _trends.fold(
          0,
          (sum, t) =>
              sum + t.points.where((p) => _foreignValue(p) == null).length,
        );

  /// Urutkan kartu produk dari data terbaru lebih dulu; produk tanpa tanggal
  /// diletakkan di akhir agar daftar yang tampil selalu mulai dari pembelian
  /// terakhir yang tersedia.
  int _compareByLatestData(
    ImportProductPriceTrend a,
    ImportProductPriceTrend b,
  ) {
    final dateA = a.latest?.date;
    final dateB = b.latest?.date;
    if (dateA == null && dateB == null) {
      return a.productName.compareTo(b.productName);
    }
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    final byDate = dateB.compareTo(dateA);
    return byDate != 0 ? byDate : a.productName.compareTo(b.productName);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Trend Harga Satuan',
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
      ),
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: _trends.isEmpty && !_isLoading && _error == null,
      emptyState: const EmptyState(
        icon: Icons.show_chart_rounded,
        title: 'Belum ada data harga',
        subtitle: 'Tambahkan produk pada proses impor untuk melihat trend '
            'harga satuan lintas pembelian.',
      ),
      body: Builder(
        builder: (bodyContext) => RefreshIndicator(
          // Pull-to-refresh ikut menyegarkan kurs publik.
          onRefresh: () => _load(refreshRate: true),
          child: ListView(
            padding: EdgeInsets.only(
              top: AppBarInsets.top(bodyContext) + AppSpacing.md,
              bottom: AppSpacing.xl,
            ),
            children: [
              _buildControls(),
              const SizedBox(height: AppSpacing.sectionGap),
              for (final trend in _trends) ...[
                _TrendCard(
                  trend: trend,
                  currency: _modeCurrency,
                  valueOf: _mode == _PriceMode.idr
                      ? (point) => point.unitPriceIdr
                      : _foreignValue,
                ),
                const SizedBox(height: AppSpacing.sectionGap),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  size: 19,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_trends.length} produk dipantau',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Harga satuan lintas pembelian impor',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: AppSpacing.borderRadiusSM,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: _LegendDot(
                    color: AppColors.success,
                    label: 'Realisasi',
                  ),
                ),
                const Expanded(
                  child: _LegendDot(
                    color: AppColors.warning,
                    label: 'Estimasi',
                  ),
                ),
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Realisasi memakai HPP setelah barang diterima; sebelum itu '
            'estimasi.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          IosSegmentedControl<_PriceMode>(
            segments: const {
              _PriceMode.idr: 'IDR',
              _PriceMode.usd: 'USD',
              _PriceMode.vnd: 'VND',
            },
            groupValue: _mode,
            onValueChanged: (value) {
              setState(() => _mode = value);
              // Mode valuta baru → ambil kurs terpusat untuk tanggal yang
              // dibutuhkan mode itu.
              unawaited(_fetchRates());
            },
            padding: EdgeInsets.zero,
          ),
          if (_mode != _PriceMode.idr)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'IDR = HPP (nilai barang + biaya). $_modeCurrency = harga '
                'kontrak invoice per satuan; pembelian beda valuta '
                'dikonversi ke $_modeCurrency memakai kurs pada tanggal '
                'pembeliannya.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          _buildRateSection(),
        ],
      ),
    );
  }

  /// Baris kurs terkini 1 USD → VND pada mode USD/VND — dari backend
  /// terpusat (server mengambil/meng-cache referensi publik), dengan
  /// tombol segarkan dan pintu ke tabel kurs per tanggal.
  Widget _buildRateSection() {
    if (_mode == _PriceMode.idr) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final latest = _rates?.latestRate;
    final latestDate = _rates?.latestDate;

    final String sourceChip;
    if (latest != null) {
      final date = DateTime.tryParse(latestDate ?? '');
      sourceChip = date == null
          ? 'Publik'
          : 'Publik · ${DateFormat('d MMM', 'id_ID').format(date)}';
    } else if (_ratesLoading) {
      sourceChip = 'Memuat…';
    } else {
      sourceChip = 'Tidak tersedia';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: AppSpacing.borderRadiusSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.currency_exchange_rounded,
                    size: 15,
                    color: latest != null ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Kurs USD → VND',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    sourceChip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: latest != null ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '1 USD =',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      latest == null ? '—' : FormatUtils.formatAmount(latest),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            latest == null ? cs.onSurfaceVariant : cs.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VND',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: _ratesLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 17,
                            tooltip: 'Segarkan kurs',
                            icon: Icon(
                              Icons.refresh_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                            onPressed: () => _fetchRates(),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                latest != null
                    ? 'Konversi tiap pembelian memakai kurs pada tanggalnya '
                        '(manual admin menimpa publik; data publik mulai '
                        '28 Mar 2024, lebih lama memakai tanggal terdekat). '
                        'Tersimpan terpusat — konsisten di semua perangkat.'
                    : _ratesLoading
                        ? 'Mengambil kurs dari server…'
                        : (_ratesError ??
                            'Kurs belum tersedia — coba '
                                'segarkan, atau isi manual lewat tabel kurs.'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              // Tombol aksi di baris sendiri: caption + tombol dalam satu
              // baris membuat caption terjepit sempit dan menjulang.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _openRateTable,
                  child: Text(
                    'Tabel kurs',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              if (_skippedForeignPoints > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$_skippedForeignPoints pembelian valuta lain '
                          'belum ditampilkan — menunggu kurs.',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tabel kurs USD → VND per tanggal pembelian valuta, tersimpan TERPUSAT
/// di server: prefill otomatis dari referensi publik bila tersedia, dan
/// bisa diubah manual (tersimpan ke server — konsisten di semua
/// perangkat). Pembelian lama di luar cakupan data publik (sebelum
/// 28 Mar 2024) diisi tangan di sini.
class _RateTableSheet extends StatefulWidget {
  const _RateTableSheet({required this.host});

  final _ImportPriceTrendPageState host;

  @override
  State<_RateTableSheet> createState() => _RateTableSheetState();
}

class _RateTableSheetState extends State<_RateTableSheet> {
  final _ctrls = <String, TextEditingController>{};

  /// Baris yang sudah disentuh pengguna — isinya tidak ditimpa sync
  /// otomatis lagi (kosong = sengaja kosong, konversi jatuh ke terkini).
  final _dirty = <String>{};

  @override
  void dispose() {
    for (final ctrl in _ctrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = host._foreignDates.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // terbaru dulu

    return ValueListenableBuilder<int>(
      valueListenable: host._ratesVersion,
      builder: (context, _, __) {
        // Controller tiap baris dibuat sekali; baris yang belum disentuh
        // disinkronkan ke kurs efektif (bisa tiba belakangan dari
        // jaringan saat sheet terbuka).
        for (final row in rows) {
          _syncController(row.key);
        }
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.currency_exchange_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kurs USD → VND per tanggal',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Terisi otomatis dari referensi publik; ubah '
                                'angkanya lalu tekan ✓ untuk menyimpan kurs '
                                'manual tanggal itu ke server. Pembelian '
                                'sebelum 28 Mar 2024 diisi tangan.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (host._ratesLoading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Melengkapi kurs publik…',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: rows.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Belum ada pembelian valuta USD/VND — tabel '
                              'terisi setelah proses impor dibuat.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: rows.length,
                            itemBuilder: (_, i) =>
                                _row(rows[i].key, rows[i].value),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Samakan isi field dengan kurs efektif — hanya untuk baris yang
  /// belum disentuh manual.
  void _syncController(String dayKey) {
    final host = widget.host;
    // Baris ber-kurs transaksi bersifat baca-saja — tanpa controller.
    if (host._embeddedRateForDay(dayKey) != null) return;
    final ctrl = _ctrls[dayKey] ??= TextEditingController();
    if (_dirty.contains(dayKey)) return;
    if (host._rates?.rates[dayKey]?.source == 'manual') return;
    final (rate, _) = host._effectiveRateForDay(dayKey);
    final text = rate > 0 ? FormatUtils.formatAmount(rate) : '';
    if (ctrl.text != text) ctrl.text = text;
  }

  /// Simpan perubahan satu baris ke server (0/kosong = hapus manual,
  /// kembali ke publik). Baris yang tak berubah tidak dikirim.
  void _commit(String dayKey, String text) {
    if (!_dirty.contains(dayKey)) return;
    _dirty.remove(dayKey);
    final host = widget.host;
    final rate = parseAmount(text) ?? 0;
    final current = host._rates?.rates[dayKey];
    if (rate > 0 &&
        current != null &&
        current.source == 'manual' &&
        (current.rate - rate).abs() < 0.0001) {
      return; // tidak berubah
    }
    host._saveManualRate(dayKey, rate);
  }

  Widget _row(String dayKey, Set<String> currencies) {
    final host = widget.host;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final date = DateTime.tryParse(dayKey);
    final dateLabel =
        date == null ? dayKey : DateFormat('d MMM yyyy', 'id_ID').format(date);
    final (_, source) = host._effectiveRateForDay(dayKey);
    final manual = host._rates?.rates[dayKey]?.source == 'manual';
    // Garis tepi cream di dark mode jangan terlihat seperti garis putih
    // keras — sama seperti AmountField.
    final borderColor =
        cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.8);
    final sourceColor = manual ? cs.primary : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  (currencies.toList()..sort()).join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      // Kurs melekat pada transaksi (diinput saat create)
                      // — baca-saja; ubah lewat edit proses impor itu.
                      child: host._embeddedRateForDay(dayKey) != null
                          ? Text(
                              FormatUtils.formatAmount(
                                host._embeddedRateForDay(dayKey)!,
                              ),
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            )
                          : TextField(
                              controller: _ctrls[dayKey],
                              keyboardType: TextInputType.number,
                              inputFormatters: const [CurrencyInputFormatter()],
                              textAlign: TextAlign.end,
                              textInputAction: TextInputAction.done,
                              // Simpan ke server saat "selesai"/ketuk di luar —
                              // bukan per ketukan (menghindari spam POST).
                              onSubmitted: (text) {
                                _commit(dayKey, text);
                                FocusScope.of(context).unfocus();
                              },
                              onTapOutside: (_) {
                                _commit(dayKey, _ctrls[dayKey]?.text ?? '');
                                FocusScope.of(context).unfocus();
                              },
                              onChanged: (_) => _dirty.add(dayKey),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor:
                                    cs.surfaceContainerHighest.withValues(
                                  alpha: isDark ? 0.45 : 0.35,
                                ),
                                hintText: 'kurs',
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                suffixText: 'VND',
                                suffixStyle:
                                    theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: AppSpacing.borderRadiusSM,
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: AppSpacing.borderRadiusSM,
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: AppSpacing.borderRadiusSM,
                                  borderSide: BorderSide(
                                    color: cs.primary,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    if (manual)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17),
                        tooltip: 'Kembali ke kurs publik',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _dirty.remove(dayKey);
                          host._saveManualRate(dayKey, 0);
                        },
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusSM,
                    ),
                    child: Text(
                      source,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: sourceColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final ImportProductPriceTrend trend;

  /// Valuta tampilan: 'IDR' (HPP) atau 'USD'/'VND' (harga kontrak).
  final String currency;

  /// Nilai satu titik pada valuta tampilan. Null = titik tidak bisa
  /// dikonversi (valuta lawan tanpa kurs) — dilewati dari seri, dicatat
  /// sebagai catatan di kartu kontrol.
  final double? Function(ImportPriceTrendPoint point) valueOf;

  const _TrendCard({
    required this.trend,
    required this.currency,
    required this.valueOf,
  });

  bool get _isIdr => currency == 'IDR';

  /// VND sama dengan IDR: ribuan bertitik tanpa desimal (dong tanpa
  /// pecahan); USD tetap presi 4 desimal.
  bool get _isVnd => currency == 'VND';

  String _formatValue(double value) => _isIdr
      ? FormatUtils.formatRupiah(value)
      : _isVnd
          ? 'VND ${FormatUtils.formatAmount(value)}'
          : 'USD ${FormatUtils.formatAmount(value, decimals: 4)}';

  String _formatAxis(double value) => _isIdr
      ? FormatUtils.formatRupiahCompact(value)
      : _isVnd
          ? FormatUtils.formatAmount(value)
          : FormatUtils.formatAmount(value, decimals: 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Hanya titik yang punya nilai pada mode ini (IDR selalu punya;
    // USD/VND butuh kurs untuk pembelian valuta lawan).
    final entries = <(ImportPriceTrendPoint, double)>[
      for (final point in trend.points)
        if (valueOf(point) case final value?) (point, value),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    final latest = entries.last.$1;
    final latestValue = entries.last.$2;
    final previous = entries.length > 1 ? entries[entries.length - 2] : null;
    final previousValue = previous?.$2;
    final deltaPercent = previousValue != null && previousValue > 0
        ? (latestValue - previousValue) / previousValue * 100
        : null;
    final unitSuffix = trend.unitName.isEmpty ? '' : ' / ${trend.unitName}';
    final dateLabel = latest.date == null
        ? 'Tanggal tidak tercatat'
        : DateFormat('d MMM yyyy', 'id_ID').format(latest.date!);
    final values = [for (final e in entries) e.$2];
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final avgValue = values.reduce((a, b) => a + b) / values.length;
    final sourceColor =
        latest.isRealized ? AppColors.success : AppColors.warning;

    return SectionCard(
      title: trend.productName,
      icon: Icons.inventory_2_outlined,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Harga terakhir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SourceBadge(
                          label: latest.isRealized ? 'Realisasi' : 'Estimasi',
                          color: sourceColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_formatValue(latestValue)}$unitSuffix',
                        maxLines: 1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dateLabel • ${latest.supplierName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (deltaPercent != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _DeltaChip(percent: deltaPercent),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: AppSpacing.borderRadiusSM,
            ),
            child: Row(
              children: [
                _statColumn(
                  theme,
                  cs,
                  label: 'Terendah',
                  value: _formatValue(minValue),
                ),
                _statDivider(cs),
                _statColumn(
                  theme,
                  cs,
                  label: 'Tertinggi',
                  value: _formatValue(maxValue),
                ),
                _statDivider(cs),
                _statColumn(
                  theme,
                  cs,
                  label: 'Rata-rata',
                  value: _formatValue(avgValue),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_isIdr ? 'Rupiah' : currency} per satuan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${entries.length} pembelian',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 176,
            child: _PriceTrendChart(
              points: [for (final e in entries) e.$1],
              values: values,
              formatAxis: _formatAxis,
              formatValue: _formatValue,
            ),
          ),
          if (entries.length < 2) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Trend akan terbentuk setelah ada pembelian berikutnya.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statColumn(
    ThemeData theme,
    ColorScheme cs, {
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: cs.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _PriceTrendChart extends StatelessWidget {
  /// Titik terplot dan nilainya pada valuta tampilan — sejajar:
  /// values[i] milik points[i].
  final List<ImportPriceTrendPoint> points;
  final List<double> values;
  final String Function(double value) formatAxis;
  final String Function(double value) formatValue;

  const _PriceTrendChart({
    required this.points,
    required this.values,
    required this.formatAxis,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = maxValue - minValue;
    final padding = span > 0 ? span * 0.2 : math.max(maxValue * 0.05, 1.0);
    final minY = math.max(0.0, minValue - padding);
    final maxY = maxValue + padding;
    final yInterval = (maxY - minY) / 3;
    // Hanya label pertama, tengah, dan terakhir yang ditampilkan agar sumbu
    // tanggal tidak berdesakan saat riwayat pembelian panjang.
    final labelIndexes = <int>{
      0,
      points.length ~/ 2,
      points.length - 1,
    };
    final maxAxisChars = formatAxis(maxY).length;
    final yLabelWidth = (maxAxisChars * 5.2).clamp(38.0, 64.0) + AppSpacing.sm;

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final dotColors = points
        .map(
            (point) => point.isRealized ? AppColors.success : AppColors.warning)
        .toList(growable: false);

    return LineChart(
      LineChartData(
        minX: -0.35,
        maxX: points.length <= 1 ? 0.35 : points.length - 0.65,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval > 0 ? yInterval : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: yLabelWidth,
              interval: yInterval > 0 ? yInterval : 1,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  formatAxis(value),
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > 0.001 ||
                    index < 0 ||
                    index >= points.length ||
                    !labelIndexes.contains(index)) {
                  return const SizedBox.shrink();
                }
                final date = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    date == null ? '—' : DateFormat('d/M').format(date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? AppColors.darkSurfaceVariant : AppColors.primary,
            tooltipBorderRadius: BorderRadius.circular(8),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final index = spot.spotIndex;
              if (index < 0 || index >= points.length) return null;
              final point = points[index];
              final date = point.date == null
                  ? '—'
                  : DateFormat('d MMM yyyy', 'id_ID').format(point.date!);
              final color = isDark ? AppColors.darkOnSurface : Colors.white;
              return LineTooltipItem(
                formatValue(values[index]),
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                children: [
                  TextSpan(
                    text: '\n$date • '
                        '${point.isRealized ? 'Realisasi' : 'Estimasi'}'
                        '\n${point.supplierName}',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.78),
                      fontWeight: FontWeight.normal,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: points.length > 2,
            curveSmoothness: 0.18,
            preventCurveOverShooting: true,
            color: cs.primary,
            barWidth: 2.2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isLatest = index == points.length - 1;
                return FlDotCirclePainter(
                  radius: isLatest ? 4.4 : 3.2,
                  color: dotColors[index],
                  strokeWidth: isLatest ? 2 : 1.5,
                  strokeColor: cs.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.primary.withValues(alpha: 0.14),
                  cs.primary.withValues(alpha: 0.01),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double percent;

  const _DeltaChip({required this.percent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final up = percent > 0;
    final color = percent == 0
        ? cs.onSurfaceVariant
        : (up ? cs.error : AppColors.success);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusSM,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            percent == 0
                ? Icons.remove_rounded
                : (up
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${percent > 0 ? '+' : ''}'
            '${FormatUtils.formatAmount(percent, decimals: 1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SourceBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusSM,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
