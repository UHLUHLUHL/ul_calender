# 울 캘린더 (Wool Calendar) - 프로젝트 설명 및 백업 🛡️

이 문서는 프로젝트의 핵심 로직과 데이터베이스 구조를 보존하기 위해 작성되었습니다.
**AI 또는 개발자가 코드를 수정하기 전에 반드시 이 문서를 필독해야 합니다.**

---

## 🏗️ 아키텍처 개요

- **아키텍처**: Cloud-Only (로컬 DB 미사용, Firestore 100% 의존)
- **버전**: v6.4 (1.2.4+8)
- **주요 특징**:
  - **실시간 동기화**: `CalendarProvider`에서 Firestore Stream을 구독하여 UI 갱신.
  - **ID 체계**: `DateTime.now().millisecondsSinceEpoch`를 사용하여 **정수(int) ID** 생성 후, Firestore 문서 ID로는 `String` 변환하여 저장. (문서 내부 `id` 필드와 일치 필수)
  - **데이터 삭제**: `isDeleted` (0/1) 필드를 사용한 Soft Delete. **절대 `deletedAt` 필드를 사용하지 말 것.**

---

## 🔒 데이터베이스 구조 (Firestore)

### 1. 컬렉션 경로

모든 데이터는 사용자별(`users/{uid}`) 하위 컬렉션에 저장됩니다.

- `users/{uid}/profiles`: 사용자 프로필 (카테고리)
- `users/{uid}/schedules`: 일정 데이터
- `users/{uid}/incomes`: 수입 데이터 (사용 안 함 가능성 있음, 일정 모델에 통합)

### 2. ScheduleModel (Schedules)

- **필드명 주의**: `isDeleted` (int, 0=활성, 1=삭제), `date` (ISO8601 String)
- **날짜 정규화**: `date` 필드는 반드시 시간 정보를 제외한 **자정(00:00:00)** 기준이어야 함.
- **ID**: `id` 필드는 정수(int)이며, 문서 ID(`doc.id`)와 동일한 숫자여야 함.

---

## 💾 핵심 코드 백업 (Core Code Backup)

이 코드는 프로젝트의 심장입니다. 수정 시 원본 로직을 파괴하지 않도록 주의하세요.

### 1. `lib/models/schedule_model.dart`

*데이터 구조 정의. 필드명 변경 금지.*

```dart
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
```

### 2. `lib/services/firestore_service.dart`

