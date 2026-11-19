import 'text_formatters.dart';

class FormatUtils {
  static String formatNumber(num number) {
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final String intPart = number.round().toString();
    final String result = intPart.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    return result;
  }

  static String formatCurrency(num number) {
    return 'Rp ${formatNumber(number)}';
  }

  /// Nominal gaya Indonesia dengan desimal: titik ribuan, koma desimal.
  /// Angka nol di ujung desimal dibuang (`trimZeros`) agar "17.545,00"
  /// tampil sebagai "17.545" namun "0,78" tetap utuh.
  static String formatAmount(num value, {int decimals = 0, bool trimZeros = true}) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(decimals);
    final dot = fixed.indexOf('.');
    final intPart = dot >= 0 ? fixed.substring(0, dot) : fixed;
    var decPart = dot >= 0 ? fixed.substring(dot + 1) : '';
    if (trimZeros) decPart = decPart.replaceFirst(RegExp(r'0+$'), '');
    final grouped = groupThousands(intPart);
    final body = decPart.isEmpty ? grouped : '$grouped,$decPart';
    return negative ? '-$body' : body;
  }

  /// "Rp 1.234.567" — rupiah utuh (desimal sen dibulatkan).
  static String formatRupiah(num value) => 'Rp ${formatAmount(value.round())}';

  /// Ringkas untuk ruang sempit: "Rp 1,23 M", "Rp 417,1 jt", "Rp 850 rb".
  static String formatRupiahCompact(num value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    if (abs >= 1000000000) {
      return '${sign}Rp ${formatAmount(abs / 1000000000, decimals: 2)} M';
    }
    if (abs >= 1000000) {
      return '${sign}Rp ${formatAmount(abs / 1000000, decimals: 1)} jt';
    }
    if (abs >= 1000) {
      return '${sign}Rp ${formatAmount(abs / 1000, decimals: 0)} rb';
    }
    return '${sign}Rp ${formatAmount(abs)}';
  }

  static String formatDate(DateTime date) {
    return '${date.day}-${date.month}-${date.year}';
  }

  static String stripHtml(String html) {
    if (html.isEmpty) return html;
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Compact rupiah formatting for dashboard cards/charts.
  /// Examples: 12500000 → "Rp 12.5jt", 1200000000 → "Rp 1.2M", 5000 → "Rp 5rb".
  static String formatCurrencyCompact(int value) {
    if (value >= 1000000000) {
      return 'Rp ${(value / 1000000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
    }
    if (value >= 1000) {
      return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp $value';
  }
}
