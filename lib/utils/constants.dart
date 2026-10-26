class ApiConstants {
  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'https://api.sagansa.id');
  // static const String baseUrl = String.fromEnvironment('API_URL',
  //     defaultValue: 'http://192.168.0.142:8001'); // wi-fi ip fxor physical android device
  // static const String baseUrl = String.fromEnvironment('API_URL',
  //     defaultValue: 'http://127.0.0.1:8001'); // local api service

  // Auth Endpoints
  static const String login = '$baseUrl/login';
  static const String logout = '$baseUrl/logout';

  // General Endpoints
  static const String appVersion = '$baseUrl/app-version';

  // Profile Endpoints (data pribadi + rekening, DB recruitment)
  static const String profile = '$baseUrl/profile';
  static const String adminProfiles = '$baseUrl/admin/profile';

  // Fallback URL (used for connectivity retries; defaults to same domain)
  static const String fallbackBaseUrl = String.fromEnvironment(
    'FALLBACK_API_URL',
    defaultValue: baseUrl,
  );

  // Document (surat) service — host terpisah dari API utama, memakai
  // bearer token Sanctum yang sama. Override lokal via
  // --dart-define DOCUMENT_BASE_URL=http://127.0.0.1:8002 (pola imgBaseUrl
  // di image_service.dart).
  static const String documentBaseUrl = String.fromEnvironment(
    'DOCUMENT_BASE_URL',
    defaultValue: 'https://document.sagansa.id',
  );

  // Calendar Endpoint
  static const String calendar = '$baseUrl/calendar';

  // Presence Endpoints
  static const String userPresence = '$baseUrl/user-presence';
  static const String leaves = '$baseUrl/leaves';
  static const String adminLeaves = '$baseUrl/admin/leaves';
  static const String salaries = '$baseUrl/salaries';
  static const String checkIn = '$baseUrl/check-in';
  static const String checkOut = '$baseUrl/check-out';
  static const String todayPresenceEndpoint = '$baseUrl/presences/today';
  static const String historyPresenceEndpoint = '$baseUrl/presences/history';
  // Admin manual presence management (CRUD).
  static const String adminPresences = '$baseUrl/admin/presences';

  // Store Endpoints
  static const String stores = '$baseUrl/stores';
  static const String shiftStores = '$baseUrl/shift-stores';

  // Employee Location Tracking Endpoints
  static const String locationPing = '$baseUrl/location';
  static const String deviceTokens = '$baseUrl/device-tokens';

  // Sales Order Delivery Endpoints
  static const String searchSalesOrder = '$baseUrl/sales-orders/search';
  static const String readyToShip = '$baseUrl/sales-orders/ready-to-ship';
  static const String markPaymentProofsPrinted =
      '$baseUrl/sales-orders/payment-proofs/printed';
  static const String updateDeliveryStatus =
      '$baseUrl/sales-orders/delivery-update';

  // Sales Order Online - Create (admin)
  static const String onlineShopProviders =
      '$baseUrl/sales-orders/online-shop-providers';
  static const String deliveryServices =
      '$baseUrl/sales-orders/delivery-services';
  static const String onlineProducts = '$baseUrl/sales-orders/online-products';
  static const String createSalesOrderOnline =
      '$baseUrl/sales-orders/online';

  // Sales Order Employee (for=2) — penjualan oleh sales.
  static const String salesOrderEmployee = '$baseUrl/sales-orders/employee';

  // Inventory Anomaly Comparison (admin)
  static const String compareInventoryAnomaly =
      '$baseUrl/inventory-anomalies/compare';

  // Sales Dashboard (admin)
  static const String salesDashboard = '$baseUrl/sales-dashboard';

  // Production & Recipes (admin only)
  static const String recipes = '$baseUrl/recipes';
  static const String productions = '$baseUrl/productions';

  // Daily Salary Endpoints
  static const String dailySalaries = '$baseUrl/daily-salaries';

  // Payment Receipt Endpoints
  static const String paymentReceipts = '$baseUrl/procurement/payment-receipts';

  // Asset Management Endpoints (kategorisasi produk + pemeriksaan berkala).
  static const String assetCategories = '$baseUrl/asset-categories';
  static const String assets = '$baseUrl/assets';
  static const String assetDashboard = '$baseUrl/assets/dashboard';
  static const String assetCurrentStore = '$baseUrl/assets/current-store';
  static const String assetFromProduct = '$baseUrl/assets/from-product';
  static const String assetProducts = '$baseUrl/asset-products';
  static const String assetChecks = '$baseUrl/asset-checks';
  static const String assetIssues = '$baseUrl/asset-issues';

  // Hygiene Endpoints
  static const String hygieneRooms = '$baseUrl/hygiene/rooms';
  static const String hygieneTodayStatus = '$baseUrl/hygiene/today-status';
  static const String hygiene = '$baseUrl/hygiene';
  static const String hygieneOfRoom = '$baseUrl/hygiene/of-rooms';
  static const String hygieneRoomUpdate = '$baseUrl/hygiene/of-rooms';

  static Map<String, String> headers(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String get closingStoreUrl {
    return resolveClosingStoreUrl(baseUrl);
  }

  /// Resolusi URL admin panel closing store dari [apiBaseUrl] yang diberikan.
  ///
  /// Aturan (regression-safe terhadap implementasi lama):
  /// - Host yang diawali `api.` → diganti jadi `www.` (production-like).
  /// - Localhost / 127.0.0.1 / 192.168.x.x → port admin web 8000.
  /// - HTTPS production (port 443 atau tidak ada port) → tidak menampilkan port.
  ///
  /// Dipisah sebagai method pure-function agar bisa di-unit-test (karena
  /// [baseUrl] adalah `const`, tidak bisa di-override di runtime).
  static String resolveClosingStoreUrl(String apiBaseUrl) {
    final api = Uri.parse(apiBaseUrl);
    final adminHost = _resolveAdminHost(api.host);
    final adminPort = _resolveAdminPort(api);
    final adminScheme = adminHost == api.host ? api.scheme : 'https';

    final admin = api.replace(
      scheme: adminScheme,
      host: adminHost,
      port: adminPort,
      path: '/admin/transaction/closings/panel/closing-stores',
      queryParameters: {},
      fragment: '',
    );

    // Hilangkan port eksplisit untuk HTTPS 443 / HTTP 80.
    final portPart = (admin.scheme == 'https' && admin.port == 443) ||
            (admin.scheme == 'http' && admin.port == 80)
        ? ''
        : ':${admin.port}';

    return '${admin.scheme}://${admin.host}$portPart${admin.path}';
  }

  static String _resolveAdminHost(String apiHost) {
    if (apiHost.startsWith('api.')) {
      return 'www.${apiHost.substring(4)}';
    }
    return apiHost;
  }

  static int _resolveAdminPort(Uri api) {
    // Lokal dev: admin web jalan di port 8000.
    if (api.host == '127.0.0.1' || api.host == 'localhost') return 8000;
    if (api.host.startsWith('192.168.')) return 8000;
    // Production HTTPS standar.
    return api.port == 0 ? 443 : api.port;
  }
}

