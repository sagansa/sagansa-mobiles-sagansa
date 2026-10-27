/// Model domain surat (document service) — parsing toleran null mengikuti
/// pola model existing (mis. [LeaveModel]): field numerik lewat
/// `int.tryParse`, tanggal lewat `DateTime.tryParse`, relasi bersarang
/// diparse hanya bila bentuknya `Map`.
library;

/// Hasil halaman dari envelope `{success, data: [...], meta}` service
/// document — meta selalu `{current_page, last_page, total, per_page}`.
class PaginatedResult<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  bool get hasMore => currentPage < lastPage;

  /// Parse envelope paginated; [fromJson] dipakai untuk tiap elemen `data`.
  static PaginatedResult<T> fromEnvelope<T>(
    Map<String, dynamic> body, {
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    final rawItems = body['data'];
    final meta = body['meta'] is Map<String, dynamic>
        ? body['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return PaginatedResult<T>(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : <T>[],
      currentPage: _asInt(meta['current_page']) ?? 1,
      lastPage: _asInt(meta['last_page']) ?? 1,
      total: _asInt(meta['total']) ?? 0,
      perPage: _asInt(meta['per_page']) ?? 0,
    );
  }
}

/// Satu field khusus jenis surat (mis. KUA) — bentuk backend
/// `specific_fields: [{key, label}]`.
class LetterSpecificField {
  final String key;
  final String label;

  const LetterSpecificField({required this.key, required this.label});

  @override
  bool operator ==(Object other) =>
      other is LetterSpecificField && other.key == key && other.label == label;

  @override
  int get hashCode => Object.hash(key, label);
}

/// Jenis surat aktif — `GET /api/v1/letter-types`
/// `{code, name, specific_fields?}`.
class LetterTypeModel {
  final String code;
  final String name;
  final List<LetterSpecificField>? specificFields;

  const LetterTypeModel({
    required this.code,
    required this.name,
    this.specificFields,
  });

  factory LetterTypeModel.fromJson(Map<String, dynamic> json) {
    return LetterTypeModel(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      specificFields: _specificFieldList(json['specific_fields']),
    );
  }
}

/// Template isi surat per jenis — `GET /api/v1/templates?letter_type_code=`
/// `{id, name, letter_type_code, body_html, placeholders?, is_default}`.
class TemplateModel {
  final int id;
  final String name;
  final String letterTypeCode;
  final String? bodyHtml;
  final List<String>? placeholders;
  final bool isDefault;

  const TemplateModel({
    required this.id,
    required this.name,
    required this.letterTypeCode,
    this.bodyHtml,
    this.placeholders,
    required this.isDefault,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      letterTypeCode: json['letter_type_code']?.toString() ?? '',
      bodyHtml: _nullableString(json['body_html']),
      placeholders: _stringList(json['placeholders']),
      isDefault: json['is_default'] == true,
    );
  }
}

/// Pihak eksternal (buku pihak) — `GET/POST /api/v1/parties`
/// `{id, name, identity_no?, address?, occupation?, notes?, created_at?}`.
class PartyModel {
  final int id;
  final String name;
  final String? identityNo;
  final String? address;
  final String? occupation;
  final String? notes;
  final DateTime? createdAt;

  const PartyModel({
    required this.id,
    required this.name,
    this.identityNo,
    this.address,
    this.occupation,
    this.notes,
    this.createdAt,
  });

  factory PartyModel.fromJson(Map<String, dynamic> json) {
    return PartyModel(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      identityNo: _nullableString(json['identity_no']),
      address: _nullableString(json['address']),
      occupation: _nullableString(json['occupation']),
      notes: _nullableString(json['notes']),
      createdAt: _tryParseDate(json['created_at']),
    );
  }
}

/// Penandatangan (signer) — bentuk di `GET /me/signer` dan di dalam
/// signing request `{id, role, display_name, title?, signature_ready?}`.
class SignerModel {
  final int id;
  final String role;
  final String displayName;
  final String? title;
  final bool signatureReady;

  const SignerModel({
    required this.id,
    required this.role,
    required this.displayName,
    this.title,
    this.signatureReady = false,
  });

  factory SignerModel.fromJson(Map<String, dynamic> json) {
    return SignerModel(
      id: _asInt(json['id']) ?? 0,
      role: json['role']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      title: _nullableString(json['title']),
      signatureReady: json['signature_ready'] == true,
    );
  }

