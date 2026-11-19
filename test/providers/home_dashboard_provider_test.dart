import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sagansa/models/inventory_anomaly_model.dart';
import 'package:sagansa/models/leave_model.dart';
import 'package:sagansa/models/procurement_model.dart';
import 'package:sagansa/models/sales_dashboard_model.dart';
import 'package:sagansa/providers/home_dashboard_provider.dart';
import 'package:sagansa/services/asset_service.dart';
import 'package:sagansa/services/inventory_anomaly_service.dart';
import 'package:sagansa/services/leave_service.dart';
import 'package:sagansa/services/presence_service.dart';
import 'package:sagansa/services/procurement_service.dart';
import 'package:sagansa/services/salary_service.dart';
import 'package:sagansa/services/sales_dashboard_service.dart';
import 'package:sagansa/services/storage_stock_service.dart';
import 'package:sagansa/services/user_service.dart';

class _MockProcurement extends Mock implements ProcurementService {}
class _MockAsset extends Mock implements AssetService {}
class _MockSales extends Mock implements SalesDashboardService {}
class _MockAnomaly extends Mock implements InventoryAnomalyService {}
class _MockStorage extends Mock implements StorageStockService {}
class _MockPresence extends Mock implements PresenceService {}
class _MockUser extends Mock implements UserService {}
class _MockLeave extends Mock implements LeaveService {}
class _MockSalary extends Mock implements SalaryService {}

DetailRequestItem _item(int id, String status) => DetailRequestItem(
      id: id,
      productId: 1,
      quantityPlan: 1,
      status: status,
      productName: 'P',
      unitName: 'u',
    );

InvoicePurchase _invoice(int id, {int? paymentTypeId = 1}) => InvoicePurchase(
      id: id,
      paymentTypeId: paymentTypeId,
      storeId: 1,
      date: '2026-07-20',
      createdById: 1,
      storeName: 'Toko',
    );

