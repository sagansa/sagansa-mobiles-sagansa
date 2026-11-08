import '../widgets/status_badge.dart';

class StatusMappers {
  /// Delivery status (1=pending, 2=valid, 3=delivered, 4=ready, 5=fix,
  /// 6=returned, 7=cancelled)
  static StatusType deliveryStatus(int? code) => switch (code) {
        2 => StatusType.success,
        3 => StatusType.info,
        6 => StatusType.error,
        7 => StatusType.error,
        _ => StatusType.warning,
      };

  static String deliveryLabel(int? code) => switch (code) {
        1 => 'Belum Dikirim',
        2 => 'Valid (Terkunci)',
        3 => 'Sudah Dikirim',
        4 => 'Siap Dikirim',
        5 => 'Perbaiki',
        6 => 'Dikembalikan',
        7 => 'Dibatalkan',
        _ => 'Tidak Diketahui',
      };

  /// Payment status (1=paid, 2=valid, 3=invalid, 4=pending)
  static StatusType paymentStatus(String? code) => switch (code) {
        '1' => StatusType.warning,
        '2' => StatusType.success,
        '3' => StatusType.error,
        _ => StatusType.neutral,
      };

  static String paymentLabel(String? code) => switch (code) {
        '1' => 'Sudah Dibayar',
        '2' => 'Valid',
        '3' => 'Tidak Valid',
        '4' => 'Menunggu Pembayaran',
        _ => '-',
      };

  /// Payment proof status (1=pending, 2=approved, 3=rejected)
  static StatusType paymentProofStatus(int? code) => switch (code) {
        2 => StatusType.success,
        3 => StatusType.error,
        _ => StatusType.warning,
      };

  static String paymentProofLabel(int? code) => switch (code) {
        1 => 'Belum Disetujui',
        2 => 'Disetujui',
        3 => 'Ditolak',
        _ => 'Tidak Diketahui',
      };

  /// Procurement status (1=pending, 2=approved, 3=rejected, 4=completed)
  static StatusType procurementStatus(int? code) => switch (code) {
        2 => StatusType.success,
        3 => StatusType.error,
        4 => StatusType.info,
        _ => StatusType.warning,
      };

  static String procurementLabel(int? code) => switch (code) {
        1 => 'Pending',
        2 => 'Disetujui',
        3 => 'Ditolak',
        4 => 'Selesai',
        _ => 'Tidak Diketahui',
      };

  /// Leave status (1=pending, 2=approved, 3=rejected)
  static StatusType leaveStatus(int? code) => switch (code) {
        2 => StatusType.success,
        3 => StatusType.error,
        _ => StatusType.warning,
      };

  static String leaveLabel(int? code) => switch (code) {
        1 => 'Pending',
        2 => 'Disetujui',
        3 => 'Ditolak',
        _ => 'Tidak Diketahui',
      };

  /// Daily salary status (1=unpaid, 2=paid, 3=ready, 4=fix)
  static StatusType dailySalaryStatus(int? code) => switch (code) {
        2 => StatusType.success,
        3 => StatusType.info,
        4 => StatusType.error,
        _ => StatusType.warning,
      };

  static String dailySalaryLabel(int? code) => switch (code) {
        1 => 'Belum Dibayar',
        2 => 'Sudah Dibayar',
        3 => 'Siap Dibayar',
        4 => 'Perbaiki',
        _ => 'Tidak Diketahui',
      };

  /// Apakah daily salary bisa dibayar via payment receipt: status 1 (belum
  /// dibayar) / 3 (siap dibayar) dan metode Transfer. Sama dengan guard
  /// server ProcurementController::storeDailySalaryPaymentReceipt.
  /// Status/tipe pembayaran dari JSON bisa int maupun string.
  static bool isPayableDailySalary(dynamic salary) {
    if (salary is! Map) return false;
    final status = salary['status'];
    final payableStatus =
        status == 1 || status == '1' || status == 3 || status == '3';
    final paymentType = salary['payment_type_id'];
    final isTransfer = paymentType == 1 || paymentType == '1';
    return payableStatus && isTransfer;
  }

  /// Hygiene status (1=pending, 2=approved, 3=rejected)
  static StatusType hygieneStatus(int? code) => switch (code) {
        2 => StatusType.success,
        3 => StatusType.error,
        _ => StatusType.warning,
      };

  static String hygieneLabel(int? code) => switch (code) {
        1 => 'Pending',
        2 => 'Disetujui',
        3 => 'Ditolak',
        _ => 'Tidak Diketahui',
      };

  /// Procurement — status global request (label hasil [overallStatusText]
  /// / label item). Konsisten dgn mapping dashboard procurement:
  /// Pending Approval=warning, Partially Approved & Approved=info,
  /// Done=success, Rejected=error, selain itu neutral.
  static StatusType procurementGlobalStatus(String label) => switch (label) {
        'Pending Approval' => StatusType.warning,
        'Partially Approved' || 'Approved' => StatusType.info,
        'Done' => StatusType.success,
        'Rejected' => StatusType.error,
        _ => StatusType.neutral,
      };
}
