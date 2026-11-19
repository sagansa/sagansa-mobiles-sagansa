import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/app_page_scaffold.dart';
import 'package:sagansa/widgets/safe_bottom_bar.dart';

/// Keyboard vs bar aksi: Scaffold menempel bottomNavigationBar di dasar
/// layar — tanpa padding viewInsets, tombol simpan tertutup keyboard dan
/// pengguna tidak bisa submit (laporan lapangan pada form impor).
void main() {
  testWidgets('keyboard terbuka: bar aksi naik di atas keyboard',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppPageScaffold(
        titleText: 'Form',
        bodyPadding: const EdgeInsets.all(16),
        body: const TextField(),
        bottomAction: FilledButton(
          onPressed: () {},
          child: const Text('Simpan'),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Keyboard tertutup: bar menempel di dasar layar (permukaan uji
    // default 800×600, tanpa inset sistem di desktop test).
    var bar = tester.getRect(find.byType(SafeBottomBar));
    expect(bar.bottom, closeTo(600, 0.5));

    // Buka keyboard setinggi 300 logical px.
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Bar aksi (dan tombol simpan di dalamnya) berada DI ATAS keyboard.
    bar = tester.getRect(find.byType(SafeBottomBar));
    expect(bar.bottom, closeTo(600 - 300, 1));
    expect(tester.getRect(find.text('Simpan')).bottom, lessThan(300));
    expect(tester.takeException(), isNull);
  });
}
