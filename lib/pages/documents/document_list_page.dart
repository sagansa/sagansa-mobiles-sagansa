import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/document/document_models.dart';
import '../../services/document/document_service.dart';
import '../../services/document/incoming_service.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_spacing.dart';
import '../../utils/error_utils.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_page_scaffold.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/bar_button_cluster.dart';
import '../../widgets/documents/document_status_badge.dart';
import '../../widgets/documents/letter_action_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/ios_segmented_control.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../home_page.dart';
import '../hrd_dashboard_page.dart';
import '../stock_dashboard_page.dart';
import '../transaction_dashboard_page.dart';
import 'document_create_wizard.dart';
import 'document_detail_page.dart';
import 'document_upload_page.dart';
import 'incoming/incoming_form_page.dart';
import 'incoming/incoming_list_section.dart';
import 'signing_task_page.dart';

/// Arsip Surat Perusahaan dengan tab "Keluar | Masuk" (segmented control
/// di bawah AppBar, pola `SalesHomePage`/`IosSegmentedControl` +
/// `IndexedStack` — state tiap tab terpisah dan dipertahankan).
///
/// - Tab Keluar: arsip surat keluar fase 1 (`_OutgoingListSection`) —
///   filter status/jenis/tahun, pencarian, infinite scroll.
/// - Tab Masuk: buku agenda surat masuk fase 1b (`IncomingListSection`).
/// - Aksi utama per tab via tombol "+" di AppBar (pola arsip standar):
///   Keluar → wizard "Buat Surat" (task 20); Masuk → form "Daftar Surat
///   Masuk" (Task 9, `IncomingFormPage`).
///
/// [service] & [incomingService] adalah seam test — produksi memakai
/// instance default.
class DocumentListPage extends StatefulWidget {
  final DocumentService? service;
  final IncomingService? incomingService;

  const DocumentListPage({super.key, this.service, this.incomingService});

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  late final DocumentService _service = widget.service ?? DocumentService();
  late final IncomingService _incomingService =
      widget.incomingService ?? IncomingService();

  /// Index tab aktif: 0 = Keluar, 1 = Masuk.
  int _tab = 0;

  /// Tab Masuk baru dibangun saat pertama dikunjungi (lazy) — menghindari
  /// request ganda saat halaman dibuka di tab Keluar; setelah itu state
  /// dipertahankan `IndexedStack`.
  bool _incomingVisited = false;

  final GlobalKey<_OutgoingListSectionState> _outgoingKey =
      GlobalKey<_OutgoingListSectionState>();
  final GlobalKey<IncomingListSectionState> _incomingKey =
      GlobalKey<IncomingListSectionState>();

