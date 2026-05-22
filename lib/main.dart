import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/login_page.dart';
import '../pages/home_page.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/themes.dart';

// Custom error widget to show instead of the default red screen
class CustomErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const CustomErrorWidget({
    super.key,
    required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Terjadi kesalahan pada aplikasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      errorDetails.toString(),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Restart app
                  SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                },
                child: const Text('Tutup Aplikasi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorBoundaryWidget extends StatefulWidget {
  final Widget child;

  const ErrorBoundaryWidget({super.key, required this.child});

  @override
  _ErrorBoundaryWidgetState createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget>
    with WidgetsBindingObserver {
  bool hasError = false;
  FlutterErrorDetails? errorDetails;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      developer.log(
        'Flutter Error',
        error: details.exception,
        stackTrace: details.stack,
      );
      setState(() {
        hasError = true;
        errorDetails = details;
      });
    };

    // Handle platform channel errors
    PlatformDispatcher.instance.onError = (error, stack) {
      developer.log(
        'Platform Dispatcher Error',
        error: error,
        stackTrace: stack,
      );
      return true;
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('App lifecycle state changed to: $state');
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return CustomErrorWidget(errorDetails: errorDetails!);
    }
    return widget.child;
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set up global error handling
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return CustomErrorWidget(errorDetails: details);
    };

    // Set orientasi ke portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Cek apakah token tersimpan untuk auto login
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    final String initialRoute = (token != null && token.isNotEmpty) ? '/home' : '/login';

    runApp(ErrorBoundaryWidget(child: MyApp(initialRoute: initialRoute)));
  }, (error, stackTrace) {
    developer.log(
      'Uncaught error',
      error: error,
      stackTrace: stackTrace,
    );
  });
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sagansa',
      theme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        SfGlobalLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id'),
        Locale('en'),
      ],
      locale: const Locale('id'),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}
