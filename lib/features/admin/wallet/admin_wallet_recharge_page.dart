import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../services/admin_wallet_service.dart';

/// Admin Wallet Recharge page.
///
/// Flow: search account → account card → amount + note →
/// confirmation dialog → success with backend-returned data.
///
/// UI only: every API call goes through [AdminWalletService]. The
/// backend is authoritative for all balances; the client only shows
/// a display-only expected balance before confirmation.
class AdminWalletRechargePage extends StatefulWidget {
  const AdminWalletRechargePage({super.key});

  @override
  State<AdminWalletRechargePage> createState() =>
      _AdminWalletRechargePageState();
}

class _AdminWalletRechargePageState
    extends State<AdminWalletRechargePage> {
  final AdminWalletService _service = AdminWalletService();

  // Colors follow the existing admin panel palette.
  static const Color _primary = Color(0xFF18A99A);
  static const Color _danger = Color(0xFFD95757);
  static const Color _dangerBg = Color(0xFFFDECEC);
  static const Color _muted = Color(0xFF596273);

  // ================================================================
  // Search state
  // ================================================================

  bool _searchByWalletNumber = true;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _searching = false;
  String? _searchError;

  AdminWalletLookup? _account;

  // ================================================================
  // Recharge state
  // ================================================================

  bool _submitting = false;

  /// One stable idempotency key per recharge ATTEMPT. Generated the
  /// moment the admin confirms the operation and kept across any
  /// retry of that same operation; cleared after it finishes so the
  /// next recharge starts a new operation.
  String? _activeIdempotencyKey;

  AdminWalletRecharge? _result;

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ================================================================
  // Helpers
  // ================================================================

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _errorText(Object error) {
    if (error is ApiClientException) {
      return 'HTTP ${error.statusCode ?? '؟'} — ${error.message}';
    }
    return '$error';
  }

  String get _searchLabel =>
      _searchByWalletNumber ? 'رقم المحفظة' : 'User ID';

  // ================================================================
  // Lookup / reset
  // ================================================================

  Future<void> _lookup() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchError = 'أدخل $_searchLabel للبحث';
        _account = null;
        _result = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _account = null;
      _result = null;
    });

    try {
      final account = _searchByWalletNumber
          ? await _service.lookupWalletByNumber(query)
          : await _service.lookupWalletByUserId(query);

      if (!mounted) return;
      setState(() => _account = account);
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _account = null;
        _searchError = error.statusCode == 404
            ? 'الحساب غير موجود — تحقق من $_searchLabel وحاول مجددًا'
            : _errorText(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _account = null;
        _searchError = _errorText(error);
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _resetForNewSearch() {
    setState(() {
      _account = null;
      _result = null;
      _searchError = null;
      _amountController.clear();
      _noteController.clear();
      _activeIdempotencyKey = null;
    });
  }

  void _switchSearchMode(bool byWalletNumber) {
    setState(() {
      _searchByWalletNumber = byWalletNumber;
      _resetForNewSearch();
      _searchController.clear();
    });
  }

  // ================================================================
  // Recharge
  // ================================================================

  /// Amount validation: integer only, greater than zero. Digits-only
  /// input formatting prevents decimals/negatives at typing time,
  /// and parsing rejects anything else before a request is made.
  int? _parseAmount() {
    final raw = _amountController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _confirmAndRecharge() async {
    final account = _account;

    if (account == null || _submitting) return;

    final amount = _parseAmount();

    if (amount == null || amount <= 0) {
      _showSnack('المبلغ يجب أن يكون عددًا صحيحًا أكبر من صفر');
      return;
    }

    final expectedBalance = account.coinsBalance + amount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مراجعة عملية الشحن'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('المستخدم', account.fullName),
              _confirmRow('اسم المستخدم', '@${account.username}'),
              _confirmRow('رقم المحفظة', account.walletNumber),
              _confirmRow(
                'الرصيد الحالي',
                '${account.coinsBalance} عملة',
              ),
              _confirmRow('مبلغ الشحن', '+$amount عملة'),
              _confirmRow(
                'الرصيد بعد الشحن (متوقع)',
                '$expectedBalance عملة',
              ),
              const SizedBox(height: 8),
              const Text(
                'الرصيد الفعلي يحدده الخادم. هل تريد تأكيد الشحن؟',
                style: TextStyle(color: _muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تأكيد الشحن'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // One stable key for this attempt; reused across retries of the
    // same operation until it finishes.
    _activeIdempotencyKey ??=
        DateTime.now().microsecondsSinceEpoch.toString();

    setState(() => _submitting = true);

    try {
      final result = await _service.rechargeWallet(
        targetUserId: account.userId,
        amount: amount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        idempotencyKey: _activeIdempotencyKey,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _account = null;
        _amountController.clear();
        _noteController.clear();
      });
      _showSnack(
        'تم شحن ${result.amount} عملة بنجاح إلى محفظة ${result.walletNumber}',
      );
    } on ApiClientException catch (error) {
      if (!mounted) return;
      final message = error.statusCode == 404
          ? 'الحساب أو المحفظة غير موجودة'
          : _errorText(error);
      _showSnack('فشل تنفيذ الشحن ($message)');
    } catch (error) {
      if (!mounted) return;
      _showSnack('فشل تنفيذ الشحن (${_errorText(error)})');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          // The attempt is finished; clear the key so the next
          // recharge starts a new operation.
          _activeIdempotencyKey = null;
        });
      }
    }
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // UI
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شحن محفظة'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _searchCard(),
            if (_account != null) ...[
              const SizedBox(height: 16),
              _accountCard(_account!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _resultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'البحث عن مستخدم',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('رقم المحفظة'),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('User ID'),
                ),
              ],
              selected: {_searchByWalletNumber},
              onSelectionChanged: (selection) {
                _switchSearchMode(selection.first);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: _searchLabel,
                      hintText: _searchByWalletNumber
                          ? 'W12345678901'
                          : 'معرف الحساب',
                    ),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                  ),
                  onPressed: _searching ? null : _lookup,
                  icon: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                  label: const Text('بحث'),
                ),
              ],
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _dangerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _searchError!,
                  style: const TextStyle(color: _danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _accountCard(AdminWalletLookup account) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_circle_rounded,
                  color: _primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'بيانات الحساب',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _submitting ? null : _resetForNewSearch,
                  child: const Text('بحث جديد'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('الاسم', account.fullName),
            _infoRow('اسم المستخدم', '@${account.username}'),
            _infoRow(
              'الهاتف',
              (account.phone == null || account.phone!.isEmpty)
                  ? 'غير متوفر'
                  : account.phone!,
            ),
            _infoRow('User ID', account.userId),
            _infoRow('رقم المحفظة', account.walletNumber),
            _infoRow(
              'الرصيد الحالي',
              '${account.coinsBalance} عملة',
            ),
            _infoRow(
              'حالة المحفظة',
              account.walletStatus ?? 'غير معروفة',
            ),
            _infoRow(
              'حالة الحساب',
              account.isActive ? 'نشط' : 'غير نشط',
            ),
            _infoRow(
              'التحقق',
              account.isVerified ? 'موثّق' : 'غير موثّق',
            ),
            const Divider(height: 28),
            const Text(
              'مبلغ الشحن',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'عدد صحيح أكبر من صفر',
                hintText: 'مثال: 1000',
                suffixText: 'عملة',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'السبب / ملاحظة (اختياري)',
                hintText: 'سبب شحن المحفظة',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                ),
                onPressed: _submitting ? null : _confirmAndRecharge,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_card_rounded),
                label: Text(
                  _submitting ? 'جارٍ التنفيذ...' : 'مراجعة وتأكيد الشحن',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(AdminWalletRecharge result) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: _primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'تم الشحن بنجاح 🎉',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Transaction ID', result.transactionId),
            _infoRow('Recharge ID', result.rechargeId),
            _infoRow('المبلغ', '${result.amount} عملة'),
            _infoRow('الرصيد قبل', '${result.balanceBefore} عملة'),
            _infoRow('الرصيد بعد', '${result.balanceAfter} عملة'),
            _infoRow('رقم المحفظة', result.walletNumber),
            _infoRow('الحالة', result.status.name.toUpperCase()),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _resetForNewSearch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('شحن محفظة أخرى'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
