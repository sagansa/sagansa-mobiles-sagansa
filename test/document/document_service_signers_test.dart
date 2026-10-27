import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/services/document/document_service.dart';

/// Parse `GET /signers` (task 20) — parser bersama `parseSignerList` yang
/// dipakai `getSigners` (data array langsung) dan `getMySigners`
/// (`data.signers`), plus seam `fetchSigners` yang dioverride fake service.
class _FakeSignerService extends DocumentService {
  /// Isi `data` envelope yang dikembalikan GET /signers.
  dynamic dataToReturn;

  @override
  Future<dynamic> fetchSigners() async => dataToReturn;
}

void main() {
  test('parseSignerList: array signer → SignerModel urut apa adanya', () {
    final signers = DocumentService.parseSignerList([
      {
        'id': 1,
        'role': 'direktur',
        'display_name': 'Dira Direktur',
        'title': null,
        'signature_ready': false,
      },
      {
        'id': 2,
        'role': 'komisaris',
        'display_name': 'Rina Komisaris',
        'title': 'Komisaris Utama',
        'signature_ready': true,
      },
    ]);

    expect(signers, hasLength(2));
    expect(signers[0].id, 1);
    expect(signers[0].roleLabel, 'Direktur');
    expect(signers[0].signatureReady, isFalse);
    expect(signers[1].displayName, 'Rina Komisaris');
    expect(signers[1].title, 'Komisaris Utama');
    expect(signers[1].signatureReady, isTrue);
  });

  test('parseSignerList: bentuk tak dikenal → list kosong, tidak melempar',
      () {
    expect(DocumentService.parseSignerList(null), isEmpty);
    expect(DocumentService.parseSignerList('bukan list'), isEmpty);
    expect(DocumentService.parseSignerList([1, 'x', null]), isEmpty);
  });

  test('getSigners memakai fetchSigners lalu parse (seam fake)', () async {
    final service = _FakeSignerService()
      ..dataToReturn = [
        {
          'id': 9,
          'role': 'komisaris',
          'display_name': 'Bona Komisaris',
          'title': null,
          'signature_ready': true,
        },
      ];

    final signers = await service.getSigners();

    expect(signers, hasLength(1));
    expect(signers.single.id, 9);
    expect(signers.single.role, 'komisaris');
    expect(signers.single.roleLabel, 'Komisaris');
  });

  test('parseSignerList juga dipakai me/signer (data.signers map)', () {
    final envelope = {
      'signers': [
        {'id': 5, 'role': 'direktur', 'display_name': 'Ari'},
      ],
    };
    final signers = DocumentService.parseSignerList(envelope['signers']);
    expect(signers.single.displayName, 'Ari');
  });
}