  /// Jumlah tugas tanda tangan pending (badge ikon AppBar). Pull-to-refresh
  /// saja — push notifikasi = fase 2. Gagal ambil = badge disembunyikan.
  int _pendingSignCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshPendingSignCount();
  }

  /// Muat jumlah tugas tanda tangan `diminta` (badge AppBar). Kegagalan
  /// diabaikan diam-diam — badge bukan data utama halaman.
  Future<void> _refreshPendingSignCount() async {
    try {
      final result = await _service.mySigningRequests(status: 'diminta');
      if (!mounted) return;
      setState(() => _pendingSignCount = result.total);
    } catch (_) {
      // Offline/error: badge 0, dicoba lagi saat refresh berikutnya.
    }
  }

  /// Buka Tugas Tanda Tangan (badge di-refresh saat kembali — tugas bisa
  /// selesai diputuskan di sana).
  Future<void> _openSigningTasks() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SigningTaskPage(service: _service),
      ),
    );
    if (mounted) _refreshPendingSignCount();
  }

  /// Ikon search/close AppBar mengikuti state pencarian tab AKTIF —
  /// section memanggil callback ini saat baris pencarian berubah.
  void _onSearchStateChanged() {
    if (mounted) setState(() {});
  }

  /// Badge tombol filter (tune) AppBar mengikuti jumlah filter aktif
  /// tab AKTIF — section memanggil callback ini saat filter diterapkan.
  void _onFilterStateChanged() {
    if (mounted) setState(() {});
  }

  /// Jumlah filter aktif tab aktif (badge tombol tune).
  int get _activeFilterCount => _tab == 0
      ? (_outgoingKey.currentState?.activeFilterCount ?? 0)
      : (_incomingKey.currentState?.activeFilterCount ?? 0);

  /// Buka sheet filter tab aktif (tombol tune AppBar).
  void _openFilterSheet() {
    if (_tab == 0) {
      _outgoingKey.currentState?.openFilterSheet(context);
    } else {
      _incomingKey.currentState?.openFilterSheet(context);
    }
  }

  bool get _isSearchActive => _tab == 0
      ? (_outgoingKey.currentState?.isSearchActive ?? false)
      : (_incomingKey.currentState?.isSearchActive ?? false);

  void _toggleSearch() {
    if (_tab == 0) {
      _outgoingKey.currentState?.toggleSearch();
    } else {
      _incomingKey.currentState?.toggleSearch();
    }
  }

  void _handleNavigation(BuildContext context, int index) {
    if (index == 4) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const HomePage()));
        break;
      case 1:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const HRDDashboardPage()));
        break;
      case 2:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const StockDashboardPage()));
        break;
      case 3:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const TransactionDashboardPage()));
        break;
    }
  }

  /// Aksi "+" tab Keluar — wizard 6 langkah (task 20); kembali dari wizard
  /// me-refresh daftar (draf baru / surat terbit langsung terlihat).
  Future<void> _openWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCreateWizard(service: _service),
      ),
    );
    if (mounted) _outgoingKey.currentState?.refresh();
  }

  /// Aksi "+" tab Masuk — form pendaftaran surat masuk (Task 9); kembali
  /// dari form (atau dari detail setelah sukses) me-refresh buku agenda.
  Future<void> _openIncomingForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingFormPage(
          service: _incomingService,
          documentService: _service,
        ),
      ),
    );
    if (mounted) _incomingKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      titleText: 'Surat Perusahaan',
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: IosSegmentedControl<int>(
          segments: const {0: 'Keluar', 1: 'Masuk'},
          groupValue: _tab,
          onValueChanged: (value) => setState(() {
            _tab = value;
            if (value == 1) _incomingVisited = true;
          }),
        ),
      ),
      actions: [
        BarButtonCluster(
          actions: [
            BarButtonSpec(
              icon: Icons.draw_rounded,
              iconSize: 22,
              tooltip: 'Tugas Tanda Tangan',
              badgeCount: _pendingSignCount,
              onTap: _openSigningTasks,
            ),
            BarButtonSpec(
              icon: _isSearchActive
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
              iconSize: 22,
              tooltip: _isSearchActive ? 'Tutup Pencarian' : 'Cari Surat',
              onTap: _toggleSearch,
            ),
            // Filter via tombol tune + FilterBottomSheet — pola standar
            // halaman arsip (supplier/dll), bukan baris chip inline.
            BarButtonSpec(
              icon: Icons.tune,
              tooltip: _tab == 0 ? 'Filter Surat Keluar' : 'Filter Surat Masuk',
              badgeCount: _activeFilterCount,
              onTap: _openFilterSheet,
            ),
            // Aksi utama per tab sebagai tombol "+" di AppBar — pola
            // standar halaman arsip (supplier/kebersihan/stok gudang),
            // bukan FAB melayang.
            BarButtonSpec(
              icon: Icons.add_rounded,
              iconSize: 22,
              tooltip: _tab == 0 ? 'Buat Surat' : 'Daftar Surat Masuk',
              onTap: _tab == 0 ? _openWizard : _openIncomingForm,
            ),
          ],
        ),
      ],
      bodyPadding: EdgeInsets.zero,
      body: SafeArea(
        top: true,
        bottom: false,
        // IndexedStack: kedua tab tetap hidup — filter, pencarian,
        // dan posisi scroll masing-masing dipertahankan.
        child: IndexedStack(
          index: _tab,
          children: [
            _OutgoingListSection(
              key: _outgoingKey,
              service: _service,
              incomingService: _incomingService,
              onSearchStateChanged: _onSearchStateChanged,
              onFilterChanged: _onFilterStateChanged,
              onListRefreshed: _refreshPendingSignCount,
              onOpenIncomingTab: () => setState(() {
                _tab = 1;
                _incomingVisited = true;
              }),
            ),
            if (_incomingVisited)
              IncomingListSection(
                key: _incomingKey,
                service: _incomingService,
                documentService: _service,
                onSearchStateChanged: _onSearchStateChanged,
                onFilterChanged: _onFilterStateChanged,
                onRegisterIncoming: _openIncomingForm,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 4,
        onTap: (index) => _handleNavigation(context, index),
      ),
    );
  }
}

