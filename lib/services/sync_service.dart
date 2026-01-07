import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/schedule_model.dart';
import '../models/profile_model.dart';
import '../models/income_model.dart';
import 'database_service.dart';

class SyncService {
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Firestore References
  CollectionReference _getUserSchedulesRef(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('schedules');
  }

  CollectionReference _getUserProfilesRef(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('profiles');
  }

  CollectionReference _getUserIncomesRef(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('incomes');
  }

  // --- Profile Sync ---
  Future<void> uploadProfile(ProfileModel profile, String userId) async {
    try {
      if (profile.id == null) return;
      await _getUserProfilesRef(userId)
          .doc(profile.id.toString())
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error uploading profile: $e");
    }
  }

  Future<void> deleteProfile(int id, String userId) async {
    try {
      await _getUserProfilesRef(userId).doc(id.toString()).delete();
    } catch (e) {
      debugPrint("Error deleting profile: $e");
    }
  }

  // --- Income Sync ---
  Future<void> uploadIncome(IncomeModel income, String userId) async {
    try {
      if (income.id == null) return;
      await _getUserIncomesRef(
        userId,
      ).doc(income.id.toString()).set(income.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error uploading income: $e");
    }
  }

  Future<void> deleteIncome(int id, String userId) async {
    try {
      await _getUserIncomesRef(userId).doc(id.toString()).delete();
    } catch (e) {
      debugPrint("Error deleting income: $e");
    }
  }

  // --- Schedule Sync ---
  Future<void> uploadSchedule(ScheduleModel schedule, String userId) async {
    try {
      if (schedule.id == null) return;
      await _getUserSchedulesRef(userId)
          .doc(schedule.id.toString())
          .set(schedule.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error uploading schedule: $e");
    }
  }

  Future<void> deleteSchedule(int id, String userId) async {
    try {
      await _getUserSchedulesRef(userId).doc(id.toString()).delete();
    } catch (e) {
      debugPrint("Error deleting schedule from cloud: $e");
    }
  }

  // --- Full Sync Downloads ---
  Future<void> syncFromServerToLocal(
    DatabaseService dbService,
    String userId,
  ) async {
    try {
      // 1. Sync Profiles FIRST (because schedules/incomes depend on them)
      final profileSnap = await _getUserProfilesRef(userId).get();
      for (var doc in profileSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        try {
          await dbService.upsertProfile(ProfileModel.fromMap(data), userId);
        } catch (e) {
          debugPrint("Error syncing profile: $e");
        }
      }

      // 2. Sync Incomes
      final incomeSnap = await _getUserIncomesRef(userId).get();
      for (var doc in incomeSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        try {
          await dbService.upsertIncome(IncomeModel.fromMap(data), userId);
        } catch (e) {
          debugPrint("Error syncing income: $e");
        }
      }

      // 3. Sync Schedules
      final scheduleSnap = await _getUserSchedulesRef(userId).get();
      debugPrint("Syncing ${scheduleSnap.docs.length} schedules from cloud");
      for (var doc in scheduleSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        try {
          await dbService.upsertSchedule(ScheduleModel.fromMap(data), userId);
        } catch (e) {
          debugPrint("Error syncing schedule: $e");
        }
      }
    } catch (e) {
      debugPrint("Master sync error: $e");
    }
  }

  // --- Full Sync Uploads (Push All) ---
  Future<void> pushAllLocalToCloud(
    DatabaseService dbService,
    String userId,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Push Profiles
      final profiles = await dbService.getAllProfiles(userId);
      final pRef = _getUserProfilesRef(userId);
      for (var p in profiles) {
        if (p.id != null) {
          batch.set(
            pRef.doc(p.id.toString()),
            p.toMap(),
            SetOptions(merge: true),
          );
        }
      }

      // 2. Push Incomes
      final incomes = await dbService.getAllIncomes(userId);
      final iRef = _getUserIncomesRef(userId);
      for (var i in incomes) {
        if (i.id != null) {
          batch.set(
            iRef.doc(i.id.toString()),
            i.toMap(),
            SetOptions(merge: true),
          );
        }
      }

      // 3. Push Schedules
      final schedules = await dbService.getAllSchedules(userId);
      final sRef = _getUserSchedulesRef(userId);
      for (var s in schedules) {
        if (s.id != null) {
          batch.set(
            sRef.doc(s.id.toString()),
            s.toMap(),
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();
      debugPrint("Master full push completed for $userId");
    } catch (e) {
      debugPrint("Master full push error: $e");
    }
  }
}
