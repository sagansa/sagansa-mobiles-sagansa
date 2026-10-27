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
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/ios_segmented_control.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../home_page.dart';
import '../hrd_dashboard_page.dart';
import '../stock_dashboard_page.dart';
import '../transaction_dashboard_page.dart';
import 'document_create_wizard.dart';
import 'document_detail_page.dart';
import 'document_upload_page.dart';
import 'incoming/incoming_list_section.dart';
import 'signing_task_page.dart';

/// Arsip Surat Perusahaan dengan tab "Keluar | Masuk" (segmented control
/// di bawah AppBar, pola `SalesHomePage`/`IosSegmentedControl` +
/// `IndexedStack` — state tiap tab terpisah dan dipertahankan).
///
/// - Tab Keluar: arsip surat keluar fase 1 (`_OutgoingListSection`) —
///   filter status/jenis/tahun, pencarian, infinite scroll.
/// - Tab Masuk: buku agenda surat masuk fase 1b (`IncomingListSection`).
/// - FAB kontekstual: Keluar → wizard "Buat Surat" (task 20); Masuk →
///   form "Daftar Surat Masuk" (Task 9, placeholder).
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

  /// FAB tab Keluar — wizard 6 langkah (task 20); kembali dari wizard
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

  /// FAB tab Masuk — TODO(Task 9): ganti placeholder dengan form
  /// pendaftaran surat masuk; kembali me-refresh buku agenda.
  Future<void> _openIncomingForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncomingFormPlaceholderPage()),
    );
    if (mounted) _incomingKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Catatan penempatan FAB & nav: `ModernBottomNav` meng-ukur setinggi
    // layar penuh di slot `Scaffold.bottomNavigationBar` (Align internal
    // tanpa heightFactor) sehingga FAB slot-scaffold terdorong keluar layar
    // dan snackbar floating di-assert "off screen". Keduanya ditempatkan
    // sebagai anak Stack di body — perilaku visual identik, FAB & snackbar
    // aman di semua ukuran layar (ponsel & tablet).
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
          ],
        ),
      ],
      bodyPadding: EdgeInsets.zero,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              // IndexedStack: kedua tab tetap hidup — filter, pencarian,
              // dan posisi scroll masing-masing dipertahankan.
              child: IndexedStack(
                index: _tab,
                children: [
                  _OutgoingListSection(
                    key: _outgoingKey,
                    service: _service,
                    onSearchStateChanged: _onSearchStateChanged,
                    onListRefreshed: _refreshPendingSignCount,
                  ),
                  if (_incomingVisited)
                    IncomingListSection(
                      key: _incomingKey,
                      service: _incomingService,
                      onSearchStateChanged: _onSearchStateChanged,
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
            // Nav bawah melayang (tampilan sama seperti slot scaffold).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ModernBottomNav(
                currentIndex: 4,
                onTap: (index) => _handleNavigation(context, index),
              ),
            ),
            // FAB kontekstual per tab — melayang di atas nav bawah.
            Positioned(
              right: AppSpacing.md,
              bottom: ModernBottomNav.clearance(context) + AppSpacing.sm,
              child: FloatingActionButton(
                onPressed: _tab == 0 ? _openWizard : _openIncomingForm,
                tooltip: _tab == 0 ? 'Buat Surat' : 'Daftar Surat Masuk',
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: Icon(
                  _tab == 0
                      ? Icons.note_add_rounded
                      : Icons.mark_email_unread_rounded,
                ),
              ),
            ),
          ],
        ),
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
  final VoidCallback? onSearchStateChanged;
  final VoidCallback? onListRefreshed;

  const _OutgoingListSection({
    super.key,
    required this.service,
    this.onSearchStateChanged,
    this.onListRefreshed,
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

  /// Baris pencarian sedang tampil (dibaca AppBar induk untuk ikon
  /// search/close pada tab aktif).
  bool get isSearchActive => _isSearchActive;

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
        builder: (_) =>
            DocumentDetailPage(documentId: document.id, service: _service),
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
          ),
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  /// Task 21: aksi kartu "Terbitkan ulang" (hanya status terbit) — pilih
  /// metode sheet (b/c/d) → DocumentUploadPage alur reissue (note alasan
  /// dikumpulkan di sana sebelum submit); kembali me-refresh daftar.
  Future<void> _reissue(DocumentModel document) async {
    const methodTitles = {
      'b': ('Unggah PDF — tempel QR verifikasi',
          'PDF baru ditempel QR pada posisi pilihan Anda.'),
      'c': ('Unggah PDF ber-e-materai / TTE resmi',
          'PDF final dari platform resmi, dipakai apa adanya.'),
      'd': ('Pindai hasil tanda tangan basah',
          'Foto/scan tiap halaman hasil ttd basah + meterai tempel.'),
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
                              icon: Icons.description_outlined,
                              title: _query != null
                                  ? 'Tidak ada surat yang cocok dengan pencarian.'
                                  : 'Belum ada surat.',
                              subtitle: _query != null
                                  ? 'Coba kata kunci lain atau hapus filter.'
                                  : 'Surat yang Anda buat akan tampil di sini.',
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

  /// Baris chip filter: status + jenis + tahun (pola chip SOP/supplier).
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
                : DocumentModel.statusLabelOf(status),
          ),
          if (_letterTypes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            FilterChipRow<LetterTypeModel?>(
              options: [null, ..._letterTypes],
              selected: _selectedLetterType,
              onSelected: (value) {
                setState(() => _letterTypeCode = value?.code);
                _fetch();
              },
              getLabel: (type) => type?.name ?? 'Semua',
            ),
          ],
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

  LetterTypeModel? get _selectedLetterType {
    for (final type in _letterTypes) {
      if (type.code == _letterTypeCode) return type;
    }
    return null;
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

  Widget _buildCard(DocumentModel document) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final issuance = document.activeIssuance;
    final issuanceLabel = _issuanceShortLabel(issuance);

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
        onTap: () => _openDetail(document),
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
                    // Baris 1: nomor surat + aksi per kartu.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.number ?? 'Belum bernomor',
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Aksi Surat',
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'duplicate') _duplicate(document);
                            if (value == 'reissue') _reissue(document);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Text('Salin surat ini'),
                            ),
                            PopupMenuItem(
                              value: 'reissue',
                              // Reissue hanya untuk surat terbit (guard
                              // backend Finalizer 409 — menu lain diredam).
                              enabled: document.status == 'terbit',
                              child: const Text('Terbitkan ulang'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 2: badge status + metode terbitan aktif.
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
                                        color: colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 3: perihal.
                    Text(
                      document.subject,
                      style: textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 4: jenis • tanggal.
                    Row(
                      children: [
                        Icon(Icons.category_outlined,
                            size: 13, color: colorScheme.primary),
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
