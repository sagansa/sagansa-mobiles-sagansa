import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/delivery/delivery_actions.dart';

void main() {
  group('CancelOrderButton', () {
    testWidgets('menampilkan label dan memanggil onCancel saat ditekan',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CancelOrderButton(onCancel: () => tapped = true),
        ),
      ));

      expect(find.text('Batalkan Order'), findsOneWidget);
      await tester.tap(find.byType(CancelOrderButton));
      expect(tapped, isTrue);
    });
  });

  group('CancelOrderDialog', () {
    testWidgets('alasan default terisi dan confirm mengirim alasan hasil trim',
        (tester) async {
      String? confirmedReason;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CancelOrderDialog(
            onConfirm: (reason) => confirmedReason = reason,
          ),
        ),
      ));

      expect(find.text('Dibatalkan oleh pembeli'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Pembeli batal  ');
      await tester.pump();
      await tester.tap(find.text('Ya, Batalkan'));
      await tester.pump();

      expect(confirmedReason, 'Pembeli batal');
    });

    testWidgets('confirm disabled saat alasan dihapus kosong', (tester) async {
      String? confirmedReason;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CancelOrderDialog(
            onConfirm: (reason) => confirmedReason = reason,
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final confirmButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Ya, Batalkan'),
      );
      expect(confirmButton.onPressed, isNull);
      expect(confirmedReason, isNull);
    });
  });
}
