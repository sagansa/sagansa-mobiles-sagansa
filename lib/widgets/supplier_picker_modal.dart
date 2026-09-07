import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SupplierPickerModal extends StatefulWidget {
  final List<dynamic> suppliers;
  final int? selectedSupplierId;

  const SupplierPickerModal({
    super.key,
    required this.suppliers,
    this.selectedSupplierId,
  });

  /// Static helper to launch the modern supplier picker bottom sheet
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required List<dynamic> suppliers,
    int? selectedSupplierId,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SupplierPickerModal(
        suppliers: suppliers,
        selectedSupplierId: selectedSupplierId,
      ),
    );
  }

  @override
  State<SupplierPickerModal> createState() => _SupplierPickerModalState();
}

class _SupplierPickerModalState extends State<SupplierPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final filtered = widget.suppliers.where((s) {
      // Filter out blacklisted suppliers (status == 3)
      final status = s['status'];
      if (status == 3) return false;
      if (_query.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final address = (s['address'] ?? '').toString().toLowerCase();
      final q = _query.toLowerCase();
      return name.contains(q) || address.contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75,
      ),
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_mall_directory_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Supplier',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${filtered.length} supplier tersedia',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (val) => setState(() => _query = val.trim()),
              decoration: InputDecoration(
                hintText: 'Cari nama supplier atau alamat...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Supplier List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          AppSpacing.gapVerticalSM,
                          Text(
                            'Supplier tidak ditemukan',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final id = item['id'];
                      final name = (item['name'] ?? '').toString();
                      final address = (item['address'] ?? '').toString();
                      final phone = (item['no_telp'] ?? item['phone'] ?? '').toString();
                      final isSelected = widget.selectedSupplierId == id;

                      String subtitleText = '';
                      if (address.isNotEmpty && phone.isNotEmpty) {
                        subtitleText = '$address • $phone';
                      } else if (address.isNotEmpty) {
                        subtitleText = address;
                      } else if (phone.isNotEmpty) {
                        subtitleText = phone;
                      }

                      final initialLetter = name.isNotEmpty ? name[0].toUpperCase() : 'S';

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer.withValues(alpha: 0.25)
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.5)
                                : colorScheme.outline.withValues(alpha: 0.1),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx, item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Circle Initial Avatar
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      initialLetter,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isSelected
                                            ? colorScheme.onPrimary
                                            : colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Supplier info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      if (subtitleText.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitleText,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 11.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      // Bank / QRIS badges
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          if ((item['bank_account_no'] ?? '').toString().isNotEmpty ||
                                              (item['bank_name'] ?? '').toString().isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${(item['bank_name'] ?? 'Bank').toString()} ${(item['bank_account_no'] ?? '').toString()}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                          if ((item['qris'] ?? '').toString().isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'QRIS',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Check icon if selected
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
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
        ],
      ),
    );
  }
}
