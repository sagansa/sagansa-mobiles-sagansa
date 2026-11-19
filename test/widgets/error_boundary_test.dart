import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/main.dart';

/// Child yang meniru error diagnostik non-fatal ala ListTile
/// (`FlutterError.reportError` dipanggil DI TENGAH fase build).
class _DiagnosticReporter extends StatelessWidget {
  const _DiagnosticReporter();

  @override
  Widget build(BuildContext context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError('diagnostik: background ListTile invisible'),
        library: 'test',
        context: ErrorDescription('saat build'),
      ),
    );
    return const Text('child-ok');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorBoundaryWidget (main.dart)', () {
    testWidgets(
      'tidak melakukan setState saat menerima error diagnostik di tengah build (anti rebuild-storm)',
      (tester) async {
        await tester.pumpWidget(
          // Pump di root tanpa Directionality — sama seperti posisi
          // ErrorBoundaryWidget di atas MaterialApp di main().
          Directionality(
            textDirection: TextDirection.ltr,
            child: ErrorBoundaryWidget(child: const _DiagnosticReporter()),
          ),
        );

        // Sebelum fix: reportError -> onError -> setState during build
        // melempar exception dan mengganti seluruh app dengan CustomErrorWidget.
        expect(tester.takeException(), isNull);
        expect(find.text('child-ok'), findsOneWidget);
      },
    );
  });

  group('CustomErrorWidget sebagai ErrorWidget.builder', () {
    testWidgets(
      'tetap bisa render tanpa ancestor Directionality/Localizations/MaterialApp',
      (tester) async {
        // ErrorWidget.builder di-inflate pada posisi widget yang error,
        // yang bisa saja TANPA Directionality (mis. subtree di atas MaterialApp).
        await tester.pumpWidget(
          CustomErrorWidget(
            errorDetails: FlutterErrorDetails(exception: Exception('boom')),
          ),
        );

        expect(
          find.text('Terjadi kesalahan pada aplikasi'),
          findsOneWidget,
        );
      },
    );
  });
}
