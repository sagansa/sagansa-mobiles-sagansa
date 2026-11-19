import 'dart:io';
import 'dart:typed_data' as typed_data;

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/utils/image_utils.dart';

class _MockCompressPlatform extends FlutterImageCompressPlatform {
  bool shouldThrow = false;

  @override
  FlutterImageCompressValidator get validator =>
      FlutterImageCompressValidator(const MethodChannel('flutter_image_compress'));

  @override
  Future<void> showNativeLog(bool value) async {}

  @override
  void ignoreCheckSupportPlatform(bool bool) {}

  @override
  Future<XFile?> compressAndGetFile(
    String path,
    String targetPath, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    if (shouldThrow) {
      throw CompressError('Failed to decode image data', code: 'decode_failed');
    }
    File(targetPath).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
    return XFile(targetPath);
  }

  @override
  Future<typed_data.Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async =>
      null;

  @override
  Future<typed_data.Uint8List> compressWithList(
    typed_data.Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async =>
      image;

  @override
  Future<typed_data.Uint8List?> compressAssetImage(
    String assetName, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late File srcFile;
  late _MockCompressPlatform mockPlatform;
  late FlutterImageCompressPlatform originalPlatform;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('img_test_');
    srcFile = File('${tmpDir.path}/source.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

    mockPlatform = _MockCompressPlatform();
    originalPlatform = FlutterImageCompressPlatform.instance;
    FlutterImageCompressPlatform.instance = mockPlatform;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return tmpDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    FlutterImageCompressPlatform.instance = originalPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (srcFile.existsSync()) await srcFile.delete();
    if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
  });

  group('compressImage fallback on decode_failed', () {
    test(
      'returns original file when compress throws CompressError(decode_failed)',
      () async {
        mockPlatform.shouldThrow = true;

        final result = await ImageUtils.compressImage(srcFile.path);

        expect(result, isA<File>());
        expect(result.path, srcFile.path);
        expect(result.existsSync(), isTrue);
      },
    );

    test('returns compressed file when compression succeeds', () async {
      mockPlatform.shouldThrow = false;

      final result = await ImageUtils.compressImage(srcFile.path);

      expect(result, isA<File>());
      expect(result.path, isNot(srcFile.path));
      expect(result.existsSync(), isTrue);
    });
  });
}
