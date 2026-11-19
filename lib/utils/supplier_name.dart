/// Bentuk legal yang selalu ditulis kapital penuh.
const _uppercaseWords = {
  'PT',
  'CV',
  'UD',
  'PD',
  'TBK',
  'PERSERO',
  'PERUM',
  'BUMN',
  'BUMD',
  'KUD',
  'NV',
  'BV',
  'LTD',
  'INC',
  'LLC',
  'CORP',
  'GMBH',
  'SDN',
  'BHD',
  'JSC',
  'PLC',
  'PTE',
  'SPBU',
  'NS',
  'JNE',
  'POS',
  'TIKI',
  'DHL',
  'SICEPAT',
  'NINJA',
  'UPS',
  'FEDEX',
  'EMS',
};

/// Rapikan nama supplier: akronim/legal form tetap kapital penuh, kata lain
/// memakai huruf kapital di awal kata (Title Case).
String formatSupplierName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;

  return trimmed.replaceAllMapped(RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]+'), (match) {
    final word = match[0]!;
    final upper = word.toUpperCase();
    if (_uppercaseWords.contains(upper)) return upper;

    final lower = word.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  });
}
