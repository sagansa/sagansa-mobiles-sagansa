import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/utils/whatsapp_utils.dart';

void main() {
  group('WhatsAppUtils.normalizePhone', () {
    test('format umum Indonesia', () {
      expect(WhatsAppUtils.normalizePhone('0812-3456-7890'), '6281234567890');
      expect(WhatsAppUtils.normalizePhone('+62 812 3456 7890'), '6281234567890');
      expect(WhatsAppUtils.normalizePhone('6281234567890'), '6281234567890');
      expect(WhatsAppUtils.normalizePhone('81234567890'), '6281234567890');
      expect(WhatsAppUtils.normalizePhone('(021) 555-0100'), '62215550100');
    });

    test('nomor luar negeri dibiarkan (sudah kode negara)', () {
      expect(WhatsAppUtils.normalizePhone('+65 9123 4567'), '6591234567');
    });

    test('invalid mengembalikan null', () {
      expect(WhatsAppUtils.normalizePhone(''), isNull);
      expect(WhatsAppUtils.normalizePhone('   '), isNull);
      expect(WhatsAppUtils.normalizePhone('abc'), isNull);
      expect(WhatsAppUtils.normalizePhone('1234567'), isNull); // < 8 digit
      expect(WhatsAppUtils.normalizePhone('0812'), isNull); // 62812 < 8 digit
    });
  });

  group('WhatsAppUtils.chatUri', () {
    test('menghasilkan uri wa.me', () {
      expect(
        WhatsAppUtils.chatUri('0812-3456-7890').toString(),
        'https://wa.me/6281234567890',
      );
    });

    test('null bila tidak bisa dinormalisasi', () {
      expect(WhatsAppUtils.chatUri('abc'), isNull);
    });
  });
}
