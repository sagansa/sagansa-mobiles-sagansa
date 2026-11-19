import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Komponen lampiran foto/gambar yang kompak dan hemat ruang untuk form.
///
/// Menggantikan tampilan gambar raksasa (180px+) dengan tile horizontal
/// yang rapi (~56px), dilengkapi pratinjau thumbnail, status badge,
/// dan aksi ganti/hapus yang cepat.
class FormImageTile extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final String label;
  final String? hint;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final bool isRequired;

  const FormImageTile({
    super.key,
    this.imageFile,
    this.imageUrl,
    required this.label,
    this.hint,
    required this.onPick,
    this.onRemove,
    this.isRequired = false,
  });

  bool get _hasImage => imageFile != null || (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (!_hasImage) {
      return InkWell(
        onTap: onPick,
        borderRadius: AppSpacing.borderRadiusMD,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              style: BorderStyle.solid,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRequired ? '$label *' : label,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageFile != null
                ? Image.file(
                    imageFile!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image, size: 24),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Foto terlampir',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: colorScheme.primary,
            tooltip: 'Ganti Foto',
            onPressed: onPick,
            visualDensity: VisualDensity.compact,
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: colorScheme.error,
              tooltip: 'Hapus Foto',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
