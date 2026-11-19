import 'package:flutter/material.dart';
import '../models/procurement_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import 'safe_bottom_bar.dart';

class ProcurementPipelineCard extends StatelessWidget {
  final RequestPurchase request;
  final InvoicePurchase? invoice;
  final List<InvoicePurchase>? allInvoices;
  final PaymentReceipt? receipt;
  final List<PaymentReceipt>? allReceipts;
  final VoidCallback? onTapRequest;
  final VoidCallback? onCreateInvoice;
  final VoidCallback? onTapInvoice;
  final Function(InvoicePurchase inv)? onTapSpecificInvoice;
  final VoidCallback? onCreateReceipt;
  final VoidCallback? onTapReceipt;

  const ProcurementPipelineCard({
    super.key,
    required this.request,
    this.invoice,
    this.allInvoices,
    this.receipt,
    this.allReceipts,
    this.onTapRequest,
    this.onCreateInvoice,
    this.onTapInvoice,
    this.onTapSpecificInvoice,
    this.onCreateReceipt,
    this.onTapReceipt,
  });

  /// Step 1 State: Request
  /// 0: Pending, 1: Approved / Processed, 2: Rejected
  int get _requestStepState {
    if (request.detailRequests.isEmpty) return 0;
    if (request.detailRequests.every((i) => i.statusEnum.isRejected)) return 2; // Rejected
    if (request.detailRequests.any((i) => i.statusEnum.isApproved)) return 1; // Approved
    return 0; // Pending
  }

  /// Step 2 State: Invoice
  /// 0: Not Created, 1: Created (Unpaid), 2: Received / Paid
  int get _invoiceStepState {
    if (invoice == null) return 0;
    if (invoice!.paymentStatus == '2') return 2; // Paid
    return 1; // Created
  }