  /// Label jabatan ramah (pola ROLE_LABEL VerifyController).
  String get roleLabel {
    switch (role) {
      case 'direktur':
        return 'Direktur';
      case 'komisaris':
        return 'Komisaris';
      case 'pemegang_saham':
        return 'Pemegang Saham';
      default:
        return role;
    }
  }
}

/// Hasil penerbitan (issuance) — muncul di detail dokumen
/// (active_issuance / issuances) dan response finalize/reissue.
///
/// `method` a|b|c|d; `methodLabel` nilai kolom backend:
/// elektronik | ttd_elektronik_resmi | manual.
class IssuanceModel {
  final String id;
  final String method;
  final String methodLabel;
  final String? fileSha256;
  final String? note;
  final bool isActive;
  final String? replacedById;
  final DateTime? finalizedAt;

  const IssuanceModel({
    required this.id,
    required this.method,
    required this.methodLabel,
    this.fileSha256,
    this.note,
    this.isActive = false,
    this.replacedById,
    this.finalizedAt,
  });

  factory IssuanceModel.fromJson(Map<String, dynamic> json) {
    return IssuanceModel(
      id: json['id']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      methodLabel: json['method_label']?.toString() ?? '',
      fileSha256: _nullableString(json['file_sha256']),
      note: _nullableString(json['note']),
      isActive: json['is_active'] == true,
      replacedById: _nullableString(json['replaced_by_id']),
      finalizedAt: _tryParseDate(json['finalized_at']),
    );
  }

  /// Label metode ramah pengguna (pola METHOD_TEXT halaman verifikasi).
  String get methodLabelText {
    switch (methodLabel) {
      case 'elektronik':
        return 'Elektronik — ditandatangani elektronik (QR)';
      case 'ttd_elektronik_resmi':
        return 'Tanda tangan elektronik resmi + e-materai';
      case 'manual':
        return 'Manual — dokumen fisik, tanda tangan basah + meterai tempel';
      default:
        return methodLabel;
    }
  }
}

/// Lampiran surat — `POST /documents/{id}/attachments` & detail dokumen
/// `{id, label, sort, mime, size, sha256}`.
class AttachmentModel {
  final String id;
  final String label;
  final int sort;
  final String? mime;
  final int? size;
  final String? sha256;

  const AttachmentModel({
    required this.id,
    required this.label,
    required this.sort,
    this.mime,
    this.size,
    this.sha256,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sort: _asInt(json['sort']) ?? 0,
      mime: _nullableString(json['mime']),
      size: _asInt(json['size']),
      sha256: _nullableString(json['sha256']),
    );
  }
}

/// Proyeksi ringkas surat di dalam signing request (daftar tugas)
/// `{id, number?, subject?, status?}`.
class SigningRequestDocumentRef {
  final String id;
  final String? number;
  final String? subject;
  final String? status;

  const SigningRequestDocumentRef({
    required this.id,
    this.number,
    this.subject,
    this.status,
  });

  factory SigningRequestDocumentRef.fromJson(Map<String, dynamic> json) {
    return SigningRequestDocumentRef(
      id: json['id']?.toString() ?? '',
      number: _nullableString(json['number']),
      subject: _nullableString(json['subject']),
      status: _nullableString(json['status']),
    );
  }
}

/// Permintaan tanda tangan — status diminta | disetujui | ditolak.
class SigningRequestModel {
  final String id;
  final String status;
  final DateTime? requestedAt;
  final DateTime? actedAt;
  final String? note;
  final SignerModel? signer;
  final SigningRequestDocumentRef? document;

  const SigningRequestModel({
    required this.id,
    required this.status,
    this.requestedAt,
    this.actedAt,
    this.note,
    this.signer,
    this.document,
  });

  factory SigningRequestModel.fromJson(Map<String, dynamic> json) {
    return SigningRequestModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      requestedAt: _tryParseDate(json['requested_at']),
      actedAt: _tryParseDate(json['acted_at']),
      note: _nullableString(json['note']),
      signer: json['signer'] is Map<String, dynamic>
          ? SignerModel.fromJson(json['signer'] as Map<String, dynamic>)
          : null,
      document: json['document'] is Map<String, dynamic>
          ? SigningRequestDocumentRef.fromJson(
              json['document'] as Map<String, dynamic>)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'diminta':
        return 'Diminta';
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      default:
        return status;
    }
  }

  bool get isPending => status == 'diminta';
}

