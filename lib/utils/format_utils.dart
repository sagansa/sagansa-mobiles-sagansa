class FormatUtils {
  static String formatNumber(int number) {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = number
        .toString()
        .replaceAllMapped(reg, (Match match) => '${match[1]}.');
    return result;
  }

  static String formatCurrency(int number) {
    return 'Rp ${formatNumber(number)}';
  }

  static String formatDate(DateTime date) {
    // Implementasi format tanggal, misalnya:
    return '${date.day}-${date.month}-${date.year}';
  }
}
