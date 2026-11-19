import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Segmented control gaya iOS untuk pilihan mode/tab tingkat halaman.
///
/// Standar pengganti `TabBar` di AppBar untuk pilihan 2–4 opsi
/// (mis. Online/Employee/Direct di Penjualan, Penjualan/Konsumen di
/// Sales Home). Pakai bersama `IndexedStack` di body:
///
/// ```dart
/// GlassAppBar(
///   title: const Text('Penjualan'),
///   bottom: PreferredSize(
///     preferredSize: const Size.fromHeight(52),
///     child: IosSegmentedControl<int>(
///       segments: const {0: 'Online', 1: 'Employee', 2: 'Direct'},
///       groupValue: _index,
///       onValueChanged: (v) => setState(() => _index = v),
///     ),
///   ),
/// )
/// ```
class IosSegmentedControl<T extends Object> extends StatelessWidget {
  /// Segmen berurutan (insertion-order) nilai → label.
  final Map<T, String> segments;

  /// Nilai terpilih saat ini. Harus salah satu key [segments].
  final T groupValue;

  /// Dipanggil saat segmen lain dipilih.
  final ValueChanged<T> onValueChanged;

  /// Padding luar di sekitar kontrol.
  final EdgeInsetsGeometry padding;

  const IosSegmentedControl({
    super.key,
    required this.segments,
    required this.groupValue,
    required this.onValueChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  }) : assert(segments.length >= 2, 'Butuh minimal 2 segmen');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: groupValue,
        onValueChanged: (v) {
          if (v != null) onValueChanged(v);
        },
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest,
        thumbColor: isDark
            ? Colors.white.withValues(alpha: 0.22)
            : colorScheme.surface,
        children: {
          for (final entry in segments.entries)
            entry.key: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: entry.key == groupValue
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: entry.key == groupValue
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        },
      ),
    );
  }
}
