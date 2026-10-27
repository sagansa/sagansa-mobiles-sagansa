/// Model domain surat masuk + disposisi + runutan surat (document service
/// fase 1b) — parsing toleran null mengikuti pola [document_models]
/// (`int.tryParse`, `DateTime.tryParse`, relasi diparse hanya bila Map).
///
/// Sumber bentuk: `IncomingLetterResource` (list vs detail via whenLoaded),
/// `DispositionController::resource`, dan `ThreadBuilder::build`.
library;

import 'document_models.dart';

/// Surat masuk — bentuk list `GET /incoming-letters` (kolom registrasi +
/// metadata integritas scan; isi scan hanya via `GET /{id}/scan`) dan
/// bentuk detail `GET /incoming-letters/{id}` (+ `dispositions`, `thread`,
/// `links_count` saat diisi controller).
class IncomingLetterModel {
  final String id;

  /// Nomor agenda internal (mis. `SM-001/X/2026`) — di-generate backend.
  final String agendaNumber;

  /// Nomor surat dari pengirim (bisa null — tidak semua surat bernomor).
  final String? numberExternal;

  /// Pengirim — backend mengirim `{id, name}` saat di-eager (list & detail).
  final PartyModel? senderParty;
  final DateTime? letterDate;
  final DateTime? receivedAt;
  final String subject;

  /// biasa | segera | rahasia.
  final String sifat;
  final String classification;

  /// terdaftar | diproses | selesai.
  final String status;

  /// Metadata integritas scan (`scan: {sha256, size, pages}`) — path
  /// internal TIDAK diekspos backend; isi bytes via [IncomingService].
  final String? scanSha256;
  final int? scanSize;
  final int? scanPages;
  final String? attachmentsNote;
  final DateTime? createdAt;

  /// Hanya bentuk detail (whenLoaded `dispositions`), urut created_at.
  final List<DispositionModel> dispositions;

  /// Embed thread (hanya bentuk detail; list tidak memuat kunci ini).
  final ThreadModel? thread;

  /// Jumlah edge letter_links kedua arah (hanya bentuk detail).
  final int? linksCount;

  const IncomingLetterModel({
    required this.id,
    required this.agendaNumber,
    this.numberExternal,
    this.senderParty,
    this.letterDate,
    this.receivedAt,
    required this.subject,
    required this.sifat,
    required this.classification,
    required this.status,
    this.scanSha256,
    this.scanSize,
    this.scanPages,
    this.attachmentsNote,
    this.createdAt,
    this.dispositions = const [],
    this.thread,
    this.linksCount,
  });

  factory IncomingLetterModel.fromJson(Map<String, dynamic> json) {
    final scan = json['scan'] is Map<String, dynamic>
        ? json['scan'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return IncomingLetterModel(
      id: json['id']?.toString() ?? '',
      agendaNumber: json['agenda_number']?.toString() ?? '',
      numberExternal: _nullableString(json['number_external']),
      senderParty: json['sender_party'] is Map<String, dynamic>
          ? PartyModel.fromJson(
              json['sender_party'] as Map<String, dynamic>)
          : null,
      letterDate: _tryParseDate(json['letter_date']),
      receivedAt: _tryParseDate(json['received_at']),
      subject: json['subject']?.toString() ?? '',
      sifat: json['sifat']?.toString() ?? '',
      classification: json['classification']?.toString() ?? 'umum',
      status: json['status']?.toString() ?? 'terdaftar',
      scanSha256: _nullableString(scan['sha256']),
      scanSize: _asInt(scan['size']),
      scanPages: _asInt(scan['pages']),
      attachmentsNote: _nullableString(json['attachments_note']),
      createdAt: _tryParseDate(json['created_at']),
      dispositions: _modelList<DispositionModel>(
          json['dispositions'], DispositionModel.fromJson),
      thread: json['thread'] is Map<String, dynamic>
          ? ThreadModel.fromJson(json['thread'] as Map<String, dynamic>)
          : null,
      linksCount: _asInt(json['links_count']),
    );
  }

  /// Label status bahasa Indonesia untuk UI.
  String get statusLabel => statusLabelOf(status);

  /// Label status dari kode — dipakai chip filter UI tanpa instans surat.
  static String statusLabelOf(String status) {
    switch (status) {
      case 'terdaftar':
        return 'Terdaftar';
      case 'diproses':
        return 'Diproses';
      case 'selesai':
        return 'Selesai';
      default:
        return status;
    }
  }

  /// Label sifat surat (biasa | segera | rahasia).
  String get sifatLabel => sifatLabelOf(sifat);

  /// Label sifat dari kode — dipakai filter UI.
  static String sifatLabelOf(String sifat) {
    switch (sifat) {
      case 'biasa':
        return 'Biasa';
      case 'segera':
        return 'Segera';
      case 'rahasia':
        return 'Rahasia';
      default:
        return sifat;
    }
  }

  String get classificationLabel =>
      classification == 'rahasia' ? 'Rahasia' : 'Umum';

  bool get isSecret => classification == 'rahasia';
}

/// Catatan pengarahan (disposisi) pada surat masuk.
///
/// Bentuk backend: `{id, to_user_id, to_user_label, instruction, status,
/// acted_at?, created_at}` (+ `incoming_letter_id` pada response create /
/// complete). Label penerima lintas-DB `"Pengguna #id"`.
class DispositionModel {
  final String id;

