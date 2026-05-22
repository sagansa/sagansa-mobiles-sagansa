import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/widgets/modern_text_field.dart';
import 'package:sagansa/providers/theme_provider.dart';

void main() {
  group('ModernTextField Widget Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('should render text field with label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Test Label',
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should render text field with prefix icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Email',
              controller: controller,
              prefixIcon: Icons.email,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('should render text field with suffix icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Password',
              controller: controller,
              suffixIcon: const Icon(Icons.visibility),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('should handle text input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Input Test',
              controller: controller,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello World');
      expect(controller.text, equals('Hello World'));
    });

    testWidgets('should show error text when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Error Test',
              controller: controller,
              errorText: 'This field is required',
            ),
          ),
        ),
      );

      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('should show helper text when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Helper Test',
              controller: controller,
              helperText: 'Enter your email address',
            ),
          ),
        ),
      );

      expect(find.text('Enter your email address'), findsOneWidget);
    });

    testWidgets('should be disabled when enabled is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Disabled Field',
              controller: controller,
              enabled: false,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('should handle obscure text for passwords',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Password',
              controller: controller,
              obscureText: true,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('should handle multiline text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'Description',
              controller: controller,
              maxLines: 3,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, equals(3));
    });

    testWidgets('should call onChanged when text changes',
        (WidgetTester tester) async {
      String? changedText;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeProvider.lightTheme,
          home: Scaffold(
            body: ModernTextField(
              labelText: 'OnChanged Test',
              controller: controller,
              onChanged: (value) => changedText = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      expect(changedText, equals('Test'));
    });
  });
}
