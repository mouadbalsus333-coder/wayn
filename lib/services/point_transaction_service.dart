import '../models/point_transaction.dart';
import 'repositories/point_transaction_repository.dart';
import 'repositories/repository_factory.dart';

class PointTransactionService {
  final PointTransactionRepository _pointTransactionRepository;

  PointTransactionService({
    PointTransactionRepository? pointTransactionRepository,
  }) : _pointTransactionRepository =
           pointTransactionRepository ?? createPointTransactionRepository();

  Future<List<PointTransaction>> getPointTransactionsForUser(
    String userId, {
    int limit = 50,
  }) async {
    return _pointTransactionRepository.getPointTransactionsForUser(
      userId,
      limit: limit,
    );
  }

  Future<PointTransaction?> createPointTransaction(
    PointTransaction transaction,
  ) async {
    return _pointTransactionRepository.createPointTransaction(transaction);
  }

  Future<int> getPointsBalance(String userId) async {
    return _pointTransactionRepository.getPointsBalance(userId);
  }
}