  /// Step 3 State: Payment Receipt
  /// 0: Not Paid, 1: Payment Receipt Created (Done)
  int get _receiptStepState {
    if (receipt != null) return 1;
    if (invoice != null && invoice!.paymentStatus == '2') return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isPaid = _receiptStepState == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: isPaid
              ? AppColors.success.withValues(alpha: 0.4)
              : colorScheme.outline.withValues(alpha: 0.15),
          width: isPaid ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Request Number & Store
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.success.withValues(alpha: 0.08)
                  : colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REQ #${request.id} • ${request.storeName}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Pemohon: ${request.userName} • ${request.date}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(theme),
              ],
            ),
          ),

          // Middle Interactive Pipeline Stepper
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPipelineTimeline(context),
                const SizedBox(height: 14),

                // Item summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${request.detailRequests.length} Item Belanja',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (invoice != null)
                      Text(
                        FormatUtils.formatCurrency(invoice!.totalPrice),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Action Bar
                _buildActionBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme) {
    String text = 'Pending';
    Color color = AppColors.warning;

    if (_receiptStepState == 1) {
      text = 'Selesai & Lunas';
      color = AppColors.success;
    } else if (invoice != null) {
      text = 'Menunggu Pembayaran';
      color = AppColors.info;
    } else if (_requestStepState == 1) {
      text = 'Disetujui (Siap Invoice)';
      color = AppColors.primary;
    } else if (_requestStepState == 2) {
      text = 'Ditolak';
      color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPipelineTimeline(BuildContext context) {
    final hasMultipleInvoices = allInvoices != null && allInvoices!.length > 1;
    final String invoiceSubtitle = hasMultipleInvoices
        ? '${allInvoices!.length} Invoice'
        : (invoice != null
            ? 'Nota #${invoice!.id}'
            : (_requestStepState == 1 ? 'Siap Buat' : 'Belum Ada'));

    return Row(
      children: [
        // Node 1: Request
        Expanded(
          child: _buildNodeStep(
            context: context,
            stepNumber: 1,
            title: 'Request',
            subtitle: request.overallStatusText,
            isCompleted: _requestStepState == 1,
            isActive: _requestStepState == 0,
            isFailed: _requestStepState == 2,
            onTap: onTapRequest,
          ),
        ),
        _buildConnectorLine(_requestStepState == 1),

        // Node 2: Invoice
        Expanded(
          child: _buildNodeStep(
            context: context,
            stepNumber: 2,
            title: 'Invoice',
            subtitle: invoiceSubtitle,
            isCompleted: _invoiceStepState >= 1,
            isActive: _requestStepState == 1 && invoice == null,
            isFailed: false,
            onTap: () {
              if (hasMultipleInvoices) {
                _showMultiInvoicePicker(context, allInvoices!);
              } else if (invoice != null) {
                if (onTapInvoice != null) onTapInvoice!();
              } else {
                if (onCreateInvoice != null) onCreateInvoice!();
              }
            },
          ),
        ),
        _buildConnectorLine(_invoiceStepState >= 1),

        // Node 3: Payment
        Expanded(
          child: _buildNodeStep(
            context: context,
            stepNumber: 3,
            title: 'Payment',
            subtitle: receipt != null
                ? 'Lunas'
                : (invoice != null ? 'Perlu Bayar' : 'Menunggu'),
            isCompleted: _receiptStepState == 1,
            isActive: invoice != null && receipt == null,
            isFailed: false,
            onTap: receipt != null ? onTapReceipt : onCreateReceipt,
          ),
        ),
      ],
    );
  }

  void _showMultiInvoicePicker(BuildContext context, List<InvoicePurchase> invoices) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          // + inset sistem bawah (home indicator / gesture bar).
          padding: EdgeInsets.only(
            left: 20,
            top: 20,
            right: 20,
            bottom: 20 + ctx.systemBottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Daftar Invoice Request #${request.id}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Request ini dibeli melalui ${invoices.length} invoice terpisah:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              ...invoices.map((inv) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.description, color: colorScheme.primary, size: 20),
                  ),
                  title: Text(
                    'Invoice #${inv.id} • ${inv.supplierName ?? 'Supplier'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Total: ${FormatUtils.formatCurrency(inv.totalPrice)} • Status: ${inv.paymentStatusText}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (onTapSpecificInvoice != null) {
                      onTapSpecificInvoice!(inv);
                    } else if (onTapInvoice != null) {
                      onTapInvoice!();
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectorLine(bool isDone) {
    return Container(
      width: 20,
      height: 2,
      color: isDone ? AppColors.success : Colors.grey.shade300,
    );
  }

  Widget _buildNodeStep({
    required BuildContext context,
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool isFailed,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color nodeBg = Colors.grey.shade200;
    Color nodeIconColor = Colors.grey.shade600;
    Widget iconChild = Text(
      '$stepNumber',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: nodeIconColor,
      ),
    );

    if (isCompleted) {
      nodeBg = AppColors.success;
      nodeIconColor = Colors.white;
      iconChild = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isFailed) {
      nodeBg = AppColors.error;
      nodeIconColor = Colors.white;
      iconChild = const Icon(Icons.close, size: 14, color: Colors.white);
    } else if (isActive) {
      nodeBg = colorScheme.primary;
      nodeIconColor = Colors.white;
      iconChild = Text(
        '$stepNumber',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: nodeBg,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Center(child: iconChild),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9.5,
                color: isCompleted
                    ? AppColors.success
                    : colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Direct Quick Action Logic
    if (_requestStepState == 1 && invoice == null && onCreateInvoice != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onCreateInvoice,
          icon: const Icon(Icons.note_add_outlined, size: 16),
          label: const Text('Buat Invoice Belanja'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else if (invoice != null && _receiptStepState == 0 && onCreateReceipt != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onCreateReceipt,
          icon: const Icon(Icons.payment, size: 16),
          label: const Text('Bayar & Buat Payment Receipt'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: onTapRequest,
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text('Lihat Detail Request'),
          ),
        ),
        if (invoice != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onTapInvoice,
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Detail Invoice'),
            ),
          ),
      ],
    );
  }
}
