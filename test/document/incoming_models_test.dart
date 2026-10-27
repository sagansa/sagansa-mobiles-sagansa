import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sagansa/services/api_client.dart';
import 'package:sagansa/services/document/document_api_client.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/services/document/incoming_models.dart';
import 'package:sagansa/services/document/incoming_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parsing model surat masuk fase 1b dari fixture JSON persis bentuk
/// IncomingLetterResource (list + detail dispositions/thread) dan
/// ThreadBuilder, plus mapping error `{error:{code,message}}` (via
/// DocumentApiClient) dan field `in_reply_to` DocumentService.createDraft.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  // ——— envelope paginated GET /incoming-letters ———

  const paginatedIncomingEnvelope = {
    'success': true,
    'data': [
      {
        'id': 'a1a1a1a1-1111-4111-8111-111111111111',
        'agenda_number': 'SM-003/X/2026',
        'number_external': '023/DP/X/2026',
        'letter_date': '2026-10-01',
        'received_at': '2026-10-02',
        'year': 2026,
        'subject': 'Undangan Rapat Koordinasi',
        'sifat': 'segera',
        'classification': 'umum',
        'status': 'terdaftar',
        'attachments_note': '2 lembar lampiran',
        'company_id': null,
        'scan': {
          'sha256':
              'ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11',
          'size': 524288,
          'pages': 3,
        },
        'sender_party': {'id': 9, 'name': 'Dinas Perdagangan'},
        'created_by': 7,
        'created_at': '2026-10-02T03:04:05+00:00',
        'updated_at': '2026-10-02T03:04:05+00:00',
      },
      {
        // Rahasia tetap tampil penuh di list fase ini (internal) — hanya
        // metadata scan; isi bytes via endpoint stream terpisah.
        'id': 'a2a2a2a2-2222-4222-8222-222222222222',
        'agenda_number': 'SM-004/X/2026',
        'number_external': null,
        'letter_date': null,
        'received_at': '2026-10-03',
        'year': 2026,
        'subject': 'Pemberitahuan Penyesuaan Harga',
        'sifat': 'rahasia',
        'classification': 'rahasia',
        'status': 'diproses',
        'attachments_note': null,
        'company_id': null,
        'scan': {
          'sha256':
              'ff22ff22ff22ff22ff22ff22ff22ff22ff22ff22ff22ff22ff22ff22ff22ff22',
          'size': 1024,
          'pages': 1,
        },
        'sender_party': {'id': 5, 'name': 'PT Mitra Sejahtera'},
        'created_by': 7,
        'created_at': '2026-10-03T03:04:05+00:00',
        'updated_at': '2026-10-03T03:04:05+00:00',
      },
    ],
    'meta': {'current_page': 2, 'last_page': 3, 'total': 34, 'per_page': 15},
  };

  test('PaginatedResult.fromEnvelope memparse data + meta surat masuk', () {
    final page = PaginatedResult.fromEnvelope(
      paginatedIncomingEnvelope,
      fromJson: IncomingLetterModel.fromJson,
    );

    expect(page.items, hasLength(2));
    expect(page.currentPage, 2);
    expect(page.lastPage, 3);
    expect(page.total, 34);
    expect(page.perPage, 15);
    expect(page.hasMore, isTrue);

    final first = page.items.first;
    expect(first.id, 'a1a1a1a1-1111-4111-8111-111111111111');
    expect(first.agendaNumber, 'SM-003/X/2026');
    expect(first.numberExternal, '023/DP/X/2026');
    expect(first.senderParty?.id, 9);
    expect(first.senderParty?.name, 'Dinas Perdagangan');
    expect(first.letterDate, DateTime.parse('2026-10-01'));
    expect(first.receivedAt, DateTime.parse('2026-10-02'));
    expect(first.subject, 'Undangan Rapat Koordinasi');
    expect(first.sifat, 'segera');
    expect(first.sifatLabel, 'Segera');
    expect(first.status, 'terdaftar');
    expect(first.statusLabel, 'Terdaftar');
    expect(first.classificationLabel, 'Umum');
    expect(first.isSecret, isFalse);
    expect(first.scanSha256, startsWith('ee11'));
    expect(first.scanSize, 524288);
    expect(first.scanPages, 3);
    expect(first.attachmentsNote, '2 lembar lampiran');
    expect(first.createdAt, isNotNull);
    // Bentuk list: relasi detail tidak muncul (whenLoaded backend).
    expect(first.dispositions, isEmpty);
    expect(first.thread, isNull);
    expect(first.linksCount, isNull);

    // Rahasia: tampil dengan metadata scan (bytes via stream terpisah).
    final secret = page.items.last;
    expect(secret.isSecret, isTrue);
    expect(secret.sifatLabel, 'Rahasia');
    expect(secret.classificationLabel, 'Rahasia');
    expect(secret.numberExternal, isNull);
    expect(secret.letterDate, isNull);
    expect(secret.attachmentsNote, isNull);
    expect(secret.scanPages, 1);
    expect(secret.statusLabel, 'Diproses');
  });

  // ——— detail: dispositions + thread 4 node bercabang + links_count ———

  const incomingDetailData = {
    'id': 'a1a1a1a1-1111-4111-8111-111111111111',
    'agenda_number': 'SM-003/X/2026',
    'number_external': '023/DP/X/2026',
    'letter_date': '2026-10-01',
    'received_at': '2026-10-02',
    'year': 2026,
    'subject': 'Undangan Rapat Koordinasi',
    'sifat': 'segera',
    'classification': 'umum',
    'status': 'diproses',
    'attachments_note': null,
    'company_id': null,
    'scan': {
      'sha256':
          'ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11ee11',
      'size': 524288,
      'pages': 3,
    },
    'sender_party': {'id': 9, 'name': 'Dinas Perdagangan'},
    'created_by': 7,
    'created_at': '2026-10-02T03:04:05+00:00',
    'updated_at': '2026-10-06T03:04:05+00:00',
    'dispositions': [
      {
        'id': 'b1b1b1b1-1111-4111-8111-111111111111',
        'to_user_id': 4242,
        'to_user_label': 'Pengguna #4242',
        'instruction': 'Siapkan laporan kehadiran',
        'status': 'selesai',
        'acted_at': '2026-10-06T02:00:00+00:00',
        'created_at': '2026-10-05T01:00:00+00:00',
      },
      {
        'id': 'b2b2b2b2-2222-4222-8222-222222222222',
        'to_user_id': 11,
        'to_user_label': 'Pengguna #11',
        'instruction': 'Arsipkan lampiran rapat',
        'status': 'open',
        'acted_at': null,
        'created_at': '2026-10-05T01:05:00+00:00',
      },
    ],
    // Graf: incoming (akar) → D1 (balasan) → D2 (tindak_lanjut);
    //       incoming → D3 (referensi). Urutan flat chronological.
    'thread': {
      'root': {'type': 'incoming_letter', 'id': 'a1a1a1a1-1111-4111-8111-111111111111'},
      'nodes': [
        {
          'type': 'incoming_letter',
          'id': 'a1a1a1a1-1111-4111-8111-111111111111',
          'number': 'SM-003/X/2026',
          'date': '2026-10-01',
          'title': 'Undangan Rapat Koordinasi',
          'party_name': 'Dinas Perdagangan',
          'status': 'diproses',
          'relation_to_parent': null,
          'children_count': 2,
          'depth': 0,
        },
        {
          'type': 'document',
          'id': 'c1c1c1c1-1111-4111-8111-111111111111',
          'number': '001/ST/DIR/X/2026',
          'date': '2026-10-03',
          'title': 'Surat Tugas Menghadiri Rapat',
          'party_name': null,
          'status': 'terbit',
          'relation_to_parent': 'balasan',
          'children_count': 1,
          'depth': 1,
        },
        {
          'type': 'document',
          'id': 'c3c3c3c3-3333-4333-8333-333333333333',
          'number': '002/KUA/DIR/X/2026',
          'date': '2026-10-05',
          'title': 'Undangan Delegasi',
          'party_name': 'PT Mitra Sejahtera',
          'status': 'menunggu_ttd',
          'relation_to_parent': 'referensi',
          'children_count': 0,
          'depth': 1,
        },
        {
          'type': 'document',
          'id': 'c2c2c2c2-2222-4222-8222-222222222222',
          'number': '—',
          'date': '2026-10-07',
          'title': 'Laporan Tindak Lanjut Rapat',
          'party_name': null,
          'status': 'draft',
          'relation_to_parent': 'tindak_lanjut',
          'children_count': 0,
          'depth': 2,
        },
      ],
      'total': 4,
    },
    'links_count': 3,
  };

  test('IncomingLetterModel.fromJson memparse detail + disposisi + thread',
      () {
    final letter = IncomingLetterModel.fromJson(incomingDetailData);

    expect(letter.status, 'diproses');
    expect(letter.linksCount, 3);

    // Disposisi urut created_at: selesai + open.
    expect(letter.dispositions, hasLength(2));
    final done = letter.dispositions.first;
    expect(done.id, 'b1b1b1b1-1111-4111-8111-111111111111');
    expect(done.toUserId, 4242);
    expect(done.toUserLabel, 'Pengguna #4242');
    expect(done.instruction, 'Siapkan laporan kehadiran');
    expect(done.status, 'selesai');
    expect(done.statusLabel, 'Selesai');
    expect(done.isCompleted, isTrue);
    expect(done.actedAt, isNotNull);
    // Embed relasi detail TIDAK memuat incoming_letter_id.
    expect(done.incomingLetterId, isNull);
    final open = letter.dispositions.last;
    expect(open.status, 'open');
    expect(open.statusLabel, 'Terbuka');
    expect(open.isCompleted, isFalse);
    expect(open.actedAt, isNull);

    // Thread 4 node bercabang: akar incoming, depth 0-2, relation bervariasi.
    final thread = letter.thread;
    expect(thread, isNotNull);
    expect(thread!.rootType, 'incoming_letter');
    expect(thread.rootId, 'a1a1a1a1-1111-4111-8111-111111111111');
    expect(thread.total, 4);
    expect(thread.nodes, hasLength(4));
    expect(
      thread.isRoot('incoming_letter', 'a1a1a1a1-1111-4111-8111-111111111111'),
      isTrue,
    );
    expect(thread.isRoot('document', 'c1c1c1c1-1111-4111-8111-111111111111'),
        isFalse);

    final root = thread.nodes.first;
    expect(root.type, 'incoming_letter');
    expect(root.isIncomingLetter, isTrue);
    expect(root.number, 'SM-003/X/2026');
    expect(root.partyName, 'Dinas Perdagangan');
    expect(root.relationToParent, isNull); // akar
    expect(root.relationLabel, isNull);
    expect(root.childrenCount, 2);
    expect(root.depth, 0);

    final reply = thread.nodes[1];
    expect(reply.relationToParent, 'balasan');
    expect(reply.relationLabel, 'Membalas');
    expect(reply.depth, 1);
    expect(reply.isIncomingLetter, isFalse);

    final reference = thread.nodes[2];
    expect(reference.relationToParent, 'referensi');
    expect(reference.relationLabel, 'Mereferensikan');
    expect(reference.depth, 1);
    expect(reference.partyName, 'PT Mitra Sejahtera');

    final followUp = thread.nodes[3];
    expect(followUp.relationToParent, 'tindak_lanjut');
    expect(followUp.relationLabel, 'Menindaklanjuti');
    expect(followUp.depth, 2);
    // Document pra-nomor: backend mengirim '—' (bukan null/kosong).
    expect(followUp.number, '—');
    expect(followUp.displayNumber, '—');
  });

  test('ThreadModel.fromJson menoleransi bentuk minimal/null', () {
    const json = {
      'root': {'type': 'document', 'id': 'c1c1c1c1-1111-4111-8111-111111111111'},
      'nodes': [
        {
          'type': 'document',
          'id': 'c1c1c1c1-1111-4111-8111-111111111111',
          'number': null,
          'date': null,
          'title': null,
          'party_name': null,
          'status': null,
          'relation_to_parent': null,
          'children_count': null,
          'depth': null,
        },
      ],
      'total': 1,
    };

    final thread = ThreadModel.fromJson(json);
    expect(thread.total, 1);
    final node = thread.nodes.single;
    expect(node.number, isNull);
    expect(node.displayNumber, '—'); // fallback UI
    expect(node.date, isNull);
    expect(node.depth, 0);
    expect(node.childrenCount, 0);
    expect(node.relationLabel, isNull);
  });

  test('statusLabel/sifatLabel memetakan SEMUA nilai ke bahasa Indonesia',
      () {
    IncomingLetterModel fromJson(Map<String, dynamic> json) =>
        IncomingLetterModel.fromJson(json);

    expect(IncomingLetterModel.statusLabelOf('terdaftar'), 'Terdaftar');
    expect(IncomingLetterModel.statusLabelOf('diproses'), 'Diproses');
    expect(IncomingLetterModel.statusLabelOf('selesai'), 'Selesai');
    // Nilai tak dikenal tidak diubah (tidak menyembunyikan data).
    expect(IncomingLetterModel.statusLabelOf('aneh'), 'aneh');

    expect(IncomingLetterModel.sifatLabelOf('biasa'), 'Biasa');
    expect(IncomingLetterModel.sifatLabelOf('segera'), 'Segera');
    expect(IncomingLetterModel.sifatLabelOf('rahasia'), 'Rahasia');
    expect(IncomingLetterModel.sifatLabelOf('aneh'), 'aneh');

    // Scan null / absent tidak melempar (parsing toleran null).
    final bare = fromJson(const {
      'id': 'x',
      'agenda_number': 'SM-001/X/2026',
      'subject': 's',
      'sifat': 'biasa',
      'status': 'terdaftar',
    });
    expect(bare.scanSha256, isNull);
    expect(bare.scanSize, isNull);
    expect(bare.scanPages, isNull);
    expect(bare.classification, 'umum');
    expect(bare.senderParty, isNull);
    expect(bare.dispositions, isEmpty);

    // Relasi tak dikenal relationLabel mengembalikan kode mentah.
    final unknownRelation = ThreadNodeModel.fromJson(const {
      'type': 'document',
      'id': 'x',
      'relation_to_parent': 'lampiran',
    });
    expect(unknownRelation.relationLabel, 'lampiran');
  });

  test('createIncoming menolak payload scan tanpa/keduanya (mirror backend)',
      () {
    final service = IncomingService();

    expect(
      () => service.createIncoming(
        senderPartyId: 9,
        receivedAt: DateTime(2026, 10, 2),
        subject: 'Undangan',
        sifat: 'biasa',
      ),
      throwsArgumentError,
      reason: 'tanpa scan → ArgumentError sebelum request jalan',
    );

    expect(
      () => service.createIncoming(
        senderPartyId: 9,
        receivedAt: DateTime(2026, 10, 2),
        subject: 'Undangan',
        sifat: 'biasa',
        scanBytes: [1, 2, 3],
        scanImages: [
          const IncomingScanImage(bytes: [4, 5, 6], fileName: 'a.jpg'),
        ],
      ),
      throwsArgumentError,
      reason: 'scan + scan_images bersamaan → ArgumentError',
    );
  });

  // ——— DocumentService.createDraft + in_reply_to ———

  test('createDraft mengirim field in_reply_to object', () async {
    String? capturedBody;
    final mock = MockClient((request) async {
      capturedBody = request.body;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'd1d1d1d1-1111-4111-8111-111111111111',
            'number': null,
            'status': 'draft',
            'classification': 'umum',
            'subject': 'Balasan undangan rapat',
            'date': '2026-10-26',
          },
        }),
        201,
      );
    });

    await http.runWithClient(() async {
      final document = await DocumentService().createDraft(
        letterTypeCode: 'ST',
        unit: 'DIR',
        subject: 'Balasan undangan rapat',
        date: DateTime(2026, 10, 26),
        inReplyTo: const {
          'type': 'incoming_letter',
          'id': 'a1a1a1a1-1111-4111-8111-111111111111',
          'relation': 'balasan',
        },
      );
      expect(document.status, 'draft');
      expect(document.subject, 'Balasan undangan rapat');
    }, () => mock);

    final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
    expect(body['in_reply_to'], const {
      'type': 'incoming_letter',
      'id': 'a1a1a1a1-1111-4111-8111-111111111111',
      'relation': 'balasan',
    });
  });

  // ——— mapping error envelope ke ApiException ———

  test('DocumentApiClient memetakan INCOMING_LOCKED 409 ke ApiException',
      () async {
    const errorBody = {
      'error': {
        'code': 'INCOMING_LOCKED',
        'message':
            'Surat masuk sudah selesai — kolom isian dibekukan dan tidak dapat diubah.',
      },
    };
    final mock = MockClient(
      // Body utf8 (pesan berisi em-dash; Response default latin1).
      (request) async => http.Response.bytes(
        utf8.encode(jsonEncode(errorBody)),
        409,
      ),
    );

    await http.runWithClient(() async {
      await expectLater(
        DocumentApiClient().patch('incoming-letters/x', body: {
          'subject': 'ubah',
        }),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.errorCode,
                'errorCode',
                'INCOMING_LOCKED',
              )
              .having(
                (e) => e.message,
                'message',
                contains('dibekukan'),
              ),
        ),
      );
    }, () => mock);
  });

  test('getBytes mengembalikan bytes scan & memparse error 404 envelope',
      () async {
    final scanBytes = [0x25, 0x50, 0x44, 0x46]; // %PDF
    final mock = MockClient((request) async {
      if (request.url.path.contains('a1a1a1a1')) {
        return http.Response.bytes(scanBytes, 200);
      }
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Berkas scan tidak ditemukan.',
          },
        }),
        404,
      );
    });

    await http.runWithClient(() async {
      final bytes = await DocumentApiClient()
          .getBytes('incoming-letters/a1a1a1a1-1111-4111-8111-111111111111/scan');
      expect(bytes, scanBytes);

      await expectLater(
        DocumentApiClient().getBytes('incoming-letters/ghost/scan'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.errorCode, 'errorCode', 'NOT_FOUND'),
        ),
      );
    }, () => mock);
  });
}
