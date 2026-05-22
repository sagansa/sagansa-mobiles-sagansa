import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  static Future<File?> pickAndResizeImage({
    required ImageSource source,
    int maxWidth = 1024, // ukuran maksimal lebar
    int maxHeight = 1024, // ukuran maksimal tinggi
    int quality = 85, // kualitas kompresi (0-100)
  }) async {
    try {
      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile == null) return null;

      // Baca file sebagai bytes
      final File imageFile = File(pickedFile.path);
      final bytes = await imageFile.readAsBytes();

      // Decode image
      final img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Resize image
      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.linear,
      );

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;
      final String targetPath =
          '$tempPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Encode dan simpan image yang sudah diresize
      final File targetFile = File(targetPath);
      await targetFile.writeAsBytes(
        img.encodeJpg(resizedImage, quality: quality),
      );

      return targetFile;
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }
}
