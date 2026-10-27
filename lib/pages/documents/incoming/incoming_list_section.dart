import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/document/incoming_models.dart';
import '../../../services/document/incoming_service.dart';
import '../../../theme/app_button_style.dart';
import '../../../theme/app_spacing.dart';
import '../../../utils/error_utils.dart';
import '../../../widgets/app_page_scaffold.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/filter_chip_row.dart';
import '../../../widgets/modern_bottom_nav.dart';
import '../../../widgets/status_badge.dart';

/// Bagian "Masuk" arsip Surat Perusahaan — buku agenda surat masuk
/// (`IncomingService.getIncoming`) dengan pola persis bagian "Keluar"
/// fase 1: pencarian debounce, chip filter, infinite scroll,
/// pull-to-refresh, serta state loading/error/kosong.
///
/// Dipakai sebagai anak `IndexedStack` di `DocumentListPage` sehingga
/// state tiap tab terpisah dan dipertahankan saat pindah tab.
///
/// [service] adalah seam test — produksi memakai instance default
/// `IncomingService()`. [onSearchStateChanged] memberi tahu induk saat
/// baris pencarian dibuka/ditutup (ikon search AppBar mengikuti tab
/// aktif).
class IncomingListSection extends StatefulWidget {
  final IncomingService? service;
  final VoidCallback? onSearchStateChanged;

  const IncomingListSection({
    super.key,
    this.service,
    this.onSearchStateChanged,
  });

  @override
  State<IncomingListSection> createState() => IncomingListSectionState();
}

class IncomingListSectionState extends State<IncomingListSection> {
  late final IncomingService _service = widget.service ?? IncomingService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormatter = DateFormat('d MMM yyyy', 'id_ID');
  Timer? _searchDebounce;

  List<IncomingLetterModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Filter aktif — null berarti "Semua".
  String? _status;
  String? _sifat;
  int? _year;
  String? _query;
  bool _isSearchActive = false;

  /// Opsi tahun filter: Semua + 3 tahun terakhir (pola fase 1).
  late final List<int> _yearOptions = List.generate(
    3,
    (i) => DateTime.now().year - i,
  );

  static const List<String> _statusOptions = [
    'terdaftar',
    'diproses',
    'selesai',
  ];

  static const List<String> _sifatOptions = [
    'biasa',
    'segera',
    'rahasia',
  ];

  /// Baris pencarian sedang tampil (dibaca AppBar induk untuk ikon
  /// search/close).
  bool get isSearchActive => _isSearchActive;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Buka/tutup baris pencarian — dipanggil ikon search di AppBar induk
  /// untuk tab aktif.
  void toggleSearch() {
    if (_isSearchActive) {
      _closeSearch();
    } else {
      setState(() => _isSearchActive = true);
      widget.onSearchStateChanged?.call();
    }
  }

