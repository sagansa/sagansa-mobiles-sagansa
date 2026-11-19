import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/providers/theme_provider.dart';
import 'package:sagansa/theme/app_button_style.dart';
import 'package:sagansa/theme/app_colors.dart';

/// Regression test: tombol "Tambah" (TextButton + AppButtonStyle.text) harus
/// terlihat di dark mode — warna foreground mengikuti tema per-mode, bukan
/// konstanta light-mode (AppColors.primary #262626 yang nyaris hitam).
void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Tambah'),
              style: AppButtonStyle.text(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? renderedTextColor(WidgetTester tester) {
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.text('Tambah'),
        matching: find.byType(RichText),
      ),
    );
    return richText.text.style?.color;
  }

  testWidgets('dark mode: foreground memakai warna tema dark (terlihat)', (
    tester,
  ) async {
    await pumpButton(tester, theme: ThemeProvider.darkTheme);
    expect(renderedTextColor(tester), AppColors.darkPrimary);
  });

  testWidgets('light mode: foreground tetap AppColors.primary (tidak berubah)', (
    tester,
  ) async {
    await pumpButton(tester, theme: ThemeProvider.lightTheme);
    expect(renderedTextColor(tester), AppColors.primary);
  });
}
