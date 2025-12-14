import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const String _baseUrl = 'http://10.0.2.2:3000/tasks';

  Uri _uri([String? path]) =>
      Uri.parse(path == null ? _baseUrl : '$_baseUrl/$path');

  Future<List<Task>> fetchTasks() async {
    final resp = await http.get(_uri());
    if (resp.statusCode != 200) {
      throw Exception('Erro ao buscar tarefas: ${resp.statusCode}');
    }
    final List data = jsonDecode(resp.body) as List;
    return data
        .map((e) => Task.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Task?> fetchTaskById(int id) async {
    final resp = await http.get(_uri('$id'));
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw Exception('Erro ao buscar tarefa: ${resp.statusCode}');
    }
    final Map<String, dynamic> data =
    jsonDecode(resp.body) as Map<String, dynamic>;
    return Task.fromMap(data);
  }

  Future<Task> createTask(Task task) async {
    final resp = await http.post(
      _uri(),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(task.toMap()),
    );
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception('Erro ao criar tarefa: ${resp.statusCode}');
    }
    final Map<String, dynamic> data =
    jsonDecode(resp.body) as Map<String, dynamic>;
    return Task.fromMap(data);
  }

  Future<Task> updateTask(Task task) async {
    if (task.id == null) {
      throw Exception('Task sem ID para update');
    }
    final resp = await http.put(
      _uri('${task.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(task.toMap()),
    );
    if (resp.statusCode != 200) {
      throw Exception('Erro ao atualizar tarefa: ${resp.statusCode}');
    }
    final Map<String, dynamic> data =
    jsonDecode(resp.body) as Map<String, dynamic>;
    return Task.fromMap(data);
  }

  Future<void> deleteTask(int id) async {
    final resp = await http.delete(_uri('$id'));
    if (resp.statusCode != 200 &&
        resp.statusCode != 204 &&
        resp.statusCode != 404) {
      throw Exception('Erro ao deletar tarefa: ${resp.statusCode}');
    }
  }
}
