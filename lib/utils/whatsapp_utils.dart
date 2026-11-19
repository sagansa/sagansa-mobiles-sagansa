/// Normalisasi no telp Indonesia ke format click-to-chat wa.me.
class WhatsAppUtils {
  /// Mengembalikan nomor siap wa.me (angka saja, kode negara), atau null bila
  /// tidak bisa dinormalisasi:
  /// 1. buang semua non-digit;
  /// 2. mulai '0'  -> ganti leading 0 dengan '62';
  /// 3. mulai '8'  -> prepend '62' (nomor lokal tanpa prefix);
  /// 4. selain itu biarkan (dianggap sudah kode negara, mis. 62/65);
  /// 5. panjang hasil < 8 digit -> null.
  static String? normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    var normalized = digits;
    if (normalized.startsWith('0')) {
      normalized = '62${normalized.substring(1)}';
    } else if (normalized.startsWith('8')) {
      normalized = '62$normalized';
    }

    if (normalized.length < 8) return null;
    return normalized;
  }

  /// URI click-to-chat WhatsApp, atau null bila nomor tidak valid.
  static Uri? chatUri(String raw) {
    final normalized = normalizePhone(raw);
    if (normalized == null) return null;
    return Uri.parse('https://wa.me/$normalized');
  }
}
