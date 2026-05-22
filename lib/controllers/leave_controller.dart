import 'package:flutter/material.dart';
import '../services/leave_service.dart';

class LeaveController {
  final LeaveService _leaveService = LeaveService();
  final BuildContext context;

  LeaveController(this.context);

  Future<void> submitLeave({
    required int selectedReason,
    required DateTime fromDate,
    required DateTime untilDate,
    required String notes,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final success = await _leaveService.submitLeave(
        reason: selectedReason,
        fromDate: fromDate,
        untilDate: untilDate,
        notes: notes,
      );

      if (success) {
        onSuccess();
      } else {
        onError('Gagal mengajukan cuti');
      }
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> updateLeave({
    required int leaveId,
    required String reason,
    required DateTime fromDate,
    required DateTime untilDate,
    required String notes,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    try {
      await _leaveService.updateLeave(
        leaveId,
        reason,
        fromDate,
        untilDate,
        notes,
      );
      onSuccess();
    } catch (e) {
      onError(e.toString());
    }
  }

  bool validateDates(DateTime? fromDate, DateTime? untilDate) {
    if (fromDate == null || untilDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal cuti')),
      );
      return false;
    }
    return true;
  }

  bool validateReason(int? selectedReason) {
    if (selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis cuti')),
      );
      return false;
    }
    return true;
  }
}
