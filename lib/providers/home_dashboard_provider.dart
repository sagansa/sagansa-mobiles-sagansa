import 'package:flutter/foundation.dart';
import '../models/presence_model.dart';
import '../models/sales_dashboard_model.dart';
import '../services/asset_service.dart';
import '../services/closing_store_service.dart';
import '../services/inventory_anomaly_service.dart';
import '../services/leave_service.dart';
import '../services/presence_service.dart';
import '../services/procurement_service.dart';
import '../services/readiness_service.dart';
import '../services/salary_service.dart';
import '../services/sales_dashboard_service.dart';
import '../services/storage_stock_service.dart';
import '../services/user_service.dart';
import '../utils/constants.dart';

// === State value objects (immutable per-group) ===

@immutable
class HomeProcurementState {
  final int pendingCount;
  final int approvedCount;
  final int invoiceDraftCount;
  final int invoiceDoneCount;
  final int unpaidInvoicesCount;
  final int unpaidTransferInvoicesCount;
  final bool isLoading;

  const HomeProcurementState({
    this.pendingCount = 0,
    this.approvedCount = 0,
    this.invoiceDraftCount = 0,
    this.invoiceDoneCount = 0,
    this.unpaidInvoicesCount = 0,
    this.unpaidTransferInvoicesCount = 0,
    this.isLoading = false,
  });

