import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'safe_bottom_bar.dart';

/// Item data model untuk [ModernPickerSheet].
class ModernPickerItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool isDestructive;

  const ModernPickerItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.isDestructive = false,
  });
}

/// Bottom Sheet pilihan modern dengan styling iOS Inset-Grouped list.
/// Menggantikan Radio card list yang tebal dan kaku dengan layout bersih,
/// indikator checkmark di sisi kanan, pencarian otomatis, dan safe area bottom inset.
class ModernPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<ModernPickerItem<T>> items;
  final T? selectedItem;
  final bool searchable;
  final String? searchHint;
  final bool showClearAll;
  final String? clearAllLabel;
  final T? clearAllValue;
  final ValueChanged<T?>? onSelected;

  const ModernPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedItem,
    this.searchable = false,
    this.searchHint,
    this.showClearAll = false,
    this.clearAllLabel,
    this.clearAllValue,
    this.onSelected,
  });

  /// Helper statis untuk menampilkan bottom sheet pilihan secara deklaratif.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<ModernPickerItem<T>> items,
    T? selectedItem,
    bool? searchable,
    String? searchHint,
    bool showClearAll = false,
    String? clearAllLabel,
    T? clearAllValue,
    ValueChanged<T?>? onSelected,
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModernPickerSheet<T>(
        title: title,
        items: items,
        selectedItem: selectedItem,
        searchable: searchable ?? (items.length > 5),
        searchHint: searchHint,
        showClearAll: showClearAll,
        clearAllLabel: clearAllLabel,
        clearAllValue: clearAllValue,
        onSelected: onSelected,
      ),
    );
  }

  /// Helper statis praktis dari List Tuple `(T, String)`.
  static Future<T?> showFromTuples<T>({
    required BuildContext context,
    required String title,
    required List<(T, String)> options,
    T? selectedItem,
    bool? searchable,
    bool showAllOption = false,
    String? allOptionLabel,
    T? allOptionValue,
    ValueChanged<T?>? onSelected,
  }) {
    final items = options
        .map((opt) => ModernPickerItem<T>(value: opt.$1, label: opt.$2))
        .toList();

    return show<T>(
      context: context,
      title: title,
      items: items,
      selectedItem: selectedItem,
      searchable: searchable,
      showClearAll: showAllOption,
      clearAllLabel: allOptionLabel ?? 'Semua $title',
      clearAllValue: allOptionValue,
      onSelected: onSelected,
    );
  }

  @override
  State<ModernPickerSheet<T>> createState() => _ModernPickerSheetState<T>();
}

class _ModernPickerSheetState<T> extends State<ModernPickerSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  late List<ModernPickerItem<T>> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = item.label.toLowerCase();
          final subtitle = item.subtitle?.toLowerCase() ?? '';
          return label.contains(q) || subtitle.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      margin: EdgeInsets.only(bottom: keyboardPadding),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? 'Cari ${widget.title.toLowerCase()}...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.borderRadiusMD,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 8),

          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

          // Items List (iOS Inset-Grouped card style)
          Flexible(
            child: _filteredItems.isEmpty && !widget.showClearAll
                ? Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada pilihan ditemukan',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // iOS Inset Group Container
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // "Semua" Option jika diaktifkan
                            if (widget.showClearAll) ...[
                              _buildRow(
                                context: context,
                                label: widget.clearAllLabel ?? 'Semua',
                                subtitle: null,
                                leading: null,
                                isSelected: widget.selectedItem == widget.clearAllValue,
                                onTap: () {
                                  widget.onSelected?.call(widget.clearAllValue);
                                  Navigator.pop(context, widget.clearAllValue);
                                },
                              ),
                              if (_filteredItems.isNotEmpty)
                                Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: 16,
                                  color: cs.outlineVariant.withValues(alpha: 0.35),
                                ),
                            ],

                            // Dynamic Items
                            for (int i = 0; i < _filteredItems.length; i++) ...[
                              _buildRow(
                                context: context,
                                label: _filteredItems[i].label,
                                subtitle: _filteredItems[i].subtitle,
                                leading: _filteredItems[i].leading,
                                isDestructive: _filteredItems[i].isDestructive,
                                isSelected: widget.selectedItem == _filteredItems[i].value,
                                onTap: () {
                                  widget.onSelected?.call(_filteredItems[i].value);
                                  Navigator.pop(context, _filteredItems[i].value);
                                },
                              ),
                              if (i < _filteredItems.length - 1)
                                Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: _filteredItems[i].leading != null ? 52 : 16,
                                  color: cs.outlineVariant.withValues(alpha: 0.35),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          // Safe inset bottom
          SizedBox(height: context.systemBottomInset + 12),
        ],
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required String label,
    required String? subtitle,
    required Widget? leading,
    bool isDestructive = false,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: isSelected
          ? cs.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isDestructive
                            ? cs.error
                            : (isSelected ? cs.primary : cs.onSurface),
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  color: cs.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
