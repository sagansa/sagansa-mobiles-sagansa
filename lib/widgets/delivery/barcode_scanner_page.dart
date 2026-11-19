import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../bar_button_cluster.dart';
import '../glass_app_bar.dart';


class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController? _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      _hasScanned = true;
      Navigator.pop(context, barcode.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Scan Resi / Barcode / QR'),
        foregroundColor: Colors.white,
        opacity: 0.4,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller!,
            builder: (context, state, child) {
              return BarButtonCluster(
                actions: [
                  BarButtonSpec(
                    icon: state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                    tooltip: 'Senter',
                    onTap: () => _controller!.toggleTorch(),
                  ),
                ],
              );
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 280,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.surface, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke QR code atau Barcode resi',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.surface.withValues(alpha: 0.8),
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
