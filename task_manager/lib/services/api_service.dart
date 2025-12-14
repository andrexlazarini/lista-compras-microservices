import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';

/// Serviço simples de comunicação com a API REST.
/// Ajuste a [baseUrl] de acordo com o backend usado na disciplina.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Para Android Emulator falando com o host:
  /// use 10.0.2.2. Ajuste porta/caminho conforme seu backend.
  final String baseUrl = 'http://10.0.2.2:3000/tasks';

  Future<List<Task>> fetchAllTasks() async {
    final uri = Uri.parse(baseUrl);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar tarefas no servidor: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => _taskFromServer(e as Map<String, dynamic>)).toList();
  }

  Future<Task?> fetchTaskById(int id) async {
    final uri = Uri.parse('$baseUrl/$id');
    final response = await http.get(uri);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar tarefa $id: ${response.statusCode}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return _taskFromServer(data);
  }

  Future<Task> upsertTask(Task task) async {
    if (task.id == null) {
      // create
      final uri = Uri.parse(baseUrl);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_taskToServer(task)),
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Erro ao criar tarefa no servidor: ${response.statusCode}');
      }
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return _taskFromServer(data);
    } else {
      // update
      final uri = Uri.parse('$baseUrl/${task.id}');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_taskToServer(task)),
      );
      if (response.statusCode != 200) {
        throw Exception('Erro ao atualizar tarefa no servidor: ${response.statusCode}');
      }
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return _taskFromServer(data);
    }
  }

  Future<void> deleteTask(int id) async {
    final uri = Uri.parse('$baseUrl/$id');
    final response = await http.delete(uri);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao deletar tarefa $id no servidor: ${response.statusCode}');
    }
  }

  // ----------------------------------------------
  // Mapeamentos entre modelo local e JSON da API
  // ----------------------------------------------
  Map<String, dynamic> _taskToServer(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'completed': task.completed,
      'priority': task.priority,
      'createdAt': task.createdAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'dueDate': task.dueDate?.toIso8601String(),
    };
  }

  Task _taskFromServer(Map<String, dynamic> json) {
    // Aqui assumimos que o backend envia campos compatíveis.
    // Ajuste se for diferente.
    return Task(
      id: json['id'] as int?,
      title: json['title'] as String,
      description: (json['description'] ?? '') as String,
      completed: (json['completed'] ?? false) as bool,
      priority: (json['priority'] ?? 'medium') as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      isSynced: true,
    );
  }
}
