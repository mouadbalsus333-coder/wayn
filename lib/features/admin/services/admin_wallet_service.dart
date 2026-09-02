import '../../../core/network/api_client.dart';
import '../../../core/network/dart_http_api_client.dart';
import '../../../core/network/wayn_api.dart';

/// Admin Wallet Recharge — data/API service layer.
///
/// Wraps the FastAPI admin wallet endpoints under /api/v1/admin/wallet.
/// Uses the authenticated admin API client ([waynAdminApi]); JWT and
/// error surfacing are handled by the client, same as the rest of the
/// admin panel. Balances are always backend-computed; this layer only
/// parses and exposes them.
///
/// Response shapes match app/api/routers/admin_wallet.py.
class AdminWalletService {
  static const String _base = '/api/v1/admin/wallet';

  final DartHttpApiClient _client;

  AdminWalletService({DartHttpApiClient? client})
      : _client = client ?? waynAdminApi;

  // ================================================================
  // Lookup
  // ================================================================

  /// Look up a wallet by wallet number (confirmation screen data).
  ///
  /// Throws [ApiClientException] with statusCode 404 when the account
  /// does not exist; callers can catch it to show "account not found".
  Future<AdminWalletLookup> lookupWalletByNumber(
    String walletNumber,
  ) async {
    final data = await _client.get(
      '$_base/lookup',
      queryParams: {'wallet_number': walletNumber.trim()},
    );

    return AdminWalletLookup.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  /// Look up a wallet by the owner's user ID.
  Future<AdminWalletLookup> lookupWalletByUserId(
    String userId,
  ) async {
    final data = await _client.get(
      '$_base/lookup',
      queryParams: {'user_id': userId.trim()},
    );

    return AdminWalletLookup.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  // ================================================================
  // Recharge
  // ================================================================

  /// Recharge a user's wallet with coins.
  ///
  /// [idempotencyKey] is optional. When supplied, it is sent exactly
  /// as provided (trimmed) so retries of the SAME recharge attempt
  /// hit the backend's idempotency constraint
  /// (uq_wallet_admin_recharges_admin_idempotency) and are not
  /// executed twice. When omitted, the field is sent as null and the
  /// backend treats the call as a new operation — this service layer
  /// intentionally does NOT invent a client-side key, because a key
  /// generated per invocation would make every repeated call a
  /// different operation. The UI layer is responsible for generating
  /// one stable key per recharge attempt.
  ///
  /// Balances are computed by the backend only.
  Future<AdminWalletRecharge> rechargeWallet({
    required String targetUserId,
    required int amount,
    String? note,
    String? idempotencyKey,
  }) async {
    final data = await _client.post(
      '$_base/recharge',
      body: {
        'target_user_id': targetUserId.trim(),
        'amount': amount,
        'note': (note != null && note.trim().isNotEmpty)
            ? note.trim()
            : null,
        'idempotency_key':
            (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
                ? idempotencyKey.trim()
                : null,
      },
    );

    return AdminWalletRecharge.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  // ================================================================
  // Recharge log (paginated)
  // ================================================================

  /// List admin recharge operations, newest first, with filters.
  Future<AdminWalletRechargePage> listRecharges({
    String? walletNumber,
    String? userId,
    int? adminId,
    String? status,
    DateTime? createdFrom,
    DateTime? createdTo,
    String? search,
    int offset = 0,
    int limit = 20,
  }) async {
    final data = await _client.get(
      '$_base/recharges',
      queryParams: {
        if (walletNumber != null && walletNumber.trim().isNotEmpty)
          'wallet_number': walletNumber.trim(),
        if (userId != null && userId.trim().isNotEmpty)
          'user_id': userId.trim(),
        if (adminId != null) ...{'admin_id': adminId},
        if (status != null && status.trim().isNotEmpty)
          'status': status.trim(),
        if (createdFrom != null)
          'created_from': createdFrom.toUtc().toIso8601String(),
        if (createdTo != null)
          'created_to': createdTo.toUtc().toIso8601String(),
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
        'offset': offset,
        'limit': limit,
      },
    );

    return AdminWalletRechargePage.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  // ================================================================
  // Recharge details
  // ================================================================

  /// Full details of one recharge operation (user, admin, audit
  /// metadata).
  Future<AdminWalletRechargeDetail> getRecharge(
    String rechargeId,
  ) async {
    final data = await _client.get(
      '$_base/recharges/${Uri.encodeComponent(rechargeId.trim())}',
    );

    return AdminWalletRechargeDetail.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  // ================================================================
  // Statistics
  // ================================================================

  /// Aggregate recharge statistics, optionally within a date range.
  Future<AdminWalletRechargeStats> getRechargeStats({
    DateTime? createdFrom,
    DateTime? createdTo,
  }) async {
    final data = await _client.get(
      '$_base/recharges/stats',
      queryParams: {
        if (createdFrom != null)
          'created_from': createdFrom.toUtc().toIso8601String(),
        if (createdTo != null)
          'created_to': createdTo.toUtc().toIso8601String(),
      },
    );

    return AdminWalletRechargeStats.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }
}

// ================================================================
// Models
// ================================================================

/// Status of an admin recharge operation (backend enum values).
enum AdminRechargeStatus { pending, confirmed, failed }

class AdminRechargeStatusParser {
  static AdminRechargeStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return AdminRechargeStatus.pending;
      case 'FAILED':
        return AdminRechargeStatus.failed;
      case 'CONFIRMED':
      default:
        return AdminRechargeStatus.confirmed;
    }
  }
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _dateTimeValue(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

/// Account data returned by /lookup for the confirmation screen.
class AdminWalletLookup {
  final String userId;
  final String walletId;
  final String walletNumber;
  final String fullName;
  final String username;
  final String? phone;
  final int coinsBalance;
  final String? walletStatus;
  final bool isActive;
  final bool isVerified;

  const AdminWalletLookup({
    required this.userId,
    required this.walletId,
    required this.walletNumber,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.coinsBalance,
    required this.walletStatus,
    required this.isActive,
    required this.isVerified,
  });

  factory AdminWalletLookup.fromMap(Map<String, dynamic> m) =>
      AdminWalletLookup(
        userId: m['user_id']?.toString() ?? '',
        walletId: m['wallet_id']?.toString() ?? '',
        walletNumber: m['wallet_number']?.toString() ?? '',
        fullName: m['full_name']?.toString() ?? '',
        username: m['username']?.toString() ?? '',
        phone: m['phone']?.toString(),
        coinsBalance: _intValue(m['coins_balance']),
        walletStatus: m['wallet_status']?.toString(),
        isActive: m['is_active'] == true,
        isVerified: m['is_verified'] == true,
      );
}

/// Base recharge record (list + recharge response shape).
class AdminWalletRecharge {
  final String rechargeId;
  final String transactionId;
  final String userId;
  final String walletId;
  final String walletNumber;
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final AdminRechargeStatus status;
  final int adminId;
  final String adminEmail;
  final DateTime? createdAt;

  const AdminWalletRecharge({
    required this.rechargeId,
    required this.transactionId,
    required this.userId,
    required this.walletId,
    required this.walletNumber,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.adminId,
    required this.adminEmail,
    required this.createdAt,
  });

  factory AdminWalletRecharge.fromMap(Map<String, dynamic> m) =>
      AdminWalletRecharge(
        rechargeId: m['recharge_id']?.toString() ?? '',
        transactionId: m['transaction_id']?.toString() ?? '',
        userId: m['user_id']?.toString() ?? '',
        walletId: m['wallet_id']?.toString() ?? '',
        walletNumber: m['wallet_number']?.toString() ?? '',
        amount: _intValue(m['amount']),
        balanceBefore: _intValue(m['balance_before']),
        balanceAfter: _intValue(m['balance_after']),
        status: AdminRechargeStatusParser.fromString(
          m['status']?.toString() ?? '',
        ),
        adminId: _intValue(m['admin_id']),
        adminEmail: m['admin_email']?.toString() ?? '',
        createdAt: _dateTimeValue(m['created_at']),
      );
}

// ================================================================
// Pagination wrapper ({items, total, offset, limit}).
// ================================================================

class AdminWalletRechargePage {
  final List<AdminWalletRecharge> items;
  final int total;
  final int offset;
  final int limit;

  const AdminWalletRechargePage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  factory AdminWalletRechargePage.fromMap(Map<String, dynamic> m) =>
      AdminWalletRechargePage(
        items: ((m['items'] as List?) ?? const [])
            .map(
              (e) => AdminWalletRecharge.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        total: _intValue(m['total']),
        offset: _intValue(m['offset']),
        limit: _intValue(m['limit']),
      );
}

/// Details of one recharge, including audit metadata and the
/// target user / acting admin summaries.
class AdminWalletRechargeDetail extends AdminWalletRecharge {
  final String? note;
  final String? idempotencyKey;
  final String? ipAddress;
  final String? userAgent;
  final AdminRechargeTargetUser user;
  final AdminRechargeActorAdmin admin;

  const AdminWalletRechargeDetail({
    required super.rechargeId,
    required super.transactionId,
    required super.userId,
    required super.walletId,
    required super.walletNumber,
    required super.amount,
    required super.balanceBefore,
    required super.balanceAfter,
    required super.status,
    required super.adminId,
    required super.adminEmail,
    required super.createdAt,
    required this.note,
    required this.idempotencyKey,
    required this.ipAddress,
    required this.userAgent,
    required this.user,
    required this.admin,
  });

  factory AdminWalletRechargeDetail.fromMap(Map<String, dynamic> m) {
    final base = AdminWalletRecharge.fromMap(m);

    return AdminWalletRechargeDetail(
      rechargeId: base.rechargeId,
      transactionId: base.transactionId,
      userId: base.userId,
      walletId: base.walletId,
      walletNumber: base.walletNumber,
      amount: base.amount,
      balanceBefore: base.balanceBefore,
      balanceAfter: base.balanceAfter,
      status: base.status,
      adminId: base.adminId,
      adminEmail: base.adminEmail,
      createdAt: base.createdAt,
      note: m['note']?.toString(),
      idempotencyKey: m['idempotency_key']?.toString(),
      ipAddress: m['ip_address']?.toString(),
      userAgent: m['user_agent']?.toString(),
      user: AdminRechargeTargetUser.fromMap(
        Map<String, dynamic>.from((m['user'] as Map?) ?? const {}),
      ),
      admin: AdminRechargeActorAdmin.fromMap(
        Map<String, dynamic>.from((m['admin'] as Map?) ?? const {}),
      ),
    );
  }
}

class AdminRechargeTargetUser {
  final String id;
  final String fullName;
  final String username;
  final String? phone;

  const AdminRechargeTargetUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.phone,
  });

  factory AdminRechargeTargetUser.fromMap(Map<String, dynamic> m) =>
      AdminRechargeTargetUser(
        id: m['id']?.toString() ?? '',
        fullName: m['full_name']?.toString() ?? '',
        username: m['username']?.toString() ?? '',
        phone: m['phone']?.toString(),
      );
}

class AdminRechargeActorAdmin {
  final int id;
  final String email;
  final String fullName;

  const AdminRechargeActorAdmin({
    required this.id,
    required this.email,
    required this.fullName,
  });

  factory AdminRechargeActorAdmin.fromMap(Map<String, dynamic> m) =>
      AdminRechargeActorAdmin(
        id: _intValue(m['id']),
        email: m['email']?.toString() ?? '',
        fullName: m['full_name']?.toString() ?? '',
      );
}

/// Aggregate statistics from /recharges/stats.
class AdminWalletRechargeStats {
  final int totalOperations;
  final int totalCoinsRecharged;
  final int confirmedCount;
  final int failedCount;

  const AdminWalletRechargeStats({
    required this.totalOperations,
    required this.totalCoinsRecharged,
    required this.confirmedCount,
    required this.failedCount,
  });

  factory AdminWalletRechargeStats.fromMap(Map<String, dynamic> m) =>
      AdminWalletRechargeStats(
        totalOperations: _intValue(m['total_operations']),
        totalCoinsRecharged: _intValue(m['total_coins_recharged']),
        confirmedCount: _intValue(m['confirmed_count']),
        failedCount: _intValue(m['failed_count']),
      );
}
