import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/supplier_picker_modal.dart';

void main() {
  group('SupplierPickerModal blacklist filter', () {
    final suppliers = [
      {'id': 1, 'name': 'PT Sumber Pangan', 'address': 'Jakarta', 'status': 1},
      {'id': 2, 'name': 'CV Berkah Jaya', 'address': 'Bandung', 'status': 2},
      {'id': 3, 'name': 'UD Terlarang', 'address': 'Surabaya', 'status': 3},
    ];

    Future<void> pumpModal(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupplierPickerModal(
              suppliers: suppliers,
              selectedSupplierId: null,
            ),
          ),
        ),
      );
    }

    testWidgets('menyembunyikan supplier Blacklist dari daftar',
        (tester) async {
      await pumpModal(tester);

      expect(find.text('2 supplier tersedia'), findsOneWidget);
      expect(find.text('PT Sumber Pangan'), findsOneWidget);
      expect(find.text('CV Berkah Jaya'), findsOneWidget);
      expect(find.text('UD Terlarang'), findsNothing);
    });

    testWidgets('pencarian tetap memfilter tanpa blacklist',
        (tester) async {
      await pumpModal(tester);

      // Cari nama supplier blacklist — tidak boleh muncul sebagai item
      // daftar (teks hanya boleh ada di kolom pencarian).
      await tester.enterText(find.byType(TextField), 'UD Terlarang');
      await tester.pump();

      expect(find.text('0 supplier tersedia'), findsOneWidget);
      expect(find.text('Supplier tidak ditemukan'), findsOneWidget);
      expect(find.text('UD Terlarang', skipOffstage: false),
          findsOneWidget); // hanya di TextField
    });
  });
}
