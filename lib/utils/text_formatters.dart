import 'package:flutter/services.dart';

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}

/// Formatter isian nominal gaya Indonesia: titik pemisah ribuan dirapikan
/// otomatis, koma sebagai desimal (tombol desimal keyboard lokal), maksimal
/// [decimals] angka di belakang koma. Titik yang diketik satu per satu
/// dianggap niat desimal (pemisah ribuan tidak pernah perlu diketik), jadi
/// "1.5" dan "1,5" sama-sama menjadi 1,5. Baca nilainya dengan
/// [parseAmount].
class CurrencyInputFormatter extends TextInputFormatter {
  final int decimals;

  const CurrencyInputFormatter({this.decimals = 0}) : assert(decimals >= 0);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var raw = newValue.text;

    if (decimals > 0 && raw.length == oldValue.text.length + 1) {
      final typedAt = newValue.selection.baseOffset - 1;
      if (typedAt >= 0 && typedAt < raw.length && raw[typedAt] == '.') {
        raw = raw.replaceRange(typedAt, typedAt + 1, ',');
      }
    }

    final text = formatAmountText(raw, decimals: decimals);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Rapikan teks nominal bebas menjadi "1.234.567,89": hanya digit, koma
/// pertama sebagai desimal, titik lain dibuang lalu dikelompokkan ulang.
String formatAmountText(String raw, {int decimals = 0}) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (cleaned.isEmpty) return '';

  final commaIdx = cleaned.indexOf(',');
  var intDigits = (commaIdx >= 0 ? cleaned.substring(0, commaIdx) : cleaned)
      .replaceAll(RegExp(r'[^0-9]'), '');
  var decDigits = commaIdx >= 0
      ? cleaned.substring(commaIdx + 1).replaceAll(RegExp(r'[^0-9]'), '')
      : '';
  if (decDigits.length > decimals) decDigits = decDigits.substring(0, decimals);

  intDigits = intDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (intDigits.isEmpty && commaIdx >= 0) intDigits = '0';

  final grouped = groupThousands(intDigits);
  if (decimals == 0 || commaIdx < 0) return grouped;
  return '$grouped,$decDigits';
}

/// Sisipkan titik ribuan pada deretan digit: "1234567" → "1.234.567".
String groupThousands(String digits) {
  return digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
}

/// Baca nominal bergaya Indonesia ("Rp 1.234,5", "1.234", "0,78") ke double.
/// Null bila kosong/tidak terbaca.
double? parseAmount(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.'));
}

/// Nominal rupiah utuh dari input terformat; 0 bila kosong/tidak terbaca.
int parseAmountInt(String text) => (parseAmount(text) ?? 0).round();

/// Formatter standar input rupiah (tanpa desimal).
const List<TextInputFormatter> rupiahInputFormatters = [
  CurrencyInputFormatter(),
];

/// Formatter standar input valuta asing (2 desimal, gaya Indonesia).
const List<TextInputFormatter> foreignInputFormatters = [
  CurrencyInputFormatter(decimals: 2),
];
