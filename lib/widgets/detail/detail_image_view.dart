import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../glass_app_bar.dart';

/// Tampilan gambar bukti/lampiran standar untuk halaman detail.
///
/// Standar yang dijaga widget ini agar seragam di seluruh halaman detail:
/// - Sudut melengkung [AppSpacing.borderRadiusMD] di semua sisi.
/// - Overlay bawah "Ketuk untuk memperbesar gambar" (ikon zoom_in).
/// - Tap membuka preview full-screen (latar hitam + InteractiveViewer).
/// - Placeholder loading & error yang seragam.
///
/// Ukuran gambar diatur salah satu dari: [height] (default 220),
/// [aspectRatio] (mis. 16/9 bila layout mengikat rasio), atau keduanya
/// null untuk mengikuti ukuran intrinsik gambar.
class DetailImageView extends StatelessWidget {
  final String imageUrl;

  /// Judul app bar pada preview full-screen.
  final String? previewTitle;

  /// Tinggi gambar; null bila memakai [aspectRatio] atau ukuran intrinsik.
  final double? height;

  /// Rasio lebar-tinggi alternatif pengganti [height] (mis. 16/9, 1).
  final double? aspectRatio;

  /// URL cadangan bila [imageUrl] gagal dimuat (mis. fallback path lama).
  final String? fallbackImageUrl;

  /// Override aksi tap (mis. membuka viewer dengan tombol bagikan).
  /// Null → buka preview full-screen bawaan.
  final VoidCallback? onTap;

  final BoxFit fit;

  const DetailImageView({
    super.key,
    required this.imageUrl,
    this.previewTitle,
    this.height = 220,
    this.aspectRatio,
    this.fallbackImageUrl,
    this.onTap,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget image = Image.network(
      imageUrl,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, __, ___) => fallbackImageUrl != null &&
              fallbackImageUrl!.isNotEmpty
          ? Image.network(
              fallbackImageUrl!,
              width: double.infinity,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _errorPlaceholder(colorScheme),
            )
          : _errorPlaceholder(colorScheme),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _loadingPlaceholder(colorScheme, progress);
      },
    );

    if (height != null) {
      image = SizedBox(height: height, width: double.infinity, child: image);
    } else if (aspectRatio != null) {
      image = AspectRatio(aspectRatio: aspectRatio!, child: image);
    }

    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusMD,
      child: GestureDetector(
        onTap: onTap ?? () => _openPreview(context),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            image,
            Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.55),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.zoom_in, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  // Flexible: caption wrap di lebar sempit (thumbnail
                  // multi-foto) daripada overflow.
                  Flexible(
                    child: Text(
                      'Ketuk untuk memperbesar gambar',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPlaceholder(ColorScheme colorScheme) {
    return Container(
      height: 140,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Center(
        child: Icon(Icons.broken_image_outlined,
            size: 40, color: colorScheme.outline),
      ),
    );
  }

  Widget _loadingPlaceholder(
      ColorScheme colorScheme, ImageChunkEvent? progress) {
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Center(
        child: CircularProgressIndicator(
          value: progress == null || progress.expectedTotalBytes == null
              ? null
              : progress.cumulativeBytesLoaded /
                  progress.expectedTotalBytes!,
        ),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: GlassAppBar(
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.87),
            foregroundColor: colorScheme.surface,
            title: Text(
              previewTitle ?? 'Gambar',
              style: TextStyle(color: colorScheme.surface),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => fallbackImageUrl != null &&
                        fallbackImageUrl!.isNotEmpty
                    ? Image.network(
                        fallbackImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image,
                          color: colorScheme.surface.withValues(alpha: 0.54),
                          size: 64,
                        ),
                      )
                    : Icon(
                        Icons.broken_image,
                        color: colorScheme.surface.withValues(alpha: 0.54),
                        size: 64,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
