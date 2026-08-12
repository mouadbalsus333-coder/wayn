import '../../models/point_transaction.dart';

abstract class PointTransactionRepository {
  Future<List<PointTransaction>> getPointTransactionsForUser(
    String userId, {
    int limit = 50,
  });

  Future<PointTransaction?> createPointTransaction(
    PointTransaction transaction,
  );

  Future<int> getPointsBalance(String userId);
}
