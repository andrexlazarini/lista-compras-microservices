class Task {
  final int? id;
  final String title;
  final String description;
  final String priority;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Câmera
  final String? photoPath;
  final String? photoUrl; // URL no S3 (LocalStack)

  // Sensores
  final DateTime? completedAt;
  final String? completedBy; // 'manual' | 'shake'

  // GPS
  final double? latitude;
  final double? longitude;
  final String? locationName;

  // Sincronização
  final bool isSynced; // true = sincronizado com servidor

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.priority,
    this.completed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.photoPath,
    this.photoUrl,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'priority': priority,
    'completed': completed ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'photoPath': photoPath,
    'photoUrl': photoUrl,
    'completedAt': completedAt?.toIso8601String(),
    'completedBy': completedBy,
    'latitude': latitude,
    'longitude': longitude,
    'locationName': locationName,
    'isSynced': isSynced ? 1 : 0,
  };

  factory Task.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];
    final updatedAtRaw = map['updatedAt'];

    final created = createdAtRaw is String
        ? DateTime.parse(createdAtRaw)
        : DateTime.now();

    final updated =
    updatedAtRaw is String ? DateTime.parse(updatedAtRaw) : created;

    // completed pode vir como int (sqlite), bool (api) ou null
    final completedRaw = map['completed'];
    final completed = completedRaw is bool
        ? completedRaw
        : (completedRaw is int ? completedRaw == 1 : false);

    // isSynced pode vir null (assume true quando vem do servidor)
    final isSyncedRaw = map['isSynced'];
    final isSynced =
    isSyncedRaw == null ? true : (isSyncedRaw as int) == 1;

    return Task(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      priority: (map['priority'] as String?) ?? 'medium',
      completed: completed,
      createdAt: created,
      updatedAt: updated,
      photoPath: map['photoPath'] as String?,
      photoUrl: map['photoUrl'] as String?,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      completedBy: map['completedBy'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationName: map['locationName'] as String?,
      isSynced: isSynced,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? photoPath,
    String? photoUrl,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
    bool? isSynced,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
