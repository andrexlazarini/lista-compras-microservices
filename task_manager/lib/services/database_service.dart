import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('task_manager.db');
    await _seedIfEmpty(_db!);
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, fileName);

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await _createTasksTable(db);
        await _createSyncQueueTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add offline-first fields
          await db.execute("ALTER TABLE tasks ADD COLUMN updatedAt TEXT");
          await db.execute(
              "ALTER TABLE tasks ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 1");
          await db.execute(
              "UPDATE tasks SET updatedAt = createdAt WHERE updatedAt IS NULL");
          await _createSyncQueueTable(db);
        }
      },
    );
  }

  Future<void> _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        dueDate TEXT,
        isSynced INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER,
        operation TEXT NOT NULL, -- create | update | delete
        payload TEXT NOT NULL,   -- JSON com o snapshot da Task
        timestamp TEXT NOT NULL,
        processed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _seedIfEmpty(Database db) async {
    final countRes =
        await db.rawQuery('SELECT COUNT(*) as c FROM tasks');
    final c = (countRes.first['c'] as int?) ?? 0;
    if (c == 0) {
      final now = DateTime.now().toIso8601String();
      await db.insert('tasks', {
        'title': 'Exemplo: Estudar Flutter',
        'description': 'Abrir o projeto e criar sua primeira tarefa.',
        'priority': 'medium',
        'completed': 0,
        'createdAt': now,
        'updatedAt': now,
        'dueDate': null,
        'isSynced': 1,
      });
    }
  }

  // ---------- CRUD das tarefas ----------

  Future<int> create(Task task) async {
    final db = await database;
    final now = DateTime.now();
    final toSave = task.copyWith(
      createdAt: task.createdAt,
      updatedAt: now,
    );
    return await db.insert(
      'tasks',
      toSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> readAll() async {
    final db = await database;
    final res = await db.query(
      'tasks',
      orderBy: 'createdAt DESC, id DESC',
    );
    return res.map((e) => Task.fromMap(e)).toList();
  }

  Future<Task?> readById(int id) async {
    final db = await database;
    final res = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return Task.fromMap(res.first);
  }

  Future<int> update(Task task) async {
    final db = await database;
    final toSave = task.copyWith(updatedAt: DateTime.now());
    return await db.update(
      'tasks',
      toSave.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(int? id) async {
    if (id == null) return 0;
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('tasks');
  }

  Future<void> markTaskSynced(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'isSynced': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Fila de sincronização (sync_queue) ----------

  Future<int> enqueueSync(String operation, Task task) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final payloadJson = jsonEncode(task.toMap());
    return await db.insert(
      'sync_queue',
      {
        'taskId': task.id,
        'operation': operation, // create | update | delete
        'payload': payloadJson,
        'timestamp': now,
        'processed': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'processed = 0',
      orderBy: 'timestamp ASC, id ASC',
    );
  }

  Future<void> markSyncItemProcessed(int queueId) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'processed': 1},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }
}
