class ScheduleModel {
  final int? id;
  final DateTime date;
  final String title;
  final String? locationName;
  final bool isAllDay;
  final String? startTime;
  final String? memo;
  final int profileId;
  final double? incomeAmount;
  final bool isDeleted;

  ScheduleModel({
    this.id,
    required this.date,
    required this.title,
    this.locationName,
    this.isAllDay = false,
    this.startTime,
    this.memo,
    required this.profileId,
    this.incomeAmount,
    this.isDeleted = false,
  });

  ScheduleModel copyWith({
    int? id,
    DateTime? date,
    String? title,
    String? locationName,
    bool? isAllDay,
    String? startTime,
    String? memo,
    int? profileId,
    double? incomeAmount,
    bool? isDeleted,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      locationName: locationName ?? this.locationName,
      isAllDay: isAllDay ?? this.isAllDay,
      startTime: startTime ?? this.startTime,
      memo: memo ?? this.memo,
      profileId: profileId ?? this.profileId,
      incomeAmount: incomeAmount ?? this.incomeAmount,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'locationName': locationName,
      'isAllDay': isAllDay ? 1 : 0,
      'startTime': startTime,
      'memo': memo,
      'profileId': profileId,
      'incomeAmount': incomeAmount,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      title: map['title'],
      locationName: map['locationName'],
      isAllDay: map['isAllDay'] == 1,
      startTime: map['startTime'],
      memo: map['memo'],
      profileId: map['profileId'] ?? 1,
      incomeAmount: map['incomeAmount'],
      isDeleted: map['isDeleted'] == 1,
    );
  }
}
