import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/modern_bottom_nav.dart';

/// Verifikasi floating pill glassmorphism tab bar:
/// - Berbentuk pill kapsul melayang (ClipRRect radius 33).
/// - Android: bar melayang DI ATAS navigation bar (bottomInset + 8).
/// - iOS: bar melayang 20pt dari dasar layar di atas home indicator.
/// - Tanpa inset: bar melayang 12pt dari dasar layar.
/// - Menampilkan 5 tab dengan indicator pill capsule dan callback onTap.
void main() {
  Future<void> pumpNav(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.iOS,
    int currentIndex = 0,
    ValueChanged<int>? onTap,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        extendBody: true,
        bottomNavigationBar: ModernBottomNav(
          currentIndex: currentIndex,
          onTap: onTap ?? (_) {},
        ),
        body: const SizedBox.expand(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Rect pillRect(WidgetTester tester) {
    return tester.getRect(find
        .descendant(
          of: find.byType(ModernBottomNav),
          matching: find.byType(ClipRRect),
        )
        .first);
  }

  testWidgets('Android dengan nav bar 48dp: bar melayang 8pt di atasnya',
      (tester) async {
    // Layar 360x800 dp (1080x2400 px @ dpr 3); inset sistem 48dp = 144px.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);

    await pumpNav(tester, platform: TargetPlatform.android);

    // Dasar bar harus di 800 - (48 + 8) = 744dp.
    expect(pillRect(tester).bottom, 744.0);
  });

  testWidgets('iOS dengan home indicator 34pt: bar melayang 20pt dari dasar layar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: 102); // 34pt * 3
    addTearDown(tester.view.reset);

    await pumpNav(tester, platform: TargetPlatform.iOS);

    expect(pillRect(tester).bottom, 780.0);
  });

  testWidgets('Tanpa inset sistem: bar melayang 12pt dari dasar layar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewPadding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await pumpNav(tester, platform: TargetPlatform.android);

    expect(pillRect(tester).bottom, 788.0);
  });

  testWidgets('Menampilkan 5 tab dengan icon filled untuk item aktif',
      (tester) async {
    await pumpNav(tester, currentIndex: 0);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('HRD'), findsOneWidget);
    expect(find.text('Stok'), findsOneWidget);
    expect(find.text('Transaksi'), findsOneWidget);
    expect(find.text('Ops'), findsOneWidget);

    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person_2), findsOneWidget);
  });

  testWidgets('Tap pada tab memanggil onTap callback', (tester) async {
    int? tappedIndex;
    await pumpNav(
      tester,
      currentIndex: 0,
      onTap: (index) => tappedIndex = index,
    );

    await tester.tap(find.text('Transaksi'));
    expect(tappedIndex, 3);
  });
}
