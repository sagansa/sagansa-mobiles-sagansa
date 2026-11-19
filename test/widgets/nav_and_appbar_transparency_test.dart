import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/providers/theme_provider.dart';
import 'package:sagansa/widgets/glass_app_bar.dart';
import 'package:sagansa/widgets/modern_bottom_nav.dart';

/// Verifikasi floating pill glassmorphism tab bar & glass app bar:
/// 1. Floating capsule bar dengan pill indicator di setiap slot.
/// 2. GlassAppBar & background ModernBottomNav translusen dengan efek blur.
void main() {
  Future<void> pumpShell(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeProvider.darkTheme : ThemeProvider.lightTheme,
        home: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: GlassAppBar(toolbarHeight: 44.0),
          bottomNavigationBar: ModernBottomNav(
            currentIndex: 0,
            onTap: (_) {},
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Alpha dari Container ber-BoxDecoration semi-transparan pertama di
  /// dalam subtree [scope].
  double tintAlphaOf(WidgetTester tester, Finder scope) {
    final finder = find.descendant(
      of: scope,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final box = w.decoration as BoxDecoration?;
        return box?.color != null && box!.color!.a < 1;
      }),
    );
    final container = tester.widget<Container>(finder.first);
    return (container.decoration as BoxDecoration).color!.a;
  }

  Finder pillFinder() => find.descendant(
        of: find.byType(ModernBottomNav),
        matching: find.byType(AnimatedContainer),
      );

  testWidgets('capsule terpilih seragam: ukuran sama dimanapun yang dipilih', (
    tester,
  ) async {
    await pumpShell(tester, dark: false);

    expect(pillFinder(), findsNWidgets(5));

    Size sizeOf(Element e) => (e.findRenderObject() as RenderBox).size;
    final sizes = pillFinder().evaluate().map(sizeOf).toList();

    // Tab aktif (index 0) lebih lebar dibanding tab inaktif (rasio flex 13:10 ~1.3x)
    expect(sizes[0].width, greaterThan(sizes[1].width));
    expect(sizes[0].width / sizes[1].width, closeTo(1.3, 0.05));
    expect(sizes.map((s) => s.height).toSet().single,
        ModernBottomNav.height - 9.0);

    // Bar dibatasi maxWidth 500 di layar lebar
    final barFinder = find.descendant(
      of: find.byType(ModernBottomNav),
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final box = w.decoration as BoxDecoration?;
        return box?.color != null && box!.color!.a < 1;
      }),
    );
    final barBox = barFinder.evaluate().first.findRenderObject() as RenderBox;
    expect(barBox.size.width, closeTo(500, 2));
  });

  testWidgets('GlassAppBar translusen: alpha tint 0.60 light / 0.45 dark', (
    tester,
  ) async {
    await pumpShell(tester, dark: false);
    final alpha = tintAlphaOf(tester, find.byType(BackdropFilter).first);
    expect(alpha, closeTo(0.60, 0.01));

    await pumpShell(tester, dark: true);
    final alphaDark = tintAlphaOf(tester, find.byType(BackdropFilter).first);
    expect(alphaDark, closeTo(0.45, 0.01));
  });

  testWidgets('background ModernBottomNav sangat translusen (0.55/0.38)', (
    tester,
  ) async {
    await pumpShell(tester, dark: false);
    expect(tintAlphaOf(tester, find.byType(ModernBottomNav)), closeTo(0.55, 0.01));

    await pumpShell(tester, dark: true);
    expect(tintAlphaOf(tester, find.byType(ModernBottomNav)), closeTo(0.38, 0.01));
  });
}
