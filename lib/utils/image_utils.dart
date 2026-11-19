import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static const int _quality = 75;

  /// Deteksi PDF dari magic bytes `%PDF-`.
  ///
  /// Nama/path hasil picker dari cloud (Google Drive/iCloud) kadang tidak
  /// membawa ekstensi sehingga pengecekan ekstensi saja tidak cukup.
  static Future<bool> isPdf(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final raf = await file.open();
      try {
        final header = await raf.read(5);
        return header.length == 5 && String.fromCharCodes(header) == '%PDF-';
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Kompres gambar di perangkat untuk meminimalkan data yang dikirim ke server.
  ///
  /// Android  -> WebP lossy (~30% lebih kecil dari JPEG pada kualitas setara).
  /// iOS      -> JPEG (flutter_image_compress tidak mendukung encoder WebP di iOS).
  /// Web      -> mengembalikan file asli (kIsWeb).
  ///
  /// Jika encoder native tidak tersedia, atau kompresi native gagal (mis.
  /// `decode_failed` pada iOS untuk file yang rusak/terpotong), method ini
  /// fallback ke file asli sehingga alur pengambilan foto tidak putus.
  ///
  /// Catatan: flutter_image_compress ≥1.1.0 (common ≥1.1.0) melempar
  /// [CompressError] alih-alih mengembalikan null pada kegagalan kompresi.
  static Future<File> compressImage(String sourcePath, {int? quality}) async {
    if (kIsWeb) {
      return File(sourcePath);
    }

    final useWebP = defaultTargetPlatform == TargetPlatform.android;

    final dir = await getTemporaryDirectory();
    final ext = useWebP ? 'webp' : 'jpg';
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final targetPath = p.join(dir.path, name);

    XFile? xfile;
    try {
      xfile = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: quality ?? _quality,
        format: useWebP ? CompressFormat.webp : CompressFormat.jpeg,
        keepExif: false,
      );
    } on CompressError catch (e) {
      final file = File(sourcePath);
      final size = file.existsSync() ? file.lengthSync() : 0;
      List<int> header = [];
      if (size > 0) {
        final raf = file.openSync(mode: FileMode.read);
        // File rusak <12 byte (kosong/terpotong) justru kasus yang paling
        // perlu bukti magic-byte-nya.
        header = raf.readSync(size < 12 ? size : 12);
        raf.closeSync();
      }
      final hex =
          header.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      debugPrint(
        '[ImageUtils] compress failed (${e.code}): ${e.message} | '
        'src=$sourcePath size=${size}B header=$hex',
      );
      return file;
    }

    if (xfile == null) {
      return File(sourcePath);
    }

    return File(xfile.path);
  }
}
