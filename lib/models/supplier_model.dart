import '../services/image_service.dart';
import '../utils/country_catalog.dart';
import '../utils/supplier_name.dart';

class SupplierModel {
  final int id;
  final String name;
  final String? noTelp;
  final String? address;
  final int? provinceId;
  final String? provinceName;
  final int? cityId;

  /// Nama kota: relasi wilayah Indonesia (domestik) atau isian bebas
  /// `city_name` (luar negeri) — pemakai cukup membaca satu field.
  final String? cityName;
  final int? districtId;
  final String? districtName;
  final int? subdistrictId;
  final String? subdistrictName;
  final int? postalCodeId;
  final String? postalCode;

  /// ISO 3166-1 alpha-2; null/ID = domestik.
  final String? countryCode;

  /// Valuta transaksi default (prefill proses impor), hanya supplier LN.
  final String? currency;
  final int? bankId;

  /// Nama bank: relasi bank lokal (domestik) atau isian bebas (luar negeri).
  final String? bankName;
  final String? bankSwiftCode;
  final String? bankAccountName;
  final String? bankAccountNo;
  final String? qris;
  final int status;
  final String? image;
  String? get imageUrl => ImageService.buildUrl(image);
  final int? userId;
  final String? userName;
  final String? createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.noTelp,
    this.address,
    this.provinceId,
    this.provinceName,
    this.cityId,
    this.cityName,
    this.districtId,
    this.districtName,
    this.subdistrictId,
    this.subdistrictName,
    this.postalCodeId,
    this.postalCode,
    this.countryCode,
    this.currency,
    this.bankId,
    this.bankName,
    this.bankSwiftCode,
    this.bankAccountName,
    this.bankAccountNo,
    this.qris,
    required this.status,
    this.image,
    this.userId,
    this.userName,
    this.createdAt,
  });

  bool get isForeign => CountryCatalog.isForeign(countryCode);

  Country? get country => CountryCatalog.byCode(countryCode);

  String get countryName => CountryCatalog.nameOf(countryCode);

  /// "Ho Chi Minh, Vietnam" / "Bandung" — satu baris lokasi untuk list & picker.
  String get locationLabel {
    final parts = <String>[
      if (cityName != null && cityName!.isNotEmpty) cityName!,
      if (isForeign) countryName,
    ];
    return parts.join(', ');
  }

  String get statusText {
    switch (status) {
      case 1:
        return 'Belum Diperiksa';
      case 2:
        return 'Valid';
      case 3:
        return 'Blacklist';
      default:
        return 'Unknown';
    }
  }

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    // Safe helper: converts any value to String? (null stays null, non-null uses toString)
    String? s(dynamic v) => v?.toString();
    String? blankToNull(String? v) => (v == null || v.isEmpty) ? null : v;

    return SupplierModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: formatSupplierName(s(json['name']) ?? ''),
      noTelp: s(json['no_telp']),
      address: s(json['address']),
      provinceId: json['province_id'] == null
          ? null
          : (json['province_id'] is int
              ? json['province_id']
              : int.tryParse(json['province_id'].toString())),
      provinceName: s(json['province']?['name']),
      cityId: json['city_id'] == null
          ? null
          : (json['city_id'] is int
              ? json['city_id']
              : int.tryParse(json['city_id'].toString())),
      cityName: s(json['city']?['name']) ?? blankToNull(s(json['city_name'])),
      districtId: json['district_id'] == null
          ? null
          : (json['district_id'] is int
              ? json['district_id']
              : int.tryParse(json['district_id'].toString())),
      districtName: s(json['district']?['name']),
      subdistrictId: json['subdistrict_id'] == null
          ? null
          : (json['subdistrict_id'] is int
              ? json['subdistrict_id']
              : int.tryParse(json['subdistrict_id'].toString())),
      subdistrictName: s(json['subdistrict']?['name']),
      postalCodeId: json['postal_code_id'] == null
          ? null
          : (json['postal_code_id'] is int
              ? json['postal_code_id']
              : int.tryParse(json['postal_code_id'].toString())),
      postalCode: s(json['postal_code']?['postal_code']),
      countryCode: blankToNull(s(json['country_code'])?.toUpperCase()),
      currency: blankToNull(s(json['currency'])?.toUpperCase()),
      bankId: json['bank_id'] == null
          ? null
          : (json['bank_id'] is int
              ? json['bank_id']
              : int.tryParse(json['bank_id'].toString())),
      bankName: s(json['bank']?['name']) ?? blankToNull(s(json['bank_name'])),
      bankSwiftCode: blankToNull(s(json['bank_swift_code'])),
      bankAccountName: s(json['bank_account_name']),
      bankAccountNo: s(json['bank_account_no']),
      qris: s(json['qris']),
      status: json['status'] is int
          ? json['status']
          : int.tryParse(json['status']?.toString() ?? '1') ?? 1,
      image: s(json['image']),
      userId: json['user_id'] == null
          ? null
          : (json['user_id'] is int
              ? json['user_id']
              : int.tryParse(json['user_id'].toString())),
      userName: s(json['user']?['name']),
      createdAt: s(json['created_at']),
    );
  }
}

class ProvinceModel {
  final int id;
  final String name;

  ProvinceModel({required this.id, required this.name});

  factory ProvinceModel.fromJson(Map<String, dynamic> json) =>
      ProvinceModel(id: json['id'], name: json['name'] ?? '');
}

class CityModel {
  final int id;
  final String name;

  CityModel({required this.id, required this.name});

  factory CityModel.fromJson(Map<String, dynamic> json) =>
      CityModel(id: json['id'], name: json['name'] ?? '');
}

class DistrictModel {
  final int id;
  final String name;

  DistrictModel({required this.id, required this.name});

  factory DistrictModel.fromJson(Map<String, dynamic> json) =>
      DistrictModel(id: json['id'], name: json['name'] ?? '');
}

class SubdistrictModel {
  final int id;
  final String name;

  SubdistrictModel({required this.id, required this.name});

  factory SubdistrictModel.fromJson(Map<String, dynamic> json) =>
      SubdistrictModel(id: json['id'], name: json['name'] ?? '');
}

class PostalCodeModel {
  final int id;
  final String postalCode;

  PostalCodeModel({required this.id, required this.postalCode});

  factory PostalCodeModel.fromJson(Map<String, dynamic> json) =>
      // postal_code bertipe INT di DB → datang sebagai angka dari API; parse
      // toleran agar tidak TypeError int as String.
      PostalCodeModel(
          id: json['id'], postalCode: json['postal_code']?.toString() ?? '');
}

class BankModel {
  final int id;
  final String name;

  BankModel({required this.id, required this.name});

  factory BankModel.fromJson(Map<String, dynamic> json) =>
      BankModel(id: json['id'], name: json['name'] ?? '');
}
