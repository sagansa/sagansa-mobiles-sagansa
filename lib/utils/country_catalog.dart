/// Negara asal supplier (ISO 3166-1 alpha-2) beserta valuta umum dan kode
/// telepon — dipakai form supplier luar negeri dan prefill valuta impor.
class Country {
  final String code;
  final String name;
  final String currency;
  final String dialCode;

  const Country(this.code, this.name, this.currency, this.dialCode);

  @override
  bool operator ==(Object other) => other is Country && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class CountryCatalog {
  CountryCatalog._();

  static const Country indonesia = Country('ID', 'Indonesia', 'IDR', '+62');

  /// Supplier dianggap luar negeri bila kode negara terisi dan bukan ID;
  /// baris lama tanpa kode negara tetap dibaca sebagai domestik.
  static bool isForeign(String? code) =>
      code != null && code.isNotEmpty && code.toUpperCase() != indonesia.code;

  static Country? byCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final upper = code.toUpperCase();
    if (upper == indonesia.code) return indonesia;
    for (final c in foreign) {
      if (c.code == upper) return c;
    }
    return null;
  }

  static String nameOf(String? code) => byCode(code)?.name ?? (code ?? '');

  /// Daftar negara luar negeri, terurut nama Indonesia.
  static final List<Country> foreign = List<Country>.unmodifiable(
    [..._raw]..sort((a, b) => a.name.compareTo(b.name)),
  );

