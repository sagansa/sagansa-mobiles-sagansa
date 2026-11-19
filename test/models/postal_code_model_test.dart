import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/supplier_model.dart';

void main() {
  group('PostalCodeModel.fromJson', () {
    // Kolom postal_codes.postal_code bertipe INT di DB, sehingga endpoint
    // region mengirim angka (mis. 24184). Model tidak boleh crash saat
    // mem-parse angka tersebut (dulu: TypeError int as String).
    test('parse postal_code berupa int', () {
      final m = PostalCodeModel.fromJson({'id': 42, 'postal_code': 24184});

      expect(m.id, 42);
      expect(m.postalCode, '24184');
    });

    test('parse postal_code berupa string tetap didukung', () {
      final m = PostalCodeModel.fromJson({'id': 7, 'postal_code': '11510'});

      expect(m.id, 7);
      expect(m.postalCode, '11510');
    });
  });
}
