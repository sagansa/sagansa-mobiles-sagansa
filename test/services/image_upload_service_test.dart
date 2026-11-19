import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sagansa/services/image_upload_service.dart';

void main() {
  test('finalize memancarkan List<int> dan progres tanpa type error', () async {
    var sent = 0;
    int? total;
    final request = ProgressMultipartRequest(
      'POST',
      Uri.parse('https://img.example.test/api/upload'),
      onProgress: (s, t) {
        sent = s;
        total = t;
      },
    );

    request.fields['directory'] = 'images/Test';
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        Uint8List.fromList(List<int>.filled(64, 7)),
        filename: 'foto.jpg',
      ),
    );

    final chunks = await request.finalize().toList();
    final bytes = chunks.expand((chunk) => chunk).toList();

    expect(bytes, isNotEmpty);
    expect(sent, greaterThan(0));
    expect(total, isNotNull);
  });
}
