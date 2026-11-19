/// Parser payload EMV QRIS (TLV: tag 2 digit + length 2 digit + value).
///
/// Dipakai untuk menampilkan Nama Merchant (tag 59) dan NMID
/// (merchant PAN/ID di sub-TLV tag 26–51) langsung dari payload
/// supplier tanpa perlu panggilan API.
class QrisParsedPayload {
  final String? merchantName;
  final String? merchantCity;
  final String? merchantNmid;

  const QrisParsedPayload({
    this.merchantName,
    this.merchantCity,
    this.merchantNmid,
  });
}

Map<String, String> parseQrisTags(String payload) {
  final tags = <String, String>{};
  var offset = 0;
  while (offset + 4 <= payload.length) {
    final id = payload.substring(offset, offset + 2);
    final lengthText = payload.substring(offset + 2, offset + 4);
    final length = int.tryParse(lengthText);
    if (length == null) break;
    final valueEnd = offset + 4 + length;
    if (valueEnd > payload.length) break;
    tags[id] = payload.substring(offset + 4, valueEnd);
    offset = valueEnd;
  }
  return tags;
}

QrisParsedPayload parseQrisPayload(String payload) {
  final tags = parseQrisTags(payload);

  String? nmid;
  for (final entry in tags.entries) {
    final id = int.tryParse(entry.key);
    if (id == null || id < 26 || id > 51) continue;
    final children = parseQrisTags(entry.value);
    // NMID = merchant PAN (01) atau merchant id (02/03) pada sub-TLV.
    nmid ??= children['01'] ?? children['02'] ?? children['03'];
  }

  return QrisParsedPayload(
    merchantName: tags['59'],
    merchantCity: tags['60'],
    merchantNmid: nmid,
  );
}

class _QrisTag {
  final String id;
  final String value;
  const _QrisTag(this.id, this.value);
}

/// Parse payload menjadi daftar tag berurutan (untuk manipulasi payload).
List<_QrisTag> _parseTagList(String payload) {
  final tags = <_QrisTag>[];
  var offset = 0;
  while (offset + 4 <= payload.length) {
    final id = payload.substring(offset, offset + 2);
    final length = int.tryParse(payload.substring(offset + 2, offset + 4));
    if (length == null) break;
    final valueEnd = offset + 4 + length;
    if (valueEnd > payload.length) break;
    tags.add(_QrisTag(id, payload.substring(offset + 4, valueEnd)));
    offset = valueEnd;
  }
  return tags;
}

String _crc16Ccitt(String input) {
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

/// Ubah payload QRIS statis menjadi dinamis dengan menyisipkan [amount]
/// (tag 54), mengubah Point of Initiation menjadi dinamis (tag 01 = "12"),
/// lalu menghitung ulang CRC. Port dari QrisService::generateDynamicPayload
/// di services/api — output harus identik agar kompatibel dengan backend.
String generateDynamicQrisPayload(String staticPayload, int amount) {
  if (amount <= 0) {
    throw ArgumentError.value(amount, 'amount', 'harus lebih besar dari 0');
  }

  final tags = _parseTagList(staticPayload);
  if (tags.isEmpty) {
    throw FormatException('QRIS payload tidak valid');
  }

  final amountTag =
      '54${amount.toString().length.toString().padLeft(2, '0')}$amount';

  final buffer = StringBuffer();
  var amountWritten = false;
  for (final tag in tags) {
    if (tag.id == '63') continue; // CRC lama dibuang.
    if (tag.id == '01') {
      buffer.write('010212'); // Point of initiation: dinamis.
      continue;
    }
    if (tag.id == '54') {
      buffer.write(amountTag);
      amountWritten = true;
      continue;
    }
    if (!amountWritten && tag.id.compareTo('54') > 0) {
      buffer.write(amountTag);
      amountWritten = true;
    }
    buffer.write(tag.id);
    buffer.write(tag.value.length.toString().padLeft(2, '0'));
    buffer.write(tag.value);
  }
  if (!amountWritten) buffer.write(amountTag);

  final payloadForCrc = '${buffer.toString()}6304';
  return payloadForCrc + _crc16Ccitt(payloadForCrc);
}
