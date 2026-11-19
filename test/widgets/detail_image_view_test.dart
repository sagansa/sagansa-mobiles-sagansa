import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/theme/app_spacing.dart';
import 'package:sagansa/widgets/detail/detail_image_view.dart';

void main() {
  /// Halaman pembungkus supaya DetailImageView (yang butuh arah teks & tema)
  /// di-build dalam konteks MaterialApp seperti di halaman detail aslinya.
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('menampilkan hint standar "Ketuk untuk memperbesar gambar"',
      (tester) async {
    await tester.pumpWidget(wrap(const DetailImageView(
      imageUrl: 'https://example.com/photo.jpg',
    )));
    await tester.pumpAndSettle();

    expect(
      find.text('Ketuk untuk memperbesar gambar'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);
  });

  testWidgets('image terbungkus ClipRRect (sudut melengkung standar)',
      (tester) async {
    await tester.pumpWidget(wrap(const DetailImageView(
      imageUrl: 'https://example.com/photo.jpg',
    )));
    await tester.pumpAndSettle();

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
    expect(clip.borderRadius, AppSpacing.borderRadiusMD);
  });

  testWidgets('tap image membuka preview full-screen', (tester) async {
    await tester.pumpWidget(wrap(const DetailImageView(
      imageUrl: 'https://example.com/photo.jpg',
      previewTitle: 'Foto Bukti',
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DetailImageView));
    await tester.pumpAndSettle();

    expect(find.text('Foto Bukti'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('mode aspectRatio tidak melempar constraint invalid',
      (tester) async {
    // Regresi: Stack dulu memakai StackFit.expand sehingga saat parent
    // memberi tinggi tak terbatas (scroll view) constraint jadi infinite.
    await tester.pumpWidget(wrap(
      SingleChildScrollView(
        child: DetailImageView(
          imageUrl: 'https://example.com/photo.jpg',
          aspectRatio: 16 / 9,
          height: null,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('mode intrinsik (height null) di scroll view tidak error',
      (tester) async {
    await tester.pumpWidget(wrap(
      ListView(
        children: const [
          DetailImageView(
            imageUrl: 'https://example.com/photo.jpg',
            height: null,
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ketuk untuk memperbesar gambar'), findsOneWidget);
  });
}
