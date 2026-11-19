import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';

import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/sales_home_page.dart';
import 'providers/asset_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/fuel_service_payment_provider.dart';
import 'providers/home_dashboard_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/theme_provider.dart';
import 'services/asset_service.dart';
import 'services/auth_service.dart';
import 'services/auth_session.dart';
import 'services/closing_store_service.dart';
import 'services/inventory_anomaly_service.dart';
import 'services/leave_service.dart';
import 'services/location_tracking_service.dart';
import 'services/navigator_service.dart';
import 'services/presence_service.dart';
import 'services/procurement_service.dart';
import 'services/readiness_service.dart';
import 'services/salary_service.dart';
import 'services/sales_dashboard_service.dart';
import 'services/storage_stock_service.dart';
import 'services/token_store.dart';
import 'services/user_service.dart';
import 'theme/app_colors.dart';

// Custom error widget to show instead of the default red screen
class CustomErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const CustomErrorWidget({
    super.key,
    required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    // Widget ini dipakai sebagai `ErrorWidget.builder`, sehingga di-inflate
    // pada posisi widget yang error — BISA JADI tanpa ancestor Directionality,
    // Theme, ataupun MediaQuery (mis. di atas MaterialApp). Semua dependensi
    // harus disediakan sendiri agar error screen tidak ikut crash → layar hitam.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery.fromView(
        view: View.of(context),
        child: Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: Material(
            color: AppColors.darkBackground,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
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
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Restart app
                        SystemChannels.platform
                            .invokeMethod('SystemNavigator.pop');
                      },
                      child: const Text('Tutup Aplikasi'),
                    ),
                  ],
                ),
              ),
            ),
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
  ErrorBoundaryWidgetState createState() => ErrorBoundaryWidgetState();
}

class ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up error handling.
    //
    // PENTING: JANGAN pernah setState() di sini. onError bisa terpanggil
    // DI TENGAH fase build (termasuk untuk error diagnostik non-fatal seperti
    // "ListTile background may be invisible" yang hanya reportError). setState
    // saat itu → "setState() or markNeedsBuild() called during build" berulang
    // (exception storm) → frame gagal total → layar hitam.
    // Ganti tampilan error saat build error adalah tugas ErrorWidget.builder
    // (per-subtree), bukan tugas handler ini (global).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      developer.log(
        'Flutter Error',
        error: details.exception,
        stackTrace: details.stack,
      );
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
    // Safety net: pastikan splash tidak tersisa saat app kembali ke foreground.
    if (state == AppLifecycleState.resumed) {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

void main() {
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // SAFETY NET: jadwalkan penghapusan splash SEBELUM await berisiko,
    // agar splash tidak pernah stuck walau langkah di bawah throw/hang.
    // (Future.delayed berjalan di event loop; walau await di bawah belum
    // selesai, timer ini tetap fire setelah 3 detik.)
    Timer(const Duration(seconds: 3), () {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    });

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return CustomErrorWidget(errorDetails: details);
    };

    // Inisialisasi orientasi dan migrasi token secara paralel untuk optimasi cold boot
    await Future.wait([
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
      TokenStore.instance.migrateFromPrefs(),
    ]);

    // Edge-to-edge: konten digambar di belakang status bar & nav bar Android,
    // sehingga nav bar sistem otomatis mengikuti warna background aplikasi.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final String? token = await TokenStore.instance.readToken();
    final bool isSalesOnly = token != null &&
        token.isNotEmpty &&
        await AuthService.isSalesOnlyUser();
    final String initialRoute = isSalesOnly
        ? '/sales-home'
        : ((token != null && token.isNotEmpty) ? '/home' : '/login');

    runApp(ErrorBoundaryWidget(child: MyApp(initialRoute: initialRoute)));

    widgetsBinding.addPostFrameCallback((_) {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocationTrackingService.instance.initialize();
      // User sales-only tidak memanggil onLogin — tidak ada fitur lokasi.
      if (token != null && token.isNotEmpty && !isSalesOnly) {
        await LocationTrackingService.instance.onLogin();
      }
    });
  }, (error, stackTrace) {
    developer.log('Uncaught error', error: error, stackTrace: stackTrace);
    // LAST RESORT: bila main() throw sebelum runApp, tetap lepas splash
    // agar user tidak melihat splash selamanya.
    try {
      FlutterNativeSplash.remove();
    } catch (_) {}
  });
}

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();
  final PrinterProvider _printerProvider = PrinterProvider();
  final AuthProvider _authProvider = AuthProvider();
  final FuelServicePaymentProvider _fuelServicePaymentProvider =
      FuelServicePaymentProvider();

  /// Key global Navigator agar service layer (AuthSession) bisa navigasi
  /// tanpa BuildContext — dipakai untuk auto-logout saat 401 dan deep-link
  /// notifikasi. Disentralisasi lewat [NavigatorService] (satu instance).
  final GlobalKey<NavigatorState> _navigatorKey = NavigatorService.navigatorKey;

  @override
  void reassemble() {
    super.reassemble();
  }

  @override
  void initState() {
    super.initState();
    _themeProvider.initialize();
    // PrinterProvider melakukan load di constructor, tidak perlu await.
    AuthSession.instance.configure(_navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<PrinterProvider>.value(value: _printerProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<FuelServicePaymentProvider>.value(
            value: _fuelServicePaymentProvider),
        ChangeNotifierProvider<NotificationProvider>.value(
            value: NotificationProvider.instance),
        ChangeNotifierProvider<HomeDashboardProvider>(
          create: (_) => HomeDashboardProvider(
            procurementService: ProcurementService(),
            assetService: AssetService(),
            salesDashboardService: SalesDashboardService(),
            anomalyService: InventoryAnomalyService(),
            storageService: StorageStockService(),
            presenceService: PresenceService(),
            userService: UserService(),
            leaveService: LeaveService(),
            salaryService: SalaryService(),
            readinessService: ReadinessService(),
            closingStoreService: ClosingStoreService(),
          ),
        ),
        // PresenceProvider dipakai oleh PresencePage (check-in & check-out).
        // Harus ada di ancestor widget tree; sebelumnya hilang saat
        // refactoring home_page menghapus controller-based access.
        ChangeNotifierProvider<PresenceProvider>(
          create: (_) => PresenceProvider(),
        ),
        ChangeNotifierProvider<AssetProvider>(
          create: (_) => AssetProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Ambil tema berdasarkan mode. Gunakan tema sistem (biasanya
          // light) sebagai default selama inisialisasi agar tidak ada
          // transisi warna yang mencolok (flash) dari tema gelap lama.
          final isDark = themeProvider.isDarkMode;
          final ThemeData themeData =
              isDark ? ThemeProvider.darkTheme : ThemeProvider.lightTheme;
          final overlayStyle = SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            // Nav bar transparan + tanpa scrim kontras otomatis agar
            // background aplikasi terlihat sampai ke tepi bawah layar
            // (mengikuti warna background apps, lihat SystemUiMode.edgeToEdge
            // di main()).
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          );

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: MaterialApp(
              navigatorKey: NavigatorService.navigatorKey,
              title: 'Sagansa',
              theme: themeData,
              darkTheme: ThemeProvider.darkTheme,
              themeMode: themeProvider.themeMode,
              initialRoute: widget.initialRoute,
              routes: {
                '/login': (context) => const LoginPage(),
                '/home': (context) => const HomePage(),
                '/sales-home': (context) => const SalesHomePage(),
              },
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                SfGlobalLocalizations.delegate,
                // Modul surat (task 20): toolbar/editor flutter_quill butuh
                // delegate ini, tanpanya QuillToolbar melempar exception.
                ...FlutterQuillLocalizations.localizationsDelegates,
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
            ),
          );
        },
      ),
    );
  }
}
