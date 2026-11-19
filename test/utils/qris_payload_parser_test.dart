import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/utils/qris_payload_parser.dart';

void main() {
  // Payload statis QRIS contoh (format EMV TLV).
  const payload =
      '00020101021126690014ID.CO.QRIS.WWW011893600915000000000202181500000000000000000303UMI5204541153033605802ID5912TOKO SAGANSA6007JAKARTA6105102106209070503A01630415C4';
  group('parseQrisPayload', () {
    test('mengekstrak nama merchant, NMID, dan kota', () {
      final parsed = parseQrisPayload(payload);

      expect(parsed.merchantName, 'TOKO SAGANSA');
      expect(parsed.merchantNmid, '936009150000000002');
      expect(parsed.merchantCity, 'JAKARTA');
    });

    test('payload bukan TLV → semua field null tanpa crash', () {
      final parsed = parseQrisPayload('bukan-payload-qris');

      expect(parsed.merchantName, isNull);
      expect(parsed.merchantNmid, isNull);
      expect(parsed.merchantCity, isNull);
    });

    test('payload dengan tag 51 (merchant account alternatif)', () {
      // Tag 51 berisi sub-TLV: 01=merchant PAN (10), 02=merchant id, 03=kriteria.
      const alt =
          '00020101021151270110ID102600000202990303UMI5802ID5910WARUNG ABC6304ABCD';
      final parsed = parseQrisPayload(alt);

      expect(parsed.merchantName, 'WARUNG ABC');
      expect(parsed.merchantNmid, 'ID10260000');
    });
  });

  group('generateDynamicQrisPayload', () {
    test('output identik dengan backend PHP untuk amount 75000', () {
      // Golden value diambil dari QrisService::generateDynamicPayload
      // (services/api) — dipakai juga di FuelServiceSupplierReceiptTest.
      const expected =
          '00020101021226690014ID.CO.QRIS.WWW011893600915000000000202181500000000000000000303UMI5204541153033605405750005802ID5912TOKO SAGANSA6007JAKARTA6105102106209070503A0163048F4F';
      expect(generateDynamicQrisPayload(payload, 75000), expected);
    });

    test('payload hasil generate mengandung tag nominal & CRC valid', () {
      final dynamic100k = generateDynamicQrisPayload(payload, 100000);

      expect(dynamic100k, contains('010212')); // dinamis
      expect(dynamic100k, contains('5406100000')); // tag 54 = 100000
      // CRC dihitung ulang dari payload tanpa CRC.
      final withoutCrc = dynamic100k.substring(0, dynamic100k.length - 4);
      final recomputed = _crc16ForTest(withoutCrc);
      expect(dynamic100k.substring(dynamic100k.length - 4), recomputed);
      // Payload statis tidak berubah (fungsi murni).
      expect(payload.startsWith('000201010211'), isTrue);
    });

    test('amount <= 0 ditolak', () {
      expect(() => generateDynamicQrisPayload(payload, 0), throwsArgumentError);
      expect(() => generateDynamicQrisPayload(payload, -5), throwsArgumentError);
    });
  });
}

/// CRC16-CCITT-FALSE untuk memvalidasi output generator (mirror algoritma).
String _crc16ForTest(String input) {
  var crc = 0xFFFF;
  for (final codeUnit in input.codeUnits) {
    crc ^= codeUnit << 8;
    for (var i = 0; i < 8; i++) {
      if (crc & 0x8000 != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}