LeaveModel _leave({
  required int status,
  required String statusText,
  DateTime? from,
  DateTime? until,
}) {
  final now = DateTime.now();
  return LeaveModel(
    id: 1,
    reason: 1,
    reasonText: 'Cuti',
    fromDate: from ?? now,
    untilDate: until ?? now,
    status: status,
    statusText: statusText,
    createdBy: CreatedBy(id: 1, name: 'U'),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late HomeDashboardProvider provider;
  late _MockProcurement mockProcurement;
  late _MockAsset mockAsset;
  late _MockSales mockSales;
  late _MockAnomaly mockAnomaly;
  late _MockStorage mockStorage;
  late _MockPresence mockPresence;
  late _MockUser mockUser;
  late _MockLeave mockLeave;
  late _MockSalary mockSalary;

  setUp(() {
    mockProcurement = _MockProcurement();
    mockAsset = _MockAsset();
    mockSales = _MockSales();
    mockAnomaly = _MockAnomaly();
    mockStorage = _MockStorage();
    mockPresence = _MockPresence();
    mockUser = _MockUser();
    mockLeave = _MockLeave();
    mockSalary = _MockSalary();

    provider = HomeDashboardProvider(
      procurementService: mockProcurement,
      assetService: mockAsset,
      salesDashboardService: mockSales,
      anomalyService: mockAnomaly,
      storageService: mockStorage,
      presenceService: mockPresence,
      userService: mockUser,
      leaveService: mockLeave,
      salaryService: mockSalary,
    );

    // Default fallback stubs (return safe empty values).
    registerFallbackValue(SalesPeriode.today);
  });

  group('initial state', () {
    test('all state groups have default/empty values', () {
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.procurement.pendingCount, 0);
      expect(provider.procurement.approvedCount, 0);
      expect(provider.asset.dueTodayCount, 0);
      expect(provider.sales.yesterdayOmzet, isNull);
      expect(provider.anomaly.mismatchCount, isNull);
      expect(provider.storage.reportedStores, 0);
      expect(provider.adminPresence.totalEmployees, 0);
      expect(provider.leaveSalary.salaryPaymentStatus, 'Belum Ada');
      expect(provider.orders.pendingOnlineOrderCount, 0);
      expect(provider.adminStock.monitoringItems, isEmpty);
      expect(provider.presence.todayPresence, isNull);
      expect(provider.presence.isUserDataLoaded, false);
    });

    test('notifyListeners is called on state mutations', () {
      var notifiedCount = 0;
      provider.addListener(() => notifiedCount++);

      provider.setPresenceLoaded(true);
      expect(notifiedCount, greaterThan(0));

      notifiedCount = 0;
      provider.setActiveLeave(true);
      expect(notifiedCount, greaterThan(0));
    });
  });

  group('loadProcurement', () {
    test('populates pending/approved counts and invoice stats', () async {
      final summary = {
        'requests': [
          RequestPurchase(
            id: 1,
            storeId: 1,
            storeName: 'Toko',
            date: '2026-07-20',
            userId: 1,
            userName: 'U',
            detailRequests: [
              _item(11, '1'),
              _item(12, '1'),
              _item(13, '4'),
              _item(14, '2'),
            ],
          ),
        ],
        'invoice_draft': 2,
        'invoice_done': 5,
        'invoice_unpaid': 3,
      };
      when(() => mockProcurement.getProcurementSummary())
          .thenAnswer((_) async => summary);
      when(() => mockProcurement.getInvoices(paymentStatus: '1', perPage: 100))
          .thenAnswer((_) async => PaginatedResult(
                items: [
                  _invoice(1, paymentTypeId: 1),
                  _invoice(2, paymentTypeId: 2),
                  _invoice(3, paymentTypeId: 1),
                ],
                currentPage: 1,
                lastPage: 1,
                perPage: 100,
                total: 3,
              ));

      await provider.loadProcurement();

      expect(provider.procurement.pendingCount, 2);
      expect(provider.procurement.approvedCount, 2);
      expect(provider.procurement.invoiceDraftCount, 2);
      expect(provider.procurement.invoiceDoneCount, 5);
      expect(provider.procurement.unpaidInvoicesCount, 3);
      expect(provider.procurement.unpaidTransferInvoicesCount, 2);
      expect(provider.procurement.isLoading, false);
    });

    test('counts items with status code 1 as pending', () async {
      when(() => mockProcurement.getProcurementSummary()).thenAnswer(
          (_) async => {
                'requests': [
                  RequestPurchase(
                    id: 1,
                    storeId: 1,
                    storeName: 'T',
                    date: '',
                    userId: 1,
                    userName: '',
                    detailRequests: [
                      _item(1, '1'),
                      _item(2, '1'),
                      _item(3, '1'),
                    ],
                  )
                ],
              });
      when(() => mockProcurement.getInvoices(paymentStatus: '1', perPage: 100))
          .thenAnswer((_) async => PaginatedResult(
                items: const [],
                currentPage: 1,
                lastPage: 1,
                perPage: 100,
                total: 0,
              ));

      await provider.loadProcurement();

      expect(provider.procurement.pendingCount, 3);
      expect(provider.procurement.approvedCount, 0);
    });

    test('swallows service error, state stays default', () async {
      when(() => mockProcurement.getProcurementSummary())
          .thenThrow(Exception('network'));

      await provider.loadProcurement();

      expect(provider.procurement.pendingCount, 0);
      expect(provider.procurement.isLoading, false);
    });

    test('soft-fails invoice fetch, keeps procurement counts', () async {
      when(() => mockProcurement.getProcurementSummary()).thenAnswer(
          (_) async => {
                'requests': const [],
                'invoice_draft': 1,
                'invoice_done': 1,
                'invoice_unpaid': 1,
              });
      when(() => mockProcurement.getInvoices(paymentStatus: '1', perPage: 100))
          .thenThrow(Exception('invoice service down'));

      await provider.loadProcurement();

      expect(provider.procurement.invoiceDraftCount, 1);
      expect(provider.procurement.unpaidTransferInvoicesCount, 0);
    });
  });

  group('loadAsset', () {
    test('populates dueToday/overdue/dueThisWeek counts', () async {
      when(() => mockAsset.getDashboardSummary())
          .thenAnswer((_) async => {'due_today': 3, 'overdue': 1, 'due_this_week': 7});

      await provider.loadAsset();

      expect(provider.asset.dueTodayCount, 3);
      expect(provider.asset.overdueCount, 1);
      expect(provider.asset.dueThisWeekCount, 7);
      expect(provider.asset.isLoading, false);
    });

    test('swallows error, state stays default', () async {
      when(() => mockAsset.getDashboardSummary()).thenThrow(Exception());

      await provider.loadAsset();

      expect(provider.asset.dueTodayCount, 0);
    });
  });

  group('loadSales', () {
    test('populates yesterdayOmzet', () async {
      when(() => mockSales.getSummary(SalesPeriode.yesterday))
          .thenAnswer((_) async => const SalesSummary(
                periodeLabel: 'Kemarin',
                omzet: 1500000,
                orderCount: 10,
                totalQty: 50,
                omzetPrev: 1000000,
                orderCountPrev: 8,
                totalQtyPrev: 40,
                prevLabel: 'Lusa',
              ));
      when(() => mockSales.getSummary(SalesPeriode.today))
          .thenAnswer((_) async => const SalesSummary(
                periodeLabel: 'Hari Ini',
                omzet: 2000000,
                orderCount: 12,
                totalQty: 60,
                omzetPrev: 1500000,
                orderCountPrev: 10,
                totalQtyPrev: 50,
                prevLabel: 'Kemarin',
              ));

      await provider.loadSales();

      expect(provider.sales.yesterdayOmzet, 1500000);
      expect(provider.sales.todayOmzet, 2000000);
      expect(provider.sales.isLoading, false);
    });

    test('swallows error, omzet becomes null', () async {
      when(() => mockSales.getSummary(SalesPeriode.yesterday))
          .thenThrow(Exception());
      when(() => mockSales.getSummary(any()))
          .thenThrow(Exception());

      await provider.loadSales();

      expect(provider.sales.yesterdayOmzet, isNull);
    });
  });

  group('loadAnomaly', () {
    test('populates mismatch & match counts', () async {
      when(() => mockAnomaly.getComparison()).thenAnswer((_) async =>
          InventoryAnomalyResponse(
            period: const InventoryAnomalyPeriod(
                dateFrom: '', dateTo: '', storeIds: []),
            summary: const InventoryAnomalySummary(
              productsCompared: 12,
              matchCount: 10,
              mismatchCount: 2,
              noSoDataCount: 0,
              noStockDataCount: 0,
              totalSoldQty: 0,
              totalStockOutQty: 0,
            ),
            items: const [],
            meta: const InventoryAnomalyMeta(
                currentPage: 1, lastPage: 1, perPage: 50, total: 0),
          ));

      await provider.loadAnomaly();

      expect(provider.anomaly.mismatchCount, 2);
      expect(provider.anomaly.matchCount, 10);
    });

    test('swallows error, mismatch becomes null', () async {
      when(() => mockAnomaly.getComparison()).thenThrow(Exception());

      await provider.loadAnomaly();

      expect(provider.anomaly.mismatchCount, isNull);
    });
  });

  group('loadStorage', () {
    test('populates reported/total stores & hasReportedToday flag', () async {
      when(() => mockStorage.checkTodayStatus()).thenAnswer((_) async => {
            'total_stores': 5,
            'reported_stores': 3,
            'user_store_reported': 1,
          });

      await provider.loadStorage();

      expect(provider.storage.reportedStores, 3);
      expect(provider.storage.totalStores, 5);
      expect(provider.storage.hasReportedToday, true);
    });

    test('hasReportedToday is false when reportedStores is 0', () async {
      when(() => mockStorage.checkTodayStatus()).thenAnswer((_) async => {
            'total_stores': 5,
            'reported_stores': 0,
            'user_store_reported': 0,
          });

      await provider.loadStorage();

      expect(provider.storage.hasReportedToday, false);
    });
  });

  group('loadAdminPresence', () {
    test('aggregates today presences + staff count + late count', () async {
      when(() => mockPresence.getAllTodayPresences()).thenAnswer((_) async =>
          (
            presences: [
              {'id': 1, 'name': 'A'},
              {'id': 2, 'name': 'B'},
            ],
            summary: {'late_count': 1, 'on_time_count': 1},
          ));
      when(() => mockUser.getUsers(role: 'staff'))
          .thenAnswer((_) async => [{'id': 1}, {'id': 2}, {'id': 3}]);

      await provider.loadAdminPresence();

      expect(provider.adminPresence.todayPresences.length, 2);
      expect(provider.adminPresence.totalEmployees, 3);
      expect(provider.adminPresence.lateCount, 1);
    });

    test('presences still load when users endpoint fails', () async {
      when(() => mockPresence.getAllTodayPresences())
          .thenAnswer((_) async => (
                presences: [{'id': 1}],
                summary: {'late_count': 0},
              ));
      when(() => mockUser.getUsers(role: 'staff'))
          .thenThrow(Exception('users 500'));

      await provider.loadAdminPresence();

      expect(provider.adminPresence.todayPresences.length, 1);
      expect(provider.adminPresence.totalEmployees, 0);
    });
  });

  group('loadLeaveSalary', () {
    test('populates pendingLeaves/hasLeaves/salaryStatus/loan', () async {
      final now = DateTime.now();
      when(() => mockLeave.getLeaves()).thenAnswer((_) async => [
            _leave(
                status: 1,
                statusText: 'Pending',
                from: now,
                until: now),
            _leave(
                status: 2,
                statusText: 'Approved',
                from: now,
                until: now),
          ]);
      when(() => mockSalary.getSalaryHistory()).thenAnswer((_) async => [
            {'status': 'paid', 'has_loan': true},
          ]);

      await provider.loadLeaveSalary();

      expect(provider.leaveSalary.pendingLeavesCount, 1);
      expect(provider.leaveSalary.hasLeavesThisMonth, true);
      expect(provider.leaveSalary.salaryPaymentStatus, 'Gaji Lunas');
      expect(provider.leaveSalary.hasLoanData, true);
    });

    test('salary "processing" maps to "Proses Gaji"', () async {
      when(() => mockLeave.getLeaves()).thenAnswer((_) async => const []);
      when(() => mockSalary.getSalaryHistory()).thenAnswer((_) async => [
            {'status': 'processing', 'has_loan': false},
          ]);

      await provider.loadLeaveSalary();

      expect(provider.leaveSalary.salaryPaymentStatus, 'Proses Gaji');
    });

    test('salary other status maps to "Belum Lunas"', () async {
      when(() => mockLeave.getLeaves()).thenAnswer((_) async => const []);
      when(() => mockSalary.getSalaryHistory()).thenAnswer((_) async => [
            {'status': 'pending', 'has_loan': false},
          ]);

      await provider.loadLeaveSalary();

      expect(provider.leaveSalary.salaryPaymentStatus, 'Belum Lunas');
    });

    test('empty salary history keeps default "Belum Ada"', () async {
      when(() => mockLeave.getLeaves()).thenAnswer((_) async => const []);
      when(() => mockSalary.getSalaryHistory()).thenAnswer((_) async => const []);

      await provider.loadLeaveSalary();

      expect(provider.leaveSalary.salaryPaymentStatus, 'Belum Ada');
      expect(provider.leaveSalary.hasLoanData, false);
    });

    test('sets hasActiveLeave when approved leave contains now', () async {
      final now = DateTime.now();
      when(() => mockLeave.getLeaves()).thenAnswer((_) async => [
            _leave(
              status: 2, // approved
              statusText: 'Approved',
              from: now.subtract(const Duration(days: 1)),
              until: now.add(const Duration(days: 1)),
            ),
          ]);
      when(() => mockSalary.getSalaryHistory()).thenAnswer((_) async => const []);

      await provider.loadLeaveSalary();

      expect(provider.presence.hasActiveLeave, true);
    });
  });

  group('loadOrders', () {
    test('aggregates online + direct pending order totals', () async {
      when(() => mockPresence.getSalesOrders(
              deliveryStatus: 2,
              page: 1,
              perPage: 1,
              orderFor: '3'))
          .thenAnswer((_) async => {
                'success': true,
                'meta': {'total': 4},
              });
      when(() => mockPresence.getSalesOrders(
              deliveryStatus: 2,
              page: 1,
              perPage: 1,
              orderFor: '1'))
          .thenAnswer((_) async => {
                'success': true,
                'meta': {'total': 2},
              });

      await provider.loadOrders();

      expect(provider.orders.pendingOnlineOrderCount, 4);
      expect(provider.orders.pendingDirectOrderCount, 2);
    });

    test('non-success response keeps count at 0', () async {
      when(() => mockPresence.getSalesOrders(
              deliveryStatus: 2,
              page: 1,
              perPage: 1,
              orderFor: '3'))
          .thenAnswer((_) async => {'success': false});
      when(() => mockPresence.getSalesOrders(
              deliveryStatus: 2,
              page: 1,
              perPage: 1,
              orderFor: '1'))
          .thenAnswer((_) async => {'success': false});

      await provider.loadOrders();

      expect(provider.orders.pendingOnlineOrderCount, 0);
      expect(provider.orders.pendingDirectOrderCount, 0);
    });
  });

  group('loadAdminStock', () {
    test('populates monitoringItems + latestStockDate', () async {
      when(() => mockStorage.getStockMonitoring()).thenAnswer((_) async => [
            {
              'name': 'Beras',
              'last_stock_date': '2026-07-19',
              'calculated_total_stock': 5,
              'quantity_low': 10,
            },
          ]);

      await provider.loadAdminStock();

      expect(provider.adminStock.monitoringItems.length, 1);
      expect(provider.adminStock.latestStockDate, '2026-07-19');
    });

    test('latestStockDate empty when no monitoring items', () async {
      when(() => mockStorage.getStockMonitoring())
          .thenAnswer((_) async => const []);

      await provider.loadAdminStock();

      expect(provider.adminStock.monitoringItems, isEmpty);
      expect(provider.adminStock.latestStockDate, '');
    });
  });

  group('loadPresence', () {
    test('parses today + yesterday + previous presences', () async {
      when(() => mockPresence.getUserPresence()).thenAnswer((_) async => {
            'data': {
              'today': {
                'id': 1,
                'store': 'Toko A',
                'shift_store': 'Pagi',
                'check_in': '2026-07-21 08:00:00',
                'check_in_status': 'tepat_waktu',
                'check_out': null,
                'check_out_status': 'tidak_absen',
              },
              'previous': [
                {
                  'id': 2,
                  'store': 'Toko B',
                  'shift_store': 'Sore',
                  'check_in': '2026-07-20 08:00:00',
                  'check_in_status': 'tepat_waktu',
                  'check_out': '2026-07-20 17:00:00',
                  'check_out_status': 'tepat_waktu',
                },
              ],
            },
          });

      await provider.loadPresence();

      expect(provider.presence.todayPresence, isNotNull);
      expect(provider.presence.todayPresence!.store, 'Toko A');
      expect(provider.presence.yesterdayPresence, isNotNull);
      expect(provider.presence.previousPresences.length, 1);
      expect(provider.presence.isUserDataLoaded, true);
    });

    test('handles missing today/previous gracefully', () async {
      when(() => mockPresence.getUserPresence())
          .thenAnswer((_) async => {'data': {}});

      await provider.loadPresence();

      expect(provider.presence.todayPresence, isNull);
      expect(provider.presence.previousPresences, isEmpty);
      expect(provider.presence.isUserDataLoaded, true);
    });

    test('service failure marks data loaded with empty state', () async {
      when(() => mockPresence.getUserPresence()).thenThrow(Exception());

      await provider.loadPresence();

      expect(provider.presence.todayPresence, isNull);
      expect(provider.presence.isUserDataLoaded, true);
    });
  });

  group('loadAll', () {
    test('runs 5 loaders in parallel and clears isLoading', () async {
      when(() => mockProcurement.getProcurementSummary())
          .thenAnswer((_) async => {'requests': const []});
      when(() => mockProcurement.getInvoices(paymentStatus: '1', perPage: 100))
          .thenAnswer((_) async => PaginatedResult(
              items: const [], currentPage: 1, lastPage: 1, perPage: 100, total: 0));
      when(() => mockAsset.getDashboardSummary())
          .thenAnswer((_) async => {'due_today': 0});
      when(() => mockSales.getSummary(any()))
          .thenAnswer((_) async => const SalesSummary(
              periodeLabel: '',
              omzet: 0,
              orderCount: 0,
              totalQty: 0,
              omzetPrev: 0,
              orderCountPrev: 0,
              totalQtyPrev: 0,
              prevLabel: ''));
      when(() => mockAnomaly.getComparison()).thenAnswer((_) async =>
          InventoryAnomalyResponse(
            period: const InventoryAnomalyPeriod(
                dateFrom: '', dateTo: '', storeIds: []),
            summary: const InventoryAnomalySummary(
                productsCompared: 0,
                matchCount: 0,
                mismatchCount: 0,
                noSoDataCount: 0,
                noStockDataCount: 0,
                totalSoldQty: 0,
                totalStockOutQty: 0),
            items: const [],
            meta: const InventoryAnomalyMeta(
                currentPage: 1, lastPage: 1, perPage: 50, total: 0),
          ));
      when(() => mockStorage.checkTodayStatus()).thenAnswer((_) async =>
          {'total_stores': 0, 'reported_stores': 0, 'user_store_reported': 0});

      await provider.loadAll();

      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });
  });
}
