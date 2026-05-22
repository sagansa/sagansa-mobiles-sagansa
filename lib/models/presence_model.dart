import 'package:flutter/material.dart';

class PresenceModel {
  final String store;
  final String shiftStore;
  final int status;
  final String checkIn;
  final String? checkOut;
  final String latitudeIn;
  final String longitudeIn;
  final String? imageIn;
  final String? latitudeOut;
  final String? longitudeOut;
  final String? imageOut;
  final String shiftStartTime;
  final String shiftEndTime;
  final String checkInStatus;
  final String? checkOutStatus;
  final int? lateMinutes;
  final String? shiftEndDatetime;
  final String? checkoutDeadline;
  final int? workingHours;
  final String? workingHoursNotes;
  final Map<String, dynamic>? salaryInfo;

  PresenceModel({
    required this.store,
    required this.shiftStore,
    required this.status,
    required this.checkIn,
    this.checkOut,
    required this.latitudeIn,
    required this.longitudeIn,
    this.imageIn,
    this.latitudeOut,
    this.longitudeOut,
    this.imageOut,
    required this.shiftStartTime,
    required this.shiftEndTime,
    required this.checkInStatus,
    this.checkOutStatus,
    this.lateMinutes,
    this.shiftEndDatetime,
    this.checkoutDeadline,
    this.workingHours,
    this.workingHoursNotes,
    this.salaryInfo,
  });

  factory PresenceModel.fromJson(Map<String, dynamic> json) {
    return PresenceModel(
      store: json['store']?.toString() ?? '',
      shiftStore: json['shift_store']?.toString() ?? '',
      status: int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      checkIn: json['check_in']?.toString() ?? '',
      checkOut: json['check_out']?.toString(),
      latitudeIn: json['latitude_in']?.toString() ?? '0',
      longitudeIn: json['longitude_in']?.toString() ?? '0',
      imageIn: json['image_in']?.toString(),
      latitudeOut: json['latitude_out']?.toString(),
      longitudeOut: json['longitude_out']?.toString(),
      imageOut: json['image_out']?.toString(),
      shiftStartTime: json['shift_start_time']?.toString() ?? '',
      shiftEndTime: json['shift_end_time']?.toString() ?? '',
      checkInStatus: json['check_in_status']?.toString() ?? '',
      checkOutStatus: json['check_out_status']?.toString(),
      lateMinutes: int.tryParse(json['late_minutes']?.toString() ?? ''),
      shiftEndDatetime: json['shift_end_datetime']?.toString(),
      checkoutDeadline: json['checkout_deadline']?.toString(),
      workingHours: int.tryParse(json['working_hours']?.toString() ?? ''),
      workingHoursNotes: json['working_hours_notes']?.toString(),
      salaryInfo: json['salary_info'] as Map<String, dynamic>?,
    );
  }

  Color getStatusColor(String? status) {
    switch (status) {
      case 'tepat_waktu':
        return Colors.green;
      case 'terlambat':
        return Colors.red;
      case 'pulang_cepat':
        return Colors.orange;
      case 'tidak_absen':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String? status) {
    switch (status) {
      case 'tepat_waktu':
        return 'sesuai';
      case 'terlambat':
        return 'Terlambat';
      case 'pulang_cepat':
        return 'Pulang Cepat';
      case 'tidak_absen':
        return 'Tidak Absen';
      default:
        return '-';
    }
  }
}
