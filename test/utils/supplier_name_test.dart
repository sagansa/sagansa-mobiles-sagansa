import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/utils/supplier_name.dart';

void main() {
  group('formatSupplierName', () {
    test('akronim yang didefinisikan tetap kapital penuh', () {
      expect(formatSupplierName('SPBU'), 'SPBU');
      expect(formatSupplierName('Spbu Pertamina'), 'SPBU Pertamina');
      expect(formatSupplierName('Pt Karya Baru Indonesia'),
          'PT Karya Baru Indonesia');
      expect(formatSupplierName('cv maju jaya'), 'CV Maju Jaya');
    });

    test('setiap kata memakai huruf kapital di awal', () {
      expect(formatSupplierName('PT SUMBER MAKMUR'), 'PT Sumber Makmur');
      expect(formatSupplierName('lele adi'), 'Lele Adi');
      expect(formatSupplierName('Kios Sayur Rodi'), 'Kios Sayur Rodi');
    });

    test('nilai kosong tetap kosong', () {
      expect(formatSupplierName(''), '');
      expect(formatSupplierName('   '), '');
    });
  });
}
