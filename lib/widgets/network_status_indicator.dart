import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class NetworkStatusIndicator extends StatefulWidget {
  final bool showWhenConnected;

  const NetworkStatusIndicator({
    super.key,
    this.showWhenConnected = false,
  });

  @override
  State<NetworkStatusIndicator> createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  NetworkStatus? _networkStatus;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkNetworkStatus();
  }

  Future<void> _checkNetworkStatus() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      final status = await NetworkService.getNetworkStatus();
      if (mounted) {
        setState(() {
          _networkStatus = status;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _networkStatus = NetworkStatus(
            isConnected: false,
            canReachApi: false,
            message: 'Error checking network',
          );
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Container(
        padding: AppSpacing.paddingHorizontalMD + AppSpacing.paddingVerticalSM,
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: AppSpacing.borderRadiusSM,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Checking connection...'),
          ],
        ),
      );
    }

    if (_networkStatus == null) return const SizedBox.shrink();

    // Don't show indicator if connected and showWhenConnected is false
    if (_networkStatus!.isFullyConnected && !widget.showWhenConnected) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _checkNetworkStatus,
      child: Container(
        padding: AppSpacing.paddingHorizontalMD + AppSpacing.paddingVerticalSM,
        decoration: BoxDecoration(
          color: _getBackgroundColor().withOpacity(0.1),
          borderRadius: AppSpacing.borderRadiusSM,
          border: Border.all(
            color: _getBackgroundColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIcon(),
              color: _getBackgroundColor(),
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _networkStatus!.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getBackgroundColor(),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.refresh,
              color: _getBackgroundColor().withOpacity(0.7),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_networkStatus!.isFullyConnected) {
      return AppColors.success;
    } else if (_networkStatus!.isConnected) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }

  IconData _getIcon() {
    if (_networkStatus!.isFullyConnected) {
      return Icons.wifi;
    } else if (_networkStatus!.isConnected) {
      return Icons.wifi_off;
    } else {
      return Icons.signal_wifi_off;
    }
  }
}