  HomeProcurementState copyWith({
    int? pendingCount,
    int? approvedCount,
    int? invoiceDraftCount,
    int? invoiceDoneCount,
    int? unpaidInvoicesCount,
    int? unpaidTransferInvoicesCount,
    bool? isLoading,
  }) =>
      HomeProcurementState(
        pendingCount: pendingCount ?? this.pendingCount,
        approvedCount: approvedCount ?? this.approvedCount,
        invoiceDraftCount: invoiceDraftCount ?? this.invoiceDraftCount,
        invoiceDoneCount: invoiceDoneCount ?? this.invoiceDoneCount,
        unpaidInvoicesCount: unpaidInvoicesCount ?? this.unpaidInvoicesCount,
        unpaidTransferInvoicesCount:
            unpaidTransferInvoicesCount ?? this.unpaidTransferInvoicesCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeAssetState {
  final int dueTodayCount;
  final int overdueCount;
  final int dueThisWeekCount;
  final bool isLoading;

  const HomeAssetState({
    this.dueTodayCount = 0,
    this.overdueCount = 0,
    this.dueThisWeekCount = 0,
    this.isLoading = false,
  });

  HomeAssetState copyWith({
    int? dueTodayCount,
    int? overdueCount,
    int? dueThisWeekCount,
    bool? isLoading,
  }) =>
      HomeAssetState(
        dueTodayCount: dueTodayCount ?? this.dueTodayCount,
        overdueCount: overdueCount ?? this.overdueCount,
        dueThisWeekCount: dueThisWeekCount ?? this.dueThisWeekCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeSalesState {
  final int? yesterdayOmzet;
  final int? todayOmzet;
  final bool isLoading;
  const HomeSalesState({
    this.yesterdayOmzet,
    this.todayOmzet,
    this.isLoading = false,
  });
  HomeSalesState copyWith({
    int? yesterdayOmzet,
    int? todayOmzet,
    bool? isLoading,
  }) =>
      HomeSalesState(
        yesterdayOmzet: yesterdayOmzet ?? this.yesterdayOmzet,
        todayOmzet: todayOmzet ?? this.todayOmzet,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeStaffChecklistState {
  final bool hasSubmittedReadiness;
  final bool hasActiveClosingDraft;
  final bool isLoading;

  const HomeStaffChecklistState({
    this.hasSubmittedReadiness = false,
    this.hasActiveClosingDraft = false,
    this.isLoading = false,
  });

  HomeStaffChecklistState copyWith({
    bool? hasSubmittedReadiness,
    bool? hasActiveClosingDraft,
    bool? isLoading,
  }) =>
      HomeStaffChecklistState(
        hasSubmittedReadiness:
            hasSubmittedReadiness ?? this.hasSubmittedReadiness,
        hasActiveClosingDraft:
            hasActiveClosingDraft ?? this.hasActiveClosingDraft,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeAnomalyState {
  final int? mismatchCount;
  final int matchCount;
  final bool isLoading;
  const HomeAnomalyState(
      {this.mismatchCount, this.matchCount = 0, this.isLoading = false});
  HomeAnomalyState copyWith(
          {int? mismatchCount, int? matchCount, bool? isLoading}) =>
      HomeAnomalyState(
        mismatchCount: mismatchCount ?? this.mismatchCount,
        matchCount: matchCount ?? this.matchCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeStorageState {
  final int reportedStores;
  final int totalStores;
  final bool hasReportedToday;
  final bool isLoading;
  const HomeStorageState({
    this.reportedStores = 0,
    this.totalStores = 0,
    this.hasReportedToday = false,
    this.isLoading = false,
  });
  HomeStorageState copyWith({
    int? reportedStores,
    int? totalStores,
    bool? hasReportedToday,
    bool? isLoading,
  }) =>
      HomeStorageState(
        reportedStores: reportedStores ?? this.reportedStores,
        totalStores: totalStores ?? this.totalStores,
        hasReportedToday: hasReportedToday ?? this.hasReportedToday,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeAdminPresenceState {
  final List<dynamic> todayPresences;
  final int totalEmployees;
  final int lateCount;
  final bool isLoading;
  const HomeAdminPresenceState({
    this.todayPresences = const [],
    this.totalEmployees = 0,
    this.lateCount = 0,
    this.isLoading = false,
  });
  HomeAdminPresenceState copyWith({
    List<dynamic>? todayPresences,
    int? totalEmployees,
    int? lateCount,
    bool? isLoading,
  }) =>
      HomeAdminPresenceState(
        todayPresences: todayPresences ?? this.todayPresences,
        totalEmployees: totalEmployees ?? this.totalEmployees,
        lateCount: lateCount ?? this.lateCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeLeaveSalaryState {
  final int pendingLeavesCount;
  final bool hasLeavesThisMonth;
  final String salaryPaymentStatus;
  final bool hasLoanData;
  final bool isLoading;
  const HomeLeaveSalaryState({
    this.pendingLeavesCount = 0,
    this.hasLeavesThisMonth = false,
    this.salaryPaymentStatus = 'Belum Ada',
    this.hasLoanData = false,
    this.isLoading = false,
  });
  HomeLeaveSalaryState copyWith({
    int? pendingLeavesCount,
    bool? hasLeavesThisMonth,
    String? salaryPaymentStatus,
    bool? hasLoanData,
    bool? isLoading,
  }) =>
      HomeLeaveSalaryState(
        pendingLeavesCount: pendingLeavesCount ?? this.pendingLeavesCount,
        hasLeavesThisMonth: hasLeavesThisMonth ?? this.hasLeavesThisMonth,
        salaryPaymentStatus: salaryPaymentStatus ?? this.salaryPaymentStatus,
        hasLoanData: hasLoanData ?? this.hasLoanData,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeOrdersState {
  final int pendingOnlineOrderCount;
  final int pendingDirectOrderCount;
  final bool isLoading;
  const HomeOrdersState({
    this.pendingOnlineOrderCount = 0,
    this.pendingDirectOrderCount = 0,
    this.isLoading = false,
  });
  HomeOrdersState copyWith({
    int? pendingOnlineOrderCount,
    int? pendingDirectOrderCount,
    bool? isLoading,
  }) =>
      HomeOrdersState(
        pendingOnlineOrderCount:
            pendingOnlineOrderCount ?? this.pendingOnlineOrderCount,
        pendingDirectOrderCount:
            pendingDirectOrderCount ?? this.pendingDirectOrderCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomeAdminStockState {
  final List<Map<String, dynamic>> monitoringItems;
  final String latestStockDate;
  final bool isLoading;
  const HomeAdminStockState({
    this.monitoringItems = const [],
    this.latestStockDate = '',
    this.isLoading = false,
  });
  HomeAdminStockState copyWith({
    List<Map<String, dynamic>>? monitoringItems,
    String? latestStockDate,
    bool? isLoading,
  }) =>
      HomeAdminStockState(
        monitoringItems: monitoringItems ?? this.monitoringItems,
        latestStockDate: latestStockDate ?? this.latestStockDate,
        isLoading: isLoading ?? this.isLoading,
      );
}

@immutable
class HomePresenceState {
  final bool isUserDataLoaded;
  final bool hasActiveLeave;
  final PresenceModel? todayPresence;
  final PresenceModel? yesterdayPresence;
  final List<PresenceModel> previousPresences;
  final bool isLoading;
  const HomePresenceState({
    this.isUserDataLoaded = false,
    this.hasActiveLeave = false,
    this.todayPresence,
    this.yesterdayPresence,
    this.previousPresences = const [],
    this.isLoading = false,
  });
  HomePresenceState copyWith({
    bool? isUserDataLoaded,
    bool? hasActiveLeave,
    PresenceModel? todayPresence,
    PresenceModel? yesterdayPresence,
    List<PresenceModel>? previousPresences,
    bool? isLoading,
  }) =>
      HomePresenceState(
        isUserDataLoaded: isUserDataLoaded ?? this.isUserDataLoaded,
        hasActiveLeave: hasActiveLeave ?? this.hasActiveLeave,
        todayPresence: todayPresence ?? this.todayPresence,
        yesterdayPresence: yesterdayPresence ?? this.yesterdayPresence,
        previousPresences: previousPresences ?? this.previousPresences,
        isLoading: isLoading ?? this.isLoading,
      );
}

// === Provider ===

/// Memegang semua state summary dashboard Home.
///
/// Service di-inject via constructor untuk testability (mockable).
/// Panggil [loadAll] sekali saat page init.
class HomeDashboardProvider extends ChangeNotifier {
  final ProcurementService _procurementService;
  final AssetService _assetService;
  final SalesDashboardService _salesDashboardService;
  final InventoryAnomalyService _anomalyService;
  final StorageStockService _storageService;
  final PresenceService _presenceService;
  final UserService _userService;
  final LeaveService _leaveService;
  final SalaryService _salaryService;
  final ReadinessService _readinessService;
  final ClosingStoreService _closingStoreService;

  HomeProcurementState _procurement = const HomeProcurementState();
  HomeAssetState _asset = const HomeAssetState();
  HomeSalesState _sales = const HomeSalesState();
  HomeAnomalyState _anomaly = const HomeAnomalyState();
  HomeStorageState _storage = const HomeStorageState();
  HomeAdminPresenceState _adminPresence = const HomeAdminPresenceState();
  HomeLeaveSalaryState _leaveSalary = const HomeLeaveSalaryState();
  HomeOrdersState _orders = const HomeOrdersState();
  HomeAdminStockState _adminStock = const HomeAdminStockState();
  HomePresenceState _presence = const HomePresenceState();
  HomeStaffChecklistState _staffChecklist = const HomeStaffChecklistState();

  bool _isLoading = false;
  String? _error;
  Future<void>? _loadAllInFlight;

  HomeDashboardProvider({
    required ProcurementService procurementService,
    required AssetService assetService,
    required SalesDashboardService salesDashboardService,
    required InventoryAnomalyService anomalyService,
    required StorageStockService storageService,
    required PresenceService presenceService,
    required UserService userService,
    required LeaveService leaveService,
    required SalaryService salaryService,
    ReadinessService? readinessService,
    ClosingStoreService? closingStoreService,
  })  : _procurementService = procurementService,
        _assetService = assetService,
        _salesDashboardService = salesDashboardService,
        _anomalyService = anomalyService,
        _storageService = storageService,
        _presenceService = presenceService,
        _userService = userService,
        _leaveService = leaveService,
        _salaryService = salaryService,
        _readinessService = readinessService ?? ReadinessService(),
        _closingStoreService = closingStoreService ?? ClosingStoreService();

  // Getters
  HomeProcurementState get procurement => _procurement;
  HomeAssetState get asset => _asset;
  HomeSalesState get sales => _sales;
  HomeAnomalyState get anomaly => _anomaly;
  HomeStorageState get storage => _storage;
  HomeAdminPresenceState get adminPresence => _adminPresence;
  HomeLeaveSalaryState get leaveSalary => _leaveSalary;
  HomeOrdersState get orders => _orders;
  HomeAdminStockState get adminStock => _adminStock;
  HomePresenceState get presence => _presence;
  HomeStaffChecklistState get staffChecklist => _staffChecklist;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Update presence flags (loaded state + active leave).
  /// Data presence ituself (todayPresence/previous) tetap dipegang oleh
  /// HomePage karena terkait navigasi clock in/out & bottom nav.
  void setPresenceLoaded(bool loaded) {
    _presence = _presence.copyWith(isUserDataLoaded: loaded);
    notifyListeners();
  }

  void setActiveLeave(bool hasLeave) {
    _presence = _presence.copyWith(hasActiveLeave: hasLeave);
    notifyListeners();
  }

  /// Load semua section (parallel).
  Future<void> loadAll() async {
    final inFlight = _loadAllInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadAllInternal();
    _loadAllInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_loadAllInFlight, future)) {
        _loadAllInFlight = null;
      }
    }
  }

  Future<void> _loadAllInternal() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadProcurement(),
        loadAsset(),
        loadSales(),
        loadAnomaly(),
        loadStorage(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load procurement summary.
  Future<void> loadProcurement() async {
    _procurement = _procurement.copyWith(isLoading: true);
    notifyListeners();

    try {
      final summary = await _procurementService.getProcurementSummary();
      final List requests = summary['requests'] as List? ?? [];

      int pending = 0;
      int approved = 0;
      for (final req in requests) {
        for (final item in (req as dynamic).detailRequests) {
          final status = (item as dynamic).status;
          if (status == '1') {
            pending++;
          } else if (status == '4' || status == '2') {
            approved++;
          }
        }
      }

      // Fetch unpaid transfer invoices count
      int unpaidTransferCount = 0;
      try {
        final invoiceResult = await _procurementService.getInvoices(
          paymentStatus: '1',
          perPage: 100,
        );
        unpaidTransferCount = invoiceResult.items
            .where((inv) => inv.paymentTypeId == 1)
            .length;
      } catch (_) {
        // Soft fail: unpaidTransferCount stays 0.
      }

      _procurement = _procurement.copyWith(
        pendingCount: pending,
        approvedCount: approved,
        invoiceDraftCount: (summary['invoice_draft'] as num?)?.toInt() ?? 0,
        invoiceDoneCount: (summary['invoice_done'] as num?)?.toInt() ?? 0,
        unpaidInvoicesCount: (summary['invoice_unpaid'] as num?)?.toInt() ?? 0,
        unpaidTransferInvoicesCount: unpaidTransferCount,
        isLoading: false,
      );
    } catch (_) {
      _procurement = _procurement.copyWith(isLoading: false);
    } finally {
      notifyListeners();
    }
  }

  /// Load asset summary.
  Future<void> loadAsset() async {
    _asset = _asset.copyWith(isLoading: true);
    notifyListeners();
    try {
      final summary = await _assetService.getDashboardSummary();
      _asset = _asset.copyWith(
        dueTodayCount: (summary['due_today'] ?? 0) as int,
        overdueCount: (summary['overdue'] ?? 0) as int,
        dueThisWeekCount: (summary['due_this_week'] ?? 0) as int,
        isLoading: false,
      );
    } catch (_) {
      _asset = _asset.copyWith(isLoading: false);
    } finally {
      notifyListeners();
    }
  }

  /// Load sales summary (kemarin dan live hari ini).
  Future<void> loadSales() async {
    _sales = _sales.copyWith(isLoading: true);
    notifyListeners();
    try {
      final results = await Future.wait([
        _salesDashboardService.getSummary(SalesPeriode.yesterday),
        _salesDashboardService.getSummary(SalesPeriode.today),
      ]);
      final yesterdaySummary = results[0];
      final todaySummary = results[1];
      _sales = _sales.copyWith(
        yesterdayOmzet: yesterdaySummary.omzet,
        todayOmzet: todaySummary.omzet,
        isLoading: false,
      );
    } catch (_) {
      _sales = _sales.copyWith(
        yesterdayOmzet: null,
        todayOmzet: null,
        isLoading: false,
      );
    } finally {
      notifyListeners();
    }
  }

  /// Load status checklist operasional staff harian (kesiapan & draft closing).
  Future<void> loadStaffChecklist() async {
    _staffChecklist = _staffChecklist.copyWith(isLoading: true);
    notifyListeners();
    try {
      final results = await Future.wait([
        _readinessService.checkStatus().catchError((_) => <String, dynamic>{}),
        _closingStoreService.getActiveDraft().catchError((_) => <String, dynamic>{}),
      ]);
      final readinessData = results[0];
      final closingData = results[1];

      final hasReadiness =
          readinessData['data']?['has_submitted_today'] == true;
      final hasClosingDraft =
          closingData.isNotEmpty && closingData['id'] != null;

      _staffChecklist = _staffChecklist.copyWith(
        hasSubmittedReadiness: hasReadiness,
        hasActiveClosingDraft: hasClosingDraft,
        isLoading: false,
      );
    } catch (_) {
      _staffChecklist = _staffChecklist.copyWith(isLoading: false);
    } finally {
      notifyListeners();
    }
  }

    /// Load anomaly summary.
  Future<void> loadAnomaly() async {
    _anomaly = _anomaly.copyWith(isLoading: true);
    notifyListeners();
    try {
      final response = await _anomalyService.getComparison();
      _anomaly = _anomaly.copyWith(
        mismatchCount: response.summary.mismatchCount,
        matchCount: response.summary.matchCount,
        isLoading: false,
      );
    } catch (_) {
      _anomaly = _anomaly.copyWith(mismatchCount: null, isLoading: false);
    } finally {
      notifyListeners();
    }
  }

  /// Load storage stock today-status summary (reported/total stores).
  Future<void> loadStorage() async {
    _storage = _storage.copyWith(isLoading: true);
    notifyListeners();
    try {
      final status = await _storageService.checkTodayStatus();
      final reported = status['reported_stores'] ?? 0;
      final total = status['total_stores'] ?? 0;
      _storage = _storage.copyWith(
        reportedStores: reported,
        totalStores: total,
        hasReportedToday: reported > 0,
        isLoading: false,
      );
    } catch (_) {
      _storage = _storage.copyWith(isLoading: false);
    } finally {
      notifyListeners();
    }
  }

  /// Load admin presence summary (today presences + late count + total staff).
  /// Dipanggil terpisah (admin/storage-staff only), tidak masuk loadAll().
  Future<void> loadAdminPresence() async {
    _adminPresence = _adminPresence.copyWith(isLoading: true);
    notifyListeners();

    // Pertahankan data yang sudah tampil selama refresh. Request yang gagal
    // tidak boleh mengubah ringkasan sebelumnya menjadi 0/0.
    var presences = _adminPresence.todayPresences;
    var totalEmployees = _adminPresence.totalEmployees;
    var lateCount = _adminPresence.lateCount;

    try {
      final result = await _presenceService.getAllTodayPresences();
      // Response kosong tanpa summary menandakan request gagal (service
      // memang mengembalikan fallback kosong saat error). Jangan hapus data
      // lama dalam kondisi ini.
      if (result.summary != null || result.presences.isNotEmpty) {
        presences = result.presences;
        final summary = result.summary;
        lateCount = (summary?['late_count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    try {
      final users = await _userService.getUsers(role: 'staff');
      if (users.isNotEmpty) {
        totalEmployees = users.length;
      }
    } catch (_) {}

    _adminPresence = _adminPresence.copyWith(
      todayPresences: presences,
      totalEmployees: totalEmployees,
      lateCount: lateCount,
      isLoading: false,
    );
    notifyListeners();
  }

  /// Load leave & salary summary (pending leaves count, salary status, loan).
  Future<void> loadLeaveSalary() async {
    _leaveSalary = _leaveSalary.copyWith(isLoading: true);
    notifyListeners();
    try {
      final leaves = await _leaveService.getLeaves();
      final now = DateTime.now();
      final currentMonthLeaves = leaves
          .where((l) =>
              l.createdAt.year == now.year && l.createdAt.month == now.month)
          .toList();
      final pendingLeaves = currentMonthLeaves
          .where((l) => l.statusText.toLowerCase() == 'pending')
          .length;
      final hasLeaves = currentMonthLeaves.isNotEmpty;

      // Active leave: status approved & rentang tanggal (inklusif) mencakup
      // hari ini. Bandikan di level tanggal-kalender (bukan timestamp) supaya
      // hari pertama dan hari terakhir cuti tetap dianggap aktif. Sebelumnya
      // pakai isBefore/isAfter yang eksklusif thd. timestamp midnight, sehingga
      // hari terakhir cuti salah terdeteksi sebagai tidak aktif.
      final today = DateTime(now.year, now.month, now.day);
      final hasActiveLeave = leaves.any((l) {
        if (l.status != AppConstants.leaveStatusApproved) return false;
        final start = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
        final end = DateTime(l.untilDate.year, l.untilDate.month, l.untilDate.day);
        return !today.isBefore(start) && !today.isAfter(end);
      });
      if (hasActiveLeave != _presence.hasActiveLeave) {
        _presence = _presence.copyWith(hasActiveLeave: hasActiveLeave);
      }

      final salaries = await _salaryService.getSalaryHistory();
      String salStatus = 'Belum Ada';
      bool hasLoan = false;
      if (salaries.isNotEmpty) {
        hasLoan = salaries.any((item) => item['has_loan'] == true);
        final recent = salaries.first;
        final status = recent['status']?.toString().toLowerCase();
        if (status == 'paid') {
          salStatus = 'Gaji Lunas';
        } else if (status == 'processing') {
          salStatus = 'Proses Gaji';
        } else {
          salStatus = 'Belum Lunas';
        }
      }

      _leaveSalary = _leaveSalary.copyWith(
        pendingLeavesCount: pendingLeaves,
        hasLeavesThisMonth: hasLeaves,
        salaryPaymentStatus: salStatus,
        hasLoanData: hasLoan,
        isLoading: false,
      );
    } catch (_) {
      _leaveSalary = _leaveSalary.copyWith(isLoading: false);
    } finally {
      notifyListeners();
    }
  }

  /// Load pending orders count (storage-staff only: online + direct orders).
  Future<void> loadOrders() async {
    _orders = _orders.copyWith(isLoading: true);
    notifyListeners();
    try {
      final onlineResult = await _presenceService.getSalesOrders(
        deliveryStatus: 2,
        page: 1,
        perPage: 1,
        orderFor: '3',
      );
      final onlineTotal = onlineResult['success'] == true
          ? (onlineResult['meta']?['total'] ?? 0)
          : 0;

      final directResult = await _presenceService.getSalesOrders(
        deliveryStatus: 2,
        page: 1,
        perPage: 1,
        orderFor: '1',
      );
      final directTotal = directResult['success'] == true
          ? (directResult['meta']?['total'] ?? 0)
          : 0;

      _orders = _orders.copyWith(
        pendingOnlineOrderCount: onlineTotal,
        pendingDirectOrderCount: directTotal,
        isLoading: false,
      );
    } catch (_) {
      _orders = _orders.copyWith(isLoading: false);
    } finally {
      notifyListeners();
    }
  }

  /// Load admin stock monitoring feed (low-stock alerts).
  /// Dipanggil terpisah (admin/storage-staff only), tidak masuk loadAll().
  Future<void> loadAdminStock() async {
    _adminStock = _adminStock.copyWith(isLoading: true);
    notifyListeners();
    try {
      final data = await _storageService.getStockMonitoring();
      _adminStock = HomeAdminStockState(
        monitoringItems: data,
        latestStockDate:
            data.isNotEmpty ? (data.first['last_stock_date'] ?? '') : '',
        isLoading: false,
      );
    } catch (_) {
      _adminStock = _adminStock.copyWith(isLoading: false);
    } finally {
      notifyListeners();
    }
  }

  /// Load user presence data (today's + history).
  /// Dipanggil sekali di init + setelah clock in/out.
  Future<void> loadPresence() async {
    _presence = _presence.copyWith(isLoading: true);
    notifyListeners();
    try {
      final data = await _presenceService.getUserPresence();
      final todayData = data['data']?['today'];
      final previousData = data['data']?['previous'] as List? ?? [];

      PresenceModel? today;
      PresenceModel? yesterday;
      final previous = <PresenceModel>[];
      try {
        today =
            todayData != null ? PresenceModel.fromJson(todayData) : null;
        yesterday = previousData.isNotEmpty
            ? PresenceModel.fromJson(previousData[0])
            : null;
        previous.addAll(
          previousData.map((item) {
            try {
              return PresenceModel.fromJson(item);
            } catch (_) {
              return null;
            }
          }).whereType<PresenceModel>(),
        );
      } catch (_) {
        today = null;
        yesterday = null;
      }

      _presence = _presence.copyWith(
        todayPresence: today,
        yesterdayPresence: yesterday,
        previousPresences: previous,
        isUserDataLoaded: true,
        isLoading: false,
      );
    } catch (_) {
      _presence = _presence.copyWith(
        todayPresence: null,
        yesterdayPresence: null,
        previousPresences: const [],
        isUserDataLoaded: true,
        isLoading: false,
      );
    } finally {
      notifyListeners();
    }
  }
}
