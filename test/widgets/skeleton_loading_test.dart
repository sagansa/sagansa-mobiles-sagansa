import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/skeleton_loading.dart';
import 'package:sagansa/providers/theme_provider.dart';

void main() {
  group('SkeletonLoading Widget Tests', () {
    testWidgets('should render basic skeleton loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonLoading(
              width: 100,
              height: 20,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoading), findsOneWidget);
    });

    testWidgets('should render skeleton text with multiple lines',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonText(
              lines: 3,
              height: 16,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonText), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsNWidgets(3));
    });

    testWidgets('should render skeleton avatar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonAvatar(size: 50),
          ),
        ),
      );

      expect(find.byType(SkeletonAvatar), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsOneWidget);
    });

    testWidgets('should render skeleton card', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonCard(
              width: 200,
              height: 150,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsWidgets);
      expect(find.byType(SkeletonText), findsWidgets);
      expect(find.byType(SkeletonAvatar), findsOneWidget);
    });

    testWidgets('should render skeleton list item',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonListItem(
              hasAvatar: true,
              hasTrailing: true,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonListItem), findsOneWidget);
      expect(find.byType(SkeletonAvatar), findsOneWidget);
      expect(find.byType(SkeletonText), findsWidgets);
      expect(find.byType(SkeletonLoading), findsWidgets);
    });

    testWidgets('should render skeleton list item without avatar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonListItem(
              hasAvatar: false,
              hasTrailing: false,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonListItem), findsOneWidget);
      expect(find.byType(SkeletonAvatar), findsNothing);
      expect(find.byType(SkeletonText), findsWidgets);
    });

    testWidgets('should render skeleton grid item',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonGridItem(aspectRatio: 1.5),
          ),
        ),
      );

      expect(find.byType(SkeletonGridItem), findsOneWidget);
      expect(find.byType(AspectRatio), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsWidgets);
      expect(find.byType(SkeletonText), findsWidgets);
    });

    testWidgets('should render skeleton app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            appBar: SkeletonAppBar(
              hasBackButton: true,
              hasActions: true,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonAppBar), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsWidgets);
      expect(find.byType(SkeletonText), findsOneWidget);
    });

    testWidgets('should render skeleton bottom nav',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('Content')),
            bottomNavigationBar: SkeletonBottomNav(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(SkeletonBottomNav), findsOneWidget);
      expect(
          find.byType(SkeletonLoading),
          findsNWidgets(
              8)); // 4 icons + 4 labels (SkeletonText creates SkeletonLoading internally)
      expect(find.byType(SkeletonText), findsNWidgets(4)); // 4 labels
    });

    testWidgets('should animate skeleton loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: const Scaffold(
            body: SkeletonLoading(
              width: 100,
              height: 20,
            ),
          ),
        ),
      );

      // Initial state
      expect(find.byType(SkeletonLoading), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SkeletonLoading), findsOneWidget);

      // Continue animation
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(SkeletonLoading), findsOneWidget);
    });
  });
}
