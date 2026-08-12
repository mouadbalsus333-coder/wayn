enum TaskStatus { active, paused, completed, archived }

enum TaskScope { general, city, place, category, dataGap }

enum TaskAssignmentStatus {
  assigned,
  inProgress,
  submitted,
  completed,
  rejected,
}

class Task {
  final String id;
  final String title;
  final String? description;
  final String? placeId;
  final String? city;
  final String? categoryId;
  final TaskStatus status;
  final TaskScope scope;
  final int rewardPoints;
  final bool requiresReview;
  final DateTime createdAt;
  final DateTime? deadlineAt;
  final Map<String, dynamic> metadata;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.placeId,
    this.city,
    this.categoryId,
    required this.status,
    required this.scope,
    this.rewardPoints = 0,
    this.requiresReview = true,
    required this.createdAt,
    this.deadlineAt,
    this.metadata = const {},
  });

  factory Task.fromMap(Map<String, dynamic> data) {
    return Task(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString(),
      placeId: data['place_id']?.toString(),
      city: data['city']?.toString(),
      categoryId: data['category_id']?.toString(),
      status: TaskStatusParser.fromString(data['status']?.toString() ?? ''),
      scope: TaskScopeParser.fromString(data['scope']?.toString() ?? ''),
      rewardPoints: _intValue(data['reward_points']),
      requiresReview: _boolValue(data['requires_review']),
      createdAt: _dateTimeValue(data['created_at']) ?? DateTime.now(),
      deadlineAt: _dateTimeValue(data['deadline_at']),
      metadata: _mapValue(data['metadata']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'place_id': placeId,
      'city': city,
      'category_id': categoryId,
      'status': status.name,
      'scope': scope.name,
      'reward_points': rewardPoints,
      'requires_review': requiresReview,
      'created_at': createdAt.toIso8601String(),
      'deadline_at': deadlineAt?.toIso8601String(),
      'metadata': metadata,
    }..removeWhere((key, value) => value == null);
  }
}

class TaskStatusParser {
  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TaskStatus.active,
    );
  }
}

class TaskScopeParser {
  static TaskScope fromString(String value) {
    return TaskScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => TaskScope.general,
    );
  }
}

class TaskAssignmentStatusParser {
  static TaskAssignmentStatus fromString(String value) {
    return TaskAssignmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TaskAssignmentStatus.assigned,
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return false;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  return {};
}
