import '../services/image_service.dart';

class ApplicantDetail {
  final int? id;
  final int? userId;
  final String? nickname;
  final bool? isExperienced;
  final String? phone;
  final String? address;
  final String? birthPlace;
  final String? birthDate;
  final String? gender;
  final String? nik;
  final String? religion;
  final String? maritalStatus;
  final int? childrenCount;
  final String? educationLevel;
  final String? educationMajor;
  final String? fatherName;
  final String? motherName;
  final String? homeLocation;
  final String? emergencyPhone;
  final String? emergencyName;
  final String? driverLicense;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankName;
  final String? status;
  final String? joinDate;
  final String? position;
  final String? ktpHtmlUrl;
  final String? selfieHtmlUrl;

  ApplicantDetail({
    this.id,
    this.userId,
    this.nickname,
    this.isExperienced,
    this.phone,
    this.address,
    this.birthPlace,
    this.birthDate,
    this.gender,
    this.nik,
    this.religion,
    this.maritalStatus,
    this.childrenCount,
    this.educationLevel,
    this.educationMajor,
    this.fatherName,
    this.motherName,
    this.homeLocation,
    this.emergencyPhone,
    this.emergencyName,
    this.driverLicense,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankName,
    this.status,
    this.joinDate,
    this.position,
    this.ktpHtmlUrl,
    this.selfieHtmlUrl,
  });

  factory ApplicantDetail.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return ApplicantDetail();
    }
    final rawExp = json['is_experienced'];
    final bool? isExp = rawExp is bool
        ? rawExp
        : (rawExp is int ? rawExp == 1 : null);
    return ApplicantDetail(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      nickname: json['nickname'] as String?,
      isExperienced: isExp,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      birthPlace: json['birth_place'] as String?,
      birthDate: _asDateString(json['birth_date']),
      gender: json['gender'] as String?,
      nik: json['nik'] as String?,
      religion: json['religion'] as String?,
      maritalStatus: json['marital_status'] as String?,
      childrenCount: _asInt(json['children_count']),
      educationLevel: json['education_level'] as String?,
      educationMajor: json['education_major'] as String?,
      fatherName: json['father_name'] as String?,
      motherName: json['mother_name'] as String?,
      homeLocation: json['home_location'] as String?,
      emergencyPhone: json['emergency_phone'] as String?,
      emergencyName: json['emergency_name'] as String?,
      driverLicense: json['driver_license'] as String?,
      bankAccountName: json['bank_account_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankName: json['bank_name'] as String?,
      status: json['status'] as String?,
      joinDate: _asDateString(json['join_date']),
      position: json['position'] as String?,
      ktpHtmlUrl: (json['ktp_image_url'] ?? json['ktp_image']) as String?,
      selfieHtmlUrl:
          (json['selfie_image_url'] ?? json['selfie_image']) as String?,
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String && v.trim().isNotEmpty) return int.tryParse(v.trim());
    return null;
  }

  static String? _asDateString(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      // Backend bisa kirim datetime "2020-01-01T00:00:00.000Z" — ambil tanggalnya.
      if (t.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(t)) {
        return t.substring(0, 10);
      }
      return t;
    }
    return v.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      if (nickname != null) 'nickname': nickname,
      if (isExperienced != null) 'is_experienced': isExperienced,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (birthPlace != null) 'birth_place': birthPlace,
      if (birthDate != null) 'birth_date': birthDate,
      if (gender != null) 'gender': gender,
      if (nik != null) 'nik': nik,
      if (religion != null) 'religion': religion,
      if (maritalStatus != null) 'marital_status': maritalStatus,
      if (childrenCount != null) 'children_count': childrenCount,
      if (educationLevel != null) 'education_level': educationLevel,
      if (educationMajor != null) 'education_major': educationMajor,
      if (fatherName != null) 'father_name': fatherName,
      if (motherName != null) 'mother_name': motherName,
      if (homeLocation != null) 'home_location': homeLocation,
      if (emergencyPhone != null) 'emergency_phone': emergencyPhone,
      if (emergencyName != null) 'emergency_name': emergencyName,
      if (driverLicense != null) 'driver_license': driverLicense,
      if (bankAccountName != null) 'bank_account_name': bankAccountName,
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
      if (bankName != null) 'bank_name': bankName,
    };
  }

  /// Payload untuk POST /profile (backend recruitment).
  ///
  /// - String kosong / whitespace-only TIDAK dikirim (Laravel `date`
  ///   menolak `birth_date: ''` dengan 422; `'' != null` juga memicu
  ///   false-positive "Profile is locked" di backend).
  /// - [bankOnly] = true → hanya 3 field rekening yang dikirim, agar
  ///   profil terkunci tetap bisa simpan rekening tanpa 403.
  Map<String, dynamic> toProfilePayload({bool bankOnly = false}) {
    void putIfNotBlank(Map<String, dynamic> m, String key, String? value) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty) m[key] = v;
    }

    final payload = <String, dynamic>{};
    if (bankOnly) {
      putIfNotBlank(payload, 'bank_name', bankName);
      putIfNotBlank(payload, 'bank_account_name', bankAccountName);
      putIfNotBlank(payload, 'bank_account_number', bankAccountNumber);
      return payload;
    }
    putIfNotBlank(payload, 'nickname', nickname);
    putIfNotBlank(payload, 'phone', phone);
    putIfNotBlank(payload, 'address', address);
    putIfNotBlank(payload, 'birth_place', birthPlace);
    putIfNotBlank(payload, 'birth_date', birthDate);
    putIfNotBlank(payload, 'nik', nik);
    putIfNotBlank(payload, 'religion', religion);
    putIfNotBlank(payload, 'marital_status', maritalStatus);
    putIfNotBlank(payload, 'education_level', educationLevel);
    putIfNotBlank(payload, 'emergency_phone', emergencyPhone);
    putIfNotBlank(payload, 'emergency_name', emergencyName);
    putIfNotBlank(payload, 'bank_name', bankName);
    putIfNotBlank(payload, 'bank_account_name', bankAccountName);
    putIfNotBlank(payload, 'bank_account_number', bankAccountNumber);
    if (isExperienced != null) payload['is_experienced'] = isExperienced;
    if (childrenCount != null) payload['children_count'] = childrenCount;
    if (gender != null && gender!.trim().isNotEmpty) {
      payload['gender'] = gender!.trim();
    }
    return payload;
  }

  /// True bila field non-rekening terkunci (hanya rekening yg bisa diubah).
  bool get isLocked =>
      status != null &&
      ['submitted', 'accepted', 'reviewed', 'rejected'].contains(status) &&
      joinDate != null &&
      joinDate!.isNotEmpty;

  /// URL publik foto KTP / selfie (dari `ktp_image_url` /
  /// `selfie_image_url` atau `ktp_image` backend). Null bila belum ada.
  String? get ktpImageUrl {
    final raw = ktpHtmlUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return ImageService.buildUrl(raw);
  }

  String? get selfieImageUrl {
    final raw = selfieHtmlUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return ImageService.buildUrl(raw);
  }
}
