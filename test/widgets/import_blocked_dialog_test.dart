import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/import_model.dart';
import 'package:sagansa/widgets/import_blocked_dialog.dart';

void main() {
  testWidgets('merender daftar blocker + tombol bypass dokumen',
      (tester) async {
    var bypassed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                bypassed = await showImportBlockedDialog(
                  context,
                  title: 'Syarat Tahap Pengiriman Belum Terpenuhi',
                  blockers: const [
                    ImportBlocker(
                      kind: 'document',
                      message: 'Dokumen wajib belum diupload: Invoice',
                    ),
                    ImportBlocker(
                      kind: 'document',
                      message: 'Dokumen wajib belum diupload: Bukti Pembayaran',
                    ),
                  ],
                  allowBypass: true,
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Syarat Tahap Pengiriman Belum Terpenuhi'), findsOneWidget);
    expect(find.textContaining('Invoice'), findsOneWidget);
    expect(find.textContaining('Bukti Pembayaran'), findsOneWidget);
    expect(find.text('Lanjut Tanpa Dokumen'), findsOneWidget);

    await tester.tap(find.text('Lanjut Tanpa Dokumen'));
    await tester.pumpAndSettle();
    expect(bypassed, isTrue);
  });

  testWidgets('blocker data → tanpa tombol bypass, Tutup mengembalikan false',
      (tester) async {
    var result = true;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                result = await showImportBlockedDialog(
                  context,
                  title: 'Finalisasi Belum Dapat Dilakukan',
                  blockers: const [
                    ImportBlocker(
                      kind: 'data',
                      message:
                          '2 item belum mengisi jumlah diterima (quantity_received).',
                    ),
                  ],
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Lanjut Tanpa Dokumen'), findsNothing);
    expect(find.textContaining('2 item belum'), findsOneWidget);

    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
