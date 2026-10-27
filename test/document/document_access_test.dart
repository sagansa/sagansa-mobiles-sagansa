import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sagansa/services/document/document_access.dart';
import 'package:sagansa/services/document/document_models.dart';
import 'package:sagansa/services/document/document_service.dart';
import 'package:sagansa/services/token_store.dart';

/// Kontrak [DocumentAccess]: gate modul Surat Perusahaan = punya minimal
/// satu signer aktif (`getMySigners` non-kosong), hasil di-cache per token
/// sesi, error gagal-tertutup (false) TANPA cache, dan [DocumentAccess.reset]
/// membuang cache untuk sesi berikutnya.
class _FakeDocumentService extends DocumentService {
  _FakeDocumentService({List<SignerModel>? signers, this.error})
      : _signers = signers;

  List<SignerModel>? _signers;
  Object? error;

  /// Jumlah pemanggilan `GET /me/signer` — untuk membuktikan cache.
  int fetchCount = 0;

  @override
  Future<List<SignerModel>> getMySigners() async {
    fetchCount++;
    final failure = error;
    if (failure != null) throw failure;
    return _signers ?? const <SignerModel>[];
  }
}

class _MockTokenStore extends Mock implements TokenStore {}

void main() {
  const signer = SignerModel(
    id: 7,
    role: 'direktur',
    displayName: 'Direktur Utama',
  );

  late _MockTokenStore tokenStore;

  setUp(() {
    tokenStore = _MockTokenStore();
    when(() => tokenStore.readToken())
        .thenAnswer((_) async => 'token-sesi-a');
  });

  DocumentAccess buildAccess(_FakeDocumentService service) =>
      DocumentAccess(service: service, tokenStore: tokenStore);

  test('canAccess true bila user punya signer aktif', () async {
    final service = _FakeDocumentService(signers: [signer]);
    expect(await buildAccess(service).canAccess(), isTrue);
  });

  test('canAccess false bila user tidak punya signer', () async {
    final service = _FakeDocumentService(signers: const []);
    expect(await buildAccess(service).canAccess(), isFalse);
  });

  test('hasil di-cache per sesi — getMySigners hanya dipanggil sekali',
      () async {
    final service = _FakeDocumentService(signers: [signer]);
    final access = buildAccess(service);

    await access.canAccess();
    await access.canAccess();

    expect(service.fetchCount, 1);
  });

  test('kegagalan cek (offline/server error) gagal-tertutup TANPA cache — '
      'pemanggilan berikutnya otomatis mencoba ulang', () async {
    final service = _FakeDocumentService(error: Exception('connection reset'));
    final access = buildAccess(service);

    expect(await access.canAccess(), isFalse);
    expect(service.fetchCount, 1);

    // Koneksi pulih — cek berikutnya (mis. drawer dibuka lagi) harus
    // memanggil ulang, bukan memakai hasil false yang gagal tadi.
    service.error = null;
    service._signers = [signer];
    expect(await access.canAccess(), isTrue);
    expect(service.fetchCount, 2);
  });

  test('cache tidak dipakai lintas sesi — token berubah berarti cek ulang',
      () async {
    final service = _FakeDocumentService(signers: [signer]);
    final access = buildAccess(service);

    await access.canAccess();
    when(() => tokenStore.readToken())
        .thenAnswer((_) async => 'token-sesi-b');
    await access.canAccess();

    expect(service.fetchCount, 2);
  });

  test('reset() membuang cache — logout lalu login ulang mengeeksekusi '
      'gate lagi untuk user baru', () async {
    final service = _FakeDocumentService(signers: [signer]);
    final access = buildAccess(service);

    await access.canAccess();
    access.reset();
    await access.canAccess();

    expect(service.fetchCount, 2);
  });

  test('instance produksi singleton konsisten', () {
    expect(DocumentAccess.instance, same(DocumentAccess.instance));
  });
}
