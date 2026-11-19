import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_service.dart';
import '../theme/app_spacing.dart';

enum PhotoUploaderLayout { grid, horizontal, singleCard }

class PhotoUploader extends StatefulWidget {
  final List<File> photos;
  final ValueChanged<List<File>> onChanged;
  final int maxPhotos;
  final PhotoUploaderLayout layout;
  final String label;
  final String? subtitle;
  final String? directory;

  const PhotoUploader({
    super.key,
    required this.photos,
    required this.onChanged,
    this.maxPhotos = 1,
    this.layout = PhotoUploaderLayout.grid,
    this.label = 'Unggah Foto',
    this.subtitle,
    this.directory,
  });

  @override
  State<PhotoUploader> createState() => _PhotoUploaderState();
}

class _PhotoUploaderState extends State<PhotoUploader> {
  Future<void> _pickImage() async {
    final photo = await ImageService.selectAndPickImage(context);
    if (photo != null) {
      final updated = List<File>.from(widget.photos)..add(photo);
      widget.onChanged(updated);
    }
  }

  void _removeAt(int index) {
    final updated = List<File>.from(widget.photos)..removeAt(index);
    widget.onChanged(updated);
  }

  bool get _isFull => widget.photos.length >= widget.maxPhotos;

  @override
  Widget build(BuildContext context) {
    switch (widget.layout) {
      case PhotoUploaderLayout.horizontal:
        return _buildHorizontal(context);
      case PhotoUploaderLayout.singleCard:
        return _buildSingleCard(context);
      case PhotoUploaderLayout.grid:
        return _buildGrid(context);
    }
  }

  Widget _buildGrid(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final hasPhotos = widget.photos.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPhotos) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) => _photoThumb(index),
          ),
          AppSpacing.gapVerticalSM,
        ],
        if (!_isFull)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: hasPhotos ? 80 : 120,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: AppSpacing.borderRadiusMD,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: colorScheme.primary, size: hasPhotos ? 28 : 36),
                  const SizedBox(height: 8),
                  Text(
                    hasPhotos ? 'Tambah Foto Lagi' : widget.label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!hasPhotos && widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.photos.length + (_isFull ? 0 : 1),
        separatorBuilder: (_, __) => AppSpacing.gapHorizontalSM,
        itemBuilder: (context, index) {
          if (index == widget.photos.length) {
            return GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusMD,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: colorScheme.primary),
                    const SizedBox(height: 4),
                    Text('Tambah', style: TextStyle(fontSize: 11, color: colorScheme.primary)),
                  ],
                ),
              ),
            );
          }
          return _photoThumb(index);
        },
      ),
    );
  }

  Widget _buildSingleCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.photos.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: AppSpacing.borderRadiusMD,
            child: Image.file(
              widget.photos.first,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              radius: 18,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                onPressed: () => _removeAt(0),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.add_a_photo_rounded, size: 18),
        label: Text(widget.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _photoThumb(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppSpacing.borderRadiusSM,
          child: Image.file(
            widget.photos[index],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () => _removeAt(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
