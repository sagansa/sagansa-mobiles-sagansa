/// Aturan harga jual kacang mete — FASE TAMPILAN INFORMASI.
///
/// Harga dihitung dari HPP pembelian impor (realisasi bila tersedia,
/// fallback estimasi) memakai konfigurasi di file ini; hasilnya murni
/// informasi — tidak tersimpan ke server dan tidak mengubah master produk.
/// Persentase (margin jangkar & rasio kemasan) bisa diatur manual per
/// produk/grade lewat [MetePricingStore] (tersimpan di perangkat).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Granularitas pembulatan harga (kelipatan Rp1.000). Jangkar dibulat ke
/// ATAS agar margin aktual tidak jatuh di bawah target; kemasan turunan
/// dibulatkan ke terdekat — mengikuti pola harga pada sheet HPP:
/// 31.000 → 1kg 40.300→40.000, 100kg 27.900→28.000, 1 ton 24.800→25.000.
const double kSellingPriceRoundStep = 1000;

/// Urutan kemasan untuk tampilan daftar harga.
const List<String> kMetePackOrder = ['10kg', '1kg', '100kg', '1ton'];

/// Label tampilan kemasan ("1ton" tampil sebagai "1 ton").
String kMetePackLabel(String pack) => pack == '1ton' ? '1 ton' : pack;

/// Konfigurasi persentase harga jual mete. Default mengikat: margin
/// jangkar 10kg 40% atas HPP; 1kg/100kg/1 ton = 130%/90%/80% dari harga
/// 10kg. Semua nilai dapat diatur manual per produk (per grade).
class MetePricingConfig {
  final double anchorMarginPercent;
  final double ratio1kgPercent;
  final double ratio100kgPercent;
  final double ratio1tonPercent;

  const MetePricingConfig({
    this.anchorMarginPercent = 40,
    this.ratio1kgPercent = 130,
    this.ratio100kgPercent = 90,
    this.ratio1tonPercent = 80,
  });

  static const MetePricingConfig defaults = MetePricingConfig();

  /// Persentase harga kemasan terhadap harga 10kg ('10kg' = 100).
  double ratioPercent(String pack) => switch (pack) {
        '1kg' => ratio1kgPercent,
        '100kg' => ratio100kgPercent,
        '1ton' => ratio1tonPercent,
        _ => 100,
      };

  Map<String, dynamic> toJson() => {
        'anchor_margin': anchorMarginPercent,
        'ratio_1kg': ratio1kgPercent,
        'ratio_100kg': ratio100kgPercent,
        'ratio_1ton': ratio1tonPercent,
      };

  factory MetePricingConfig.fromJson(Map<String, dynamic> json) {
        double parse(String key, double fallback) =>
            double.tryParse(json[key]?.toString() ?? '') ?? fallback;
        return MetePricingConfig(
          anchorMarginPercent: parse('anchor_margin', 40),
          ratio1kgPercent: parse('ratio_1kg', 130),
          ratio100kgPercent: parse('ratio_100kg', 90),
          ratio1tonPercent: parse('ratio_1ton', 80),
        );
      }
}

/// Override konfigurasi per grade (base name produk) — fase informasi,
/// melekat di perangkat (SharedPreferences), bukan di server.
class MetePricingStore {
  MetePricingStore._();

  static final MetePricingStore instance = MetePricingStore._();

  static const String _prefsKey = 'mete_pricing_overrides';

  final Map<String, MetePricingConfig> _overrides = {};
  bool _loaded = false;

  /// Muat override tersimpan sekali per sesi; aman dipanggil berulang.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is Map<String, dynamic>) {
              _overrides[entry.key] = MetePricingConfig.fromJson(value);
            }
          }
        }
      }
    } catch (_) {
      // Preferensi rusak ≠ fatal — pakai default.
    }
    _loaded = true;
  }

  /// Konfigurasi aktif untuk satu grade: override manual bila ada,
  /// selebihnya default 40/130/90/80.
  MetePricingConfig configFor(String base) =>
      _overrides[base] ?? MetePricingConfig.defaults;

  bool hasOverride(String base) => _overrides.containsKey(base);

  Future<void> save(String base, MetePricingConfig config) async {
    _overrides[base] = config;
    await _persist();
  }

  Future<void> reset(String base) async {
    _overrides.remove(base);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final entry in _overrides.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    } catch (_) {
      // Gagal menulis preferensi tidak boleh merusak tampilan.
    }
  }
}

/// Harga jangkar 10kg = HPP × (1 + margin), dibulat ke atas ke Rp1.000.
double meteAnchorPrice(
  double hpp,
  MetePricingConfig config,
) {
  if (hpp <= 0) return 0;
  final raw = hpp * (1 + config.anchorMarginPercent / 100);
  return (raw / kSellingPriceRoundStep).ceil() * kSellingPriceRoundStep;
}

/// Harga satu kemasan dari harga jangkar; '10kg' = jangkar itu sendiri;
/// kemasan tanpa aturan mengembalikan 0. Dibulat ke Rp1.000 terdekat.
double metePackPrice(double anchor, String pack, MetePricingConfig config) {
  if (anchor <= 0) return 0;
  if (pack == '10kg') return anchor;
  if (!kMetePackOrder.contains(pack)) return 0;
  return (anchor * config.ratioPercent(pack) / 100 / kSellingPriceRoundStep)
          .roundToDouble() *
      kSellingPriceRoundStep;
}

/// Daftar harga jual semua kemasan dari satu HPP pembelian.
Map<String, double> metePriceList(double hpp, MetePricingConfig config) {
  final anchor = meteAnchorPrice(hpp, config);
  return {
    for (final pack in kMetePackOrder) pack: metePackPrice(anchor, pack, config),
  };
}

final RegExp _packPattern = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(kg|ton)\b',
  caseSensitive: false,
);

/// Kemasan dari nama produk, normal tanpa spasi: "1kg", "10kg", "100kg",
/// "1ton"; null bila tak ada pola kg/ton (mis. "500 gram").
String? metePackOf(String productName) {
  final m = _packPattern.firstMatch(productName);
  if (m == null) return null;
  return '${m.group(1)!.replaceAll(',', '.')}${m.group(2)!.toLowerCase()}';
}

/// Nama produk tanpa token kemasan — kunci memasangkan varian kemasan dari
/// grade yang sama ("Mete Menir - BB2 (1kg)" ≡ "Mete Menir - BB2 (10kg)").
String meteBaseName(String productName) => productName
    .toLowerCase()
    .replaceAll(_packPattern, '')
    .replaceAll(RegExp(r'\(\s*\)'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Harga jual (informasi) sebuah produk: dari HPP pembelian grade yang
/// sama, kemasan produk dihargai sesuai rasionya terhadap 10kg; produk
/// tanpa token kemasan memakai harga jangkar.
double meteInfoPrice(
  double hpp,
  String productName,
  MetePricingConfig config,
) {
  final pack = metePackOf(productName);
  if (pack == null || pack == '10kg') return meteAnchorPrice(hpp, config);
  return metePackPrice(meteAnchorPrice(hpp, config), pack, config);
}
