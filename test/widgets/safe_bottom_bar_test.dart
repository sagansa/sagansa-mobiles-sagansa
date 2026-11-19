import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/app_page_scaffold.dart';
import 'package:sagansa/widgets/safe_bottom_bar.dart';

/// Regresi dua masalah historis bar aksi bawah:
/// 1. "Padding terlalu tinggi" — inset sistem (home indicator / nav bar)
///    terhitung dua kali karena halaman membungkus tombol dengan SafeArea
///    di dalam SafeBottomBar.
/// 2. "Tertimpa nav bar Android" — bar wajib memberi ruang inset sistem.
void main() {
  // 34pt = home indicator iPhone; 48dp = nav bar Android 3-tombol.
  const insets = [34.0, 48.0];

  Future<void> pumpWithBottomInset(
    WidgetTester tester, {
    required double inset,
    required Widget home,
  }) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = FakeViewPadding(bottom: inset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  group('SafeBottomBar', () {
    for (final inset in insets) {
      testWidgets(
          'inset ${inset.toInt()}: tombol bebas dari nav bar & inset dihitung sekali',
          (tester) async {
        await pumpWithBottomInset(
          tester,
          inset: inset,
          home: Scaffold(
            bottomNavigationBar: SafeBottomBar(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Simpan'),
              ),
            ),
          ),
        );

        final button = tester.getRect(find.byType(FilledButton));
        final gapBelow = 900 - button.bottom;
        // Padding bar 12 + inset sistem SEKALI — tidak lebih (bukan 2× inset).
        expect(gapBelow, moreOrLessEquals(12 + inset, epsilon: 0.5));
      });

      testWidgets(
          'inset ${inset.toInt()}: SafeArea bersarang (pola lama) tidak menambah inset kedua',
          (tester) async {
        await pumpWithBottomInset(
          tester,
          inset: inset,
          home: Scaffold(
            bottomNavigationBar: SafeBottomBar(
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Simpan'),
                ),
              ),
            ),
          ),
        );

        final button = tester.getRect(find.byType(FilledButton));
        final gapBelow = 900 - button.bottom;
        // Minimum SafeArea (16) dihormati, tetapi inset sistem tetap sekali:
        // 12 (bar) + 16 (minimum SafeArea) + inset.
        expect(gapBelow, moreOrLessEquals(12 + 16 + inset, epsilon: 0.5));
      });
    }
  });

  group('AppPageScaffold.bottomAction', () {
    testWidgets('tombol mentah: tanpa SafeArea, inset sekali, tidak tertimpa',
        (tester) async {
      await pumpWithBottomInset(
        tester,
        inset: 34,
        home: AppPageScaffold(
          titleText: 'Tes',
          body: const SizedBox.expand(),
          bottomAction: FilledButton(
            onPressed: () {},
            child: const Text('Simpan'),
          ),
        ),
      );

      // Kontrak baru: halaman tidak lagi membungkus SafeArea sendiri.
      expect(
        find.ancestor(
          of: find.byType(FilledButton),
          matching: find.byType(SafeArea),
        ),
        findsNothing,
      );

      final button = tester.getRect(find.byType(FilledButton));
      final gapBelow = 900 - button.bottom;
      expect(gapBelow, moreOrLessEquals(12 + 34, epsilon: 0.5));

      // Tinggi total bar wajar: border 1px + 12 atas + tombol + 12 bawah +
      // inset — tidak ada lapisan ekstra dari pola lama (dulu ~+50px).
      final bar = tester.getRect(find.byType(SafeBottomBar));
      expect(bar.height, lessThan(12 + button.height + 12 + 34 + 1.5));
    });
  });
}
