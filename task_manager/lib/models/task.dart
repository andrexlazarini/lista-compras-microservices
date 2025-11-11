class Task {
  final int? id;
  final String title;
  final String description;
  final bool completed;
  final String priority; // 'low' | 'medium' | 'high' | 'urgent'
  final DateTime createdAt;
  final DateTime? dueDate;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.completed,
    DateTime? createdAt,
    this.dueDate,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? createdAt,
    DateTime? dueDate,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
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
      'dueDate': dueDate?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] ?? '') as String,
      completed: (map['completed'] ?? 0) == 1,
      priority: (map['priority'] ?? 'medium') as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
    );
  }
}