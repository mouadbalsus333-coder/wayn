import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';
import '../../models/contribution.dart';
import 'contribution_repository.dart';

class FastApiContributionRepository
    implements ContributionRepository {
  final DartHttpApiClient _api;

  FastApiContributionRepository(this._api);

  // ============================================================
  // Current user's contributions
  // ============================================================

  @override
  Future<List<Contribution>> getContributionsByUser(
    String userId, {
    ContributionStatus? status,
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'offset': offset,
      'limit': limit,
    };

    if (status != null) {
      queryParams['status'] = _statusToApi(status);
    }

    try {
      final response = await _api.get(
        '/api/v1/contributions',
        queryParams: queryParams,
      );

      return _contributionsFromResponse(response);
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // ============================================================
  // Get contribution by ID
  // ============================================================

  @override
  Future<Contribution?> getContributionById(
    String id,
  ) async {
    final contributionId = id.trim();

    if (contributionId.isEmpty) {
      return null;
    }

    try {
      final response = await _api.get(
        '/api/v1/contributions/$contributionId',
      );

      if (response == null) {
        return null;
      }

      if (response is! Map) {
        throw ApiClientException(
          'Invalid response received from '
          '/api/v1/contributions/$contributionId',
        );
      }

      return Contribution.fromMap(
        Map<String, dynamic>.from(response),
      );
    } on ApiClientException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }

      if (error.statusCode == 401) {
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // ============================================================
  // Submit contribution
  // ============================================================

  @override
  Future<Contribution?> submitContribution(
    Contribution contribution,
  ) async {
    final body = <String, dynamic>{
      'type': _typeToApi(contribution.type),
      'title': contribution.title,
      'description': contribution.description,
      'payload': contribution.payload,
      'place_id': contribution.placeId,
    };

    body.removeWhere(
      (key, value) => value == null,
    );

    try {
      final response = await _api.post(
        '/api/v1/contributions',
        body: body,
      );

      if (response == null) {
        return null;
      }

      if (response is! Map) {
        throw ApiClientException(
          'Invalid response received from '
          '/api/v1/contributions',
        );
      }

      return Contribution.fromMap(
        Map<String, dynamic>.from(response),
      );
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // ============================================================
  // Cancel contribution
  // ============================================================

  @override
  Future<Contribution?> cancelContribution(
    String contributionId,
  ) async {
    final id = contributionId.trim();

    if (id.isEmpty) {
      return null;
    }

    try {
      final response = await _api.post(
        '/api/v1/contributions/$id/cancel',
      );

      if (response == null) {
        return null;
      }

      if (response is! Map) {
        throw ApiClientException(
          'Invalid response received from '
          '/api/v1/contributions/$id/cancel',
        );
      }

      return Contribution.fromMap(
        Map<String, dynamic>.from(response),
      );
    } on ApiClientException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }

      if (error.statusCode == 401) {
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // ============================================================
  // Response parsing
  // ============================================================

  List<Contribution> _contributionsFromResponse(
    dynamic response,
  ) {
    if (response == null) {
      return [];
    }

    if (response is Map) {
      final items = response['items'];

      if (items is List) {
        return _contributionsFromList(items);
      }

      return [];
    }

    if (response is List) {
      return _contributionsFromList(response);
    }

    throw ApiClientException(
      'Invalid contributions response received',
    );
  }

  List<Contribution> _contributionsFromList(
    List<dynamic> items,
  ) {
    final contributions = <Contribution>[];

    for (final item in items) {
      if (item is! Map) {
        continue;
      }

      try {
        contributions.add(
          Contribution.fromMap(
            Map<String, dynamic>.from(item),
          ),
        );
      } catch (_) {
        // Ignore malformed contribution objects
        // instead of breaking the entire response.
        continue;
      }
    }

    return contributions;
  }

  // ============================================================
  // API enum conversion
  // ============================================================

  String _typeToApi(
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

  String _statusToApi(
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
}
