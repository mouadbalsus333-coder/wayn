enum ContributionType {
  createPlace,
  updatePlace,
  addImage,
  updateInformation,
  verifyPlace,
}

enum ContributionStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class Contribution {
  final String id;
  final String userId;
  final String? placeId;

  final ContributionType type;
  final ContributionStatus status;

  final String title;
  final String? description;

  final Map<String, dynamic> payload;

  final int pointsAwarded;

  final DateTime createdAt;
  final DateTime updatedAt;

  final DateTime? reviewedAt;
  final String? reviewedBy;

  final String? rejectionReason;

  const Contribution({
    required this.id,
    required this.userId,
    this.placeId,
    required this.type,
    required this.status,
    required this.title,
    this.description,
    this.payload = const {},
    this.pointsAwarded = 0,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  factory Contribution.fromMap(Map<String, dynamic> data) {
    return Contribution(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      placeId: data['place_id']?.toString(),

      type: ContributionTypeParser.fromString(
        data['type']?.toString() ?? '',
      ),

      status: ContributionStatusParser.fromString(
        data['status']?.toString() ?? '',
      ),

      title: data['title']?.toString() ?? '',

      description: data['description']?.toString(),

      payload: _mapValue(data['payload']),

      pointsAwarded: _intValue(
        data['points_awarded'],
      ),

      reviewedBy: data['reviewed_by']?.toString(),

      reviewedAt: _dateTimeValue(
        data['reviewed_at'],
      ),

      rejectionReason:
          data['rejection_reason']?.toString(),

      createdAt:
          _dateTimeValue(data['created_at']) ??
          DateTime.now(),

      updatedAt:
          _dateTimeValue(data['updated_at']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'place_id': placeId,
      'type': _contributionTypeToApi(type),
      'status': _contributionStatusToApi(status),
      'title': title,
      'description': description,
      'payload': payload,
      'points_awarded': pointsAwarded,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    }..removeWhere(
        (key, value) => value == null,
      );
  }
}

class ContributionTypeParser {
  static ContributionType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CREATE_PLACE':
        return ContributionType.createPlace;

      case 'UPDATE_PLACE':
        return ContributionType.updatePlace;

      case 'ADD_IMAGE':
        return ContributionType.addImage;

      case 'UPDATE_INFORMATION':
        return ContributionType.updateInformation;

      case 'VERIFY_PLACE':
        return ContributionType.verifyPlace;

      default:
        return ContributionType.createPlace;
    }
  }
}

String _contributionTypeToApi(
  ContributionType type,
) {
  switch (type) {
    case ContributionType.createPlace:
      return 'CREATE_PLACE';

    case ContributionType.updatePlace:
      return 'UPDATE_PLACE';

    case ContributionType.addImage:
      return 'ADD_IMAGE';

    case ContributionType.updateInformation:
      return 'UPDATE_INFORMATION';

    case ContributionType.verifyPlace:
      return 'VERIFY_PLACE';
  }
}

class ContributionStatusParser {
  static ContributionStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return ContributionStatus.pending;

      case 'APPROVED':
        return ContributionStatus.approved;

      case 'REJECTED':
        return ContributionStatus.rejected;

      case 'CANCELLED':
        return ContributionStatus.cancelled;

      default:
        return ContributionStatus.pending;
    }
  }
}

String _contributionStatusToApi(
  ContributionStatus status,
) {
  switch (status) {
    case ContributionStatus.pending:
      return 'PENDING';

    case ContributionStatus.approved:
      return 'APPROVED';

    case ContributionStatus.rejected:
      return 'REJECTED';

    case ContributionStatus.cancelled:
      return 'CANCELLED';
  }
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return {};
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}