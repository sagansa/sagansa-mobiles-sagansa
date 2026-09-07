import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';
import '../services/image_service.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/status_badge.dart';
import 'supplier_form_page.dart';

class SupplierDetailPage extends StatelessWidget {
  final int supplierId;

  const SupplierDetailPage({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SupplierProvider()..fetchDetail(supplierId),
      child: _SupplierDetailScaffold(supplierId: supplierId),
    );
  }
}

class _SupplierDetailScaffold extends StatefulWidget {
  final int supplierId;

  const _SupplierDetailScaffold({required this.supplierId});

  @override
  State<_SupplierDetailScaffold> createState() =>
      _SupplierDetailScaffoldState();
}

class _SupplierDetailScaffoldState extends State<_SupplierDetailScaffold> {
  bool _isAdmin = false;
  bool _isSupervisor = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        final userData = json.decode(userString);
        final roles = List<String>.from(userData['roles'] ?? []);
        if (mounted) {
          setState(() {
            _isAdmin = roles.contains('admin') || roles.contains('super_admin');
            _isSupervisor = roles.contains('supervisor');
            _isStaff = roles.contains('staff');
          });
        }
      }
    } catch (_) {}
  }

  bool get _canEditFields => _isAdmin || _isSupervisor;
  bool get _canVerify => _isAdmin;

  Future<void> _delete(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    final supplier = provider.detail.supplier;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Supplier?',
      content: 'Supplier "${supplier?.name}" akan dihapus permanen.',
      confirmText: 'Hapus',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await provider.deleteSupplier(widget.supplierId);
      if (!context.mounted) return;
      showSuccessSnackBar(context, 'Supplier berhasil dihapus.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _openEdit(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    final supplier = provider.detail.supplier;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierFormPage(supplier: supplier)),
    );
    if (result == true) provider.fetchDetail(widget.supplierId);
  }

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    final photo = await ImageService.pickAndResizeImage(
      source: ImageSource.gallery,
    );
    if (photo == null) return;
    try {
      await provider.submitUpdate(widget.supplierId, {}, image: photo);
      if (!context.mounted) return;
      showSuccessSnackBar(context, 'Foto berhasil diperbarui.');
      provider.fetchDetail(widget.supplierId);
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _showVerificationDialog(BuildContext context) async {
    final provider = context.read<SupplierProvider>();
    final supplier = provider.detail.supplier;
    if (supplier == null) return;

    final hasPhoto = supplier.image != null && supplier.image!.isNotEmpty;
    int? selectedStatus = supplier.status;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Verifikasi Supplier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              RadioGroup<int>(
                groupValue: selectedStatus,
                onChanged: (v) => setDialogState(() => selectedStatus = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RadioListTile<int>(
                      title: Text('Belum Diperiksa'),
                      value: 1,
                    ),
                    // Valid dikunci sampai supplier punya foto (guard sama di
                    // backend: 422 saat set status 2 tanpa foto).
                    _lockedWhenNoPhoto(
                      enabled: hasPhoto,
                      child: RadioListTile<int>(
                        title: const Text('Valid'),
                        subtitle:
                            hasPhoto ? null : const Text('Perlu foto supplier'),
                        value: 2,
                      ),
                    ),
                    const RadioListTile<int>(
                      title: Text('Blacklist'),
                      value: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: selectedStatus != null && selectedStatus != supplier.status
                  ? () => Navigator.pop(ctx, selectedStatus)
                  : null,
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    try {
      await provider.submitUpdate(widget.supplierId, {'status': result});
      if (!context.mounted) return;
      showSuccessSnackBar(context, 'Status supplier berhasil diperbarui.');
      provider.fetchDetail(widget.supplierId);
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Opsi "Valid" dikunci bila supplier belum punya foto — guard backend
  /// menolak status 2 tanpa foto (422).
  Widget _lockedWhenNoPhoto({required bool enabled, required Widget child}) {
    if (enabled) return child;
    return IgnorePointer(child: Opacity(opacity: 0.55, child: child));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<SupplierProvider>();
    final detail = provider.detail;

    return Scaffold(
      extendBody: true,
      body: detail.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detail.errorMessage != null
              ? _buildError(context, colorScheme, detail.errorMessage!)
              : _buildContent(context, provider, colorScheme, theme),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, SupplierProvider provider,
      ColorScheme colorScheme, ThemeData theme) {
    final s = provider.detail.supplier!;
    final imageUrl = s.image != null && s.image!.isNotEmpty
        ? _buildImageUrl(s.image!)
        : null;
    final hasPhoto = s.image != null && s.image!.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: imageUrl != null ? 240 : 120,
          pinned: true,
          actions: [
            if (_canEditFields) ...[
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _openEdit(context),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context),
                tooltip: 'Hapus',
                color: colorScheme.error,
              ),
            ],
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              s.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            background: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildHeaderPlaceholder(colorScheme, s),
                  )
                : _buildHeaderPlaceholder(colorScheme, s),
          ),
        ),
        SliverToBoxAdapter(
          child: _FadeInDetail(
            key: ObjectKey(s),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16,
                  ModernBottomNav.height + context.systemBottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge + Verify button
                  Row(
                    children: [
                      StatusBadge(
                        label: s.statusText,
                        type: s.status == 2
                            ? StatusType.success
                            : s.status == 3
                                ? StatusType.error
                                : StatusType.warning,
                        size: BadgeSize.medium,
                      ),
                      if (_canVerify) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showVerificationDialog(context),
                          icon: const Icon(Icons.verified_outlined, size: 16),
                          label: const Text('Verifikasi'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.gapVerticalLG,

                  // Photo button for all roles
                  if (_canEditFields || _isStaff) ...[
                    _buildSectionTitle('Foto', theme),
                    _buildInfoCard(
                      colorScheme: colorScheme,
                      theme: theme,
                      children: [
                        ListTile(
                          leading: Icon(
                            hasPhoto ? Icons.photo : Icons.add_a_photo_outlined,
                            color: AppColors.info,
                          ),
                          title: Text(hasPhoto ? 'Ganti Foto' : 'Tambah Foto'),
                          subtitle: Text(
                            hasPhoto ? 'Tap untuk mengganti foto supplier' : 'Tap untuk menambahkan foto',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _pickAndUploadPhoto(context),
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                  ],

                  // Contact section
                  if (s.noTelp != null) ...[
                    _buildSectionTitle('Kontak', theme),
                    _buildInfoCard(
                      colorScheme: colorScheme,
                      theme: theme,
                      children: [
                        _buildDetailRow(
                          icon: Icons.phone_rounded,
                          label: 'Telepon',
                          value: s.noTelp!,
                          colorScheme: colorScheme,
                          theme: theme,
                          onTap: () => _copyToClipboard(context, s.noTelp!),
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                  ],

                  // Bank details
                  if (s.bankName != null ||
                      s.bankAccountName != null ||
                      s.bankAccountNo != null) ...[
                    _buildSectionTitle('Rekening Bank', theme),
                    _buildInfoCard(
                      colorScheme: colorScheme,
                      theme: theme,
                      children: [
                        if (s.bankName != null)
                          _buildDetailRow(
                            icon: Icons.account_balance_rounded,
                            label: 'Bank',
                            value: s.bankName!,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        if (s.bankAccountName != null)
                          _buildDetailRow(
                            icon: Icons.person_rounded,
                            label: 'Nama Rekening',
                            value: s.bankAccountName!,
                            colorScheme: colorScheme,
                            theme: theme,
                            onTap: () =>
                                _copyToClipboard(context, s.bankAccountName!),
                          ),
                        if (s.bankAccountNo != null)
                          _buildDetailRow(
                            icon: Icons.credit_card_rounded,
                            label: 'No. Rekening',
                            value: s.bankAccountNo!,
                            colorScheme: colorScheme,
                            theme: theme,
                            onTap: () =>
                                _copyToClipboard(context, s.bankAccountNo!),
                            isLast: true,
                          ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                  ],

                  // QRIS section
                  if (s.qris != null && s.qris!.isNotEmpty) ...[
                    _buildSectionTitle('QRIS', theme),
                    _buildInfoCard(
                      colorScheme: colorScheme,
                      theme: theme,
                      children: [
                        _buildDetailRow(
                          icon: Icons.qr_code_rounded,
                          label: 'QRIS',
                          value: 'Tersedia',
                          colorScheme: colorScheme,
                          theme: theme,
                          onTap: () => _copyToClipboard(context, s.qris!),
                          isLast: true,
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                  ],

                  // Address section
                  if (s.address != null) ...[
                    _buildSectionTitle('Alamat', theme),
                    _buildInfoCard(
                      colorScheme: colorScheme,
                      theme: theme,
                      children: [
                        _buildDetailRow(
                          icon: Icons.home_rounded,
                          label: 'Alamat',
                          value: s.address!,
                          colorScheme: colorScheme,
                          theme: theme,
                        ),
                        if (s.subdistrictName != null)
                          _buildDetailRow(
                            icon: Icons.location_city_rounded,
                            label: 'Kelurahan',
                            value: s.subdistrictName!,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        if (s.districtName != null)
                          _buildDetailRow(
                            icon: Icons.map_rounded,
                            label: 'Kecamatan',
                            value: s.districtName!,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        if (s.cityName != null)
                          _buildDetailRow(
                            icon: Icons.location_on_rounded,
                            label: 'Kota',
                            value: s.cityName!,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        if (s.provinceName != null)
                          _buildDetailRow(
                            icon: Icons.flag_rounded,
                            label: 'Provinsi',
                            value: s.provinceName!,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        if (s.postalCode != null)
                          _buildDetailRow(
                            icon: Icons.markunread_mailbox_rounded,
                            label: 'Kode Pos',
                            value: s.postalCode!,
                            colorScheme: colorScheme,
                            theme: theme,
                            isLast: true,
                          ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                  ],

                  // Meta info
                  _buildSectionTitle('Informasi', theme),
                  _buildInfoCard(
                    colorScheme: colorScheme,
                    theme: theme,
                    children: [
                      if (s.userName != null)
                        _buildDetailRow(
                          icon: Icons.person_pin_rounded,
                          label: 'Dibuat oleh',
                          value: s.userName!,
                          colorScheme: colorScheme,
                          theme: theme,
                        ),
                      _buildDetailRow(
                        icon: Icons.tag_rounded,
                        label: 'ID Supplier',
                        value: '#${s.id}',
                        colorScheme: colorScheme,
                        theme: theme,
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderPlaceholder(ColorScheme colorScheme, SupplierModel s) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required ColorScheme colorScheme,
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
    required ThemeData theme,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: AppColors.info),
                const SizedBox(width: AppSpacing.sectionGap),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      AppSpacing.gapVerticalXS,
                      Text(
                        value,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.copy_rounded, size: 14, color: AppColors.info),
                ],
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 0,
              indent: 46,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }

  Widget _buildError(
      BuildContext context, ColorScheme colorScheme, String message) {
    final provider = context.read<SupplierProvider>();
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: colorScheme.error),
            AppSpacing.gapVerticalMD,
            Text(
              message,
              style: TextStyle(color: colorScheme.error),
            ),
            AppSpacing.gapVerticalMD,
            ElevatedButton.icon(
              onPressed: () => provider.fetchDetail(widget.supplierId),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showInfoSnackBar(context, '"$text" disalin ke clipboard.');
  }

  String _buildImageUrl(String imagePath) {
    return '${ApiConstants.baseUrl}/media/$imagePath';
  }
}

/// Animasi fade-in konten detail setiap kali supplier berhasil dimuat ulang.
class _FadeInDetail extends StatefulWidget {
  final Widget child;

  const _FadeInDetail({super.key, required this.child});

  @override
  State<_FadeInDetail> createState() => _FadeInDetailState();
}

class _FadeInDetailState extends State<_FadeInDetail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: widget.child);
  }
}
