import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/services/api_client.dart';
import 'package:sagansa/services/document/document_api_client.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parsing model domain surat dari fixture JSON persis bentuk envelope
/// service document, plus mapping error `{error:{code,message}}` ke
/// [ApiException] (via DocumentApiClient).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  // ——— envelope paginated GET /documents ———

  const paginatedDocumentsEnvelope = {
    'success': true,
    'data': [
      {
        'id': '0f0e8d04-63f7-4d8e-9db3-2b1c00000001',
        'number': '001/ST/DIR/X/2026',
        'status': 'terbit',
        'classification': 'umum',
        'subject': 'Surat Tugas Audit Internal',
        'date': '2026-10-20',
        'letter_type': {'code': 'ST', 'name': 'Surat Tugas'},
        'metadata': {'kepada': 'Tim Audit'},
        'created_by': 7,
        'created_at': '2026-10-20T03:04:05+00:00',
        'updated_at': '2026-10-21T03:04:05+00:00',
        'active_issuance': {
          'id': 'a1111111-1111-1111-1111-111111111111',
          'method': 'a',
          'method_label': 'elektronik',
          'file_sha256':
              'aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00aa00',
          'finalized_at': '2026-10-21T03:04:05+00:00',
        },
      },
      {
        'id': '0f0e8d04-63f7-4d8e-9db3-2b1c00000002',
        'number': null,
        'status': 'draft',
        'classification': 'rahasia',
        'subject': 'Undangan RUPS',
        'date': '2026-10-22',
        'letter_type': {'code': 'KUA', 'name': 'Surat Undangan'},
        'metadata': null,
        'created_by': 9,
        'created_at': '2026-10-22T03:04:05+00:00',
        'updated_at': '2026-10-22T03:04:05+00:00',
      },
    ],
    'meta': {'current_page': 1, 'last_page': 4, 'total': 38, 'per_page': 10},
  };

  test('PaginatedResult.fromEnvelope memparse data + meta dokumen', () {
    final page = PaginatedResult.fromEnvelope(
      paginatedDocumentsEnvelope,
      fromJson: DocumentModel.fromJson,
    );

    expect(page.items, hasLength(2));
    expect(page.currentPage, 1);
    expect(page.lastPage, 4);
    expect(page.total, 38);
    expect(page.perPage, 10);
    expect(page.hasMore, isTrue);

    final first = page.items.first;
    expect(first.id, '0f0e8d04-63f7-4d8e-9db3-2b1c00000001');
    expect(first.number, '001/ST/DIR/X/2026');
    expect(first.status, 'terbit');
    expect(first.statusLabel, 'Terbit');
    expect(first.classificationLabel, 'Umum');
    expect(first.letterType?.code, 'ST');
    expect(first.letterType?.name, 'Surat Tugas');
    expect(first.metadata?['kepada'], 'Tim Audit');
    expect(first.date, DateTime.parse('2026-10-20'));
    expect(first.activeIssuance?.method, 'a');
    expect(first.activeIssuance?.methodLabel, 'elektronik');
    expect(first.activeIssuance?.methodLabelText, contains('Elektronik'));
    expect(first.activeIssuance?.fileSha256, startsWith('aa00'));
    expect(first.activeIssuance?.finalizedAt, isNotNull);

    // Draft pra-nomor: number null (bukan string kosong).
    final second = page.items.last;
    expect(second.number, isNull);
    expect(second.statusLabel, 'Draft');
    expect(second.isSecret, isTrue);
    expect(second.isEditable, isTrue);
    expect(second.metadata, isNull);
    expect(second.attachments, isEmpty);
    expect(second.issuances, isEmpty);
  });

  test('statusLabel memetakan SEMUA status ke bahasa Indonesia', () {
    DocumentModel fromStatus(String status) => DocumentModel.fromJson(
        {'id': 'x', 'status': status, 'subject': 's'});

    expect(fromStatus('draft').statusLabel, 'Draft');
    expect(fromStatus('menunggu_ttd').statusLabel, 'Menunggu ttd');
    expect(fromStatus('terbit').statusLabel, 'Terbit');
    expect(fromStatus('dicabut').statusLabel, 'Dicabut');
    expect(fromStatus('dibatalkan').statusLabel, 'Dibatalkan');
    // Status tak dikenal tidak diubah (tidak menyembunyikan data).
    expect(fromStatus('aneh').statusLabel, 'aneh');
  });

  // ——— detail dokumen: issuances + attachments + signing requests ———

  const documentDetailData = {
    'id': '0f0e8d04-63f7-4d8e-9db3-2b1c00000003',
    'number': '002/KUA/DPR/X/2026',
    'status': 'terbit',
    'classification': 'umum',
    'subject': 'Undangan Rapat Pleno',
    'date': '2026-10-23',
    'letter_type': {'code': 'KUA', 'name': 'Surat Undangan'},
    'metadata': {'tempat': 'Ruang Rapat B'},
    'created_by': 7,
    'created_at': '2026-10-23T01:02:03+00:00',
    'updated_at': '2026-10-25T08:09:10+00:00',
    'active_issuance': {
      'id': 'b2222222-2222-2222-2222-222222222222',
      'method': 'b',
      'method_label': 'elektronik',
      'file_sha256':
          'bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11',
      'finalized_at': '2026-10-25T08:09:10+00:00',
    },
    'issuances': [
      {
        'id': 'a1111111-2222-3333-4444-555555555555',
        'method': 'a',
        'method_label': 'elektronik',
        'file_sha256':
            'cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22cc22',
        'is_active': false,
        'replaced_by_id': 'b2222222-2222-2222-2222-222222222222',
        'finalized_at': '2026-10-23T09:00:00+00:00',
      },
      {
        'id': 'b2222222-2222-2222-2222-222222222222',
        'method': 'b',
        'method_label': 'elektronik',
        'file_sha256':
            'bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11',
        'is_active': true,
        'replaced_by_id': null,
        'finalized_at': '2026-10-25T08:09:10+00:00',
      },
    ],
    'attachments': [
      {
        'id': 'c3333333-3333-3333-3333-333333333333',
        'label': 'Daftar Hadir',
        'sort': 1,
        'mime': 'application/pdf',
        'size': 204800,
        'sha256':
            'dd33dd33dd33dd33dd33dd33dd33dd33dd33dd33dd33dd33dd33dd33dd33dd33',
      },
      {
        'id': 'd4444444-4444-4444-4444-444444444444',
        'label': 'Denah Ruang',
        'sort': 2,
        'mime': 'image/png',
        'size': 1024,
        'sha256': null,
      },
    ],
    'signing_requests': [
      {
        'id': 'e5555555-5555-5555-5555-555555555555',
        'status': 'disetujui',
        'requested_at': '2026-10-24T02:00:00+00:00',
        'acted_at': '2026-10-24T05:00:00+00:00',
        'signer': {
          'display_name': 'Budi Komisaris',
          'role': 'komisaris',
        },
      },
      {
        'id': 'f6666666-6666-6666-6666-666666666666',
        'status': 'diminta',
        'requested_at': '2026-10-24T02:00:00+00:00',
        'acted_at': null,
        'signer': {
          'display_name': 'Citra Pemegang Saham',
          'role': 'pemegang_saham',
        },
      },
    ],
  };

  test('DocumentModel.fromJson memparse detail relasi lengkap', () {
    final document = DocumentModel.fromJson(documentDetailData);

    expect(document.id, documentDetailData['id']);
    expect(document.number, '002/KUA/DPR/X/2026');
    expect(document.hasPendingSignature, isTrue);
    expect(document.isEditable, isFalse); // terbit

    // active_issuance + riwayat issuances.
    expect(document.activeIssuance?.id, 'b2222222-2222-2222-2222-222222222222');
    expect(document.issuances, hasLength(2));
    expect(document.issuances.first.isActive, isFalse);
    expect(document.issuances.first.replacedById,
        'b2222222-2222-2222-2222-222222222222');
    expect(document.issuances.last.isActive, isTrue);
    expect(document.issuances.last.note, isNull);

    // attachments (sha256 nullable di-toleransi).
    expect(document.attachments, hasLength(2));
    expect(document.attachments.first.label, 'Daftar Hadir');
    expect(document.attachments.first.sort, 1);
    expect(document.attachments.first.size, 204800);
    expect(document.attachments.last.sha256, isNull);

    // signing_requests + signer bersarang.
    expect(document.signingRequests, hasLength(2));
    final approved = document.signingRequests.first;
    expect(approved.status, 'disetujui');
    expect(approved.statusLabel, 'Disetujui');
    expect(approved.isPending, isFalse);
    expect(approved.signer?.displayName, 'Budi Komisaris');
    expect(approved.signer?.roleLabel, 'Komisaris');
    final pending = document.signingRequests.last;
    expect(pending.isPending, isTrue);
    expect(pending.actedAt, isNull);
    expect(pending.signer?.roleLabel, 'Pemegang Saham');
  });

  test('SigningRequestModel memparse subset dokumen (daftar tugas mine)', () {
    const json = {
      'id': 'e5555555-5555-5555-5555-555555555555',
      'status': 'diminta',
      'requested_at': '2026-10-24T02:00:00+00:00',
      'acted_at': null,
      'note': null,
      'signer': {
        'id': 3,
        'role': 'direktur',
        'display_name': 'Ari Direktur',
        'title': 'Direktur Utama',
        'signature_ready': true,
      },
      'document': {
        'id': '0f0e8d04-63f7-4d8e-9db3-2b1c00000003',
        'number': '002/KUA/DPR/X/2026',
        'subject': 'Undangan Rapat Pleno',
        'status': 'menunggu_ttd',
      },
    };

    final request = SigningRequestModel.fromJson(json);
    expect(request.signer?.id, 3);
    expect(request.signer?.title, 'Direktur Utama');
    expect(request.signer?.signatureReady, isTrue);
    expect(request.document?.number, '002/KUA/DPR/X/2026');
    expect(request.document?.status, 'menunggu_ttd');
  });

  test('SignerModel meSigner + LetterType/Template/Party parse kunci', () {
    final signer = SignerModel.fromJson({
      'id': 11,
      'role': 'komisaris',
      'display_name': 'Budi',
      'title': null,
      'signature_ready': false,
    });
    expect(signer.id, 11);
    expect(signer.signatureReady, isFalse);
    expect(signer.title, isNull);

    final letterType = LetterTypeModel.fromJson({
      'code': 'ST',
      'name': 'Surat Tugas',
      'specific_fields': ['kepada', 'tanggal_selesai'],
    });
    expect(letterType.specificFields, ['kepada', 'tanggal_selesai']);

    final template = TemplateModel.fromJson({
      'id': 2,
      'name': 'Template Surat Tugas Standar',
      'letter_type_code': 'ST',
      'body_html': '<p>Halo</p>',
      'placeholders': ['number', 'date'],
      'is_default': true,
    });
    expect(template.letterTypeCode, 'ST');
    expect(template.isDefault, isTrue);
    expect(template.placeholders, ['number', 'date']);

    final party = PartyModel.fromJson({
      'id': 5,
      'name': 'PT Mitra Sejahtera',
      'identity_no': null,
      'address': 'Jl. Merdeka 1',
      'occupation': null,
      'notes': null,
      'created_at': '2026-10-01T00:00:00+00:00',
    });
    expect(party.name, 'PT Mitra Sejahtera');
    expect(party.identityNo, isNull);
    expect(party.createdAt, isNotNull);
  });

  // ——— mapping error envelope ke ApiException ———

  test('DocumentApiClient memetakan {error:{code,message}} ke ApiException',
      () async {
    const errorBody = {
      'error': {
        'code': 'DOCUMENT_LOCKED',
        'message':
            "Pra-final hanya bisa untuk draft|menunggu_ttd; surat ini berstatus 'terbit'.",
      },
    };
    final mock = MockClient(
      (request) async => http.Response(jsonEncode(errorBody), 409),
    );

    await http.runWithClient(() async {
      await expectLater(
        DocumentApiClient().get('documents'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                contains('Pra-final hanya bisa'),
              )
              .having((e) => e.errorCode, 'errorCode', 'DOCUMENT_LOCKED')
              .having(
                (e) => e.errorDetails,
                'errorDetails',
                isNull,
              ),
        ),
      );
    }, () => mock);
  });

  test('DocumentApiClient memetakan VALIDATION_ERROR + details per-field',
      () async {
    const errorBody = {
      'error': {
        'code': 'VALIDATION_ERROR',
        'message': 'Data yang dikirim tidak valid.',
        'details': {
          'letter_type': ['Pencabutan hanya berlaku untuk surat jenis KUA.'],
        },
      },
    };
    final mock = MockClient(
      (request) async => http.Response(jsonEncode(errorBody), 422),
    );

    await http.runWithClient(() async {
      await expectLater(
        DocumentApiClient().post('documents/x/revoke', body: {
          'reason': 'uji',
          'revoked_at': '2026-10-26T00:00:00Z',
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.errorCode, 'errorCode', 'VALIDATION_ERROR')
              .having(
                (e) => e.errorDetails?['letter_type'],
                'errorDetails.letter_type',
                isA<List<dynamic>>(),
              ),
        ),
      );
    }, () => mock);
  });
}
