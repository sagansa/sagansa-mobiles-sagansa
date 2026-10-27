import '../token_store.dart';
import 'document_service.dart';

/// Gate akses modul Surat Perusahaan (menu drawer & halaman arsip).
///
/// User dianggap ber-akses bila memiliki minimal satu signer aktif di
/// service document (`GET /api/v1/me/signer` via
/// [DocumentService.getMySigners]) — penandatangan adalah pihak yang
/// berkepentingan dengan surat perusahaan (direktur/komisaris/pemegang
/// saham), bukan sekadar role staf di API utama.
///
/// Hasil dicek sekali per sesi login:
/// - Cache dikunci pada token aktif — semua jalur logout (manual lewat
///   `AuthProvider.logout` maupun auto-logout 401 lewat `AuthSession`)
///   selalu menghapus token di [TokenStore], sehingga cache otomatis
///   invalid untuk sesi berikutnya tanpa perlu hook di tiap jalur.
/// - Tambahan belt-and-braces: [reset] dipanggil eksplisit dari
///   `AuthProvider.logout()`.
/// - Kegagalan cek (offline/error server) mengembalikan `false`
///   (fail-closed: menu tidak dirender) TANPA di-cache, sehingga membuka
///   drawer lagi otomatis mencoba ulang begitu koneksi pulih.
class DocumentAccess {
  /// Konstruktor publik dengan dependensi inject-able untuk test;
  /// produksi memakai [instance] singleton.
  DocumentAccess({DocumentService? service, TokenStore? tokenStore})
      : _service = service ?? DocumentService(),
        _tokenStore = tokenStore ?? TokenStore.instance;

  /// Singleton produksi (dipakai drawer & AuthProvider.logout).
  static final DocumentAccess instance = DocumentAccess();

  final DocumentService _service;
  final TokenStore _tokenStore;

  /// Token yang dipakai saat cache diisi; beda token = sesi beda.
  String? _cachedForToken;

  /// Hasil cache; null = belum pernah dicek pada sesi ini.
  bool? _cachedValue;

  /// Pengecekan yang sedang berjalan (mencegah burst request saat beberapa
  /// FutureBuilder memanggil bersamaan, mis. drawer dibuka cepat).
  Future<bool>? _inFlight;

  /// True bila user boleh mengakses modul Surat Perusahaan.
  Future<bool> canAccess() async {
    final token = (await _tokenStore.readToken()) ?? '';
    final cached = _cachedValue;
    if (cached != null && _cachedForToken == token) return cached;
    final pending = _inFlight;
    if (pending != null) return pending;

    final future = _fetch(token);
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<bool> _fetch(String token) async {
    try {
      final signers = await _service.getMySigners();
      final allowed = signers.isNotEmpty;
      _cachedForToken = token;
      _cachedValue = allowed;
      return allowed;
    } catch (_) {
      // Fail-closed tanpa cache — pemanggilan berikutnya mencoba ulang.
      return false;
    }
  }

  /// Buang cache hasil pengecekan. Dipanggil saat logout (lihat
  /// `AuthProvider.logout`); tidak wajib untuk kebenaran (token sudah
  /// berubah/hilang), tetapi membuat invalidasi eksplisit dan instan.
  void reset() {
    _cachedForToken = null;
    _cachedValue = null;
    _inFlight = null;
  }
}
