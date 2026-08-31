enum WalletAsset { coins }

WalletAsset walletAssetFromJson(String value) => WalletAsset.coins;

class Wallet {
  final String id;
  final String userId;
  final String walletNumber;
  final int coinsBalance;

  const Wallet({
    required this.id,
    required this.userId,
    required this.walletNumber,
    required this.coinsBalance,
  });

  factory Wallet.fromMap(Map<String, dynamic> m) => Wallet(
        id: m['id']?.toString() ?? '',
        userId: m['user_id']?.toString() ?? '',
        walletNumber: m['wallet_number']?.toString() ?? '',
        coinsBalance: _int(m['coins_balance']),
      );
}

class WalletTransaction {
  final String id;
  final String walletId;
  final String asset;
  final String type;
  final String status;
  final int amount;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.walletId,
    required this.asset,
    required this.type,
    required this.status,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> m) =>
      WalletTransaction(
        id: m['id']?.toString() ?? '',
        walletId: m['wallet_id']?.toString() ?? '',
        asset: m['asset']?.toString() ?? '',
        type: m['type']?.toString() ?? '',
        status: m['status']?.toString() ?? '',
        amount: _int(m['amount']),
        description: m['description']?.toString(),
        createdAt:
            DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

int _int(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;