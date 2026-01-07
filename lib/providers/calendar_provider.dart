import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/income_model.dart';
import '../models/schedule_model.dart';
import '../models/profile_model.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_calendar/device_calendar.dart';

/// v6.0: Firestore 전용 CalendarProvider
/// 로컬 DB를 사용하지 않고 Firestore만 사용합니다.
class CalendarProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // Stream Subscriptions
  StreamSubscription<List<ProfileModel>>? _profilesSub;
  StreamSubscription<List<ScheduleModel>>? _schedulesSub;
  StreamSubscription<List<IncomeModel>>? _incomesSub;
  StreamSubscription<List<ScheduleModel>>? _trashedSub;

  // Date State
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  // Data State (Firestore에서 실시간으로 업데이트됨)
  List<IncomeModel> _allIncomes = [];
  List<ScheduleModel> _allSchedules = [];
  List<ProfileModel> _profiles = [];
  List<ScheduleModel> _searchResults = [];
  List<ScheduleModel> _trashedSchedules = [];

  // Filtering & Profiles
  Set<int> _visibleProfileIds = {};
  ProfileModel? _currentProfile;

  // Colors
  static const Color kAmountBlue = Color(0xFF1971C2);
  static const Color kAmountPurple = Color(0xFFA594F9);

  // Stats
  double _monthlyIncomeTotal = 0;
  int _monthlyCountTotal = 0;
  Map<int, double> _profileMonthlyTotals = {};
  Map<int, int> _profileMonthlyCounts = {};

  // Device Calendar
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  List<Event> _monthlyDeviceEvents = [];

  // Getters
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  CalendarFormat get calendarFormat => _calendarFormat;

  List<IncomeModel> get dailyIncomes => _allIncomes
      .where(
        (i) =>
            _isSameDay(i.date, _selectedDate) &&
            _visibleProfileIds.contains(i.profileId),
      )
      .toList();

  List<ScheduleModel> get dailySchedules => _allSchedules
      .where(
        (s) =>
            _isSameDay(s.date, _selectedDate) &&
            _visibleProfileIds.contains(s.profileId),
      )
      .toList();

  List<ScheduleModel> get cachedMonthlySchedules => _allSchedules
      .where((s) => _visibleProfileIds.contains(s.profileId))
      .toList();

  List<ProfileModel> get profiles => _profiles;
  List<ScheduleModel> get searchResults => _searchResults;
  List<ScheduleModel> get trashedSchedules => _trashedSchedules;
  ProfileModel? get currentProfile => _currentProfile;
  double get monthlyIncomeTotal => _monthlyIncomeTotal;
  int get monthlyCountTotal => _monthlyCountTotal;
  Map<int, double> get profileMonthlyTotals => _profileMonthlyTotals;
  Map<int, int> get profileMonthlyCounts => _profileMonthlyCounts;
  Set<int> get visibleProfileIds => _visibleProfileIds;
  List<Event> get monthlyDeviceEvents => _monthlyDeviceEvents;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  CalendarProvider() {
    _setupAuthListener();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  // Helper to determine text color based on background
  static bool isLightColor(int colorValue) {
    final color = Color(colorValue);
    double luminance = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    return luminance > 0.6;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint("Auth state changed. User: ${user?.uid}");
      _cancelSubscriptions();
      clearData();
      if (user != null) {
        _setupStreams(user.uid);
      }
    });
  }

  void _cancelSubscriptions() {
    _profilesSub?.cancel();
    _schedulesSub?.cancel();
    _incomesSub?.cancel();
    _trashedSub?.cancel();
    _profilesSub = null;
    _schedulesSub = null;
    _incomesSub = null;
    _trashedSub = null;
  }

  void clearData() {
    _allIncomes = [];
    _allSchedules = [];
    _profiles = [];
    _searchResults = [];
    _trashedSchedules = [];
    _visibleProfileIds = {};
    _currentProfile = null;
    _monthlyIncomeTotal = 0;
    _monthlyCountTotal = 0;
    _profileMonthlyTotals = {};
    _profileMonthlyCounts = {};
    _monthlyDeviceEvents = [];
    notifyListeners();
  }

  /// Firestore 실시간 스트림 설정
  void _setupStreams(String userId) {
    debugPrint("Setting up Firestore streams for $userId");

    // 1. Profiles Stream (가장 먼저)
    _profilesSub = _firestoreService.profilesStream(userId).listen((profiles) {
      debugPrint("Received ${profiles.length} profiles from Firestore");
      _profiles = profiles;
      if (_profiles.isNotEmpty) {
        // 새로 추가된 프로필 ID를 visibleProfileIds에 추가
        final currentProfileIds = _profiles.map((p) => p.id!).toSet();

        if (_visibleProfileIds.isEmpty) {
          // 처음이면 모든 프로필을 표시
          _visibleProfileIds = currentProfileIds;
        } else {
          // 새로 추가된 프로필 ID 찾아서 추가
          final newIds = currentProfileIds.difference(_visibleProfileIds);
          if (newIds.isNotEmpty) {
            debugPrint("Adding new profile IDs to visible: $newIds");
            _visibleProfileIds.addAll(newIds);
          }
        }

        if (_currentProfile == null ||
            !_profiles.any((p) => p.id == _currentProfile?.id)) {
          _currentProfile = _profiles.first;
        }
      } else {
        // 프로필이 없으면 기본 프로필 생성
        _createDefaultProfile(userId);
      }
      _recalculateStats();
      notifyListeners();
    }, onError: (e) => debugPrint("Profiles stream error: $e"));

    // 2. Schedules Stream
    _schedulesSub = _firestoreService.schedulesStream(userId).listen((
      schedules,
    ) {
      debugPrint("Received ${schedules.length} schedules from Firestore");
      _allSchedules = schedules;
      _recalculateStats();
      notifyListeners();
    }, onError: (e) => debugPrint("Schedules stream error: $e"));

    // 3. Incomes Stream
    _incomesSub = _firestoreService.incomesStream(userId).listen((incomes) {
      debugPrint("Received ${incomes.length} incomes from Firestore");
      _allIncomes = incomes;
      _recalculateStats();
      notifyListeners();
    }, onError: (e) => debugPrint("Incomes stream error: $e"));

    // 4. Trashed Schedules Stream
    _trashedSub = _firestoreService.trashedSchedulesStream(userId).listen((
      trashed,
    ) {
      _trashedSchedules = trashed;
      notifyListeners();
    }, onError: (e) => debugPrint("Trashed stream error: $e"));

    // Device Calendar 로드
    _loadDeviceEvents();
  }

  Future<void> _createDefaultProfile(String userId) async {
    debugPrint("Creating default profile for new user");
    await addNewProfile("기본", 0xFF339AF0);
  }

  void _recalculateStats() {
    double total = 0;
    int countTotal = 0;
    Map<int, double> pTotals = {};
    Map<int, int> pCounts = {};

    final validProfileIds = _profiles.map((p) => p.id!).toSet();
    final targetYear = _focusedDate.year;
    final targetMonth = _focusedDate.month;

    for (var i in _allIncomes) {
      if (!validProfileIds.contains(i.profileId)) continue;
      if (i.date.year == targetYear && i.date.month == targetMonth) {
        if (_visibleProfileIds.contains(i.profileId)) {
          total += i.amount;
          countTotal++;
          pTotals[i.profileId] = (pTotals[i.profileId] ?? 0) + i.amount;
          pCounts[i.profileId] = (pCounts[i.profileId] ?? 0) + 1;
        }
      }
    }

    for (var s in _allSchedules) {
      if (!validProfileIds.contains(s.profileId)) continue;
      if (s.date.year == targetYear && s.date.month == targetMonth) {
        if (_visibleProfileIds.contains(s.profileId)) {
          double income = s.incomeAmount ?? 0;
          total += income;
          countTotal++;
          if (income > 0) {
            pTotals[s.profileId] = (pTotals[s.profileId] ?? 0) + income;
          }
          pCounts[s.profileId] = (pCounts[s.profileId] ?? 0) + 1;
        }
      }
    }

    _monthlyIncomeTotal = total;
    _monthlyCountTotal = countTotal;
    _profileMonthlyTotals = pTotals;
    _profileMonthlyCounts = pCounts;
  }

  // ===================
  // PROFILE ACTIONS
  // ===================
  void toggleProfileVisibility(int profileId) {
    if (_visibleProfileIds.contains(profileId)) {
      _visibleProfileIds.remove(profileId);
    } else {
      _visibleProfileIds.add(profileId);
    }
    _recalculateStats();
    notifyListeners();
  }

  void selectProfileForCreation(ProfileModel p) {
    _currentProfile = p;
    notifyListeners();
  }

  Future<void> addNewProfile(String name, int colorValue) async {
    if (currentUserId == null) return;
    final profile = ProfileModel(name: name, colorValue: colorValue);
    await _firestoreService.addProfile(profile, currentUserId!);
    // 스트림이 자동으로 업데이트합니다
  }

  Future<void> updateProfile(ProfileModel p) async {
    if (currentUserId == null) return;
    await _firestoreService.updateProfile(p, currentUserId!);
  }

  Future<void> deleteProfile(int id) async {
    if (currentUserId == null) return;
    if (_profiles.length <= 1) return;
    _visibleProfileIds.remove(id);
    await _firestoreService.deleteProfile(id, currentUserId!);
  }

  // ===================
  // DATE ACTIONS
  // ===================
  void onDateSelected(DateTime selected, DateTime focused) {
    _selectedDate = selected;
    _focusedDate = focused;
    notifyListeners();
  }

  Future<void> onPageChanged(DateTime focused) async {
    debugPrint("Page changed to: ${focused.year}년 ${focused.month}월");
    _focusedDate = focused;
    _recalculateStats();
    await _loadDeviceEvents();
    notifyListeners();
  }

  // ===================
  // SCHEDULE ACTIONS
  // ===================
  Future<void> addSchedule(ScheduleModel schedule) async {
    if (currentUserId == null) return;
    await _firestoreService.addSchedule(schedule, currentUserId!);
    // 스트림이 자동으로 업데이트합니다
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    if (currentUserId == null) return;
    await _firestoreService.updateSchedule(schedule, currentUserId!);
  }

  Future<void> trashSchedule(ScheduleModel schedule) async {
    if (currentUserId == null || schedule.id == null) return;
    await _firestoreService.softDeleteSchedule(schedule.id!, currentUserId!);
  }

  Future<void> restoreSchedule(int id) async {
    if (currentUserId == null) return;
    await _firestoreService.restoreSchedule(id, currentUserId!);
  }

  Future<void> permanentlyDeleteSchedule(int id) async {
    if (currentUserId == null) return;
    await _firestoreService.deleteSchedule(id, currentUserId!);
  }

  Future<void> loadTrashedSchedules() async {
    // 스트림으로 자동 로드됨
    notifyListeners();
  }

  // ===================
  // SEARCH
  // ===================
  Future<void> search(String query) async {
    if (currentUserId == null) return;
    if (query.isEmpty) {
      _searchResults = [];
    } else {
      _searchResults = await _firestoreService.searchSchedules(
        query,
        currentUserId!,
      );
    }
    notifyListeners();
  }

  // ===================
  // UTILITY
  // ===================
  ProfileModel getProfileById(int id) {
    return _profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => ProfileModel(id: 0, name: '삭제됨', colorValue: 0xFF868E96),
    );
  }

  // ===================
  // DEVICE CALENDAR
  // ===================
  Future<void> _loadDeviceEvents() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          return;
        }
      }

      final startDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 20);
      final endDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 10);

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        List<Event> allEvents = [];
        for (var calendar in calendarsResult.data!) {
          final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(startDate: startDate, endDate: endDate),
          );
          if (eventsResult.isSuccess && eventsResult.data != null) {
            allEvents.addAll(eventsResult.data!.whereType<Event>());
          }
        }
        _monthlyDeviceEvents = allEvents;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading device events: $e");
    }
  }
}
