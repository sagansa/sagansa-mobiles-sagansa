import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/email_action_row.dart';

void main() {
  testWidgets('tap email membuka mailto', (tester) async {
    Uri? launched;
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(
        body: Center(child: EmailActionRow(email: 'budi@contoh.com')),
      ),
    ));
    // Override launcher setelah pump — halaman produksi menyuntikkannya;
    // di sini gunakan default null (url_launcher asli) di-replace via
    // rebuild dengan launcher.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: EmailActionRow(
            email: 'budi@contoh.com',
            launchUrlImpl: (uri) async => launched = uri,
          ),
        ),
      ),
    ));

    await tester.tap(find.text('budi@contoh.com'));
    await tester.pumpAndSettle();

    expect(launched.toString(), 'mailto:budi@contoh.com');
  });

  testWidgets('tap ikon copy menyalin email + snackbar', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: EmailActionRow(email: 'budi@contoh.com')),
      ),
    ));

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();

    expect(clipboard, 'budi@contoh.com');
    expect(find.text('Email disalin'), findsOneWidget);
  });
}
