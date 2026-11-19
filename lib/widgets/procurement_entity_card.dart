import 'package:flutter/material.dart';
import '../models/procurement_model.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'list_thumbnail.dart';

/// Generic entity card untuk halaman procurement workflow.
/// Memiliki 3 factory mode: requestMode, invoiceMode, paymentMode.
class ProcurementEntityCard extends StatelessWidget {
  final Color borderColor;
  final IconData stageIcon;
  final String title;
  final String metaLine;
  final String? amountText;
  final Color? amountColor;
  final Widget? badge;
  final Widget? stepperOrLinks;
  final List<Widget>? actions;
  final VoidCallback? onTapCard;
  final bool isSelected;
  final Widget? leadingCheckbox;
  final String? thumbnailUrl;
  final IconData thumbnailPlaceholder;
  final VoidCallback? onTapThumbnail;
  final String? secondaryThumbnailUrl;
  final IconData secondaryThumbnailIcon;
  final VoidCallback? onTapSecondaryThumbnail;

  const ProcurementEntityCard._({
    super.key,
    required this.borderColor,
    required this.stageIcon,
    required this.title,
    required this.metaLine,
    this.amountText,
    this.amountColor,
    this.badge,
    this.stepperOrLinks,
    this.actions,
    this.onTapCard,
    this.isSelected = false,
    this.leadingCheckbox,
    this.thumbnailUrl,
    this.thumbnailPlaceholder = Icons.receipt_long,
    this.onTapThumbnail,
    this.secondaryThumbnailUrl,
    this.secondaryThumbnailIcon = Icons.payment,
    this.onTapSecondaryThumbnail,
  });

