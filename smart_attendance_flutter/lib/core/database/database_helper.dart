import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        registration_number TEXT,
        role TEXT NOT NULL,
        device_uuid TEXT,
        device_bound_at TEXT,
        access_token TEXT,
        refresh_token TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE courses (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        title TEXT NOT NULL,
        lecturer_id TEXT NOT NULL,
        lecturer_name TEXT NOT NULL,
        enrolled_count INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        synced_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_sessions (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        course_code TEXT NOT NULL,
        course_title TEXT NOT NULL,
        created_by TEXT NOT NULL,
        lecturer_name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        started_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        closed_at TEXT,
        venue TEXT,
        notes TEXT,
        session_secret TEXT,
        qr_payload TEXT,
        expiry_unix INTEGER,
        attendance_count INTEGER DEFAULT 0,
        synced_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_records (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        device_uuid TEXT NOT NULL,
        scan_source TEXT NOT NULL DEFAULT 'offline',
        scanned_at TEXT NOT NULL,
        synced_at TEXT,
        idempotency_key TEXT UNIQUE NOT NULL,
        hmac_signature TEXT,
        qr_payload TEXT,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        UNIQUE(student_id, session_id, device_uuid)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('CREATE INDEX idx_records_pending ON attendance_records(pending_sync)');
    await db.execute('CREATE INDEX idx_records_session ON attendance_records(session_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // ── Generic helpers ──────────────────────────────────────────────────────
  Future<int> insert(String table, Map<String, dynamic> data,
          {ConflictAlgorithm conflict = ConflictAlgorithm.replace}) =>
      db.then((d) => d.insert(table, data, conflictAlgorithm: conflict));

  Future<List<Map<String, dynamic>>> query(String table,
          {String? where,
          List<dynamic>? whereArgs,
          String? orderBy,
          int? limit}) =>
      db.then((d) => d.query(table,
          where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit));

  Future<int> update(String table, Map<String, dynamic> data,
          {required String where, required List<dynamic> whereArgs}) =>
      db.then((d) => d.update(table, data, where: where, whereArgs: whereArgs));

  Future<int> delete(String table,
          {required String where, required List<dynamic> whereArgs}) =>
      db.then((d) => d.delete(table, where: where, whereArgs: whereArgs));

  Future<void> rawExecute(String sql, [List<dynamic>? args]) =>
      db.then((d) => d.execute(sql, args));

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
