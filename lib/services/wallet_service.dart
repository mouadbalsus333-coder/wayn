import '../core/network/wayn_api.dart';
import '../models/wallet.dart';

class WalletService {
  Future<Wallet> getWallet() async {
    final data = await waynApi.get('/api/v1/wallet');

    return Wallet.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  Future<List<WalletTransaction>> getTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await waynApi.get(
      '/api/v1/wallet/transactions',
      queryParams: {
        'limit': limit,
        'offset': offset,
      },
    );

    return (data as List)
        .map(
          (e) => WalletTransaction.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> transfer({
    required String receiverWalletNumber,
    required int amount,
    String? description,
  }) async {
    return Map<String, dynamic>.from(
      await waynApi.post(
        '/api/v1/wallet/transfer',
        body: {
          'receiver_wallet_number': receiverWalletNumber,
          'asset': 'COINS',
          'amount': amount,
          if (description != null &&
              description.trim().isNotEmpty)
            'description': description.trim(),
          'idempotency_key':
              DateTime.now().microsecondsSinceEpoch.toString(),
        },
      ),
    );
  }
}