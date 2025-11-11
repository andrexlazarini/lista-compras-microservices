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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            priority TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> _seedIfEmpty(Database db) async {
    final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM tasks');
    final c = (countRes.first['c'] as int?) ?? 0;
    if (c == 0) {
      final now = DateTime.now().toIso8601String();
      await db.insert('tasks', {
        'title': 'Exemplo: Estudar Flutter',
        'description': 'Abrir o projeto e criar sua primeira tarefa.',
        'priority': 'medium',
        'completed': 0,
        'createdAt': now,
      });
    }
  }

  Future<int> create(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Task>> readAll() async {
    final db = await database;
    final res = await db.query('tasks', orderBy: 'createdAt DESC, id DESC');
    return res.map((e) => Task.fromMap(e)).toList();
  }

  Future<int> update(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
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
}