*DB 쿼리 및 날짜 정규화 로직. `where('isDeleted', isEqualTo: 0)` 조건 중요.*

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/schedule_model.dart';
import '../models/profile_model.dart';
import '../models/income_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Collection References ---
  CollectionReference _profilesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('profiles');

  CollectionReference _schedulesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('schedules');

  CollectionReference _incomesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('incomes');

  // 날짜 정규화 (시간 제거)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  // ID 추출 헬퍼 (v6.2 Fix)
  int _extractId(Map<String, dynamic> data, String docId) {
    if (data['id'] != null && data['id'] is int) return data['id'] as int;
    final parsed = int.tryParse(docId);
    if (parsed != null) return parsed;
    return docId.hashCode;
  }

  // ... (Profiles CRUD 생략) ...

  // ======================
  // SCHEDULE CRUD & STREAM
  // ======================
  Stream<List<ScheduleModel>> schedulesStream(String userId) {
    return _schedulesRef(
      userId,
    ).where('isDeleted', isEqualTo: 0).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final id = _extractId(data, doc.id);

        // 날짜 파싱 및 정규화
        final rawDate = DateTime.parse(data['date']);
        final normalizedDate = _normalizeDate(rawDate);

        return ScheduleModel.fromMap({
          ...data,
          'id': id,
          'date': normalizedDate.toIso8601String(),
        });
      }).toList();
    });
  }

  Future<List<ScheduleModel>> getSchedules(String userId) async {
    final snapshot = await _schedulesRef(
      userId,
    ).where('isDeleted', isEqualTo: 0).get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final id = _extractId(data, doc.id);

      final rawDate = DateTime.parse(data['date']);
      final normalizedDate = _normalizeDate(rawDate);

      return ScheduleModel.fromMap({
        ...data,
        'id': id,
        'date': normalizedDate.toIso8601String(),
      });
    }).toList();
  }

  Future<int> addSchedule(ScheduleModel schedule, String userId) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final normalizedSchedule = schedule.copyWith(
      date: _normalizeDate(schedule.date),
    );
    final data = normalizedSchedule.toMap();
    data['id'] = id;
    await _schedulesRef(userId).doc(id.toString()).set(data);
    return id;
  }

  Future<void> updateSchedule(ScheduleModel schedule, String userId) async {
    if (schedule.id == null) return;
    final normalizedSchedule = schedule.copyWith(
      date: _normalizeDate(schedule.date),
    );
    await _schedulesRef(userId)
        .doc(schedule.id.toString())
        .set(normalizedSchedule.toMap(), SetOptions(merge: true));
  }
  
  // Soft Delete (isDeleted 필드 사용)
  Future<void> softDeleteSchedule(int id, String userId) async {
    await _schedulesRef(userId).doc(id.toString()).update({
      'isDeleted': 1,
    });
  }

  Future<void> restoreSchedule(int id, String userId) async {
    await _schedulesRef(userId).doc(id.toString()).update({'isDeleted': 0});
  }
}
```

### 3. `lib/providers/calendar_provider.dart` (주요 로직)

*프로필 필터링 및 데이터 로드 로직. `_setupStreams` 중요.*

```dart
// (Imports 생략)

class CalendarProvider with ChangeNotifier {
  // ... (상태 변수 생략) ...
  
  Set<int> _visibleProfileIds = {};

  // Getter: 일별 스케줄 필터링
  List<ScheduleModel> get dailySchedules => _allSchedules
      .where(
        (s) =>
            _isSameDay(s.date, _selectedDate) &&
            _visibleProfileIds.contains(s.profileId),
      )
      .toList();

  // Firestore 스트림 설정
  void _setupStreams(String userId) {
    // 1. Profiles
    _profilesSub = _firestoreService.profilesStream(userId).listen((profiles) {
      _profiles = profiles;
      if (_profiles.isNotEmpty) {
        // v6.3 Fix: 새 프로필 자동 표시
        final currentProfileIds = _profiles.map((p) => p.id!).toSet();
        if (_visibleProfileIds.isEmpty) {
          _visibleProfileIds = currentProfileIds;
        } else {
          final newIds = currentProfileIds.difference(_visibleProfileIds);
          if (newIds.isNotEmpty) {
            _visibleProfileIds.addAll(newIds);
          }
        }
        // ... (기본 프로필 설정) ...
      } else {
        _createDefaultProfile(userId);
      }
      _recalculateStats();
      notifyListeners();
    });

    // 2. Schedules
    _schedulesSub = _firestoreService.schedulesStream(userId).listen((schedules) {
      _allSchedules = schedules;
      _recalculateStats();
      notifyListeners();
    });
    
    // ... (Incomes, Trashed 생략) ...
  }
  
  // ... (나머지 로직 생략) ...
}
```

---

## ⚠️ 절대 하지 말아야 할 것 ⚠️

1. **`deletedAt` 필드 사용 금지**: 일정 삭제 여부는 오직 `isDeleted` (0 또는 1)로 판단합니다. (쿼리 조건 수정 금지)
2. **`DateTime` 시간 포함 금지**: 일정을 저장할 때 `DateTime.now()` 그대로 저장하지 마세요. 반드시 `_normalizeDate`를 통과시켜 `00:00:00`으로 만들어야 합니다.
3. **Local DB 혼용 금지**: 이 프로젝트는 Firestore Only 입니다. SQLite 코드를 다시 가져오지 마세요.
