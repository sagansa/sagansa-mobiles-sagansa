import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/image_utils.dart';

class ImageService {
  static const String imgBaseUrl = String.fromEnvironment(
    'IMG_SERVICE_URL',
    defaultValue: 'https://img.sagansa.id',
  );

  /// Bangun URL publik dari path relatif atau URL absolut.
  static String? buildUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path; // Sudah URL absolut
    final clean = path.replaceAll(RegExp(r'^/+'), '');
    return '$imgBaseUrl/storage/$clean';
  }

  /// PIPELINE STANDAR ambil gambar untuk upload — dipakai semua fitur.
  ///
  /// 1. Pick via image_picker DENGAN constraint (sisi terpanjang 1024px,
  ///    kualitas [quality]): downscale + re-encode JPEG terjadi NATIVE
  ///    (ImageIO di iOS / BitmapFactory di Android) sehingga foto HEIC
  ///    bawaan iPhone ikut terkonversi ke JPEG dan memori tetap aman.
  ///    JANGAN pick tanpa constraint: file full-res memaksa decode berat
  ///    di Dart — main thread beku dan watchdog iOS membunuh app
  ///    (crash 0x8BADF00D), plus upload jadi ber-MB.
  /// 2. Kompres ulang native ke WebP (Android) / JPEG (iOS) via
  ///    [ImageUtils.compressImage] untuk mengecilkan ukuran upload.
  ///
  /// Return File siap dipakai / [ImageUploadService.upload]; null bila user
  /// membatalkan atau pick gagal (error sudah di-log).
  static Future<File?> pickAndResizeImage({
    required ImageSource source,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 75,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
        preferredCameraDevice: preferredCameraDevice,
      );
      if (pickedFile == null) return null;

      return await ImageUtils.compressImage(pickedFile.path, quality: quality);
    } catch (e) {
      debugPrint('ImageService: gagal pick/resize image: $e');
      return null;
    }
  }

  /// Ambil gambar dari aplikasi Files — di iOS termasuk iCloud Drive dan
  /// Google Drive bila File Provider-nya aktif. Hasil tetap dikompres.
  static Future<File?> pickImageFromFiles({
    int quality = 75,
  }) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return null;

      final path = files.first.path;
      if (path == null) return null;

      return await ImageUtils.compressImage(path, quality: quality);
    } catch (e) {
      debugPrint('ImageService: gagal pick image dari Files: $e');
      return null;
    }
  }

  /// Pipeline standar + dialog pilih sumber Kamera/Galeri/File terlebih dahulu.
  static Future<File?> selectAndPickImage(BuildContext context) async {
    final _PickSource? source = await showDialog<_PickSource>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.ltr,
        child: SimpleDialog(
          title: const Text('Pilih Sumber Foto'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogCtx, _PickSource.camera),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 10),
                  Text('Kamera'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogCtx, _PickSource.gallery),
              child: const Row(
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 10),
                  Text('Galeri'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogCtx, _PickSource.files),
              child: const Row(
                children: [
                  Icon(Icons.folder_open),
                  SizedBox(width: 10),
                  Text('File / Google Drive'),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    switch (source) {
      case _PickSource.camera:
        return pickAndResizeImage(source: ImageSource.camera);
      case _PickSource.gallery:
        return pickAndResizeImage(source: ImageSource.gallery);
      case _PickSource.files:
        return pickImageFromFiles();
      case null:
        return null;
    }
  }
}

enum _PickSource { camera, gallery, files }
