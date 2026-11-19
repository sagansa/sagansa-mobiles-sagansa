import 'package:flutter/material.dart';

import '../models/import_model.dart';
import '../services/import_service.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/mete_pricing.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

/// Informasi Harga Jual kacang mete (fase tampilan — tidak tersimpan ke
/// server, tidak mengubah master produk).
///
/// Dari HPP terbaru tiap produk hasil impor (realisasi bila tersedia,
/// fallback estimasi), harga per kemasan dihitung dengan konfigurasi mete:
/// 10kg = HPP × (1 + margin jangkar) dibulat ke atas ke Rp1.000; 1kg/100kg/
/// 1 ton = persentase dari harga 10kg, dibulat ke terdekat. Persentase bisa
/// diatur manual per produk (tersimpan di perangkat) — default 40/130/90/80.
class ImportSellingPricePage extends StatefulWidget {
  const ImportSellingPricePage({super.key});

  @override
  State<ImportSellingPricePage> createState() => _ImportSellingPricePageState();
}

class _ImportSellingPricePageState extends State<ImportSellingPricePage> {
  final ImportService _service = ImportService();
  final MetePricingStore _pricing = MetePricingStore.instance;

  List<ImportProductPriceTrend> _trends = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _pricing.load();
      final trends = await _service.getPriceTrends();
      if (!mounted) return;
      setState(() {
        // Produk dengan titik terbaru (realisasi lebih dulu) di atas.
        _trends = trends.where((t) => t.latest != null).toList()
          ..sort((a, b) {
            final al = a.latest!, bl = b.latest!;
            final byDate = (bl.date ?? DateTime(1900))
                .compareTo(al.date ?? DateTime(1900));
            if (byDate != 0) return byDate;
            if (al.isRealized != bl.isRealized) {
              return al.isRealized ? -1 : 1;
            }
            return a.productName.compareTo(b.productName);
          });
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _editConfig(ImportProductPriceTrend trend) async {
    final base = meteBaseName(trend.productName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PricingConfigDialog(
        productName: trend.productName,
        initial: _pricing.configFor(base),
        hasOverride: _pricing.hasOverride(base),
      ),
    );
    if (saved == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Harga Jual (Info)',
      isLoading: _isLoading,
      errorMessage: _error,
      onRetry: _load,
      isEmpty: _trends.isEmpty && !_isLoading && _error == null,
      emptyState: EmptyState(
        icon: Icons.sell_outlined,
        title: 'Belum ada data pembelian impor',
        subtitle:
            'Harga jual info dihitung dari HPP hasil proses impor — buat '
            'proses impor terlebih dahulu.',
      ),
      body: Builder(
        builder: (bodyContext) => RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: AppBarInsets.top(bodyContext) + AppSpacing.md,
              bottom: AppSpacing.xl,
            ),
            itemCount: _trends.length,
            itemBuilder: (context, index) => _buildCard(context, _trends[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, ImportProductPriceTrend trend) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final latest = trend.latest!;
    final hpp = latest.unitPriceIdr;
    final base = meteBaseName(trend.productName);
    final config = _pricing.configFor(base);
    final manual = _pricing.hasOverride(base);
    final prices = metePriceList(hpp, config);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SectionCard(
        title: trend.productName,
        icon: Icons.inventory_2_outlined,
        margin: EdgeInsets.zero,
        actions: [
          StatusBadge(
            label: latest.isRealized ? 'Realisasi' : 'Estimasi',
            type: latest.isRealized ? StatusType.success : StatusType.neutral,
          ),
          if (manual)
            const StatusBadge(label: 'Manual', type: StatusType.info),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: const Icon(Icons.tune_rounded),
              iconSize: 20,
              padding: EdgeInsets.zero,
              tooltip: 'Atur persentase produk ini',
              onPressed: () => _editConfig(trend),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HPP ${latest.isRealized ? 'realisasi' : 'estimasi'} terbaru: '
              '${FormatUtils.formatRupiah(hpp)}/${trend.unitName.isEmpty ? 'unit' : trend.unitName}'
              '${latest.date == null ? '' : ' (${FormatUtils.formatDate(latest.date!)})'}',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            AppSpacing.gapVerticalSM,

            // Grid 2×2: jangkar 10kg ditonjolkan; kemasan lain turunannya
            // dengan persentase aktif (default atau aturan manual produk).
            // IntrinsicHeight: Row+stretch butuh tinggi terukur agar kotak
            // kemasan sama tinggi (ListView memberi tinggi tak terbatas).
            for (var i = 0; i < kMetePackOrder.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = 0; j < 2; j++)
                        Expanded(
                          child: _packTile(
                            context,
                            pack: kMetePackOrder[i + j],
                            price: prices[kMetePackOrder[i + j]] ?? 0,
                            config: config,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _packTile(
    BuildContext context, {
    required String pack,
    required double price,
    required MetePricingConfig config,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isAnchor = pack == '10kg';
    final accent = colorScheme.primary;

    return Container(
      margin: EdgeInsets.only(
        left: isAnchor ? 0 : AppSpacing.xs,
        right: isAnchor ? AppSpacing.xs : 0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: isAnchor ? accent.withValues(alpha: 0.08) : null,
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(
          color: isAnchor
              ? accent.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kMetePackLabel(pack),
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isAnchor ? accent : colorScheme.onSurfaceVariant,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              price > 0 ? FormatUtils.formatRupiah(price) : '—',
              maxLines: 1,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isAnchor ? accent : colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            isAnchor
                ? 'HPP +${FormatUtils.formatAmount(config.anchorMarginPercent, decimals: 0)}%'
                : '${FormatUtils.formatAmount(config.ratioPercent(pack), decimals: 0)}% dari 10kg',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog pengaturan persentase harga jual satu produk. Persentase disimpan
/// di perangkat (fase informasi) dan langsung dipakai semua tampilan harga.
class _PricingConfigDialog extends StatefulWidget {
  const _PricingConfigDialog({
    required this.productName,
    required this.initial,
    required this.hasOverride,
  });

  final String productName;
  final MetePricingConfig initial;
  final bool hasOverride;

  @override
  State<_PricingConfigDialog> createState() => _PricingConfigDialogState();
}

class _PricingConfigDialogState extends State<_PricingConfigDialog> {
  late final TextEditingController _margin;
  late final TextEditingController _r1kg;
  late final TextEditingController _r100kg;
  late final TextEditingController _r1ton;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    String fmt(double v) =>
        FormatUtils.formatAmount(v, decimals: 0, trimZeros: true);
    _margin = TextEditingController(text: fmt(c.anchorMarginPercent));
    _r1kg = TextEditingController(text: fmt(c.ratio1kgPercent));
    _r100kg = TextEditingController(text: fmt(c.ratio100kgPercent));
    _r1ton = TextEditingController(text: fmt(c.ratio1tonPercent));
  }

  @override
  void dispose() {
    _margin.dispose();
    _r1kg.dispose();
    _r100kg.dispose();
    _r1ton.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = meteBaseName(widget.productName);
    final config = MetePricingConfig(
      anchorMarginPercent: parseAmount(_margin.text) ?? 40,
      ratio1kgPercent: parseAmount(_r1kg.text) ?? 130,
      ratio100kgPercent: parseAmount(_r100kg.text) ?? 90,
      ratio1tonPercent: parseAmount(_r1ton.text) ?? 80,
    );
    await MetePricingStore.instance.save(base, config);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    final base = meteBaseName(widget.productName);
    await MetePricingStore.instance.reset(base);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Persentase Harga Jual'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.productName,
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              AppSpacing.gapVerticalXS,
              Text(
                'Berlaku untuk semua kemasan grade ini, di halaman harga, '
                'detail impor, dan info Penjualan. Tersimpan di perangkat.',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              AppSpacing.gapVerticalMD,
              TextField(
                controller: _margin,
                keyboardType: TextInputType.number,
                inputFormatters: const [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Margin 10kg (%)',
                  suffixText: '%',
                  helperText: 'Atas HPP, dibulat ke atas',
                  isDense: true,
                ),
              ),
              AppSpacing.gapVerticalSM,
              TextField(
                controller: _r1kg,
                keyboardType: TextInputType.number,
                inputFormatters: const [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: '1kg (% dari 10kg)',
                  suffixText: '%',
                  isDense: true,
                ),
              ),
              AppSpacing.gapVerticalSM,
              TextField(
                controller: _r100kg,
                keyboardType: TextInputType.number,
                inputFormatters: const [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: '100kg (% dari 10kg)',
                  suffixText: '%',
                  isDense: true,
                ),
              ),
              AppSpacing.gapVerticalSM,
              TextField(
                controller: _r1ton,
                keyboardType: TextInputType.number,
                inputFormatters: const [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: '1 ton (% dari 10kg)',
                  suffixText: '%',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.hasOverride)
          TextButton(
            onPressed: _reset,
            child: const Text('Reset ke Default'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