  static const List<Country> _raw = [
    Country('AF', 'Afganistan', 'AFN', '+93'),
    Country('ZA', 'Afrika Selatan', 'ZAR', '+27'),
    Country('DZ', 'Aljazair', 'DZD', '+213'),
    Country('US', 'Amerika Serikat', 'USD', '+1'),
    Country('AO', 'Angola', 'AOA', '+244'),
    Country('SA', 'Arab Saudi', 'SAR', '+966'),
    Country('AR', 'Argentina', 'ARS', '+54'),
    Country('AM', 'Armenia', 'AMD', '+374'),
    Country('AU', 'Australia', 'AUD', '+61'),
    Country('AT', 'Austria', 'EUR', '+43'),
    Country('AZ', 'Azerbaijan', 'AZN', '+994'),
    Country('BH', 'Bahrain', 'BHD', '+973'),
    Country('BD', 'Bangladesh', 'BDT', '+880'),
    Country('NL', 'Belanda', 'EUR', '+31'),
    Country('BY', 'Belarus', 'BYN', '+375'),
    Country('BE', 'Belgia', 'EUR', '+32'),
    Country('BJ', 'Benin', 'XOF', '+229'),
    Country('BO', 'Bolivia', 'BOB', '+591'),
    Country('BW', 'Botswana', 'BWP', '+267'),
    Country('BR', 'Brasil', 'BRL', '+55'),
    Country('BN', 'Brunei Darussalam', 'BND', '+673'),
    Country('BG', 'Bulgaria', 'BGN', '+359'),
    Country('BF', 'Burkina Faso', 'XOF', '+226'),
    Country('CZ', 'Ceko', 'CZK', '+420'),
    Country('CL', 'Chili', 'CLP', '+56'),
    Country('DK', 'Denmark', 'DKK', '+45'),
    Country('EC', 'Ekuador', 'USD', '+593'),
    Country('SV', 'El Salvador', 'USD', '+503'),
    Country('EE', 'Estonia', 'EUR', '+372'),
    Country('ET', 'Etiopia', 'ETB', '+251'),
    Country('FJ', 'Fiji', 'FJD', '+679'),
    Country('PH', 'Filipina', 'PHP', '+63'),
    Country('FI', 'Finlandia', 'EUR', '+358'),
    Country('GM', 'Gambia', 'GMD', '+220'),
    Country('GE', 'Georgia', 'GEL', '+995'),
    Country('GH', 'Ghana', 'GHS', '+233'),
    Country('GT', 'Guatemala', 'GTQ', '+502'),
    Country('GN', 'Guinea', 'GNF', '+224'),
    Country('GW', 'Guinea-Bissau', 'XOF', '+245'),
    Country('HN', 'Honduras', 'HNL', '+504'),
    Country('HK', 'Hong Kong', 'HKD', '+852'),
    Country('HU', 'Hungaria', 'HUF', '+36'),
    Country('IN', 'India', 'INR', '+91'),
    Country('GB', 'Inggris', 'GBP', '+44'),
    Country('IQ', 'Irak', 'IQD', '+964'),
    Country('IR', 'Iran', 'IRR', '+98'),
    Country('IE', 'Irlandia', 'EUR', '+353'),
    Country('IL', 'Israel', 'ILS', '+972'),
    Country('IT', 'Italia', 'EUR', '+39'),
    Country('JP', 'Jepang', 'JPY', '+81'),
    Country('DE', 'Jerman', 'EUR', '+49'),
    Country('KH', 'Kamboja', 'KHR', '+855'),
    Country('CM', 'Kamerun', 'XAF', '+237'),
    Country('CA', 'Kanada', 'CAD', '+1'),
    Country('KZ', 'Kazakhstan', 'KZT', '+7'),
    Country('KE', 'Kenya', 'KES', '+254'),
    Country('KG', 'Kirgistan', 'KGS', '+996'),
    Country('CO', 'Kolombia', 'COP', '+57'),
    Country('CD', 'Kongo (RDK)', 'CDF', '+243'),
    Country('KR', 'Korea Selatan', 'KRW', '+82'),
    Country('CR', 'Kosta Rika', 'CRC', '+506'),
    Country('HR', 'Kroasia', 'EUR', '+385'),
    Country('KW', 'Kuwait', 'KWD', '+965'),
    Country('LA', 'Laos', 'LAK', '+856'),
    Country('LV', 'Latvia', 'EUR', '+371'),
    Country('LB', 'Lebanon', 'LBP', '+961'),
    Country('LR', 'Liberia', 'LRD', '+231'),
    Country('LT', 'Lituania', 'EUR', '+370'),
    Country('MG', 'Madagaskar', 'MGA', '+261'),
    Country('MO', 'Makau', 'MOP', '+853'),
    Country('MV', 'Maladewa', 'MVR', '+960'),
    Country('MW', 'Malawi', 'MWK', '+265'),
    Country('MY', 'Malaysia', 'MYR', '+60'),
    Country('ML', 'Mali', 'XOF', '+223'),
    Country('MA', 'Maroko', 'MAD', '+212'),
    Country('MX', 'Meksiko', 'MXN', '+52'),
    Country('EG', 'Mesir', 'EGP', '+20'),
    Country('MN', 'Mongolia', 'MNT', '+976'),
    Country('MZ', 'Mozambik', 'MZN', '+258'),
    Country('MM', 'Myanmar', 'MMK', '+95'),
    Country('NA', 'Namibia', 'NAD', '+264'),
    Country('NP', 'Nepal', 'NPR', '+977'),
    Country('NI', 'Nikaragua', 'NIO', '+505'),
    Country('NG', 'Nigeria', 'NGN', '+234'),
    Country('NO', 'Norwegia', 'NOK', '+47'),
    Country('OM', 'Oman', 'OMR', '+968'),
    Country('PK', 'Pakistan', 'PKR', '+92'),
    Country('PA', 'Panama', 'USD', '+507'),
    Country('CI', 'Pantai Gading', 'XOF', '+225'),
    Country('PG', 'Papua Nugini', 'PGK', '+675'),
    Country('PY', 'Paraguay', 'PYG', '+595'),
    Country('PE', 'Peru', 'PEN', '+51'),
    Country('PL', 'Polandia', 'PLN', '+48'),
    Country('PT', 'Portugal', 'EUR', '+351'),
    Country('FR', 'Prancis', 'EUR', '+33'),
    Country('QA', 'Qatar', 'QAR', '+974'),
    Country('DO', 'Republik Dominika', 'DOP', '+1'),
    Country('RO', 'Rumania', 'RON', '+40'),
    Country('RU', 'Rusia', 'RUB', '+7'),
    Country('RW', 'Rwanda', 'RWF', '+250'),
    Country('NZ', 'Selandia Baru', 'NZD', '+64'),
    Country('SN', 'Senegal', 'XOF', '+221'),
    Country('RS', 'Serbia', 'RSD', '+381'),
    Country('SL', 'Sierra Leone', 'SLE', '+232'),
    Country('SG', 'Singapura', 'SGD', '+65'),
    Country('SK', 'Slowakia', 'EUR', '+421'),
    Country('SI', 'Slovenia', 'EUR', '+386'),
    Country('ES', 'Spanyol', 'EUR', '+34'),
    Country('LK', 'Sri Lanka', 'LKR', '+94'),
    Country('SD', 'Sudan', 'SDG', '+249'),
    Country('SE', 'Swedia', 'SEK', '+46'),
    Country('CH', 'Swiss', 'CHF', '+41'),
    Country('TW', 'Taiwan', 'TWD', '+886'),
    Country('TZ', 'Tanzania', 'TZS', '+255'),
    Country('TH', 'Thailand', 'THB', '+66'),
    Country('TL', 'Timor Leste', 'USD', '+670'),
    Country('CN', 'Tiongkok', 'CNY', '+86'),
    Country('TG', 'Togo', 'XOF', '+228'),
    Country('TN', 'Tunisia', 'TND', '+216'),
    Country('TR', 'Turki', 'TRY', '+90'),
    Country('UG', 'Uganda', 'UGX', '+256'),
    Country('UA', 'Ukraina', 'UAH', '+380'),
    Country('AE', 'Uni Emirat Arab', 'AED', '+971'),
    Country('UY', 'Uruguay', 'UYU', '+598'),
    Country('UZ', 'Uzbekistan', 'UZS', '+998'),
    Country('VE', 'Venezuela', 'VES', '+58'),
    Country('VN', 'Vietnam', 'VND', '+84'),
    Country('YE', 'Yaman', 'YER', '+967'),
    Country('JO', 'Yordania', 'JOD', '+962'),
    Country('GR', 'Yunani', 'EUR', '+30'),
    Country('ZM', 'Zambia', 'ZMW', '+260'),
    Country('ZW', 'Zimbabwe', 'ZWL', '+263'),
  ];
}

/// Valuta yang lazim dipakai supplier luar negeri — urutan sesuai frekuensi
/// pemakaian, kode lain tetap bisa dimasukkan lewat [withCode].
class CurrencyCatalog {
  CurrencyCatalog._();

  static const List<String> codes = [
    'USD', 'EUR', 'CNY', 'SGD', 'MYR', 'VND', 'INR', 'THB', 'JPY', 'AUD',
    'GBP', 'HKD', 'KRW', 'TWD', 'AED', 'SAR', 'PHP', 'BRL', 'ZAR', 'CHF',
    'CAD', 'NZD', 'TRY', 'EGP', 'NGN', 'GHS', 'TZS', 'KES', 'XOF', 'XAF',
    'PKR', 'BDT', 'LKR', 'MXN', 'ARS', 'CLP', 'COP', 'PEN',
  ];

  /// Daftar pilihan yang dijamin memuat [code] (mis. valuta dari data lama
  /// yang tidak ada di daftar standar) agar dropdown tetap bisa menampilkan
  /// nilai terpilih.
  static List<String> withCode(String? code) {
    if (code == null || code.isEmpty || codes.contains(code)) return codes;
    return [code, ...codes];
  }
}