/// Surat — bentuk dasar (list/create) + relasi detail via whenLoaded
/// (active_issuance, issuances, attachments, signing_requests).
class DocumentModel {
  /// UUID string (PK service document, bukan auto-increment).
  final String id;

  /// Null sampai nomor di-reserve / finalize (pra-nomor NULL, bukan '').
  final String? number;
  final String status;
  final String classification;
  final String subject;
  final DateTime? date;
  final LetterTypeModel? letterType;
  final Map<String, dynamic>? metadata;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final IssuanceModel? activeIssuance;
  final List<IssuanceModel> issuances;
  final List<AttachmentModel> attachments;
  final List<SigningRequestModel> signingRequests;

  const DocumentModel({
    required this.id,
    this.number,
    required this.status,
    required this.classification,
    required this.subject,
    this.date,
    this.letterType,
    this.metadata,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.activeIssuance,
    this.issuances = const [],
    this.attachments = const [],
    this.signingRequests = const [],
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id']?.toString() ?? '',
      number: _nullableString(json['number']),
      status: json['status']?.toString() ?? 'draft',
      classification: json['classification']?.toString() ?? 'umum',
      subject: json['subject']?.toString() ?? '',
      date: _tryParseDate(json['date']),
      letterType: json['letter_type'] is Map<String, dynamic>
          ? LetterTypeModel.fromJson(json['letter_type'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] is Map
          ? (json['metadata'] as Map).cast<String, dynamic>()
          : null,
      createdBy: _asInt(json['created_by']),
      createdAt: _tryParseDate(json['created_at']),
      updatedAt: _tryParseDate(json['updated_at']),
      activeIssuance: json['active_issuance'] is Map<String, dynamic>
          ? IssuanceModel.fromJson(
              json['active_issuance'] as Map<String, dynamic>)
          : null,
      issuances: _modelList<IssuanceModel>(json['issuances'],
          IssuanceModel.fromJson),
      attachments: _modelList<AttachmentModel>(json['attachments'],
          AttachmentModel.fromJson),
      signingRequests: _modelList<SigningRequestModel>(
          json['signing_requests'], SigningRequestModel.fromJson),
    );
  }

  /// Label status bahasa Indonesia untuk UI.
  String get statusLabel => statusLabelOf(status);

  /// Label status dari kode — dipakai filter UI yang belum punya instans
  /// dokumen (mis. chip filter "Semua/Draft/Terbit/..." di list page).
  static String statusLabelOf(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'menunggu_ttd':
        return 'Menunggu ttd';
      case 'terbit':
        return 'Terbit';
      case 'dicabut':
        return 'Dicabut';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String get classificationLabel =>
      classification == 'rahasia' ? 'Rahasia' : 'Umum';

  bool get isSecret => classification == 'rahasia';

  /// Masih boleh diedit (guard backend PATCH/lampiran/ttd).
  bool get isEditable => status == 'draft' || status == 'menunggu_ttd';

  /// Ada signing request yang belum diputuskan (menghalangi finalize).
  bool get hasPendingSignature =>
      signingRequests.any((request) => request.isPending);
}

// ——— helper parsing toleran null (dipakai semua model di file ini) ———

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

DateTime? _tryParseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<String>? _stringList(dynamic value) {
  if (value is! List) return null;
  final items = value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty);
  return items.isEmpty ? null : items.toList(growable: false);
}

/// Parse `specific_fields` — bentuk backend `[{key, label}]`; string polos
/// (bentuk lama) ditoleransi sebagai key sekaligus label.
List<LetterSpecificField>? _specificFieldList(dynamic value) {
  if (value is! List) return null;
  final fields = <LetterSpecificField>[];
  for (final item in value) {
    if (item is Map) {
      final key = item['key']?.toString() ?? '';
      if (key.isEmpty) continue;
      fields.add(LetterSpecificField(
        key: key,
        label: item['label']?.toString().isNotEmpty == true
            ? item['label'].toString()
            : key,
      ));
    } else {
      final key = item?.toString() ?? '';
      if (key.isEmpty) continue;
      fields.add(LetterSpecificField(key: key, label: key));
    }
  }
  return fields.isEmpty ? null : fields;
}

List<T> _modelList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((e) => fromJson(e.cast<String, dynamic>()))
      .toList(growable: false);
}
