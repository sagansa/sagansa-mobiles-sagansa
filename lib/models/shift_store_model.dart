class ShiftStoreModel {
  final int id;
  final String name;
  final String shiftStartTime;
  final String shiftEndTime;

  ShiftStoreModel({
    required this.id,
    required this.name,
    required this.shiftStartTime,
    required this.shiftEndTime,
  });

  factory ShiftStoreModel.fromJson(Map<String, dynamic> json) {
    return ShiftStoreModel(
      id: json['id'],
      name: json['name'],
      shiftStartTime: json['shift_start_time'],
      shiftEndTime: json['shift_end_time'],
    );
  }
}