  /// Muat ulang daftar dari halaman pertama — dipanggil induk setelah
  /// kembali dari form pendaftaran (Task 9).
  void refresh() => _fetch();

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _items = [];
      _hasMore = true;
    });
    try {
      final result = await _service.getIncoming(
        status: _status,
        sifat: _sifat,
        year: _year,
        query: _query,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items.toList();
        _hasMore = result.hasMore;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorUtils.sanitize(e);
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.getIncoming(
        status: _status,
        sifat: _sifat,
        year: _year,
        query: _query,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  /// Pencarian dengan debounce 400 ms (pola fase 1) — request dikirim
  /// lewat field `q` backend.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = value.trim().isEmpty ? null : value.trim();
      if (q == _query) return;
      _query = q;
      _fetch();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _isSearchActive = false;
      _query = null;
    });
    widget.onSearchStateChanged?.call();
    _fetch();
  }

  /// TODO(Task 10): ganti placeholder dengan halaman detail surat masuk
  /// (info surat, disposisi, runutan, pratinjau scan).
  void _openDetail(IncomingLetterModel letter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingDetailPlaceholderPage(letter: letter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_isSearchActive) _buildSearchRow(colorScheme),
        _buildFilterRows(colorScheme),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: _errorMessage!,
                      subtitle: 'Terjadi kesalahan saat memuat data',
                      action: ElevatedButton.icon(
                        onPressed: _fetch,
                        style: AppButtonStyle.elevated(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                      ),
                    )
                  : !_hasLoaded
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? EmptyState(
                              icon: Icons.inbox_outlined,
                              title: _query != null
                                  ? 'Tidak ada surat masuk yang cocok dengan pencarian.'
                                  : 'Belum ada surat masuk.',
                              subtitle: _query != null
                                  ? 'Coba kata kunci lain atau hapus filter.'
                                  : 'Surat masuk yang didaftarkan akan tampil di sini.',
                            )
                          : _buildList(),
        ),
      ],
    );
  }

  Widget _buildSearchRow(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Cari agenda / nomor / perihal...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear_rounded),
            tooltip: 'Bersihkan pencarian',
            onPressed: () {
              _searchController.clear();
              if (_query != null) {
                setState(() => _query = null);
                _fetch();
              }
            },
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  /// Baris chip filter: status + sifat + tahun (pola fase 1; label dari
  /// `IncomingLetterModel` bahasa Indonesia).
  Widget _buildFilterRows(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChipRow<String?>(
            options: const [null, ..._statusOptions],
            selected: _status,
            onSelected: (value) {
              setState(() => _status = value);
              _fetch();
            },
            getLabel: (status) => status == null
                ? 'Semua'
                : IncomingLetterModel.statusLabelOf(status),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilterChipRow<String?>(
            options: const [null, ..._sifatOptions],
            selected: _sifat,
            onSelected: (value) {
              setState(() => _sifat = value);
              _fetch();
            },
            getLabel: (sifat) => sifat == null
                ? 'Semua'
                : IncomingLetterModel.sifatLabelOf(sifat),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilterChipRow<int?>(
            options: [null, ..._yearOptions],
            selected: _year,
            onSelected: (value) {
              setState(() => _year = value);
              _fetch();
            },
            getLabel: (year) => year == null ? 'Semua' : year.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.md,
          ModernBottomNav.clearance(context),
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildCard(_items[idx]);
        },
      ),
    );
  }

  Widget _buildCard(IncomingLetterModel letter) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final senderName = letter.senderParty?.name;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () => _openDetail(letter),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Baris 1: nomor agenda + aksi per kartu.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            letter.agendaNumber,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Aksi Surat Masuk',
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          // TODO(Task 11): tangani 'reply_external' →
                          // wizard balasan pihak luar.
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'reply_external',
                              // Dinonaktifkan sampai Task 11 — caption
                              // menjelaskan kapan tersedia.
                              enabled: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                      'Daftarkan sebagai balasan pihak luar'),
                                  Text(
                                    'Tersedia setelah Tugas 11',
                                    style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Baris 2: nomor surat pengirim (sekunder, bila ada).
                    if (letter.numberExternal != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'No. eksternal: ${letter.numberExternal}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 3: badge sifat + badge status.
                    Row(
                      children: [
                        _buildSifatBadge(letter),
                        const SizedBox(width: AppSpacing.sm),
                        _buildStatusBadge(letter),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 4: perihal.
                    Text(
                      letter.subject,
                      style: textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 5: pengirim • tanggal diterima.
                    Row(
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 13, color: colorScheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            [
                              senderName ?? 'Pengirim tidak diketahui',
                              letter.receivedAt != null
                                  ? 'Diterima ${_dateFormatter.format(letter.receivedAt!)}'
                                  : 'Tanpa tanggal terima',
                            ].join(' • '),
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// Badge sifat: rahasia merah (error), segera amber (warning), biasa
  /// netral — konsisten pemetaan warna `DocumentStatusBadge` fase 1.
  Widget _buildSifatBadge(IncomingLetterModel letter) {
    final type = switch (letter.sifat) {
      'rahasia' => StatusType.error,
      'segera' => StatusType.warning,
      _ => StatusType.neutral,
    };
    return StatusBadge(label: letter.sifatLabel, type: type);
  }

  /// Badge status: terdaftar netral (abu, seperti draf), diproses amber
  /// (seperti menunggu_ttd), selesai hijau (seperti terbit).
  Widget _buildStatusBadge(IncomingLetterModel letter) {
    final type = switch (letter.status) {
      'selesai' => StatusType.success,
      'diproses' => StatusType.warning,
      _ => StatusType.neutral,
    };
    return StatusBadge(label: letter.statusLabel, type: type);
  }
}

/// TODO(Task 10): placeholder halaman detail surat masuk — diganti
/// halaman detail penuh (info surat, disposisi, runutan, pratinjau
/// scan). Sementara menampilkan ringkas data list yang sudah ada.
class IncomingDetailPlaceholderPage extends StatelessWidget {
  final IncomingLetterModel letter;

  const IncomingDetailPlaceholderPage({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Detail Surat Masuk',
      body: EmptyState(
        icon: Icons.inbox_outlined,
        title: letter.agendaNumber,
        subtitle:
            'Detail surat masuk (disposisi, runutan, pratinjau scan) akan '
            'tersedia setelah Tugas 10.',
      ),
    );
  }
}

/// TODO(Task 9): placeholder form pendaftaran surat masuk — diganti form
/// penuh (pengirim, tanggal, scan, dsb). Dibuka FAB "Daftar Surat Masuk"
/// pada tab Masuk.
class IncomingFormPlaceholderPage extends StatelessWidget {
  const IncomingFormPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Daftar Surat Masuk',
      body: EmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'Form pendaftaran surat masuk',
        subtitle: 'Form pengisian (pengirim, tanggal, unggah scan) akan '
            'tersedia setelah Tugas 9.',
      ),
    );
  }
}
