import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/child.dart';
import '../models/institution.dart';
import '../models/schedule.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  static Database? _database;
  final _uuid = const Uuid();

  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pickup_pal_local.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE children(
            id TEXT PRIMARY KEY,
            name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE institutions(
            id TEXT PRIMARY KEY,
            name TEXT,
            contactNumber TEXT,
            memo TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE schedules(
            id TEXT PRIMARY KEY,
            childId TEXT,
            childName TEXT,
            institutionId TEXT,
            institutionName TEXT,
            type TEXT,
            daysOfWeek TEXT,
            time TEXT,
            notificationLeadTimeInMinutes INTEGER,
            isEnabled INTEGER,
            memo TEXT
          )
        ''');
      },
      // 기존 사용자(버전 1)를 위한 업그레이드 로직
      onUpgrade: (db, oldVersion, newVersion) async {
        // [중요] 기존 사용자(업데이트 유저) 감지 로직
        // 버전 4 미만(즉, 이번 업데이트 이전)에서 업데이트하는 경우
        if (oldVersion < 4) {
          final prefs = await SharedPreferences.getInstance();
          // "이 사용자는 기존 사용자입니다"라는 플래그 저장
          await prefs.setBool('is_legacy_user_grant_pending', true);
        }

        if (oldVersion < 2) {
          // institutions 테이블에 memo 컬럼 추가
          await db.execute('ALTER TABLE institutions ADD COLUMN memo TEXT');
        }
      },
    );
  }

  // --- Children ---
  Future<List<Child>> getChildren() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('children');
    return List.generate(maps.length, (i) => Child.fromMap(maps[i]));
  }

  Future<String> addChild(String name) async {
    final db = await database;
    final id = _uuid.v4(); // 로컬 ID 생성
    await db.insert('children', {'id': id, 'name': name});
    return id;
  }

  Future<void> updateChild(Child child) async {
    final db = await database;
    await db.update('children', child.toMap(), where: 'id = ?', whereArgs: [child.id]);
    // 연결된 스케줄 이름 업데이트
    await db.rawUpdate('UPDATE schedules SET childName = ? WHERE childId = ?', [child.name, child.id]);
  }

  Future<void> deleteChild(String id) async {
    final db = await database;
    await db.delete('children', where: 'id = ?', whereArgs: [id]);
    await db.delete('schedules', where: 'childId = ?', whereArgs: [id]);
  }

  // --- Institutions ---
  Future<List<Institution>> getInstitutions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('institutions');
    return List.generate(maps.length, (i) => Institution.fromMap(maps[i]));
  }

  Future<String> addInstitution(String name, String contactNumber, String memo) async {
    final db = await database;
    final id = _uuid.v4();
    await db.insert('institutions', {
      'id': id,
      'name': name,
      'contactNumber': contactNumber,
      'memo': memo
    });
    return id;
  }

  Future<void> updateInstitution(Institution inst) async {
    final db = await database;
    await db.update('institutions', inst.toMap(), where: 'id = ?', whereArgs: [inst.id]);
    await db.rawUpdate('UPDATE schedules SET institutionName = ? WHERE institutionId = ?', [inst.name, inst.id]);
  }

  Future<void> deleteInstitution(String id) async {
    final db = await database;
    await db.delete('institutions', where: 'id = ?', whereArgs: [id]);
    await db.delete('schedules', where: 'institutionId = ?', whereArgs: [id]);
  }

  // --- Schedules ---
  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('schedules');
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  Future<String> addSchedule(Schedule schedule) async {
    final db = await database;
    String id = schedule.id.isEmpty ? _uuid.v4() : schedule.id;
    // ID가 없으면 생성, 있으면 그대로 사용
    final newSchedule = schedule.copyWith(id: id);
    await db.insert('schedules', newSchedule.toMap());
    return id;
  }

  Future<void> updateSchedule(Schedule schedule) async {
    final db = await database;
    await db.update('schedules', schedule.toMap(), where: 'id = ?', whereArgs: [schedule.id]);
  }

  Future<void> deleteSchedule(String id) async {
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  // 동기화 후 로컬 데이터 삭제
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('schedules');
    await db.delete('children');
    await db.delete('institutions');
  }
}