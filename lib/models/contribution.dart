enum ContributionType {
  addPlaceInfo,
  correctPlaceInfo,
  addPhoto,
  addDescription,
  reportIssue,
  confirmVisit,
  addServiceInfo,
  addGovernmentInfo,
  completeTask,
}

enum ContributionStatus { pending, approved, rejected, needsReview }

class Contribution {
  final String id;
  final String userId;
  final String? placeId;
  final String? taskId;
  final ContributionType type;
  final ContributionStatus status;
  final Map<String, dynamic> payload;
  final int points;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNote;

  const Contribution({
    required this.id,
    required this.userId,
    this.placeId,
    this.taskId,
    required this.type,
    required this.status,
    this.payload = const {},
    this.points = 0,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNote,
  });

  factory Contribution.fromMap(Map<String, dynamic> data) {
    return Contribution(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      placeId: data['place_id']?.toString(),
      taskId: data['task_id']?.toString(),
      type: ContributionTypeParser.fromString(data['type']?.toString() ?? ''),
      status: ContributionStatusParser.fromString(
        data['status']?.toString() ?? '',
      ),
      payload: _mapValue(data['payload']),
      points: _intValue(data['points']),
      createdAt: _dateTimeValue(data['created_at']) ?? DateTime.now(),
      reviewedAt: _dateTimeValue(data['reviewed_at']),
      reviewedBy: data['reviewed_by']?.toString(),
      reviewNote: data['review_note']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'place_id': placeId,
      'task_id': taskId,
      'type': type.name,
      'status': status.name,
      'payload': payload,
      'points': points,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'review_note': reviewNote,
    }..removeWhere((key, value) => value == null);
  }
}

class ContributionTypeParser {
  static ContributionType fromString(String value) {
    return ContributionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ContributionType.addPlaceInfo,
    );
  }
}

class ContributionStatusParser {
  static ContributionStatus fromString(String value) {
    return ContributionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ContributionStatus.pending,
    );
  }
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is String) {
    return {'value': value};
  }

  return {};
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
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
