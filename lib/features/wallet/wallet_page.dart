import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../features/notifications/notifications_page.dart';
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
                                const SizedBox(height: 16),
                                _transferButtonCard(colors),
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
    openNotifications(context);
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
      padding: const EdgeInsets.fromLTRB(20, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF18A99A),
            Color(0xFF087F78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3318A99A),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // الجهة اليمنى (في RTL): رقم المحفظة + الرصيد
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'رقم المحفظة',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    walletNumber,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${wallet?.coinsBalance ?? 0}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'عملة',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // الجهة اليسرى (في RTL): زر الشحن
          _CardActionButton(
            label: 'شحن',
            icon: Icons.add_card_rounded,
            filled: false,
            onPressed: _recharge,
          ),
        ],
      ),
    );
  }

  Widget _transferButtonCard(WaynColors colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _transfer,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 22,
                    color: colors.brand,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحويل رصيد',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'أرسل عملات إلى محفظة أخرى',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _recharge() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'ميزة شحن المحفظة ستتاح قريبًا',
            textDirection: TextDirection.rtl,
          ),
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

class _CardActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled
              ? Colors.white
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled
                  ? const Color(0xFF087F78)
                  : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: filled
                    ? const Color(0xFF087F78)
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
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
