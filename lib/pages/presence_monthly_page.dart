import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/presence_service.dart';
import '../services/salary_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/glass_app_bar.dart';
import 'presence_manual_form_page.dart';

/// Rekap presensi untuk satu periode cut-off gaji bulanan (mis. "Juni 2026"
/// = presensi 26 Mei – 25 Jun).
///
/// Role-aware:
/// - Admin (role `admin` / `super_admin`): pilih karyawan mana pun + periode.
/// - Non-admin: hanya miliknya sendiri, tanpa filter karyawan.
///
/// Sumber data: `GET /presences/monthly` → `formatPresence()` backend (sama
/// dengan `/user-presence` yang dipakai `home_page.dart`). Field per baris:
/// `check_in`, `check_out`, `check_in_status` (tepat_waktu/terlambat),
/// `check_out_status` (tepat_waktu/pulang_cepat/terlambat_checkout/...),
/// `late_minutes`, `store`, `shift_store`, `image_in`, `image_out`.
class PresenceMonthlyPage extends StatefulWidget {
  const PresenceMonthlyPage({super.key});

  @override
  State<PresenceMonthlyPage> createState() => _PresenceMonthlyPageState();
}

class _PresenceMonthlyPageState extends State<PresenceMonthlyPage> {
  final SalaryService _salaryService = SalaryService();
  final PresenceService _presenceService = PresenceService();

  bool _isAdmin = false;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  List<Map<String, dynamic>> _employees = [];
  int? _selectedUserId;
  late String _selectedPeriod; // YYYY-MM

