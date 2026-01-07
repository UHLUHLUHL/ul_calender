import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/schedule_model.dart';
import '../models/profile_model.dart';
import '../models/income_model.dart';

/// Firestore 전용 데이터 서비스 (v6.0)
/// 로컬 DB를 사용하지 않고 Firestore만 사용합니다.
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
  // =====================
  // PROFILE CRUD & STREAM
  // =====================

  /// 문서에서 ID를 안전하게 추출 (내부 id 필드 우선, 없으면 문서 ID 파싱)
  int _extractId(Map<String, dynamic> data, String docId) {
    // 1. 문서 내부의 id 필드 사용 (정수)
    if (data['id'] != null && data['id'] is int) {
      return data['id'] as int;
    }
    // 2. 문서 ID를 정수로 파싱 시도
    final parsed = int.tryParse(docId);
    if (parsed != null) {
      return parsed;
    }
    // 3. 문서 ID의 hashCode 사용 (fallback)
    return docId.hashCode;
  }

  Stream<List<ProfileModel>> profilesStream(String userId) {
    return _profilesRef(userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final id = _extractId(data, doc.id);
        return ProfileModel.fromMap({...data, 'id': id});
      }).toList();
    });
  }

  Future<List<ProfileModel>> getProfiles(String userId) async {
    final snapshot = await _profilesRef(userId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final id = _extractId(data, doc.id);
      return ProfileModel.fromMap({...data, 'id': id});
    }).toList();
  }

  Future<int> addProfile(ProfileModel profile, String userId) async {
    // 타임스탬프 기반 정수 ID 생성
    final id = DateTime.now().millisecondsSinceEpoch;
    final data = profile.toMap();
    data['id'] = id;
    await _profilesRef(userId).doc(id.toString()).set(data);
    debugPrint("Added profile with ID: $id");
    return id;
  }

  Future<void> updateProfile(ProfileModel profile, String userId) async {
    if (profile.id == null) return;
    await _profilesRef(
      userId,
    ).doc(profile.id.toString()).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteProfile(int id, String userId) async {
    await _profilesRef(userId).doc(id.toString()).delete();
    // 해당 프로필과 연결된 일정/수입도 삭제
    final schedules = await _schedulesRef(
      userId,
    ).where('profileId', isEqualTo: id).get();
    for (var doc in schedules.docs) {
      await doc.reference.delete();
    }
    final incomes = await _incomesRef(
      userId,
    ).where('profileId', isEqualTo: id).get();
    for (var doc in incomes.docs) {
      await doc.reference.delete();
    }
  }

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
          'date': normalizedDate.toIso8601String(), // 다시 문자열로 넣어서 fromMap에 전달
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

      // 날짜 파싱 및 정규화
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
    // 타임스탬프 기반 정수 ID 생성
    final id = DateTime.now().millisecondsSinceEpoch;

    // 저장 전 날짜 정규화
    final normalizedSchedule = schedule.copyWith(
      date: _normalizeDate(schedule.date),
    );

    final data = normalizedSchedule.toMap();
    data['id'] = id;
    await _schedulesRef(userId).doc(id.toString()).set(data);
    debugPrint("Added schedule with ID: $id");
    return id;
  }

  Future<void> updateSchedule(ScheduleModel schedule, String userId) async {
    if (schedule.id == null) return;

    // 저장 전 날짜 정규화
    final normalizedSchedule = schedule.copyWith(
      date: _normalizeDate(schedule.date),
    );

    await _schedulesRef(userId)
        .doc(schedule.id.toString())
        .set(normalizedSchedule.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteSchedule(int id, String userId) async {
    await _schedulesRef(userId).doc(id.toString()).delete();
  }

  Future<void> softDeleteSchedule(int id, String userId) async {
    await _schedulesRef(userId).doc(id.toString()).update({'isDeleted': 1});
  }

  Future<void> restoreSchedule(int id, String userId) async {
    await _schedulesRef(userId).doc(id.toString()).update({'isDeleted': 0});
  }

  Stream<List<ScheduleModel>> trashedSchedulesStream(String userId) {
    // deletedAt 필드가 없으므로 일단 30일 필터 없이 삭제된 모든 항목을 가져옴
    // 추후 ScheduleModel에 deletedAt 추가 필요
    return _schedulesRef(userId)
        .where('isDeleted', isEqualTo: 1) // 'deletedAt' 대신 'isDeleted' 사용
        .snapshots()
        .map((snapshot) {
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

  // ====================
  // INCOME CRUD & STREAM
  // ====================
  Stream<List<IncomeModel>> incomesStream(String userId) {
    return _incomesRef(userId).where('isDeleted', isEqualTo: 0).snapshots().map(
      // 'deletedAt' 대신 'isDeleted' 사용
      (snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final id = _extractId(data, doc.id);
          return IncomeModel.fromMap({...data, 'id': id});
        }).toList();
      },
    );
  }

  Future<int> addIncome(IncomeModel income, String userId) async {
    // 타임스탬프 기반 정수 ID 생성
    final id = DateTime.now().millisecondsSinceEpoch;
    final data = income.toMap();
    data['id'] = id;
    await _incomesRef(userId).doc(id.toString()).set(data);
    debugPrint("Added income with ID: $id");
    return id;
  }

  Future<void> updateIncome(IncomeModel income, String userId) async {
    if (income.id == null) return;
    await _incomesRef(
      userId,
    ).doc(income.id.toString()).set(income.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteIncome(int id, String userId) async {
    await _incomesRef(userId).doc(id.toString()).delete();
  }

  // ====================
  // SEARCH
  // ====================
  Future<List<ScheduleModel>> searchSchedules(
    String query,
    String userId,
  ) async {
    // Firestore는 부분 문자열 검색을 기본 지원하지 않으므로,
    // 클라이언트 측 필터링으로 처리합니다.
    final all = await getSchedules(userId);
    final lowerQuery = query.toLowerCase();
    return all
        .where(
          (s) =>
              s.title.toLowerCase().contains(lowerQuery) ||
              (s.memo?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }
}
