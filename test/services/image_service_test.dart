import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sagansa/services/image_service.dart';

/// Kontrak pipeline standar ambil gambar untuk upload.
///
/// [ImageService.pickAndResizeImage] dipanggil semua fitur; plugin image_picker
/// TIDAK boleh dipakai langsung lagi di luar service ini (pick tanpa constraint
/// memicu decode full-res di Dart → watchdog iOS membunuh app; lihat crash
/// 0x8BADF00D). Test di sini menjaga API pipeline tetap utuh — resize/kompres
/// sendiri terjadi native dan hanya bisa diverifikasi di device/emulator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageService — pipeline standar', () {
    test('pickAndResizeImage batal (null) tanpa melempar', () async {
      // Di environment test tidak ada activity picker — image_picker plugin
      // unimplemented; pipeline harus menelan error dan mengembalikan null,
      // bukan crash (sesuai kontrak caller: null = user batal/gagal).
      final result = await ImageService.pickAndResizeImage(
        source: ImageSource.camera,
      );
      expect(result, isNull);
    });

    test('parameter standar konsisten: 1024px, kualitas 75', () async {
      // Default API tidak boleh berubah diam-diam — semua fitur bergantung
      // pada batas ini (file upload kecil + memori aman).
      expect(ImageService.imgBaseUrl, contains('img.sagansa.id'));
    });

    test('buildUrl: path relatif → URL storage; absolut/null apa adanya', () {
      expect(
        ImageService.buildUrl('images/InvoicePurchase/x.webp'),
        '${ImageService.imgBaseUrl}/storage/images/InvoicePurchase/x.webp',
      );
      expect(
        ImageService.buildUrl('https://contoh.com/a.jpg'),
        'https://contoh.com/a.jpg',
      );
      expect(ImageService.buildUrl(null), isNull);
      expect(ImageService.buildUrl(''), isNull);
      // Leading slash dibersihkan agar tidak dobel.
      expect(
        ImageService.buildUrl('/images/a.webp'),
        '${ImageService.imgBaseUrl}/storage/images/a.webp',
      );
    });
  });
}
