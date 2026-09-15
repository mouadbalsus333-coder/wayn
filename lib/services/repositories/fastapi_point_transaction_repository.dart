import '../../core/network/api_client.dart';
import '../../core/network/dart_http_api_client.dart';
import '../../models/point_transaction.dart';
import 'point_transaction_repository.dart';

class FastApiPointTransactionRepository
    implements PointTransactionRepository {
  final DartHttpApiClient _api;

  FastApiPointTransactionRepository(this._api);

  @override
  Future<List<PointTransaction>> getPointTransactionsForUser(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        '/api/v1/points/transactions',
        queryParams: {
          'limit': limit,
          'offset': 0,
        },
      );

      return _transactionsFromResponse(response);
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // The backend only credits points server-side; users cannot mint their
  // own point transactions, so this is intentionally not supported.
  @override
  Future<PointTransaction?> createPointTransaction(
    PointTransaction transaction,
  ) async {
    throw UnsupportedError(
      'Point transactions are created server-side only.',
    );
  }

  @override
  Future<int> getPointsBalance(String userId) async {
    try {
      final response = await _api.get(
        '/api/v1/points',
      );

      if (response is! Map) {
        return 0;
      }

      return _intValue(response['points']);
    } on ApiClientException catch (error) {
      if (error.statusCode == 401) {
        await _api.clearAuthToken();
      }

      rethrow;
    }
  }

  // ================================================================
  // Response parsing
  //
  // The backend PointTransactionResponse returns `type`/`status` as
  // SCREAMING_SNAKE enums and references `reference_type`/`reference_id`
  // instead of `contribution_id`/`task_id`, so each ledger entry is
  // mapped explicitly into the app-side [PointTransaction].
  // ================================================================

  List<PointTransaction> _transactionsFromResponse(dynamic response) {
    if (response == null) {
      return [];
    }

    final items = response is List
        ? response
        : (response is Map ? response['items'] : null);

    if (items is! List) {
      return [];
    }

    final transactions = <PointTransaction>[];

    for (final item in items) {
      if (item is! Map) {
        continue;
      }

      try {
        transactions.add(
          _transactionFromMap(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        continue;
      }
    }

    return transactions;
  }

  PointTransaction _transactionFromMap(Map<String, dynamic> data) {
    final metadata = <String, dynamic>{
      'balance_after': data['balance_after'],
      'reference_type': data['reference_type'],
      'reference_id': data['reference_id'],
    }..removeWhere((key, value) => value == null);

    return PointTransaction(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      contributionId: data['reference_id']?.toString(),
      type: _typeFromApi(data['type']?.toString()),
      status: _statusFromApi(data['status']?.toString()),
      amount: _intValue(data['amount']),
      description: data['description']?.toString(),
      createdAt: _dateTimeValue(data['created_at']) ?? DateTime.now(),
      metadata: metadata,
    );
  }

  PointTransactionType _typeFromApi(String? value) {
    switch (value) {
      case 'CONTRIBUTION':
        return PointTransactionType.contribution;

      case 'TASK_REWARD':
        return PointTransactionType.taskReward;

      case 'ACHIEVEMENT':
        return PointTransactionType.achievement;

      case 'PENALTY':
        return PointTransactionType.penalty;

      case 'ADJUSTMENT':
        return PointTransactionType.adjustment;

      default:
        return PointTransactionType.adjustment;
    }
  }

  PointTransactionStatus _statusFromApi(String? value) {
    switch (value) {
      case 'CONFIRMED':
        return PointTransactionStatus.confirmed;

      case 'PENDING':
        return PointTransactionStatus.pending;

      case 'REVOKED':
        return PointTransactionStatus.revoked;

      default:
        return PointTransactionStatus.pending;
    }
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

    return DateTime.tryParse(value.toString());
  }
}