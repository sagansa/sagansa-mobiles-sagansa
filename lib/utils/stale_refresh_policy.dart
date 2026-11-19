/// Kebijakan refresh data saat app kembali ke foreground (resume).
///
/// Latar: fetch dashboard hanya dipasang di initState HomePage, sehingga
/// membuka app dari background (proses masih hidup) menampilkan frame lama
/// tanpa panggilan API baru. Dengan kebijakan ini, resume me-refresh hanya
/// bila data terakhir di-fetch sudah lebih tua dari [threshold] — app-switch
/// singkat tidak memicu request berulang.
class StaleRefreshPolicy {
  /// Ambang umur data; di luar HomePage pakai default 5 menit.
  final Duration threshold;

  const StaleRefreshPolicy({this.threshold = const Duration(minutes: 5)});

  /// True bila perlu fetch ulang pada saat [now].
  /// [lastFetch] null berarti fetch pertama belum selesai — biarkan
  /// alur initState yang menanganinya, bukan resume.
  bool shouldRefresh(DateTime? lastFetch, DateTime now) {
    if (lastFetch == null) return false;
    return now.difference(lastFetch) >= threshold;
  }
}
