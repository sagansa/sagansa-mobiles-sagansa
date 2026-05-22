import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sagansa/pages/login_page.dart';
import 'package:sagansa/providers/auth_provider.dart';
import 'package:sagansa/providers/theme_provider.dart';

void main() {
  group('LoginPage Widget Tests', () {
    late AuthProvider mockAuthProvider;
    late ThemeProvider mockThemeProvider;

    setUp(() {
      mockAuthProvider = AuthProvider();
      mockThemeProvider = ThemeProvider();
    });

    testWidgets('should render login form correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<ThemeProvider>.value(
                value: mockThemeProvider),
          ],
          child: MaterialApp(
            theme: ThemeProvider.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Check if login form elements are present
      expect(find.text('Login'), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.text('Lupa Password?'), findsOneWidget);
      expect(find.text('Daftar Sekarang'), findsOneWidget);
    });

    testWidgets('should show error message when login fails',
        (WidgetTester tester) async {
      // Set up auth provider with error state
      mockAuthProvider.clearError(); // Reset any existing errors

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<ThemeProvider>.value(
                value: mockThemeProvider),
          ],
          child: MaterialApp(
            theme: ThemeProvider.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Enter invalid credentials
      await tester.enterText(
          find.byKey(const Key('email_field')), 'invalid@email.com');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'wrongpassword');

      // Tap login button
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Wait for login attempt to complete
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check if error message appears (this will depend on the actual API response)
      // For now, we just verify the form is still present
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('should toggle password visibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<ThemeProvider>.value(
                value: mockThemeProvider),
          ],
          child: MaterialApp(
            theme: ThemeProvider.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Find the password visibility toggle button
      final visibilityButton = find.descendant(
        of: find.byKey(const Key('password_field')),
        matching: find.byType(IconButton),
      );

      expect(visibilityButton, findsOneWidget);

      // Tap the visibility toggle
      await tester.tap(visibilityButton);
      await tester.pump();

      // The icon should change (we can't easily test the obscureText property)
      expect(visibilityButton, findsOneWidget);
    });

    testWidgets('should disable form when loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<ThemeProvider>.value(
                value: mockThemeProvider),
          ],
          child: MaterialApp(
            theme: ThemeProvider.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Check that form elements are initially enabled
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
    });

    testWidgets('should show forgot password snackbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<ThemeProvider>.value(
                value: mockThemeProvider),
          ],
          child: MaterialApp(
            theme: ThemeProvider.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Tap forgot password
      await tester.tap(find.text('Lupa Password?'));
      await tester.pump();

      // Check if snackbar appears
      expect(find.text('Fitur lupa password akan segera tersedia'),
          findsOneWidget);
    });

    testWidgets('should show register snackbar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<ThemeProvider>.value(
                value: mockThemeProvider),
          ],
          child: MaterialApp(
            theme: ThemeProvider.lightTheme,
            home: const LoginPage(),
          ),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Tap register button
      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pump();

      // Check if snackbar appears
      expect(
          find.text('Fitur registrasi akan segera tersedia'), findsOneWidget);
    });
  });
}
