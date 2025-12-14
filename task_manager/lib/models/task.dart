class Task {
  final int? id;
  final String title;
  final String description;
  final bool completed;
  final String priority; // 'low' | 'medium' | 'high' | 'urgent'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final bool isSynced; // false = pendente de sincronização

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.dueDate,
    this.isSynced = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    bool? isSynced,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      dueDate: dueDate ?? this.dueDate,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final createdAtStr = (map['createdAt'] ?? DateTime.now().toIso8601String()) as String;
    final updatedAtStr = (map['updatedAt'] ?? createdAtStr) as String;

    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] ?? '') as String,
      completed: (map['completed'] ?? 0) == 1,
      priority: (map['priority'] ?? 'medium') as String,
      createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtStr) ?? DateTime.now(),
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'] as String)
          : null,
      isSynced: (map['isSynced'] ?? 1) == 1,
    );
  }
}
