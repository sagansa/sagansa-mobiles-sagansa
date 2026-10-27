import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'document_api_client.dart';
import 'document_models.dart';

/// Service API domain surat (document service, host `DOCUMENT_BASE_URL`).
///
/// Semua endpoint di bawah prefix `/api/v1`, auth bearer token sama dengan
/// API utama. Envelope sukses `{success, data, meta?}`; error terstruktur
/// dibaca lewat [DocumentApiExceptionX.errorCode] pada [ApiException].
class DocumentService {
  final DocumentApiClient _api = DocumentApiClient();

  // ——— dokumen ———

  /// `GET /documents?status&letter_type&year&q&page` — daftar surat milik
  /// user dengan meta paginasi.
  Future<PaginatedResult<DocumentModel>> getDocuments({
    String? status,
    String? letterType,
    int? year,
    String? query,
    int page = 1,
  }) async {
    final body = await _api.getRaw('documents', queryParams: <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (letterType != null && letterType.isNotEmpty)
        'letter_type': letterType,
      if (year != null) 'year': year.toString(),
      if (query != null && query.isNotEmpty) 'q': query,
      'page': page.toString(),
    });
    return PaginatedResult.fromEnvelope(body,
        fromJson: DocumentModel.fromJson);
  }

  /// `POST /documents` — draft baru (`number` masih null sampai reserve).
  ///
  /// [unit] wajib kecuali saat duplikasi (backend `required_without:
  /// duplicate_from_id`).
  ///
  /// [inReplyTo] (fase 1b) opsional: `{type: document|incoming_letter,
  /// id: uuid, relation: balasan|tindak_lanjut|referensi}` — menautkan
  /// draft HASIL ke surat induk (edge letter_links; independen dari
  /// [duplicateFromId], keduanya boleh bersamaan).
  Future<DocumentModel> createDraft({
    required String letterTypeCode,
    String? unit,
    required String subject,
    required DateTime date,
    String? bodyHtml,
    Map<String, dynamic>? metadata,
    String? classification,
    String? companyId,
    int? templateId,
    String? duplicateFromId,
    Map<String, dynamic>? inReplyTo,
  }) async {
    final data = await _api.post('documents', body: <String, dynamic>{
      'letter_type_code': letterTypeCode,
      'subject': subject,
      'date': _formatDate(date),
      if (unit != null) 'unit': unit,
      if (bodyHtml != null) 'body_html': bodyHtml,
      if (metadata != null) 'metadata': metadata,
      if (classification != null) 'classification': classification,
      if (companyId != null) 'company_id': companyId,
      if (templateId != null) 'template_id': templateId,
      if (duplicateFromId != null) 'duplicate_from_id': duplicateFromId,
      if (inReplyTo != null) 'in_reply_to': inReplyTo,
    });
    return DocumentModel.fromJson(_asMap(data));
  }

  /// `PATCH /documents/{id}` — hanya draft|menunggu_ttd (else 409
  /// DOCUMENT_LOCKED). Hanya field non-null yang dikirim (semantik
  /// `sometimes` backend).
  Future<DocumentModel> updateDraft(
    String id, {
    String? unit,
    String? subject,
    DateTime? date,
    String? bodyHtml,
    Map<String, dynamic>? metadata,
    String? classification,
  }) async {
    final data = await _api.patch('documents/$id', body: <String, dynamic>{
      if (unit != null) 'unit': unit,
      if (subject != null) 'subject': subject,
      if (date != null) 'date': _formatDate(date),
      if (bodyHtml != null) 'body_html': bodyHtml,
      if (metadata != null) 'metadata': metadata,
      if (classification != null) 'classification': classification,
    });
    return DocumentModel.fromJson(_asMap(data));
  }

  /// Duplikasi surat: isi (unit/body/metadata/klasifikasi) disalin dari
  /// sumber; `subject` & `date` wajib dari pemanggil.
  Future<DocumentModel> duplicateFrom(
    String sourceId, {
    required String letterTypeCode,
    required String subject,
    required DateTime date,
  }) {
    return createDraft(
      letterTypeCode: letterTypeCode,
      subject: subject,
      date: date,
      duplicateFromId: sourceId,
    );
  }

  /// `POST /documents/{id}/numbering/reserve` — kunci nomor urat;
  /// idempoten. Return map `{number, seq}`.
  Future<Map<String, dynamic>> reserveNumber(String id) async {
    final data = await _api.post('documents/$id/numbering/reserve');
    return _asMap(data);
  }

  /// `GET /documents/{id}` — detail penuh: active_issuance, issuances,
  /// attachments, signing_requests (+ signer).
  Future<DocumentModel> getDetail(String id) async {
    final data = await _api.get('documents/$id');
    return DocumentModel.fromJson(_asMap(data));
  }

  // ——— signer & alur tanda tangan ———

  /// `GET /me/signer` — signer aktif milik user login
  /// (untuk pilihan penandatangan saat membuat surat).
  Future<List<SignerModel>> getMySigners() async {
    final data = await _api.get('me/signer');
    return parseSignerList(data is Map ? data['signers'] : null);
  }

  /// `GET /signers` (task 20) — direktori signer aktif perusahaan
  /// (semua user, urut direktur → komisaris → pemegang saham). Dipakai
  /// wizard saat surat butuh tanda tangan signer milik user lain;
  /// `/me/signer` hanya memuat milik sendiri.
  Future<List<SignerModel>> getSigners() async {
    final data = await fetchSigners();
    return parseSignerList(data);
  }

  /// Seam test `getSigners` — pengambilan mentah yang bisa dioverride fake.
  @visibleForTesting
  Future<dynamic> fetchSigners() => _api.get('signers');

  /// Parser bersama daftar signer (dipakai `me/signer` & `signers`).
  @visibleForTesting
  static List<SignerModel> parseSignerList(dynamic data) {
    if (data is! List) return const <SignerModel>[];
    return data
        .whereType<Map>()
        .map((e) => SignerModel.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// `POST /documents/{id}/signers` body `{signer_id}` — ajukan tanda
  /// tangan; dokumen pindah ke `menunggu_ttd`. Return shape request
  /// (+ `document_status`).
  Future<Map<String, dynamic>> requestSigning(
    String documentId,
    int signerId,
  ) async {
    final data = await _api.post('documents/$documentId/signers',
        body: {'signer_id': signerId});
    return _asMap(data);
  }

  /// `GET /signing-requests/mine?status=&page=` — daftar tugas tanda
  /// tangan milik user login (paginate 15).
  Future<PaginatedResult<SigningRequestModel>> mySigningRequests({
    String? status,
    int page = 1,
  }) async {
    final body = await _api.getRaw('signing-requests/mine',
        queryParams: <String, String>{
          if (status != null && status.isNotEmpty) 'status': status,
          'page': page.toString(),
        });
    return PaginatedResult.fromEnvelope(body,
        fromJson: SigningRequestModel.fromJson);
  }

  /// `POST /signing-requests/{id}/approve` — status surat TETAP
  /// `menunggu_ttd`; finalize baru boleh saat tak ada lagi `diminta`.
  Future<Map<String, dynamic>> approveSigning(String id, {String? note}) {
    return _decideSigning('signing-requests/$id/approve', note);
  }

  /// `POST /signing-requests/{id}/reject` — surat kembali `draft`.
  Future<Map<String, dynamic>> rejectSigning(String id, {String? note}) {
    return _decideSigning('signing-requests/$id/reject', note);
  }

  Future<Map<String, dynamic>> _decideSigning(String path, String? note) async {
    final data = await _api.post(path,
        body: <String, dynamic>{if (note != null) 'note': note});
    return _asMap(data);
  }

  // ——— lampiran ———

  /// `POST /documents/{id}/attachments` (multipart `file` + `label`) —
  /// hanya draft|menunggu_ttd. File: pdf/jpg/jpeg/png/xlsx maks 20 MB.
  Future<AttachmentModel> uploadAttachment(
    String documentId,
    File file, {
    required String label,
    int sort = 0,
  }) async {
    final data = await _api.multipart(
      method: 'POST',
      path: 'documents/$documentId/attachments',
      fields: {'label': label, 'sort': sort.toString()},
      files: [await http.MultipartFile.fromPath('file', file.path)],
    );
    return AttachmentModel.fromJson(_asMap(data));
  }

  /// `DELETE /documents/{id}/attachments/{attachmentId}`.
  Future<void> deleteAttachment(String documentId, String attachmentId) {
    return _api
        .delete('documents/$documentId/attachments/$attachmentId')
        .then((_) {});
  }

  // ——— penerbitan ———

  /// `POST /documents/{id}/pre-final` — mode `a` render isi, mode `b`
  /// stempel QR ke `pdfBase64` (overlay custom opsional, default posisi
  /// kanan-atas). Return `{download_url, expires_in}` (URL signed 15
  /// menit, tanpa bearer).
  Future<Map<String, dynamic>> preFinal(
    String id, {
    required String mode, // 'a' | 'b'
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
  }) async {
    final data = await _api.post('documents/$id/pre-final',
        body: <String, dynamic>{
          'mode': mode,
          if (pdfBase64 != null) 'pdf_base64': pdfBase64,
          if (overlays != null) 'overlays': overlays,
        });
    return _asMap(data);
  }

  /// `POST /documents/{id}/finalize` (JSON) — metode `a` render, `b`
  /// stempel QR ke [pdfBase64], `c` PDF ber-ttd elektronik resmi (tanpa
  /// overlay). Return `{issuance, verify_url, number}`.
  Future<Map<String, dynamic>> finalize(
    String id, {
    required String method, // 'a' | 'b' | 'c'
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
  }) async {
    final data = await _api.post('documents/$id/finalize',
        body: <String, dynamic>{
          'method': method,
          if (pdfBase64 != null) 'pdf_base64': pdfBase64,
          if (overlays != null) 'overlays': overlays,
        });
    return _asMap(data);
  }

  /// `POST /documents/{id}/finalize` (multipart metode `d`) — foto/scan
  /// (tiap maks 20 MB) dikomposisi backend menjadi satu PDF.
  Future<Map<String, dynamic>> finalizeManual(
    String id,
    List<File> images, {
    String? note,
  }) async {
    final files = <http.MultipartFile>[];
    for (final image in images) {
      files.add(await http.MultipartFile.fromPath('images[]', image.path));
    }
    final data = await _api.multipart(
      method: 'POST',
      path: 'documents/$id/finalize',
      fields: <String, String>{
        'method': 'd',
        if (note != null) 'note': note,
      },
      files: files,
    );
    return _asMap(data);
  }

  /// `POST /documents/{id}/reissue` — terbitkan ulang surat `terbit`;
  /// [note] alasan WAJIB (tercatat di issuance + audit). Return
  /// `{issuance, verify_url, number, note}`.
  Future<Map<String, dynamic>> reissue(
    String id, {
    required String method, // 'a' | 'b' | 'c' | 'd'
    required String note,
    String? pdfBase64,
    List<Map<String, dynamic>>? overlays,
    List<String>? imagesBase64,
  }) async {
    final data = await _api.post('documents/$id/reissue',
        body: <String, dynamic>{
          'method': method,
          'note': note,
          if (pdfBase64 != null) 'pdf_base64': pdfBase64,
          if (overlays != null) 'overlays': overlays,
          if (imagesBase64 != null) 'images_base64': imagesBase64,
        });
    return _asMap(data);
  }

  /// `POST /documents/{id}/revoke` — cabut; HANYA jenis KUA & status
  /// `terbit` (else 422/409). [revokedAt] wajib (backend `required,date`).
  Future<Map<String, dynamic>> revoke(
    String id, {
    required String reason,
    required DateTime revokedAt,
  }) async {
    final data = await _api.post('documents/$id/revoke',
        body: <String, dynamic>{
          'reason': reason,
          'revoked_at': revokedAt.toIso8601String(),
        });
    return _asMap(data);
  }

  /// `POST /documents/{id}/void` — batalkan (semua jenis; status
  /// draft|menunggu_ttd|terbit).
  Future<Map<String, dynamic>> voidDocument(String id,
      {required String reason}) async {
    final data = await _api.post('documents/$id/void',
        body: {'reason': reason});
    return _asMap(data);
  }

  // ——— wizard: jenis, template, buku pihak ———

  /// `GET /letter-types` — hanya yang aktif, urut kode.
  Future<List<LetterTypeModel>> getLetterTypes() async {
    final data = await _api.get('letter-types');
    return _mapList<LetterTypeModel>(data, LetterTypeModel.fromJson);
  }

  /// `GET /templates?letter_type_code=` — template aktif per jenis,
  /// default duluan.
  Future<List<TemplateModel>> getTemplates(String letterTypeCode) async {
    final data = await _api.get('templates',
        queryParams: {'letter_type_code': letterTypeCode});
    return _mapList<TemplateModel>(data, TemplateModel.fromJson);
  }

  /// `GET /parties?q=&page=` — cari buku pihak (paginate 15).
  Future<PaginatedResult<PartyModel>> getParties({
    String? query,
    int page = 1,
  }) async {
    final body = await _api.getRaw('parties', queryParams: <String, String>{
      if (query != null && query.isNotEmpty) 'q': query,
      'page': page.toString(),
    });
    return PaginatedResult.fromEnvelope(body, fromJson: PartyModel.fromJson);
  }

  /// `POST /parties` — tambah pihak baru.
  Future<PartyModel> createParty({
    required String name,
    String? identityNo,
    String? address,
    String? occupation,
    String? notes,
  }) async {
    final data = await _api.post('parties',
        body: <String, dynamic>{
          'name': name,
          if (identityNo != null) 'identity_no': identityNo,
          if (address != null) 'address': address,
          if (occupation != null) 'occupation': occupation,
          if (notes != null) 'notes': notes,
        });
    return PartyModel.fromJson(_asMap(data));
  }

  // ——— helper ———

  static Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  static List<T> _mapList<T>(
      dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is! List) return <T>[];
    return data
        .whereType<Map>()
        .map((e) => fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Backend menerima `date` format `Y-m-d`.
  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