/// Bagian "Keluar" — perilaku arsip fase 1 persis (tidak berubah),
/// dipisah jadi widget agar state-nya terpisah dari tab Masuk di dalam
/// `IndexedStack`.
///
/// [onListRefreshed] dipanggil induk pemicu refresh badge tugas tanda
/// tangan setelah daftar berubah (pull-to-refresh / kembali dari detail).
class _OutgoingListSection extends StatefulWidget {
  final DocumentService service;

  /// Service surat masuk — diteruskan ke Detail Surat yang dimuat dari
  /// kartu (detail memuat runutan secara eager).
  final IncomingService incomingService;
  final VoidCallback? onSearchStateChanged;

  /// Dipanggil saat filter diterapkan/direset — induk me-refresh badge
  /// tombol tune di AppBar.
  final VoidCallback? onFilterChanged;
  final VoidCallback? onListRefreshed;
  final VoidCallback? onOpenIncomingTab;

  const _OutgoingListSection({
    super.key,
    required this.service,
    required this.incomingService,
    this.onSearchStateChanged,
    this.onFilterChanged,
    this.onListRefreshed,
    this.onOpenIncomingTab,
  });

  @override
  State<_OutgoingListSection> createState() => _OutgoingListSectionState();
}

class _OutgoingListSectionState extends State<_OutgoingListSection> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormatter = DateFormat('d MMM yyyy', 'id_ID');
  Timer? _searchDebounce;

  List<DocumentModel> _items = [];
  List<LetterTypeModel> _letterTypes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Filter aktif — null berarti "Semua".
  String? _status;
  String? _letterTypeCode;
  int? _year;
  String? _query;
  bool _isSearchActive = false;
  bool _hideGuideBanner = false;

  /// Opsi tahun filter: Semua + 3 tahun terakhir.
  late final List<int> _yearOptions = List.generate(
    3,
    (i) => DateTime.now().year - i,
  );

  static const List<String> _statusOptions = [
    'draft',
    'menunggu_ttd',
    'terbit',
    'dicabut',
    'dibatalkan',
  ];

  DocumentService get _service => widget.service;
  IncomingService get _incomingService => widget.incomingService;

  /// Baris pencarian sedang tampil (dibaca AppBar induk untuk ikon
  /// search/close pada tab aktif).
  bool get isSearchActive => _isSearchActive;

  /// Jumlah filter aktif (badge tombol tune AppBar induk).
  int get activeFilterCount =>
      (_status != null ? 1 : 0) +
      (_letterTypeCode != null ? 1 : 0) +
      (_year != null ? 1 : 0);

  /// Buka sheet filter — pola `FilterBottomSheet` standar arsip
  /// (supplier/dll): status, jenis, tahun. Bukan baris chip inline.
  void openFilterSheet(BuildContext context) {
    FilterBottomSheet.show(
      context,
      title: 'Filter Surat Keluar',
      fields: [
        DropdownFilterField<String?>(
          label: 'Status',
          value: _status,
          options: [
            (null, 'Semua'),
            for (final status in _statusOptions)
              (status, DocumentModel.statusLabelOf(status)),
          ],
        ),
        DropdownFilterField<String?>(
          label: 'Jenis',
          value: _letterTypeCode,
          options: [
            (null, 'Semua'),
            for (final type in _letterTypes) (type.code, type.name),
          ],
        ),
        DropdownFilterField<int?>(
          label: 'Tahun',
          value: _year,
          options: [
            (null, 'Semua'),
            for (final year in _yearOptions) (year, year.toString()),
          ],
        ),
      ],
      onApply: (values) {
        setState(() {
          _status = values['Status'] as String?;
          _letterTypeCode = values['Jenis'] as String?;
          _year = values['Tahun'] as int?;
        });
        widget.onFilterChanged?.call();
        _fetch();
      },
      onReset: () {
        setState(() {
          _status = null;
          _letterTypeCode = null;
          _year = null;
        });
        widget.onFilterChanged?.call();
        _fetch();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadLetterTypes();
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
  /// kembali dari wizard "Buat Surat".
  void refresh() => _fetch();

  /// Muat opsi jenis surat untuk chip filter — gagal tidak menghalangkan
  /// daftar (filter jenis tetap "Semua"), pola kategori SOP.
  Future<void> _loadLetterTypes() async {
    try {
      final types = await _service.getLetterTypes();
      if (!mounted) return;
      setState(() => _letterTypes = types);
    } catch (_) {
      // Diabaikan: filter jenis opsional.
    }
  }

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
      final result = await _service.getDocuments(
        status: _status,
        letterType: _letterTypeCode,
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
      final result = await _service.getDocuments(
        status: _status,
        letterType: _letterTypeCode,
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

  /// Pencarian dengan debounce 400 ms — ketik cepat tidak memicu request
  /// per karakter.
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

  void _openDetail(DocumentModel document) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailPage(
          documentId: document.id,
          service: _service,
          // Runutan dimuat eagerly di detail — teruskan service masuk yang
          // sama (seam test ikut terbawa).
          incomingService: _incomingService,
        ),
      ),
    );
    if (mounted) {
      _fetch();
      widget.onListRefreshed?.call();
    }
  }

  /// "Lanjutkan draf" — buka wizard mode edit langsung, lalu refresh.
  Future<void> _continueDraft(DocumentModel document) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCreateWizard(
          service: _service,
          documentId: document.id,
        ),
      ),
    );
    if (mounted) {
      _fetch();
      widget.onListRefreshed?.call();
    }
  }

  /// Aksi per kartu: salin surat → konfirmasi → duplicateFrom → snackbar +
  /// refresh + buka draf baru.
  Future<void> _duplicate(DocumentModel document) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Salin Surat',
      content:
          'Buat draf baru dengan isi yang sama dari "${document.subject}"?',
      confirmText: 'Salin',
    );
    if (!confirmed || !mounted) return;

    final code = document.letterType?.code ?? '';
    if (code.isEmpty) {
      showErrorSnackBar(
          context, 'Jenis surat tidak diketahui; surat tidak dapat disalin.');
      return;
    }

    try {
      final draft = await _service.duplicateFrom(
        document.id,
        letterTypeCode: code,
        subject: document.subject,
        date: DateTime.now(),
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Surat berhasil disalin menjadi draf baru.');
      await _fetch();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentDetailPage(
            documentId: draft.id,
            service: _service,
            incomingService: _incomingService,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  /// Aksi per kartu: hapus draf permanen (hanya status draft) — konfirmasi
  /// destruktif → deleteDraft → snackbar + refresh.
  Future<void> _deleteDraft(DocumentModel document) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus draf',
      content: 'Draf "${document.subject}" dihapus permanen beserta '
          'lampirannya dan tidak bisa dikembalikan. Lanjutkan?',
      confirmText: 'Hapus',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _service.deleteDraft(document.id);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Draf surat dihapus.');
      _fetch();
      widget.onListRefreshed?.call();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  /// Task 21: aksi kartu "Terbitkan ulang" (hanya status terbit) — pilih
  /// metode sheet (b/c/d) → DocumentUploadPage alur reissue (note alasan
  /// dikumpulkan di sana sebelum submit); kembali me-refresh daftar.
  Future<void> _reissue(DocumentModel document) async {
    const methodTitles = {
      'b': (
        'Unggah PDF — tempel QR verifikasi',
        'PDF baru ditempel QR pada posisi pilihan Anda.'
      ),
      'c': (
        'Unggah PDF ber-e-materai / TTE resmi',
        'PDF final dari platform resmi, dipakai apa adanya.'
      ),
      'd': (
        'Pindai hasil tanda tangan basah',
        'Foto/scan tiap halaman hasil ttd basah + meterai tempel.'
      ),
    };
    final method = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: AppSpacing.paddingMD,
                child: Text(
                  'Terbitkan ulang "${document.subject}"',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final entry in methodTitles.entries)
                ListTile(
                  leading: const Icon(Icons.publish_rounded),
                  title: Text(entry.value.$1),
                  subtitle: Text(entry.value.$2),
                  onTap: () => Navigator.of(sheetContext).pop(entry.key),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
    if (method == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentUploadPage(
          documentId: document.id,
          documentSubject: document.subject,
          mode: DocumentUploadMode.reissue,
          reissueMethod: method,
          service: _service,
        ),
      ),
    );
    if (mounted) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_isSearchActive) _buildSearchRow(colorScheme),
        if (!_isSearchActive && !_hideGuideBanner)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: _buildIncomingGuideBanner(context),
          ),
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
                              icon: Icons.description_outlined,
                              title: _query != null
                                  ? 'Tidak ada surat yang cocok dengan pencarian.'
                                  : 'Belum ada surat keluar.',
                              subtitle: _query != null
                                  ? 'Coba kata kunci lain atau hapus filter.'
                                  : 'Surat keluar yang Anda buat akan tampil di sini. Menerima surat dari pihak lain? Buka tab Masuk untuk mendaftarkannya.',
                              action: widget.onOpenIncomingTab == null
                                  ? null
                                  : FilledButton.tonalIcon(
                                      onPressed: widget.onOpenIncomingTab,
                                      icon: const Icon(
                                          Icons.move_to_inbox_rounded),
                                      label: const Text('Buka Tab Surat Masuk'),
                                    ),
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
          hintText: 'Cari nomor / perihal surat...',
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

  Widget _buildList() {
    return RefreshIndicator(
      // Pull-to-refresh juga memeriksa tugas tanda tangan baru (pengganti
      // push notifikasi fase 2).
      onRefresh: () async {
        await _fetch();
        widget.onListRefreshed?.call();
      },
      child: ListView.builder(
        controller: _scrollController,
        // SafeArea(top) di body sudah menghitung status bar + appbar;
        // padding atas cukup kecil agar tidak terjadi inset ganda.
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

  Widget _buildIncomingGuideBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.move_to_inbox_rounded,
            size: 20,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menerima surat dari pihak lain?',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Buka tab "Masuk" untuk upload surat scan dari instansi lain (seperti DJP), lalu buat balasannya.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    height: 1.35,
                  ),
                ),
                if (widget.onOpenIncomingTab != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.onOpenIncomingTab,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Buka Tab Masuk'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Tutup saran',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _hideGuideBanner = true),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(DocumentModel document) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final issuance = document.activeIssuance;
    final issuanceLabel = _issuanceShortLabel(issuance);
    final isDraft = document.status == 'draft';
    final accent = _statusAccent(colorScheme, document.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusLG,
        child: InkWell(
          onTap: () => _openDetail(document),
          // IntrinsicHeight: rail status 3px (stretch) butuh tinggi berbatas
          // — tanpa ini Row minta tinggi tak berbatas di dalam ListView.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rail status: satu pandangan menangkap tahap surat tanpa
                // membaca badge (draft abu, menunggu amber, terbit hijau,
                // dicabut/dibatalkan merah).
                Container(width: 3, color: accent),
                Expanded(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Baris 1: kode jenis + nomor + aksi ⋮.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (document.letterType != null) ...[
                              _TypeCodeBadge(code: document.letterType!.code),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: Text(
                                document.number ?? 'Belum bernomor',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.1,
                                  color: document.number == null
                                      ? colorScheme.onSurfaceVariant
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            LetterActionMenuButton(
                              onTap: () => _openCardActions(document),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs + 2),
                        // Baris 2: perihal — judul kartu, hierarki utama.
                        Text(
                          document.subject,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (document.inReplyTo != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: AppSpacing.borderRadiusSM,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.reply_rounded,
                                  size: 13,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Membalas: ${document.inReplyTo!.numberOrAgenda ?? document.inReplyTo!.id}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm + 2),
                        // Baris 3: status + metode terbitan (bila ada).
                        Row(
                          children: [
                            DocumentStatusBadge(document: document),
                            if (issuanceLabel != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_outlined,
                                      size: 13,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        issuanceLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Baris 4: jenis • tanggal, rata bawah sebagai meta.
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                [
                                  if (document.letterType != null)
                                    document.letterType!.name,
                                  document.date != null
                                      ? _dateFormatter.format(document.date!)
                                      : 'Tanpa tanggal',
                                ].join(' • '),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Draf: teruskan bahwa draf bisa dilanjutkan dari sini.
                        if (isDraft) ...[
                          const SizedBox(height: AppSpacing.xs + 2),
                          Row(
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Ketuk untuk melanjutkan draf',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Warna rail status kartu — senada `DocumentStatusBadge`.
  Color _statusAccent(ColorScheme colorScheme, String status) {
    switch (status) {
      case 'terbit':
        return colorScheme.primary;
      case 'menunggu_ttd':
        return Colors.amber.shade700;
      case 'dicabut':
      case 'dibatalkan':
        return colorScheme.error;
      default:
        return colorScheme.outlineVariant;
    }
  }

  /// Menu ⋮ kartu — bottom sheet aksi (ikon + keterangan + area ketuk
  /// besar), bukan `PopupMenuButton` teks polos.
  Future<void> _openCardActions(DocumentModel document) async {
    final isDraft = document.status == 'draft';
    final isTerbit = document.status == 'terbit';
    final value = await showLetterActionSheet(
      context,
      title: document.number ?? 'Surat tanpa nomor',
      subtitle: document.subject,
      actions: [
        LetterAction(
          value: 'open',
          label: 'Buka detail surat',
          description: 'Lihat informasi, berkas, verifikasi, dan runutan.',
          icon: Icons.open_in_new_rounded,
        ),
        if (isDraft)
          const LetterAction(
            value: 'continue',
            label: 'Lanjutkan draf',
            description: 'Kembali ke wizard untuk menyelesaikan isi surat.',
            icon: Icons.edit_note_rounded,
          ),
        const LetterAction(
          value: 'duplicate',
          label: 'Salin surat ini',
          description: 'Buat draf baru dengan isi yang sama.',
          icon: Icons.content_copy_rounded,
        ),
        if (isTerbit) ...[
          const LetterAction(
            value: 'register_reply',
            label: 'Catat balasan pihak luar',
            description:
                'Daftarkan scan surat masuk sebagai balasan surat ini.',
            icon: Icons.move_to_inbox_rounded,
          ),
          const LetterAction(
            value: 'reissue',
            label: 'Terbitkan ulang',
            description: 'Ganti berkas terbitan; nomor surat tetap sama.',
            icon: Icons.publish_rounded,
          ),
        ],
        if (isDraft)
          const LetterAction(
            value: 'delete',
            label: 'Hapus draf',
            description: 'Dihapus permanen beserta lampirannya.',
            icon: Icons.delete_outline_rounded,
            destructive: true,
          ),
      ],
    );
    if (!mounted || value == null) return;

    switch (value) {
      case 'open':
        _openDetail(document);
      case 'continue':
        await _continueDraft(document);
      case 'duplicate':
        await _duplicate(document);
      case 'register_reply':
        await _registerReply(document);
      case 'reissue':
        await _reissue(document);
      case 'delete':
        await _deleteDraft(document);
    }
  }

  Future<void> _registerReply(DocumentModel document) async {
    final recipient = document.metadata?['recipient'];
    final partyName =
        recipient is Map ? (recipient['name']?.toString() ?? '') : '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingFormPage(
          service: IncomingService(),
          documentService: widget.service,
          replyToDocument: ReplyToDocument(
            id: document.id,
            partyName: partyName,
            subject: document.subject,
            number: document.number,
          ),
        ),
      ),
    );
  }

  /// Label singkat metode terbitan untuk kartu (versi panjang
  /// `IssuanceModel.methodLabelText` dipakai di detail).
  String? _issuanceShortLabel(IssuanceModel? issuance) {
    if (issuance == null) return null;
    switch (issuance.methodLabel) {
      case 'elektronik':
        return 'Elektronik';
      case 'ttd_elektronik_resmi':
        return 'Ttd elektronik resmi';
      case 'manual':
        return 'Manual';
      default:
        return issuance.methodLabel.isEmpty ? null : issuance.methodLabel;
    }
  }
}

/// Badge status surat keluar memakai widget bersama
/// `DocumentStatusBadge` (warna konsisten list & detail — task 22).

/// Kode jenis surat sebagai badge monospace kecil — memudarkan kode ke
/// latar sekunder agar nomor surat tetap jadi fokus baris pertama.
class _TypeCodeBadge extends StatelessWidget {
  final String code;

  const _TypeCodeBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: AppSpacing.borderRadiusXS,
      ),
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}
