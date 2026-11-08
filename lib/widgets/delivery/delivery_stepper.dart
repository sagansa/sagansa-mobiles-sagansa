import 'package:flutter/material.dart';
import '../../models/enums/delivery_status.dart';
import '../../models/enums/order_mode.dart';
import '../../theme/app_colors.dart';

class DeliveryStepper extends StatelessWidget {
  final DeliveryStatus status;
  final OrderMode orderMode;
  final bool isStickerPrinted;

  const DeliveryStepper({
    super.key,
    required this.status,
    required this.orderMode,
    this.isStickerPrinted = false,
  });

  int get _activeStep {
    final code = status.code;
    if (orderMode.isOnline) {
      if (code == 1) return isStickerPrinted ? 1 : 0;
      if (code == 4) return 2;
      if (code == 3 || code == 2 || code == 6 || code == 7) return 3;
      return 0;
    } else {
      if (code == 1) return 0;
      if (code == 4) return 1;
      if (code == 3 || code == 2 || code == 6 || code == 7) return 2;
      return 0;
    }
  }

  bool get _isReturned => status == DeliveryStatus.returned;

  bool get _isCancelled => status == DeliveryStatus.cancelled;

  /// Status terminal yang berakhir tidak normal (retur & batal) — keduanya
  /// memakai treatment error (merah), pola retur.
  bool get _isTerminalFailed => _isReturned || _isCancelled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final List<Map<String, dynamic>> steps;
    if (orderMode.isOnline) {
      steps = [
        {'label': 'Belum Kirim', 'icon': Icons.pending_actions},
        {'label': 'Resi Dicetak', 'icon': Icons.print_outlined},
        {'label': 'Siap Kirim', 'icon': Icons.inventory_2_outlined},
        {
          'label': _isCancelled
              ? 'Dibatalkan'
              : (_isReturned ? 'Retur' : 'Terkirim'),
          'icon': _isCancelled
              ? Icons.cancel_outlined
              : (_isReturned
                  ? Icons.assignment_return_outlined
                  : Icons.check_circle_outline),
        },
      ];
    } else {
      steps = [
        {'label': 'Belum Kirim', 'icon': Icons.pending_actions},
        {'label': 'Siap Kirim', 'icon': Icons.inventory_2_outlined},
        {
          'label': _isCancelled
              ? 'Dibatalkan'
              : (_isReturned ? 'Retur' : 'Terkirim'),
          'icon': _isCancelled
              ? Icons.cancel_outlined
              : (_isReturned
                  ? Icons.assignment_return_outlined
                  : Icons.check_circle_outline),
        },
      ];
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isCompleted = index < _activeStep;
          final isActive = index == _activeStep;

          Color iconBgColor =
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
          Color iconColor =
              colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
          Color textColor =
              colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
          FontWeight fontWeight = FontWeight.normal;

          if (isActive) {
            iconBgColor = _isTerminalFailed
                ? AppColors.error.withValues(alpha: 0.15)
                : colorScheme.primary.withValues(alpha: 0.15);
            iconColor =
                _isTerminalFailed ? AppColors.error : colorScheme.primary;
            textColor =
                _isTerminalFailed ? AppColors.error : colorScheme.primary;
            fontWeight = FontWeight.bold;
          } else if (isCompleted) {
            iconBgColor = AppColors.success.withValues(alpha: 0.15);
            iconColor = AppColors.success;
            textColor = AppColors.success;
          }

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: index == 0
                          ? const SizedBox()
                          : Divider(
                              thickness: 2,
                              color: index <= _activeStep
                                  ? AppColors.success
                                  : colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                            ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? (_isTerminalFailed
                                  ? AppColors.error
                                  : colorScheme.primary)
                              : (isCompleted
                                  ? AppColors.success
                                  : Colors.transparent),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        size: 16,
                        color: iconColor,
                      ),
                    ),
                    Expanded(
                      child: index == steps.length - 1
                          ? const SizedBox()
                          : Divider(
                              thickness: 2,
                              color: index < _activeStep
                                  ? AppColors.success
                                  : colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step['label'] as String,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: fontWeight,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
