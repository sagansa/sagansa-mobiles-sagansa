import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/utils/format_utils.dart';
import 'package:sagansa/utils/text_formatters.dart';

/// Simulasi ketikan satu karakter di ujung teks (seperti keyboard).
TextEditingValue _type(
  CurrencyInputFormatter f,
  String current,
  String char,
) {
  final next = '$current$char';
  return f.formatEditUpdate(
    TextEditingValue(
      text: current,
      selection: TextSelection.collapsed(offset: current.length),
    ),
    TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    ),
  );
}

TextEditingValue _paste(CurrencyInputFormatter f, String text) {
  return f.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
}

void main() {
  group('CurrencyInputFormatter — harga valuta 2 desimal', () {
    const f = CurrencyInputFormatter(decimals: 2);

    test('koma dari keyboard Indonesia diterima sebagai desimal', () {
      var v = _type(f, '', '0');
      v = _type(f, v.text, ',');
      expect(v.text, '0,');
      v = _type(f, v.text, '7');
      v = _type(f, v.text, '8');
      expect(v.text, '0,78');
      expect(parseAmount(v.text), 0.78);
    });

    test('titik yang diketik satu per satu dianggap desimal', () {
      var v = _type(f, '1', '.');
      expect(v.text, '1,');
      v = _type(f, v.text, '5');
      expect(v.text, '1,5');
      expect(parseAmount(v.text), 1.5);
    });

    test('desimal dibatasi dua digit', () {
      final v = _type(f, '0,78', '9');
      expect(v.text, '0,78');
    });

    test('pemisah desimal kedua diabaikan', () {
      final v = _type(f, '1,5', ',');
      expect(v.text, '1,5');
    });

    test('ribuan dikelompokkan otomatis dengan titik', () {
      var v = _type(f, '', '1');
      for (final c in '250000'.split('')) {
        v = _type(f, v.text, c);
      }
      expect(v.text, '1.250.000');
      v = _type(f, v.text, ',');
      v = _type(f, v.text, '5');
      expect(v.text, '1.250.000,5');
      expect(parseAmount(v.text), 1250000.5);
    });

    test('tempel teks bergaya Indonesia dibaca utuh', () {
      final v = _paste(f, '1.250.000,50');
      expect(v.text, '1.250.000,50');
      expect(parseAmount(v.text), 1250000.5);
    });

    test('koma di awal menjadi 0,', () {
      final v = _type(f, '', ',');
      expect(v.text, '0,');
    });

    test('karakter non-angka dibuang', () {
      final v = _paste(f, 'Rp 12a3');
      expect(v.text, '123');
    });
  });

  group('CurrencyInputFormatter — rupiah bulat', () {
    const f = CurrencyInputFormatter();

    test('koma/titik tidak menghasilkan desimal', () {
      var v = _type(f, '350000000', ',');
      expect(v.text, '350.000.000');
      v = _type(f, '350000000', '.');
      expect(v.text, '350.000.000');
      expect(parseAmount(v.text), 350000000);
    });

    test('ratusan juta dan miliar terkelompok rapi', () {
      expect(_paste(f, '1234567890').text, '1.234.567.890');
      expect(parseAmount('1.234.567.890'), 1234567890);
    });
  });

  group('parseAmount', () {
    test('kosong → null, teks tak terbaca → null', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount('abc'), isNull);
    });

    test('menerima "Rp" dan spasi', () {
      expect(parseAmount('Rp 17.545,5'), 17545.5);
    });
  });

  group('FormatUtils.formatAmount / formatRupiah', () {
    test('desimal nol dibuang, selain itu dipertahankan', () {
      expect(FormatUtils.formatAmount(17545, decimals: 2), '17.545');
      expect(FormatUtils.formatAmount(17545.5, decimals: 2), '17.545,5');
      expect(FormatUtils.formatAmount(0.78, decimals: 2), '0,78');
      expect(FormatUtils.formatAmount(2.5, decimals: 3), '2,5');
    });

    test('rupiah utuh untuk ratusan juta dan miliar', () {
      expect(FormatUtils.formatRupiah(417099315), 'Rp 417.099.315');
      expect(FormatUtils.formatRupiah(1234567890.4), 'Rp 1.234.567.890');
    });

    test('prefill → formatter → parse pulang-pergi tanpa kehilangan nilai',
        () {
      const f = CurrencyInputFormatter(decimals: 2);
      final shown = FormatUtils.formatAmount(0.78, decimals: 2);
      expect(_paste(f, shown).text, shown);
      expect(parseAmount(shown), 0.78);
    });

    test('ringkas: miliar / juta / ribu', () {
      expect(FormatUtils.formatRupiahCompact(1234567890), 'Rp 1,23 M');
      expect(FormatUtils.formatRupiahCompact(417099315), 'Rp 417,1 jt');
      expect(FormatUtils.formatRupiahCompact(850000), 'Rp 850 rb');
      expect(FormatUtils.formatRupiahCompact(999), 'Rp 999');
    });
  });
}