  /// Hanya ada di response POST dispositions / complete; TIDAK ada pada
  /// embed relasi di detail surat (resource detail tanpa kolom ini).
  final String? incomingLetterId;
  final int toUserId;
  final String toUserLabel;
  final String instruction;

  /// open | selesai.
  final String status;
  final DateTime? actedAt;
  final DateTime? createdAt;

  const DispositionModel({
    required this.id,
    this.incomingLetterId,
    required this.toUserId,
    required this.toUserLabel,
    required this.instruction,
    required this.status,
    this.actedAt,
    this.createdAt,
  });

  factory DispositionModel.fromJson(Map<String, dynamic> json) {
    return DispositionModel(
      id: json['id']?.toString() ?? '',
      incomingLetterId: _nullableString(json['incoming_letter_id']),
      toUserId: _asInt(json['to_user_id']) ?? 0,
      toUserLabel: json['to_user_label']?.toString() ?? '',
      instruction: json['instruction']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      actedAt: _tryParseDate(json['acted_at']),
      createdAt: _tryParseDate(json['created_at']),
    );
  }

  /// Label status disposisi bahasa Indonesia.
  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Terbuka';
      case 'selesai':
        return 'Selesai';
      default:
        return status;
    }
  }

  bool get isCompleted => status == 'selesai';
}

/// Runutan (thread) surat lintas jenis — `GET /letters/thread/{type}/{id}`
/// dan embed `thread` di detail surat masuk.
///
/// `{root: {type, id}, nodes: [...], total}` — node URUT FLAT
/// CHRONOLOGICAL (bukan pre-order); `depth` disertakan agar UI timeline
/// bisa meng-indent ringan.
class ThreadModel {
  final String rootType;
  final String rootId;
  final List<ThreadNodeModel> nodes;
  final int total;

  const ThreadModel({
    required this.rootType,
    required this.rootId,
    this.nodes = const [],
    this.total = 0,
  });

  factory ThreadModel.fromJson(Map<String, dynamic> json) {
    final root = json['root'] is Map<String, dynamic>
        ? json['root'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ThreadModel(
      rootType: root['type']?.toString() ?? '',
      rootId: root['id']?.toString() ?? '',
      nodes: _modelList<ThreadNodeModel>(json['nodes'], ThreadNodeModel.fromJson),
      total: _asInt(json['total']) ?? 0,
    );
  }

  /// Apakah node ini adalah akar runutan.
  bool isRoot(String type, String id) => rootType == type && rootId == id;
}

/// Satu node dalam runutan surat.
///
/// `type` document | incoming_letter; `number` untuk document pra-nomor
/// sudah berupa `'—'` dari backend; `relationToParent` null untuk akar.
class ThreadNodeModel {
  final String type;
  final String id;
  final String? number;
  final DateTime? date;
  final String? title;

  /// document: nama penerima dari metadata; incoming_letter: nama pengirim.
  final String? partyName;
  final String? status;
  final String? relationToParent;
  final int childrenCount;
  final int depth;

  const ThreadNodeModel({
    required this.type,
    required this.id,
    this.number,
    this.date,
    this.title,
    this.partyName,
    this.status,
    this.relationToParent,
    this.childrenCount = 0,
    this.depth = 0,
  });

  factory ThreadNodeModel.fromJson(Map<String, dynamic> json) {
    return ThreadNodeModel(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      number: _nullableString(json['number']),
      date: _tryParseDate(json['date']),
      title: _nullableString(json['title']),
      partyName: _nullableString(json['party_name']),
      status: _nullableString(json['status']),
      relationToParent: _nullableString(json['relation_to_parent']),
      childrenCount: _asInt(json['children_count']) ?? 0,
      depth: _asInt(json['depth']) ?? 0,
    );
  }

  bool get isIncomingLetter => type == 'incoming_letter';

  /// Label relasi ke surat induk (null untuk akar thread).
  ///
  /// balasan → Membalas, tindak_lanjut → Menindaklanjuti,
  /// referensi → Mereferensikan.
  String? get relationLabel {
    if (relationToParent == null) return null;
    switch (relationToParent) {
      case 'balasan':
        return 'Membalas';
      case 'tindak_lanjut':
        return 'Menindaklanjuti';
      case 'referensi':
        return 'Mereferensikan';
      default:
        return relationToParent;
    }
  }

  /// Nomor tampil — fallback '—' bila backend tidak mengirim number.
  String get displayNumber => number ?? '—';
}

// ——— helper parsing toleran null (cermin document_models.dart; file ini
// tidak bisa memakai helper private file tersebut) ———

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

List<T> _modelList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((e) => fromJson(e.cast<String, dynamic>()))
      .toList(growable: false);
}
