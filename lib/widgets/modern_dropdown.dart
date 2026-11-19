import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'modern_picker_sheet.dart';
import 'safe_bottom_bar.dart';

/// Komponen Dropdown Modern menggantikan DropdownButtonFormField standar.
/// Menampilkan trigger box yang sleek dan membuka Bottom Sheet pilihan
/// yang intuitif dengan dukungan pencarian otomatis bila data banyak.
class ModernDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final String? labelText;
  final List<T> items;
  final String Function(T) getLabel;
  final String Function(T)? getSubtitle;
  final Widget Function(T)? itemLeading;
  final void Function(T?)? onChanged;
  final Widget? prefixIcon;
  final bool isRequired;
  final bool enabled;
  final bool? searchable;
  final String? Function(T?)? validator;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;

  const ModernDropdown({
    super.key,
    required this.value,
    required this.hint,
    this.labelText,
    required this.items,
    required this.getLabel,
    this.getSubtitle,
    this.itemLeading,
    this.onChanged,
    this.prefixIcon,
    this.isRequired = false,
    this.enabled = true,
    this.searchable,
    this.validator,
    this.isDense = true,
    this.contentPadding,
  });

  void _showSelectionSheet(BuildContext context, FormFieldState<T> state) {
    FocusScope.of(context).unfocus();
    ModernPickerSheet.show<T>(
      context: context,
      title: labelText ?? hint,
      items: items.map((item) => ModernPickerItem<T>(
        value: item,
        label: getLabel(item),
        subtitle: getSubtitle?.call(item),
        leading: itemLeading?.call(item),
      )).toList(),
      selectedItem: value,
      searchable: searchable ?? (items.length > 5),
    ).then((selected) {
      if (selected != null) {
        state.didChange(selected);
        if (onChanged != null) onChanged!(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEffectiveEnabled = enabled && onChanged != null;

    final effectiveLabel = (labelText != null && labelText!.isNotEmpty)
        ? (isRequired ? '$labelText *' : labelText)
        : null;

    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<T> state) {
        final hasValue = value != null;
        final visibleText = hasValue
            ? getLabel(value as T)
            : (effectiveLabel != null ? '' : hint);

        return InkWell(
          onTap: isEffectiveEnabled
              ? () => _showSelectionSheet(context, state)
              : null,
          borderRadius: AppSpacing.borderRadiusMD,
          child: InputDecorator(
            isEmpty: !hasValue,
            decoration: InputDecoration(
              isDense: isDense,
              contentPadding: contentPadding ??
                  (isDense
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 11)
                      : null),
              labelText: effectiveLabel,
              hintText: effectiveLabel != null ? hint : null,
              prefixIcon: prefixIcon,
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                color: isEffectiveEnabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              errorText: state.errorText,
              enabled: isEffectiveEnabled,
            ),
            child: Text(
              visibleText,
              style: hasValue
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: isEffectiveEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

/// Bottom Sheet untuk memilih item dari ModernDropdown.
class DropdownSelectionSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) getLabel;
  final String Function(T)? getSubtitle;
  final Widget Function(T)? itemLeading;
  final bool searchable;

  const DropdownSelectionSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.getLabel,
    this.getSubtitle,
    this.itemLeading,
    required this.searchable,
  });

  @override
  State<DropdownSelectionSheet<T>> createState() =>
      _DropdownSelectionSheetState<T>();
}

class _DropdownSelectionSheetState<T> extends State<DropdownSelectionSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = widget.getLabel(item).toLowerCase();
          final subtitle = widget.getSubtitle?.call(item).toLowerCase() ?? '';
          return label.contains(q) || subtitle.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Search Field (jika searchable)
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari ${widget.title.toLowerCase()}...',
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.borderRadiusMD,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          const Divider(height: 1),

          // Item List
          Flexible(
            child: _filteredItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada pilihan ditemukan',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = widget.selectedItem == item;
                      final label = widget.getLabel(item);
                      final subtitle = widget.getSubtitle?.call(item);
                      final leading = widget.itemLeading?.call(item);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, item),
                          borderRadius: AppSpacing.borderRadiusSM,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primaryContainer
                                      .withValues(alpha: 0.4)
                                  : Colors.transparent,
                              borderRadius: AppSpacing.borderRadiusSM,
                              border: isSelected
                                  ? Border.all(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.3),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (leading != null) ...[
                                  leading,
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      if (subtitle != null &&
                                          subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: context.systemBottomInset + 8),
        ],
      ),
    );
  }
}
