import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../models/wallet.dart';
import '../../services/wallet_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _service = WalletService();

  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = await _service.getWallet();
      final transactions = await _service.getTransactions();

      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _transactions = transactions;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              WaynHeader(
                onMenuPressed: _onMenuPressed,
                onNotificationsPressed: _onNotificationsPressed,
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF18A99A),
                        ),
                      )
                    : _error != null && _wallet == null
                        ? _errorState(colors)
                        : RefreshIndicator(
                            color: colors.brand,
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                _balanceCard(colors),
                                const SizedBox(height: 22),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'آخر العمليات',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _transfer,
                                      child: const Text('تحويل'),
                                    ),
                                  ],
                                ),
                                if (_transactions.isEmpty)
                                  _empty(colors)
                                else
                                  ..._transactions.map(
                                    (transaction) => _transactionTile(
                                      colors,
                                      transaction,
                                    ),
                                  ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenuPressed() {
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    debugPrint('Wallet notifications pressed');
  }

  Widget _errorState(WaynColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: colors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'تعذر تحميل المحفظة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(WaynColors colors) {
    final wallet = _wallet;

    final walletNumber = (wallet?.walletNumber ?? '').trim().isNotEmpty
        ? wallet!.walletNumber
        : '—';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF18A99A),
            Color(0xFF087F78),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3318A99A),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'رقم المحفظة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                walletNumber,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _money(
            'العملات',
            wallet?.coinsBalance ?? 0,
            Icons.monetization_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _money(
    String title,
    int amount,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            '$amount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(
    WaynColors colors,
    WalletTransaction transaction,
  ) {
    final positive = transaction.amount >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              positive
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? _type(transaction.type),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.amount > 0 ? '+' : ''}${transaction.amount}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: positive ? colors.brand : colors.danger,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.year}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
  }

  String _type(String value) {
    return value.replaceAll('_', ' ').toLowerCase();
  }

  Widget _empty(WaynColors colors) {
    return Padding(
      padding: const EdgeInsets.all(35),
      child: Center(
        child: Text(
          'لا توجد عمليات بعد',
          style: TextStyle(
            color: colors.textMuted,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Transfer
  // ============================================================

  Future<void> _transfer() async {
    final wallet = _wallet;

    if (wallet == null) return;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _WalletTransferDialog(
        wallet: wallet,
        service: _service,
      ),
    );

    if (success != true || !mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تم تنفيذ التحويل',
            textDirection: TextDirection.rtl,
          ),
        ),
      );

    await _load();
  }
}

/// حوار التحويل.
///
/// StatefulWidget يمتلك الـ TextEditingControllers داخل الـ State حتى
/// لا يتم التخلص منها قبل اكتمال خروج الحوار (كان ذلك سبب شاشة الخطأ
/// الحمراء عند إغلاق التحويل في النسخة السابقة).
class _WalletTransferDialog extends StatefulWidget {
  final Wallet wallet;
  final WalletService service;

  const _WalletTransferDialog({
    required this.wallet,
    required this.service,
  });

  @override
  State<_WalletTransferDialog> createState() => _WalletTransferDialogState();
}

class _WalletTransferDialogState extends State<_WalletTransferDialog> {
  late final TextEditingController _numberController =
      TextEditingController();
  late final TextEditingController _amountController =
      TextEditingController();
  late final TextEditingController _descriptionController =
      TextEditingController();

  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _numberController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final receiverNumber = _numberController.text.trim();

    if (receiverNumber.isEmpty) {
      setState(() => _error = 'أدخل رقم محفظة المستلم');
      return;
    }

    final amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغًا صحيحًا أكبر من صفر');
      return;
    }

    setState(() {
      _error = null;
      _sending = true;
    });

    try {
      await widget.service.transfer(
        receiverWalletNumber: receiverNumber,
        amount: amount,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return AlertDialog(
      title: const Text('تحويل من المحفظة'),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _numberController,
                maxLength: 12,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'رقم محفظة المستلم',
                  hintText: 'مثال: W12345678901',
                ),
              ),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'مبلغ العملات',
                  helperText:
                      'الرصيد المتاح: ${widget.wallet.coinsBalance}',
                ),
              ),
              TextField(
                controller: _descriptionController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'وصف اختياري',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.brand,
          ),
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('تحويل'),
        ),
      ],
    );
  }
}
