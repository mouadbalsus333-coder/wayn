enum PointTransactionType {
  contribution,
  taskReward,
  achievement,
  penalty,
  adjustment,
}

enum PointTransactionStatus { pending, confirmed, revoked }

class PointTransaction {
  final String id;
  final String userId;
  final String? contributionId;
  final String? taskId;
  final PointTransactionType type;
  final PointTransactionStatus status;
  final int amount;
  final String? description;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const PointTransaction({
    required this.id,
    required this.userId,
    this.contributionId,
    this.taskId,
    required this.type,
    required this.status,
    required this.amount,
    this.description,
    required this.createdAt,
    this.metadata = const {},
  });

  factory PointTransaction.fromMap(Map<String, dynamic> data) {
    return PointTransaction(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      contributionId: data['contribution_id']?.toString(),
      taskId: data['task_id']?.toString(),
      type: PointTransactionTypeParser.fromString(
        data['type']?.toString() ?? '',
      ),
      status: PointTransactionStatusParser.fromString(
        data['status']?.toString() ?? '',
      ),
      amount: _intValue(data['amount']),
      description: data['description']?.toString(),
      createdAt: _dateTimeValue(data['created_at']) ?? DateTime.now(),
      metadata: _mapValue(data['metadata']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'contribution_id': contributionId,
      'task_id': taskId,
      'type': type.name,
      'status': status.name,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    }..removeWhere((key, value) => value == null);
  }
}

class PointTransactionTypeParser {
  static PointTransactionType fromString(String value) {
    return PointTransactionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PointTransactionType.adjustment,
    );
  }
}

class PointTransactionStatusParser {
  static PointTransactionStatus fromString(String value) {
    return PointTransactionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PointTransactionStatus.pending,
    );
  }
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

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  return {};
}
