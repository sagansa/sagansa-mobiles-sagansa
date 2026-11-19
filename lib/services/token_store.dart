import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth untuk JWT access token.
///
/// Token dipindahkan dari plain SharedPreferences ke secure storage
/// (Keychain iOS / EncryptedSharedPreferences / Keystore Android) untuk
/// mencegah exposure pada device rooted / backup forensic.
///
/// flutter_secure_storage v11 menggunakan AES-GCM + RSA OAEP key wrapping
/// secara default di Android (API 23+) dan Keychain di iOS.
///
/// Data NON-sensitif (user object, loginData, saved_email) tetap di
/// SharedPreferences — lihat spec secure-storage-migration.
class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _keyToken = 'token';
  static const _keyTokenType = 'token_type';

  // Default constructor sudah memberikan strong encryption (AES-GCM + RSA
  // OAEP). `resetOnError: true` mencegah fatal crash bila key corrupt —
  // data di-reset daripada throw (token hilang, user login ulang).
  FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Hanya untuk unit test — inject mock storage.
  @visibleForTesting
  void setStorageForTest(FlutterSecureStorage storage) =>
      _storage = storage;

  Future<String?> readToken() => _storage.read(key: _keyToken);
  Future<String?> readTokenType() => _storage.read(key: _keyTokenType);

  Future<void> writeToken(String token, {String? tokenType}) async {
    await _storage.write(key: _keyToken, value: token);
    if (tokenType != null) {
      await _storage.write(key: _keyTokenType, value: tokenType);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyTokenType);
  }

  static const _keyMigrated = 'token_migrated_v1';

  /// One-shot migration: pindahkan token dari SharedPreferences (versi lama)
  /// ke secure storage, lalu hapus dari prefs. Idempoten.
  ///
  /// Dijalankan di main() SEBELUM runApp, sehingga semua code path setelahnya
  /// membaca dari secure storage. Aman dipanggil berkali-kali: bila token
  /// sudah ada di secure storage, prefs hanya dibersihkan tanpa overwrite.
  Future<void> migrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyMigrated) == true) {
        return;
      }

      final legacyToken = prefs.getString('token');
      final legacyType = prefs.getString('token_type');

      if (legacyToken != null && legacyToken.isNotEmpty) {
        final existing = await readToken();
        // Hanya tulis kalau secure storage belum ada isinya (anti-overwrite
        // — token di secure storage lebih baru daripada prefs).
        if (existing == null || existing.isEmpty) {
          await writeToken(legacyToken, tokenType: legacyType);
        }
      }

      // Selalu bersihkan prefs (baik ada token lama maupun tidak), agar
      // prefs tidak lagi menyimpan token setelah migration pertama.
      await prefs.remove('token');
      await prefs.remove('token_type');
      await prefs.setBool(_keyMigrated, true);
    } catch (e) {
      // Migration gagal (mis. secure storage tidak support / key corrupt).
      // Jangan crash — biarkan code path normal berjalan; user akan diminta
      // login ulang karena readToken() mengembalikan null.
      debugPrint('TokenStore.migrateFromPrefs failed: $e');
    }
  }
}
