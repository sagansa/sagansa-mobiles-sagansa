import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// Satu aksi di [showLetterActionSheet].
class LetterAction {
  /// Nilai yang di-pop saat aksi dipilih.
  final String value;
  final String label;

  /// Keterangan satu baris di bawah label — menjelaskan akibat aksi
  /// (mis. "Draf dihapus permanen, tidak bisa dikembalikan").
  final String? description;
  final IconData icon;

  /// Aksi berbahaya (hapus/batalkan) — label & ikon warna error.
  final bool destructive;

  /// Aksi tidak tersedia pada status ini — tetap tampil (posisi menu
  /// stabil) tetapi redup dan tidak bisa diketuk.
  final bool enabled;

  const LetterAction({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
    this.destructive = false,
    this.enabled = true,
  });
}

/// Menu aksi surat dalam bentuk bottom sheet modern — pengganti `PopupMenuButton`
/// teks polos pada kartu arsip & tombol ⋮ di AppBar.
///
/// Memberikan tata letak terstruktur dengan drag handle, header jelas,
/// tombol aksi berikon dengan deskripsi, pemisahan visual untuk aksi berbahaya,
/// serta tombol tutup eksplisit.
Future<String?> showLetterActionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<LetterAction> actions,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _LetterActionSheet(
      title: title,
      subtitle: subtitle,
      actions: actions,
    ),
  );
}

class _LetterActionSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<LetterAction> actions;

  const _LetterActionSheet({
    required this.title,
    this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final standardActions = actions.where((a) => !a.destructive).toList();
    final destructiveActions = actions.where((a) => a.destructive).toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    borderRadius: AppSpacing.borderRadiusFull,
                  ),
                ),
              ),

              // Header menu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: AppSpacing.borderRadiusMD,
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
              Divider(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                height: 1,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Daftar aksi standar
              if (standardActions.isNotEmpty) ...[
                for (final action in standardActions) ...[
                  _ActionTile(
                    action: action,
                    onTap: action.enabled
                        ? () => Navigator.of(context).pop(action.value)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],

              // Aksi destruktif (dibatalkan / dihapus)
              if (destructiveActions.isNotEmpty) ...[
                if (standardActions.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Divider(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                      height: 1,
                    ),
                  ),
                for (final action in destructiveActions) ...[
                  _ActionTile(
                    action: action,
                    onTap: action.enabled
                        ? () => Navigator.of(context).pop(action.value)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],

              const SizedBox(height: AppSpacing.xs),
              // Tombol tutup
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusMD,
                  ),
                ),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final LetterAction action;
  final VoidCallback? onTap;

  const _ActionTile({required this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = action.enabled;

    final foreground = !enabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : action.destructive
            ? colorScheme.error
            : colorScheme.onSurface;

    final containerColor = !enabled
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : action.destructive
            ? colorScheme.errorContainer.withValues(alpha: 0.2)
            : colorScheme.primaryContainer.withValues(alpha: 0.45);

    final iconColor = !enabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : action.destructive
            ? colorScheme.error
            : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: AppSpacing.borderRadiusLG,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLG,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: action.destructive && enabled
                ? colorScheme.errorContainer.withValues(alpha: 0.08)
                : colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: AppSpacing.borderRadiusLG,
            border: Border.all(
              color: action.destructive && enabled
                  ? colorScheme.error.withValues(alpha: 0.2)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: Icon(action.icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (action.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.description!,
                        style: textTheme.bodySmall?.copyWith(
                          color: enabled
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.45),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol ⋮ pembuka [showLetterActionSheet] — area ketuk 40×40, tooltip
/// tetap deskriptif (mis. "Aksi Surat") agar aksi mudah ditemukan dan
/// diuji. Ikon default titik-tiga vertikal dengan ripple lingkaran modern.
class LetterActionMenuButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final IconData icon;
  final Color? color;

  const LetterActionMenuButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Aksi Surat',
    this.icon = Icons.more_vert_rounded,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color ?? colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
