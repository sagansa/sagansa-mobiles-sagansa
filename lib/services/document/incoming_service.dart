import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'document_api_client.dart';
import 'document_models.dart' show PaginatedResult;
import 'incoming_models.dart';

/// Satu foto scan untuk `createIncoming` — bytes + nama berkas (ekstensi
/// menentukan validasi mime backend: jpg/jpeg/png).
class IncomingScanImage {
  final List<int> bytes;
  final String fileName;

  const IncomingScanImage({required this.bytes, required this.fileName});
}

/// Service API surat masuk + disposisi + runutan surat (document service
/// fase 1b), di atas [DocumentApiClient] (bearer + envelope
/// `{success, data, meta?}` + error `error.code`).
///
/// Endpoint: `/incoming-letters` (CRUD + status + scan stream + disposisi),
/// `/dispositions/{id}/complete`, `/letters/thread/{type}/{id}`.
class IncomingService {
  final DocumentApiClient _api = DocumentApiClient();

  // ——— buku agenda surat masuk ———

  /// `GET /incoming-letters?status&sifat&year&q&page` — daftar agenda
  /// (paginate 15) dengan meta; filter tervalidasi backend (nilai tak
  /// dikenal → 422 VALIDATION_ERROR).
  Future<PaginatedResult<IncomingLetterModel>> getIncoming({
    String? status,
    String? sifat,
    int? year,
    String? query,
    int page = 1,
  }) async {
    final body = await _api.getRaw('incoming-letters',
        queryParams: <String, String>{
          if (status != null && status.isNotEmpty) 'status': status,
          if (sifat != null && sifat.isNotEmpty) 'sifat': sifat,
          if (year != null) 'year': year.toString(),
          if (query != null && query.isNotEmpty) 'q': query,
          'page': page.toString(),
        });
    return PaginatedResult.fromEnvelope(body,
        fromJson: IncomingLetterModel.fromJson);
  }

  /// `POST /incoming-letters` (multipart) — daftarkan surat masuk.
  ///
  /// Scan dikirim SALAH SATU bentuk (mirror backend 422 SCAN_INVALID):
  /// [scanBytes] berkas scan tunggal (PDF/JPG/PNG, nama berkas via
  /// [scanFileName] — default `scan.pdf`, ekstensi harus sesuai isi) ATAU
  /// [scanImages] foto multi (jpg/png, di-compose backend jadi satu PDF).
  /// Tanggal dikirim format `yyyy-MM-dd`.
  ///
  /// [inReplyToId] + [inReplyToType] + [inReplyToRelation] (opsional,
  /// Task 9 fase 1b): tautkan surat baru sebagai child induk runutan
  /// (shape `in_reply_to` backend — dipreflight server; ghost → 422
  /// LINK_TARGET_NOT_FOUND tanpa surat tersimpan).
  Future<IncomingLetterModel> createIncoming({
    required int senderPartyId,
    String? numberExternal,
    DateTime? letterDate,
    required DateTime receivedAt,
    required String subject,
    required String sifat, // biasa | segera | rahasia
    String? attachmentsNote,
    String? companyId,
    List<int>? scanBytes,
    String? scanFileName,
    List<IncomingScanImage>? scanImages,
    String? inReplyToType,
    String? inReplyToId,
    String? inReplyToRelation,
  }) async {
    if (scanBytes != null && (scanImages?.isNotEmpty ?? false)) {
      throw ArgumentError(
          'Scan hanya boleh satu bentuk: scanBytes ATAU scanImages.');
    }
    if (scanBytes == null && !(scanImages?.isNotEmpty ?? false)) {
      throw ArgumentError(
          'Scan wajib dikirim: scanBytes ATAU minimal satu scanImages.');
    }

    final files = <http.MultipartFile>[
      if (scanBytes != null)
        http.MultipartFile.fromBytes('scan', scanBytes,
            filename: scanFileName ?? 'scan.pdf'),
      for (final image in scanImages ?? const <IncomingScanImage>[])
        http.MultipartFile.fromBytes('scan_images[]', image.bytes,
            filename: image.fileName),
    ];

    final data = await _api.multipart(
      method: 'POST',
      path: 'incoming-letters',
      fields: buildCreateFields(
        senderPartyId: senderPartyId,
        numberExternal: numberExternal,
        letterDate: letterDate,
        receivedAt: receivedAt,
        subject: subject,
        sifat: sifat,
        attachmentsNote: attachmentsNote,
        companyId: companyId,
        inReplyToType: inReplyToType,
        inReplyToId: inReplyToId,
        inReplyToRelation: inReplyToRelation,
      ),
      files: files,
    );
    return IncomingLetterModel.fromJson(_asMap(data));
  }