  /// Mode Request.
  factory ProcurementEntityCard.requestMode({
    Key? key,
    required RequestPurchase request,
    required List<InvoicePurchase> linkedInvoices,
    bool isSelected = false,
    VoidCallback? onTapCard,
    VoidCallback? onTapCreateInvoice,
    void Function(InvoicePurchase inv)? onTapLinkInvoice,
    bool showCheckbox = false,
    bool? checkboxValue,
    ValueChanged<bool>? onCheckboxChanged,
  }) {
    final isSiapInvoice = request.detailRequests.isNotEmpty;
    final badgeText = linkedInvoices.isEmpty
        ? (isSiapInvoice ? 'Siap Invoice' : 'Kosong')
        : 'Sudah Jadi Invoice (${linkedInvoices.length})';
    final badgeColor =
        linkedInvoices.isEmpty ? AppColors.warning : AppColors.success;

    final linkPills = linkedInvoices.map((inv) {
      final status = inv.paymentStatus == '2' ? '✅' : '🔴';
      return _LinkPill(
        icon: Icons.receipt_outlined,
        label: '↳ INV #${inv.id} $status',
        onTap: () => onTapLinkInvoice?.call(inv),
      );
    }).toList();

    return ProcurementEntityCard._(
      key: key,
      borderColor: AppColors.warning,
      stageIcon: Icons.shopping_bag_outlined,
      title: 'REQ #${request.id} • ${request.storeName}',
      metaLine:
          '${request.userName} • ${request.detailRequests.length} item • ${request.date}',
      badge: _Badge(text: badgeText, color: badgeColor),
      stepperOrLinks: linkedInvoices.isEmpty
          ? (isSiapInvoice
              ? Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onTapCreateInvoice,
                        icon: const Icon(Icons.arrow_forward, size: 14),
                        label: const Text(
                          'Buat Invoice',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    if (showCheckbox) ...[
                      const SizedBox(width: 8),
                      Checkbox(
                        value: checkboxValue ?? false,
                        onChanged: (v) => onCheckboxChanged?.call(v ?? false),
                      ),
                    ],
                  ],
                )
              : null)
          : Wrap(spacing: 6, runSpacing: 6, children: linkPills),
      onTapCard: onTapCard,
      isSelected: isSelected,
    );
  }

  /// Mode Invoice.
  factory ProcurementEntityCard.invoiceMode({
    Key? key,
    required InvoicePurchase invoice,
    required List<int> linkedRequestIds,
    PaymentReceipt? paymentReceipt,
    List<InvoicePurchase> linkedInvoicesInSameReceipt = const [],
    bool showCheckbox = false,
    bool? checkboxValue,
    ValueChanged<bool>? onCheckboxChanged,
    VoidCallback? onTapCard,
    VoidCallback? onTapBayar,
    VoidCallback? onTapThumbnail,
    VoidCallback? onTapSecondaryThumbnail,
    void Function(InvoicePurchase)? onTapLinkedInvoice,
  }) {
    final isPaid = invoice.paymentStatus == '2';
    final canBayar = !isPaid;

    // Badge tap-able: kalau siap dibayar, tap = bayar langsung.
    final badge = _Badge(
      text: isPaid ? 'Lunas' : 'Siap Dibayar',
      color: isPaid ? AppColors.success : AppColors.info,
      onTap: (canBayar && onTapBayar != null) ? onTapBayar : null,
    );

    // Link pills: REQ parent + invoice lain dalam kwitansi yang sama
    final linkPills = <Widget>[];
    if (linkedRequestIds.isNotEmpty) {
      linkPills.add(
        _LinkPill(
          icon: Icons.shopping_bag_outlined,
          label: '↳ REQ ${linkedRequestIds.join(",")}',
        ),
      );
    }
    if (isPaid && paymentReceipt != null && linkedInvoicesInSameReceipt.length > 1) {
      for (final otherInv in linkedInvoicesInSameReceipt
          .where((inv) => inv.id != invoice.id)) {
        linkPills.add(
          _LinkPill(
            icon: Icons.receipt_outlined,
            label: '↳ INV #${otherInv.id}',
            onTap: onTapLinkedInvoice != null
                ? () => onTapLinkedInvoice(otherInv)
                : null,
          ),
        );
      }
    }

    final actions = <Widget>[];

    // Format date dari ISO yyyy-MM-dd ke dd-MM-yyyy.
    String fmtDate(String raw) {
      if (raw.length < 10) return raw;
      final parts = raw.substring(0, 10).split('-');
      if (parts.length != 3) return raw;
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }

    final String? effectiveThumb = invoice.imageUrl;
    final IconData effectiveThumbIcon = Icons.receipt_long;
    final String? kwitansiThumb =
        (isPaid && paymentReceipt?.imageUrl != null)
            ? paymentReceipt!.imageUrl
            : null;

    return ProcurementEntityCard._(
      key: key,
      borderColor: AppColors.info,
      stageIcon: Icons.receipt_long_outlined,
      title: 'INV #${invoice.id} • ${invoice.storeName}',
      metaLine:
          'Supplier: ${invoice.supplierName ?? "-"} • Tgl: ${fmtDate(invoice.date)} • ${invoice.paymentTypeText}',
      thumbnailUrl: effectiveThumb,
      thumbnailPlaceholder: effectiveThumbIcon,
      onTapThumbnail: onTapThumbnail,
      secondaryThumbnailUrl: kwitansiThumb,
      secondaryThumbnailIcon: Icons.payment,
      onTapSecondaryThumbnail: onTapSecondaryThumbnail,
      amountText: FormatUtils.formatCurrency(invoice.totalPrice),
      amountColor: isPaid ? AppColors.success : const Color(0xFF1976D2),
      badge: badge,
      stepperOrLinks: linkPills.isEmpty
          ? null
          : Wrap(spacing: 6, runSpacing: 6, children: linkPills),
      actions: actions.isEmpty ? null : actions,
      onTapCard: onTapCard,
      isSelected: checkboxValue ?? false,
      leadingCheckbox: showCheckbox && canBayar
          ? Checkbox(
              value: checkboxValue ?? false,
              onChanged: (v) => onCheckboxChanged?.call(v ?? false),
            )
          : null,
    );
  }

  /// Mode Payment.
  factory ProcurementEntityCard.paymentMode({
    Key? key,
    required PaymentReceipt receipt,
    required bool isTunai,
    VoidCallback? onTapCard,
    VoidCallback? onTapThumbnail,
  }) {
    final isMulti = receipt.invoicePurchases.length > 1;
    final linkPills = receipt.invoicePurchases
        .map((inv) => _LinkPill(
              icon: Icons.receipt_outlined,
              label: '↳ INV #${inv.id}',
            ))
        .toList();

    // Format createdAt dari ISO ke dd-MM-yyyy.
    final rawDate = receipt.createdAt;
    String formattedDate = rawDate;
    if (rawDate.length >= 10) {
      final iso = rawDate.substring(0, 10);
      final parts = iso.split('-');
      if (parts.length == 3) {
        formattedDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    return ProcurementEntityCard._(
      key: key,
      borderColor: AppColors.success,
      stageIcon: Icons.payments_outlined,
      title: 'Kwit #${receipt.id} • ${receipt.supplierName ?? "Supplier"}',
      metaLine: 'Tgl Bayar: $formattedDate',
      thumbnailUrl: receipt.imageUrl,
      thumbnailPlaceholder: Icons.payment,
      onTapThumbnail: onTapThumbnail,
      amountText: FormatUtils.formatCurrency(receipt.totalAmount),
      amountColor: AppColors.success,
      badge: isMulti
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Badge(text: 'Lunas', color: AppColors.success),
                const SizedBox(height: 3),
                _Badge(
                  text: '${receipt.invoicePurchases.length} Invoice Gabungan',
                  color: AppColors.secondary,
                ),
              ],
            )
          : const _Badge(text: 'Lunas', color: AppColors.success),
      stepperOrLinks: Wrap(spacing: 6, runSpacing: 6, children: linkPills),
      actions: null,
      onTapCard: onTapCard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? borderColor
              : cs.outlineVariant.withValues(alpha: 0.35),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? borderColor.withValues(alpha: 0.15)
                : AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapCard,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingCheckbox != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: leadingCheckbox!,
                  ),
                  const SizedBox(width: 8),
                ],
                // Icon avatar stage
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    stageIcon,
                    size: 16,
                    color: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: title, meta, amount
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  metaLine,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                if (amountText != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    amountText!,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: amountColor ?? cs.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (thumbnailUrl != null ||
                              secondaryThumbnailUrl != null ||
                              badge != null) ...[
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (thumbnailUrl != null ||
                                    secondaryThumbnailUrl != null) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (thumbnailUrl != null) ...[
                                        ListThumbnail(
                                          imageUrl: thumbnailUrl,
                                          placeholderIcon: thumbnailPlaceholder,
                                          size: 42,
                                          onTap: onTapThumbnail,
                                        ),
                                        if (secondaryThumbnailUrl != null)
                                          const SizedBox(width: 4),
                                      ],
                                      if (secondaryThumbnailUrl != null)
                                        ListThumbnail(
                                          imageUrl: secondaryThumbnailUrl,
                                          placeholderIcon: secondaryThumbnailIcon,
                                          size: 42,
                                          onTap: onTapSecondaryThumbnail,
                                        ),
                                    ],
                                  ),
                                  if (badge != null)
                                    const SizedBox(height: 6),
                                ],
                                if (badge != null) badge!,
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (stepperOrLinks != null) ...[
                        const SizedBox(height: 8),
                        stepperOrLinks!,
                      ],
                      if (actions != null && actions!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: actions!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;
  const _Badge({required this.text, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: onTap != null
            ? color
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: onTap == null
            ? Border.all(color: color.withValues(alpha: 0.35), width: 1)
            : null,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: onTap != null ? Colors.white : color,
          letterSpacing: 0.1,
        ),
      ),
    );

    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: container,
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _LinkPill({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
