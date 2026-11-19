import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/supplier_model.dart';
import '../providers/auth_provider.dart';
import '../providers/supplier_provider.dart';
import '../services/image_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';
import '../widgets/status_badge.dart';
import 'supplier_form_page.dart';

class SupplierDetailPage extends StatelessWidget {
  final int supplierId;

  const SupplierDetailPage({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    // Fetch hanya via post-frame di initState (sekali). Jangan panggil
    // di create: notifyListeners() sinkron di tengah mount + double request
    // dengan fetch di initState → rebuild storm saat halaman dibuka.
    return ChangeNotifierProvider(
      create: (_) => SupplierProvider(),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<SupplierProvider>();
      if (provider.detail.supplier == null && !provider.detail.isLoading) {
        provider.fetchDetail(widget.supplierId);
      }
    });
  }

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
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return AlertDialog(
            backgroundColor: colorScheme.surface,
            title: Text(
              'Verifikasi Supplier',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapVerticalMD,
                RadioGroup<int>(
                  groupValue: selectedStatus,
                  onChanged: (v) => setDialogState(() => selectedStatus = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<int>(
                        title: Text(
                          'Belum Diperiksa',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        value: 1,
                        activeColor: colorScheme.primary,
                      ),
                      _lockedWhenNoPhoto(
                        enabled: hasPhoto,
                        child: RadioListTile<int>(
                          title: Text(
                            'Valid',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          subtitle: hasPhoto
                              ? null
                              : Text(
                                  'Perlu foto supplier',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                          value: 2,
                          activeColor: colorScheme.primary,
                        ),
                      ),
                      RadioListTile<int>(
                        title: Text(
                          'Blacklist',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        value: 3,
                        activeColor: colorScheme.primary,
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
                onPressed: selectedStatus != null &&
                        selectedStatus != supplier.status
                    ? () => Navigator.pop(ctx, selectedStatus)
                    : null,
                child: const Text('Simpan'),
              ),
            ],
          );
        },
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

  Widget _lockedWhenNoPhoto({required bool enabled, required Widget child}) {
    if (enabled) return child;
    return IgnorePointer(child: Opacity(opacity: 0.55, child: child));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<SupplierProvider>();
    final auth = context.watch<AuthProvider>();
    final detail = provider.detail;

    final isAdmin = auth.hasAnyRole(['admin', 'super_admin']);
    final isSupervisor = auth.hasAnyRole(['supervisor']);
    final isStaff = auth.hasAnyRole(['staff']);
    // Foto & verifikasi tetap terbuka sesuai peran.
    final canEditFields = isAdmin || isSupervisor;
    final canVerify = isAdmin;

    if (detail.isLoading) {
      return Scaffold(
        appBar: GlassAppBar(
          title: const Text('Detail Supplier'),
          ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (detail.errorMessage != null || detail.supplier == null) {
      return Scaffold(
        appBar: GlassAppBar(
          title: const Text('Detail Supplier'),
          ),
        body: _buildError(
          context,
          colorScheme,
          detail.errorMessage ?? 'Data supplier tidak ditemukan.',
        ),
      );
    }

    final s = detail.supplier!;

    // Edit/hapus supplier luar negeri hanya admin (paritas gerbang backend).
    final canEditActions = isAdmin || (isSupervisor && !s.isForeign);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Detail Supplier'),
        actions: [
          BarButtonCluster(actions: [
            if (canEditActions) ...[
              BarButtonSpec(
                icon: Icons.edit_rounded,
                tooltip: 'Edit',
                onTap: () => _openEdit(context),
              ),
              BarButtonSpec(
                icon: Icons.delete_outline,
                tooltip: 'Hapus',
                onTap: () => _delete(context),
              ),
            ],
          ]),
        ],
      ),
      body: _buildContent(
        context,
        provider,
        s,
        colorScheme,
        theme,
        canEditFields: canEditFields,
        canEditActions: canEditActions,
        canVerify: canVerify,
        isStaff: isStaff,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SupplierProvider provider,
    SupplierModel s,
    ColorScheme colorScheme,
    ThemeData theme, {
    required bool canEditFields,
    required bool canEditActions,
    required bool canVerify,
    required bool isStaff,
  }) {
    final imageUrl = s.image != null && s.image!.isNotEmpty
        ? _buildImageUrl(s.image!)
        : null;
    final hasPhoto = s.image != null && s.image!.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => provider.fetchDetail(widget.supplierId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          AppBarInsets.top(context) + 16,
          16,
          AppSpacing.xl + context.systemBottomInset,
        ),
        children: [
          // Header Hero Card
          Container(
            width: double.infinity,
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppSpacing.borderRadiusLG,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.gapVerticalSM,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                    if (s.isForeign)
                      StatusBadge(
                        label: s.countryName,
                        type: StatusType.info,
                        size: BadgeSize.medium,
                        style: StatusBadgeStyle.outline,
                      ),
                    if (s.isForeign && s.currency != null)
                      StatusBadge(
                        label: 'Valuta ${s.currency}',
                        type: StatusType.info,
                        size: BadgeSize.medium,
                        style: StatusBadgeStyle.outline,
                      ),
                    if (canVerify)
                      FilledButton.tonalIcon(
                        onPressed: () => _showVerificationDialog(context),
                        icon: const Icon(Icons.verified_outlined, size: 16),
                        label: const Text('Verifikasi'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppSpacing.borderRadiusMD,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapVerticalLG,

          // Photo Card
          _buildSectionTitle('Foto Supplier', theme),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppSpacing.borderRadiusLG,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhoto && imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: DetailImageView(
                      imageUrl: imageUrl,
                      height: 180,
                      previewTitle: s.name,
                    ),
                  ),
                if (canEditFields || isStaff)
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      shape: hasPhoto
                          ? const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                            )
                          : RoundedRectangleBorder(
                              borderRadius: AppSpacing.borderRadiusLG,
                            ),
                      leading: Icon(
                        hasPhoto ? Icons.photo : Icons.add_a_photo_outlined,
                        color: AppColors.info,
                      ),
                      title: Text(hasPhoto ? 'Ganti Foto' : 'Tambah Foto'),
                      subtitle: Text(
                        hasPhoto
                            ? 'Tap untuk mengganti foto supplier'
                            : 'Tap untuk menambahkan foto',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _pickAndUploadPhoto(context),
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.gapVerticalMD,

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
              s.bankSwiftCode != null ||
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
                if (s.bankSwiftCode != null)
                  _buildDetailRow(
                    icon: Icons.tag_rounded,
                    label: 'Kode SWIFT / BIC',
                    value: s.bankSwiftCode!,
                    colorScheme: colorScheme,
                    theme: theme,
                    onTap: () => _copyToClipboard(context, s.bankSwiftCode!),
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
                    label: s.isForeign ? 'No. Rekening / IBAN' : 'No. Rekening',
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
                  isLast: s.isForeign
                      ? false
                      : (s.subdistrictName == null &&
                          s.districtName == null &&
                          s.cityName == null &&
                          s.provinceName == null &&
                          s.postalCode == null),
                ),
                if (s.isForeign) ...[
                  if (s.cityName != null)
                    _buildDetailRow(
                      icon: Icons.location_city_rounded,
                      label: 'Kota',
                      value: s.cityName!,
                      colorScheme: colorScheme,
                      theme: theme,
                    ),
                  _buildDetailRow(
                    icon: Icons.public_rounded,
                    label: 'Negara',
                    value: s.countryName,
                    colorScheme: colorScheme,
                    theme: theme,
                    isLast: true,
                  ),
                ] else ...[
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
              if (s.isForeign && s.currency != null)
                _buildDetailRow(
                  icon: Icons.currency_exchange_rounded,
                  label: 'Valuta Transaksi',
                  value: '${s.currency} — prefill valuta saat buat proses impor',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
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
    return ImageService.buildUrl(imagePath) ??
        '${ApiConstants.baseUrl}/media/$imagePath';
  }
}