  /// Peta field multipart `POST /incoming-letters` — dipisah dari
  /// [createIncoming] agar bentuk wire (nama field, format tanggal
  /// `yyyy-MM-dd`, kurung kurawal `in_reply_to[...]` PHP) teruji tanpa
  /// HTTP.
  @visibleForTesting
  static Map<String, String> buildCreateFields({
    required int senderPartyId,
    String? numberExternal,
    DateTime? letterDate,
    required DateTime receivedAt,
    required String subject,
    required String sifat,
    String? attachmentsNote,
    String? companyId,
    String? inReplyToType,
    String? inReplyToId,
    String? inReplyToRelation,
  }) {
    return <String, String>{
      'sender_party_id': senderPartyId.toString(),
      'received_at': _formatDate(receivedAt),
      'subject': subject,
      'sifat': sifat,
      if (numberExternal != null) 'number_external': numberExternal,
      if (letterDate != null) 'letter_date': _formatDate(letterDate),
      if (attachmentsNote != null) 'attachments_note': attachmentsNote,
      if (companyId != null) 'company_id': companyId,
      if (inReplyToId != null) ...<String, String>{
        'in_reply_to[type]': inReplyToType ?? 'document',
        'in_reply_to[id]': inReplyToId,
        'in_reply_to[relation]': inReplyToRelation ?? 'balasan',
      },
    };
  }

  /// `GET /incoming-letters/{id}` — detail: senderParty, dispositions,
  /// thread embed + links_count.
  Future<IncomingLetterModel> getIncomingDetail(String id) async {
    final data = await _api.get('incoming-letters/$id');
    return IncomingLetterModel.fromJson(_asMap(data));
  }

  /// `PATCH /incoming-letters/{id}` — ubah kolom isian (minus scan);
  /// surat `selesai` dibekukan backend (409 INCOMING_LOCKED). Hanya field
  /// non-null yang dikirim (semantik `sometimes` backend).
  Future<IncomingLetterModel> updateIncoming(
    String id, {
    int? senderPartyId,
    String? numberExternal,
    DateTime? letterDate,
    DateTime? receivedAt,
    String? subject,
    String? sifat,
    String? attachmentsNote,
    String? companyId,
  }) async {
    final data = await _api.patch('incoming-letters/$id',
        body: <String, dynamic>{
          if (senderPartyId != null) 'sender_party_id': senderPartyId,
          if (numberExternal != null) 'number_external': numberExternal,
          if (letterDate != null) 'letter_date': _formatDate(letterDate),
          if (receivedAt != null) 'received_at': _formatDate(receivedAt),
          if (subject != null) 'subject': subject,
          if (sifat != null) 'sifat': sifat,
          if (attachmentsNote != null) 'attachments_note': attachmentsNote,
          if (companyId != null) 'company_id': companyId,
        });
    return IncomingLetterModel.fromJson(_asMap(data));
  }

  /// `POST /incoming-letters/{id}/status {status}` — naik status; hanya
  /// boleh MAJU terdaftar→diproses→selesai (mundur/berulang → 409).
  Future<IncomingLetterModel> markIncomingStatus(
    String id,
    String status, // terdaftar | diproses | selesai
  ) async {
    final data = await _api.post('incoming-letters/$id/status',
        body: <String, dynamic>{'status': status});
    return IncomingLetterModel.fromJson(_asMap(data));
  }

  /// `GET /incoming-letters/{id}/scan` — bytes scan PDF untuk viewer
  /// (bearer; timeout 60 detik; berkas hilang → 404 NOT_FOUND).
  Future<List<int>> getIncomingScanBytes(String id) {
    return _api.getBytes('incoming-letters/$id/scan');
  }

  // ——— disposisi ———

  /// `POST /incoming-letters/{incomingId}/dispositions {to_user_id,
  /// instruction}` — penerima WAJIB signer aktif (else 422); surat masih
  /// `terdaftar` otomatis naik `diproses` di sisi backend.
  Future<DispositionModel> addDisposition(
    String incomingId, {
    required int toUserId,
    required String instruction,
  }) async {
    final data = await _api.post('incoming-letters/$incomingId/dispositions',
        body: <String, dynamic>{
          'to_user_id': toUserId,
          'instruction': instruction,
        });
    return DispositionModel.fromJson(_asMap(data));
  }

  /// `POST /dispositions/{id}/complete` — tandai selesai + acted_at;
  /// complete ulang → 409 INCOMING_LOCKED.
  Future<DispositionModel> completeDisposition(String id) async {
    final data = await _api.post('dispositions/$id/complete');
    return DispositionModel.fromJson(_asMap(data));
  }

  // ——— runutan surat ———

  /// `GET /letters/thread/{type}/{id}` — thread dari node mana pun dalam
  /// runutan (boleh node tengah; root dihitung backend). Node tak dikenal
  /// / tipe salah → 404 NOT_FOUND netral.
  Future<ThreadModel> getThread(String type, String id) async {
    final data = await _api.get('letters/thread/$type/$id');
    return ThreadModel.fromJson(_asMap(data));
  }

  // ——— helper ———

  static Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  /// Backend menerima tanggal format `Y-m-d`.
  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
