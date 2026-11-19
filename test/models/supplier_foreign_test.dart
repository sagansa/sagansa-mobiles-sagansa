import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/supplier_model.dart';
import 'package:sagansa/providers/supplier_provider.dart';
import 'package:sagansa/utils/country_catalog.dart';

void main() {
  group('SupplierModel — asal supplier', () {
    test('baris lama tanpa country_code tetap domestik', () {
      final s = SupplierModel.fromJson({
        'id': 1,
        'name': 'PT Sumber Pangan',
        'status': 2,
        'city': {'name': 'Bandung'},
        'bank': {'name': 'BCA'},
      });
      expect(s.isForeign, isFalse);
      expect(s.countryName, '');
      expect(s.cityName, 'Bandung');
      expect(s.bankName, 'BCA');
      expect(s.locationLabel, 'Bandung');
    });

    test('country_code ID eksplisit tetap domestik', () {
      final s = SupplierModel.fromJson({
        'id': 2,
        'name': 'CV Berkah',
        'status': 1,
        'country_code': 'ID',
      });
      expect(s.isForeign, isFalse);
    });

    test('supplier luar negeri membaca kota bebas, bank bebas, SWIFT, valuta',
        () {
      final s = SupplierModel.fromJson({
        'id': 3,
        'name': 'Olam Vietnam Ltd',
        'status': 2,
        'country_code': 'vn',
        'city_name': 'Ho Chi Minh City',
        'currency': 'usd',
        'bank_name': 'Vietcombank',
        'bank_swift_code': 'BFTVVNVX',
        'bank_account_no': 'VN123',
        'bank': null,
        'city': null,
      });
      expect(s.isForeign, isTrue);
      expect(s.countryCode, 'VN');
      expect(s.countryName, 'Vietnam');
      expect(s.currency, 'USD');
      expect(s.cityName, 'Ho Chi Minh City');
      expect(s.bankName, 'Vietcombank');
      expect(s.bankSwiftCode, 'BFTVVNVX');
      expect(s.locationLabel, 'Ho Chi Minh City, Vietnam');
    });

    test('relasi bank lokal diprioritaskan di atas bank_name bebas', () {
      final s = SupplierModel.fromJson({
        'id': 4,
        'name': 'X',
        'status': 1,
        'bank': {'name': 'Mandiri'},
        'bank_name': 'Sisa data lama',
      });
      expect(s.bankName, 'Mandiri');
    });
  });

  group('CountryCatalog', () {
    test('terurut nama Indonesia dan bisa dicari per kode', () {
      final names = CountryCatalog.foreign.map((c) => c.name).toList();
      final sorted = [...names]..sort();
      expect(names, sorted);
      expect(CountryCatalog.byCode('CN')?.name, 'Tiongkok');
      expect(CountryCatalog.byCode('id'), CountryCatalog.indonesia);
      expect(CountryCatalog.byCode('ZZ'), isNull);
      expect(CountryCatalog.isForeign(null), isFalse);
      expect(CountryCatalog.isForeign(''), isFalse);
      expect(CountryCatalog.isForeign('ID'), isFalse);
      expect(CountryCatalog.isForeign('VN'), isTrue);
    });

    test('kode negara unik', () {
      final codes = CountryCatalog.foreign.map((c) => c.code).toSet();
      expect(codes.length, CountryCatalog.foreign.length);
      expect(codes.contains('ID'), isFalse);
    });

    test('CurrencyCatalog.withCode menyisipkan kode asing', () {
      expect(CurrencyCatalog.withCode(null), CurrencyCatalog.codes);
      expect(CurrencyCatalog.withCode('USD'), CurrencyCatalog.codes);
      expect(CurrencyCatalog.withCode('XYZ').first, 'XYZ');
    });
  });

  group('SupplierProvider.buildPayload', () {
    test('luar negeri: kirim negara/kota/valuta/bank LN, tanpa wilayah lokal',
        () {
      final p = SupplierProvider();
      p.nameController.text = 'Olam Vietnam Ltd';
      p.addressController.text = 'Jl. Nguyen Hue 1';
      p.cityNameController.text = 'Ho Chi Minh City';
      p.bankNameController.text = 'Vietcombank';
      p.bankSwiftController.text = 'bftvvnvx';
      p.setForeign(true);
      p.setCountry(CountryCatalog.byCode('VN'));

      final payload = p.buildPayload();
      expect(payload['country_code'], 'VN');
      expect(payload['city_name'], 'Ho Chi Minh City');
      expect(payload['currency'], 'VND');
      expect(payload['bank_name'], 'Vietcombank');
      expect(payload['bank_swift_code'], 'BFTVVNVX');
      expect(payload.containsKey('province_id'), isFalse);
      expect(payload.containsKey('qris'), isFalse);
      p.dispose();
    });

    test('valuta mengikuti negara sampai diubah manual', () {
      final p = SupplierProvider();
      p.setForeign(true);
      p.setCountry(CountryCatalog.byCode('VN'));
      expect(p.form.currency, 'VND');
      p.setCountry(CountryCatalog.byCode('IN'));
      expect(p.form.currency, 'INR');
      p.setCurrency('USD');
      p.setCountry(CountryCatalog.byCode('CN'));
      expect(p.form.currency, 'USD');
      p.dispose();
    });

    test('edit supplier LN: controller & state terisi dari model', () {
      final s = SupplierModel.fromJson({
        'id': 3,
        'name': 'Olam Vietnam Ltd',
        'status': 2,
        'country_code': 'VN',
        'city_name': 'Ho Chi Minh City',
        'currency': 'USD',
        'bank_name': 'Vietcombank',
        'bank_swift_code': 'BFTVVNVX',
      });
      final p = SupplierProvider(editingSupplier: s);
      expect(p.form.isForeign, isTrue);
      expect(p.form.selectedCountry?.code, 'VN');
      expect(p.form.currency, 'USD');
      expect(p.cityNameController.text, 'Ho Chi Minh City');
      expect(p.bankNameController.text, 'Vietcombank');
      expect(p.bankSwiftController.text, 'BFTVVNVX');
      p.dispose();
    });
  });
}