  // Baris mana yang sedang di-expand (null = semua tertutup; satu-per-satu).
  final Map<int, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _selectedPeriod = _defaultPeriod();
    _loadUserRole();
  }

  /// "Bulan gaji" untuk hari ini: bila tanggal >= 26 → bulan depan, else
  /// bulan ini. Sama dengan logika `_resolvePeriodDate()` di salary_page.dart.
  String _defaultPeriod() {
    final now = DateTime.now();
    final salaryMonth = now.day >= 26
        ? DateTime(now.year, now.month + 1, 1)
        : DateTime(now.year, now.month, 1);
    return '${salaryMonth.year}-${salaryMonth.month.toString().padLeft(2, '0')}';
  }

  Future<void> _loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final roles =
            List<String>.from(json.decode(userString)['roles'] ?? []);
        if (mounted) {
          setState(() {
            _isAdmin =
                roles.contains('admin') || roles.contains('super_admin');
          });
        }
      }
    } catch (_) {}
    await _loadData();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _salaryService.getEmployeesForSalary();
      if (mounted) setState(() => _employees = employees);
    } catch (_) {
      // Abaikan; dropdown tetap "Semua".
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isAdmin && _employees.isEmpty) _loadEmployees();
      final data = await _salaryService.getMonthlyPresence(
        period: _selectedPeriod,
        userId: _isAdmin ? _selectedUserId : null,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedUserId = null;
      _selectedPeriod = _defaultPeriod();
    });
    _loadData();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedUserId != null) count++;
    return count;
  }

  void _openFilterSheet() {
    final employees = _employees;
    FilterBottomSheet.show(
      context,
      fields: [
        if (_isAdmin)
          DropdownFilterField<int>(
            label: 'Karyawan',
            value: _selectedUserId,
            options: employees.map((e) => (
              _toInt(e['id']),
              e['name']?.toString() ?? '-',
            )).toList(),
          ),
        DropdownFilterField<String>(
          label: 'Periode (cut-off gaji)',
          value: _selectedPeriod,
          options: List.generate(12, (i) {
            final d = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
            final period = '${d.year}-${d.month.toString().padLeft(2, '0')}';
            final label = DateFormat('MMMM yyyy', 'id_ID').format(d);
            return (period, label);
          }),
        ),
      ],
      onApply: (values) {
        setState(() {
          _selectedUserId = values['Karyawan'] as int?;
          _selectedPeriod = values['Periode (cut-off gaji)'] as String? ?? _defaultPeriod();
        });
        _loadData();
      },
      onReset: () {
        _clearFilters();
      },
    );
  }

  // ---- Status helpers (konsisten dgn PresenceModel.getStatusColor/getStatusText) ----

  /// Parse angka dari JSON (bisa int, double, atau String) ke int secara aman.
  /// JSON tidak membedakan int/double, dan Carbon diffInMinutes() mengembalikan
  /// float, jadi `value as int` bisa melempar TypeError. Selalu konversi eksplisit.
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  Color _checkInStatusColor(String? status, ColorScheme cs) {
    switch (status) {
      case 'tepat_waktu':
        return AppColors.success;
      case 'terlambat':
        return AppColors.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _checkInStatusText(String? status) {
    switch (status) {
      case 'tepat_waktu':
        return 'Tepat Waktu';
      case 'terlambat':
        return 'Terlambat';
      default:
        return '-';
    }
  }

  Color _checkOutStatusColor(String? status, ColorScheme cs) {
    switch (status) {
      case 'tepat_waktu':
        return AppColors.success;
      case 'pulang_cepat':
        return AppColors.warning;
      case 'terlambat_checkout':
      case 'tidak_absen':
        return AppColors.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _checkOutStatusText(String? status) {
    switch (status) {
      case 'tepat_waktu':
        return 'Tepat Waktu';
      case 'pulang_cepat':
        return 'Pulang Cepat';
      case 'terlambat_checkout':
        return 'Terlambat Checkout';
      case 'tidak_absen':
        return 'Tidak Absen Pulang';
      case 'belum_checkout':
        return 'Belum Checkout';
      default:
        return '-';
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    return dt != null ? DateFormat('HH:mm').format(dt) : '-';
  }

  // ---------------------------------------------------------------------------
  // Admin manual presence management (create / edit / delete).
  // ---------------------------------------------------------------------------

  Future<void> _openCreateForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PresenceManualFormPage(),
      ),
    );
    if (result == true && mounted) _loadData();
  }

  Future<void> _openEditForm(Map<String, dynamic> presence) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PresenceManualFormPage(presence: presence),
      ),
    );
    if (result == true && mounted) _loadData();
  }

  Future<void> _confirmDelete(Map<String, dynamic> presence) async {
    final id = presence['id'];
    final userName = presence['user_name']?.toString();
    final dateLabel = presence['check_in'] != null
        ? DateFormat('dd MMM yyyy', 'id_ID')
            .format(DateTime.parse(presence['check_in']))
        : '?';

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Presensi',
      content: 'Hapus presensi ${userName ?? 'karyawan'} tanggal $dateLabel? '
          'Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _isDeleting = true);
    try {
      await _presenceService.deletePresence(int.parse(id.toString()));
      if (!mounted) return;
      showSuccessSnackBar(context, 'Presensi berhasil dihapus.');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Rekap Presensi'),
        actions: [
          BarButtonCluster(actions: [
            if (_isAdmin)
              BarButtonSpec(
                icon: Icons.tune,
                tooltip: 'Filter',
                badgeCount: _activeFilterCount,
                onTap: _openFilterSheet,
              ),
            if (_isAdmin)
              BarButtonSpec(
                icon: Icons.add_rounded,
                iconSize: 22,
                tooltip: 'Tambah Presensi',
                onTap: _openCreateForm,
              ),
          ]),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: Column(
            children: [
              if (!_isAdmin)
                Container(
                  padding: AppSpacing.paddingMD,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      AppSpacing.gapHorizontalSM,
                      const Expanded(
                        child: Text(
                            'Periode cut-off gaji bulanan (26 bln lalu – 25 bln periode).'),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return ListView(
        children: [
          AppSpacing.gapVerticalLG,
          Center(
            child: Padding(
              padding: AppSpacing.paddingLG,
              child: Column(
                children: [
                  Text(_errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center),
                  AppSpacing.gapVerticalMD,
                  ElevatedButton(
                      onPressed: _loadData, child: const Text('Coba Lagi')),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final presences = (_data?['presences'] as List?) ?? [];
    if (presences.isEmpty) {
      return ListView(
        children: [
          AppSpacing.gapVerticalLG,
          const Center(
              child: Padding(
            padding: AppSpacing.paddingMD,
            child: Text('Tidak ada presensi pada periode ini.'),
          )),
        ],
      );
    }

    final summary =
        (_data?['summary'] as Map?) ?? <String, dynamic>{};
    return ListView(
      children: [
        _buildSummaryCard(summary, textTheme, colorScheme),
        ...presences.asMap().entries.map(
              (e) => _buildPresenceCard(e.value, e.key, textTheme, colorScheme),
            ),
        AppSpacing.gapVerticalLG,
      ],
    );
  }

  Widget _buildSummaryCard(Map summary, TextTheme tt, ColorScheme cs) {
    Widget cell(String label, String value, {Color? valueColor}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                Text(value,
                    style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: valueColor)),
                Text(label,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ringkasan',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            Row(children: [
              cell('Hadir', '${summary['total_hadir'] ?? 0}'),
              cell('Tepat Waktu', '${summary['count_tepat_waktu'] ?? 0}',
                  valueColor: AppColors.success),
              cell('Terlambat', '${summary['count_terlambat'] ?? 0}',
                  valueColor: AppColors.error),
            ]),
            Row(children: [
              cell('Pulang Cepat', '${summary['count_pulang_cepat'] ?? 0}',
                  valueColor: AppColors.warning),
              cell('Menit Terlambat',
                  '${summary['total_menit_terlambat'] ?? 0}'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceCard(
      dynamic p, int index, TextTheme tt, ColorScheme cs) {
    final map = Map<String, dynamic>.from(p as Map);
    final bool expanded = _expanded[index] ?? false;
    final String checkIn = map['check_in'] as String? ?? '';
    final String dateLabel = checkIn.isNotEmpty
        ? DateFormat('EEE, dd MMM', 'id_ID')
            .format(DateTime.parse(checkIn))
        : '-';
    final String? checkInStatus = map['check_in_status'] as String?;
    final int lateMinutes = _toInt(map['late_minutes']);
    // Nama karyawan hanya ada saat admin lihat semua/karyawan lain (mode all/single).
    final String? userName = map['user_name'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMD,
        onTap: () => setState(() => _expanded[index] = !expanded),
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userName != null && userName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: cs.primary),
                      AppSpacing.gapHorizontalXS,
                      Expanded(
                        child: Text(userName,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(dateLabel,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: _checkInStatusColor(checkInStatus, cs)
                          .withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusMD,
                    ),
                    child: Text(_checkInStatusText(checkInStatus),
                        style: tt.labelSmall
                            ?.copyWith(color: _checkInStatusColor(checkInStatus, cs))),
                  ),
                ],
              ),
              if (lateMinutes > 0) ...[
                AppSpacing.gapVerticalXS,
                Text('Terlambat $lateMinutes menit',
                    style: tt.bodySmall?.copyWith(color: AppColors.error)),
              ],
              if (expanded) _buildExpandedDetail(map, tt, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDetail(Map<String, dynamic> m, TextTheme tt, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Check-in', _formatTime(m['check_in'] as String?)),
          _detailRow('Check-out', _formatTime(m['check_out'] as String?)),
          _detailRow(
              'Status Pulang', _checkOutStatusText(m['check_out_status'] as String?),
              valueColor: _checkOutStatusColor(
                  m['check_out_status'] as String?, cs)),
          _detailRow('Toko', (m['store'] ?? '-') as String),
          _detailRow(
              'Shift',
              '${m['shift_store'] ?? '-'} '
              '(${m['shift_start_time'] ?? ''}–${m['shift_end_time'] ?? ''})'),
          if (m['image_in'] != null || m['image_out'] != null) ...[
            AppSpacing.gapVerticalSM,
            Row(
              children: [
                if (m['image_in'] != null)
                  _photo(m['image_in'] as String, 'Masuk'),
                if (m['image_out'] != null)
                  _photo(m['image_out'] as String, 'Pulang'),
              ],
            ),
          ],
          if (_isAdmin && m['id'] != null) ...[
            AppSpacing.gapVerticalMD,
            const Divider(height: 1),
            AppSpacing.gapVerticalSM,
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  onPressed: () => _openEditForm(m),
                ),
                AppSpacing.gapHorizontalSM,
                OutlinedButton.icon(
                  icon: _isDeleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.error,
                          ),
                        )
                      : Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                  label: Text('Hapus', style: TextStyle(color: cs.error)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    backgroundColor: cs.error.withValues(alpha: 0.08),
                    side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                  ),
                  onPressed: _isDeleting ? null : () => _confirmDelete(m),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
              child: Text(value,
                  style: valueColor != null
                      ? TextStyle(color: valueColor)
                      : null)),
        ],
      ),
    );
  }

  Widget _photo(String url, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(url),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusSM,
              child: Image.network(url,
                  width: 72, height: 72, fit: BoxFit.cover),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: GlassAppBar(),
        body: Center(child: Image.network(url)),
      ),
    ));
  }
}
