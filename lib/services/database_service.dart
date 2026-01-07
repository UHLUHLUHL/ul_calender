import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/income_model.dart';
import '../models/schedule_model.dart';
import '../models/profile_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'calendar_app_v5.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE schedules ADD COLUMN isDeleted INTEGER DEFAULT 0',
        );
      } catch (e) {
        print("Migration warning: isDeleted column might already exist. $e");
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE profiles ADD COLUMN userId TEXT');
        await db.execute('ALTER TABLE incomes ADD COLUMN userId TEXT');
        await db.execute('ALTER TABLE schedules ADD COLUMN userId TEXT');
      } catch (e) {
        print("Migration warning: userId column might already exist. $e");
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Profiles
    await db.execute('''
      CREATE TABLE profiles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        colorValue INTEGER,
        userId TEXT
      )
    ''');

    // Insert Default Profile (One UI Blue)
    // 기본 프로필은 userId가 없는 로컬 공용으로 유지하거나, 앱 로직에서 처리
    await db.insert(
      'profiles',
      ProfileModel(name: '기본', colorValue: 0xFF339AF0).toMap(),
    );

    // 2. Incomes
    await db.execute('''
      CREATE TABLE incomes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        amount REAL,
        category TEXT,
        profileId INTEGER,
        description TEXT,
        deletedAt TEXT,
        userId TEXT
      )
    ''');

    // 3. Schedules
    await db.execute('''
      CREATE TABLE schedules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        title TEXT,
        locationName TEXT,
        isAllDay INTEGER,
        startTime TEXT,
        memo TEXT,
        profileId INTEGER,
        incomeAmount REAL,
        deletedAt TEXT,
        isDeleted INTEGER DEFAULT 0,
        userId TEXT
      )
    ''');
  }

  // Helper helper to build userId where clause
  String _userIdWhere(String? userId) {
    if (userId == null) {
      return "userId IS NULL";
    } else {
      return "userId = '$userId'";
    }
  }

  // Profile CRUD
  Future<int> insertProfile(ProfileModel profile, String? userId) async {
    final db = await database;
    final data = profile.toMap();
    data['userId'] = userId;
    return await db.insert('profiles', data);
  }

  Future<List<ProfileModel>> getProfiles(String? userId) async {
    final db = await database;
    final maps = await db.query('profiles', where: _userIdWhere(userId));
    // 기본 프로필이 없을 경우(새로운 계정 등), 기본 프로필 자동 생성 로직은 Provider에서 처리하거나 여기서 처리
    return List.generate(maps.length, (i) => ProfileModel.fromMap(maps[i]));
  }

  Future<void> updateProfile(ProfileModel profile, String? userId) async {
    final db = await database;
    final data = profile.toMap();
    data['userId'] = userId;
    await db.update(
      'profiles',
      data,
      where: 'id = ? AND ${_userIdWhere(userId)}',
      whereArgs: [profile.id],
    );
  }

  // Upsert for Profile Sync
  Future<void> upsertProfile(ProfileModel profile, String? userId) async {
    final db = await database;
    final data = profile.toMap();
    data['userId'] = userId;
    final List<Map<String, dynamic>> maps = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    if (maps.isNotEmpty) {
      await db.update(
        'profiles',
        data,
        where: 'id = ?',
        whereArgs: [profile.id],
      );
    } else {
      await db.insert('profiles', data);
    }
  }

  Future<List<ProfileModel>> getAllProfiles(String? userId) async {
    final db = await database;
    final maps = await db.query('profiles', where: _userIdWhere(userId));
    return List.generate(maps.length, (i) => ProfileModel.fromMap(maps[i]));
  }

  Future<void> deleteProfile(int id, String? userId) async {
    final db = await database;
    final userFilter = _userIdWhere(userId);
    await db.delete(
      'schedules',
      where: 'profileId = ? AND $userFilter',
      whereArgs: [id],
    );
    await db.delete(
      'incomes',
      where: 'profileId = ? AND $userFilter',
      whereArgs: [id],
    );
    await db.delete(
      'profiles',
      where: 'id = ? AND $userFilter',
      whereArgs: [id],
    );
  }

  // Income CRUD
  Future<int> insertIncome(IncomeModel income, String? userId) async {
    final db = await database;
    final data = income.toMap();
    data['userId'] = userId;
    return await db.insert('incomes', data);
  }

  Future<List<IncomeModel>> getIncomes(DateTime date, String? userId) async {
    final db = await database;
    final String dateStr = date.toIso8601String().split('T')[0];
    final List<Map<String, dynamic>> maps = await db.query(
      'incomes',
      where: "date LIKE ? AND deletedAt IS NULL AND ${_userIdWhere(userId)}",
      whereArgs: ['$dateStr%'],
    );
    return List.generate(maps.length, (i) => IncomeModel.fromMap(maps[i]));
  }

  Future<List<IncomeModel>> getMonthlyIncomes(
    int year,
    int month,
    String? userId,
  ) async {
    final db = await database;
    final String prefix = "$year-${month.toString().padLeft(2, '0')}";
    final List<Map<String, dynamic>> maps = await db.query(
      'incomes',
      where: "date LIKE ? AND deletedAt IS NULL AND ${_userIdWhere(userId)}",
      whereArgs: ['$prefix%'],
    );
    return List.generate(maps.length, (i) => IncomeModel.fromMap(maps[i]));
  }

  // Upsert for Income Sync
  Future<void> upsertIncome(IncomeModel income, String? userId) async {
    final db = await database;
    final data = income.toMap();
    data['userId'] = userId;
    final List<Map<String, dynamic>> maps = await db.query(
      'incomes',
      where: 'id = ?',
      whereArgs: [income.id],
    );
    if (maps.isNotEmpty) {
      await db.update('incomes', data, where: 'id = ?', whereArgs: [income.id]);
    } else {
      await db.insert('incomes', data);
    }
  }

  Future<List<IncomeModel>> getAllIncomes(String? userId) async {
    final db = await database;
    final maps = await db.query('incomes', where: _userIdWhere(userId));
    return List.generate(maps.length, (i) => IncomeModel.fromMap(maps[i]));
  }

  // Schedule CRUD
  Future<int> insertSchedule(ScheduleModel schedule, String? userId) async {
    final db = await database;
    final data = schedule.toMap();
    data['userId'] = userId;
    return await db.insert('schedules', data);
  }

  Future<void> updateSchedule(ScheduleModel schedule, String? userId) async {
    final db = await database;
    final data = schedule.toMap();
    data['userId'] = userId;

    await db.update(
      'schedules',
      data,
      where: 'id = ? AND ${_userIdWhere(userId)}',
      whereArgs: [schedule.id],
    );
  }

  Future<List<ScheduleModel>> getSchedules(
    DateTime date,
    String? userId,
  ) async {
    final db = await database;
    final String dateStr = date.toIso8601String().split('T')[0];
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: "date LIKE ? AND deletedAt IS NULL AND ${_userIdWhere(userId)}",
      whereArgs: ['$dateStr%'],
    );
    return List.generate(maps.length, (i) => ScheduleModel.fromMap(maps[i]));
  }

  // Upsert for sync
  Future<void> upsertSchedule(ScheduleModel schedule, String? userId) async {
    final db = await database;
    final data = schedule.toMap();
    data['userId'] = userId;

    // Check if ID exists
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: 'id = ?', // 로컬 ID 기준
      whereArgs: [schedule.id],
    );
    if (maps.isNotEmpty) {
      await db.update(
        'schedules',
        data,
        where: 'id = ?',
        whereArgs: [schedule.id],
      );
    } else {
      await db.insert('schedules', data);
    }
  }

  Future<List<ScheduleModel>> getMonthlySchedules(
    int year,
    int month,
    String? userId,
  ) async {
    final db = await database;
    final String prefix = "$year-${month.toString().padLeft(2, '0')}";
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: "date LIKE ? AND deletedAt IS NULL AND ${_userIdWhere(userId)}",
      whereArgs: ['$prefix%'],
    );
    return List.generate(maps.length, (i) => ScheduleModel.fromMap(maps[i]));
  }

  // New: Range Query for Outside Days Markers
  Future<List<ScheduleModel>> getSchedulesForRange(
    DateTime start,
    DateTime end,
    String? userId,
  ) async {
    final db = await database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where:
          "date >= ? AND date <= ? AND deletedAt IS NULL AND ${_userIdWhere(userId)}",
      whereArgs: [startStr, endStr],
    );
    return List.generate(maps.length, (i) => ScheduleModel.fromMap(maps[i]));
  }

  // New: For Full Sync Push
  Future<List<ScheduleModel>> getAllSchedules(String? userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: _userIdWhere(userId),
    );
    return List.generate(maps.length, (i) => ScheduleModel.fromMap(maps[i]));
  }

  Future<ScheduleModel?> getScheduleById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ScheduleModel.fromMap(maps.first);
  }

  // Trash (Soft Delete)
  Future<void> softDeleteSchedule(int id, String? userId) async {
    final db = await database;
    await db.update(
      'schedules',
      {'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ? AND ${_userIdWhere(userId)}',
      whereArgs: [id],
    );
  }

  Future<void> restoreSchedule(int id, String? userId) async {
    final db = await database;
    await db.update(
      'schedules',
      {'deletedAt': null},
      where: 'id = ? AND ${_userIdWhere(userId)}',
      whereArgs: [id],
    );
  }

  Future<void> permanentlyDeleteSchedule(int id, String? userId) async {
    final db = await database;
    await db.delete(
      'schedules',
      where: 'id = ? AND ${_userIdWhere(userId)}',
      whereArgs: [id],
    );
  }

  Future<List<ScheduleModel>> getTrashedSchedules(String? userId) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where:
          "deletedAt IS NOT NULL AND deletedAt > ? AND ${_userIdWhere(userId)}",
      whereArgs: [cutoff],
    );
    return List.generate(maps.length, (i) => ScheduleModel.fromMap(maps[i]));
  }

  // Auto cleanup old trash
  Future<void> cleanupOldTrash() async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    await db.delete(
      'schedules',
      where: "deletedAt IS NOT NULL AND deletedAt < ?",
      whereArgs: [cutoff],
    );
    await db.delete(
      'incomes',
      where: "deletedAt IS NOT NULL AND deletedAt < ?",
      whereArgs: [cutoff],
    );
  }

  // Search
  Future<List<ScheduleModel>> searchSchedules(
    String query,
    String? userId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where:
          "(title LIKE ? OR memo LIKE ?) AND deletedAt IS NULL AND ${_userIdWhere(userId)}",
      whereArgs: ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => ScheduleModel.fromMap(maps[i]));
  }
}