class AppConstants {
  // Shared Preferences Keys
  static const String tokenKey = 'token';
  static const String loginDataKey = 'loginData';

  // Status Codes
  static const int statusSuccess = 200;
  static const int statusUnauthorized = 401;

  // Leave Status
  static const int leaveStatusPending = 1;
  static const int leaveStatusApproved = 2;
  static const int leaveStatusRejected = 3;

  // Leave Status Text Colors
  static const Map<int, String> leaveStatusColors = {
    1: '#FFA500', // Orange untuk pending
    2: '#4CAF50', // Green untuk approved
    3: '#F44336', // Red untuk rejected
  };
}

/// Konfigurasi printer thermal untuk cetak resi berbentuk stiker.
///
/// Printer dihubungkan melalui jaringan WiFi (TCP/IP). Umumnya thermal printer
/// ESC/POS network membuka port **9100**. Sesuaikan `defaultIp` & `defaultPort`
/// dengan konfigurasi printer yang dipasang.
class PrinterConstants {
  // Shared Preferences Keys untuk printer thermal
  static const String thermalEnabledKey = 'thermal_printer_enabled';
  static const String thermalWidthMmKey = 'thermal_printer_width_mm';
  static const String thermalHeightMmKey = 'thermal_printer_height_mm';
  static const String thermalIpKey = 'thermal_printer_ip';
  static const String thermalPortKey = 'thermal_printer_port';
  static const String thermalNameKey = 'thermal_printer_name';
  static const String thermalCopiesKey = 'thermal_printer_copies';
  static const String thermalFontSizeKey = 'thermal_printer_font_size';

  // Dimensi default stiker (10 cm x 15 cm -> 100mm x 150mm)
  // Catatan: ukuran ini akan dikonfirmasi/disesuaikan dengan hardware fisik.
  static const double defaultWidthMm = 100.0;
  static const double defaultHeightMm = 150.0;

  // Batasan dimensi stiker (mm) untuk mencegah konfigurasi tidak masuk akal.
  static const double minWidthMm = 30.0;
  static const double maxWidthMm = 200.0;
  static const double minHeightMm = 30.0;
  static const double maxHeightMm = 300.0;

  // Konfigurasi jaringan default thermal printer (ESC/POS over TCP).
  static const String defaultIp = '192.168.1.100';
  static const int defaultPort = 9100;

  // Default jumlah rangkap cetak
  static const int defaultCopies = 1;
  static const int minCopies = 1;
  static const int maxCopies = 5;

  // Default ukuran font pada stiker (point)
  static const double defaultFontSize = 10.0;
  static const double minFontSize = 6.0;
  static const double maxFontSize = 18.0;

  // Timeout koneksi & tulis socket (ms)
  static const int connectTimeoutMs = 5000;
  static const int writeTimeoutMs = 5000;
}
