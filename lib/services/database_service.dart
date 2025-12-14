import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textType,
        priority $textType,
        completed $intType,
        createdAt $textType,
        updatedAt $textType,
        photoPath TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER,
        operation TEXT NOT NULL, -- create | update | delete
        payload TEXT NOT NULL,   -- JSON com a Task
        timestamp TEXT NOT NULL,
        processed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE tasks ADD COLUMN updatedAt TEXT');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          processed INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Preenche updatedAt = createdAt e marca tudo como sincronizado
      final all = await db.query('tasks');
      for (final row in all) {
        await db.update(
          'tasks',
          {
            'updatedAt': row['createdAt'],
            'isSynced': 1,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  // ---------------------- CRUD tasks ----------------------

  Future<int> create(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<Task?> read(int id) async {
    final db = await instance.database;
    final maps =
    await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Task.fromMap(maps.first);
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await instance.database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> update(Task task) async {
    final db = await database;

    // Usa o toMap completo, que JÁ inclui isSynced, updatedAt, etc.
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }


  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------- Localização ----------------------

  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();
    return allTasks.where((task) {
      if (!task.hasLocation) return false;
      final latDiff = (task.latitude! - latitude).abs();
      final lonDiff = (task.longitude! - longitude).abs();
      final distance =
          ((latDiff * 111000) + (lonDiff * 111000)) / 2;
      return distance <= radiusInMeters;
    }).toList();
  }

  // ---------------------- Fila de sincronização ----------------------

  Future<void> enqueueSync(String operation, Task task) async {
    final db = await instance.database;
    await db.insert('sync_queue', {
      'taskId': task.id,
      'operation': operation,
      'payload': jsonEncode(task.toMap()),
      'timestamp': DateTime.now().toIso8601String(),
      'processed': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await instance.database;
    return db.query(
      'sync_queue',
      where: 'processed = 0',
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> markSyncItemProcessed(int queueId) async {
    final db = await instance.database;
    await db.update(
      'sync_queue',
      {'processed': 1},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
