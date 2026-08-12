import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/point_transaction.dart';
import 'point_transaction_repository.dart';

class SupabasePointTransactionRepository implements PointTransactionRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<PointTransaction?> createPointTransaction(
    PointTransaction transaction,
  ) async {
    final response = await _supabase
        .from('point_transactions')
        .insert(transaction.toMap())
        .select()
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return PointTransaction.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<int> getPointsBalance(String userId) async {
    final response = await _supabase
        .from('point_transactions')
        .select('amount')
        .eq('user_id', userId);

    return (response as List).fold<int>(0, (sum, item) {
      final value = Map<String, dynamic>.from(item);
      return sum + (int.tryParse(value['amount']?.toString() ?? '0') ?? 0);
    });
  }

  @override
  Future<List<PointTransaction>> getPointTransactionsForUser(
    String userId, {
    int limit = 50,
  }) async {
    final response = await _supabase
        .from('point_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map(
          (item) => PointTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
