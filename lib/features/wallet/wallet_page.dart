import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                                Text(
                                  'آخر العمليات',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
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

    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF18A99A),
              Color(0xFF087F78),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3318A99A),
              blurRadius: 25,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned(
                left: -45,
                bottom: -65,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                right: -40,
                top: -55,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 27,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.contactless_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              'WAYN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'الرصيد',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${wallet?.coinsBalance ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            'عملة',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'رقم المحفظة',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        walletNumber,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (walletNumber != '—') ...[
                                    const SizedBox(width: 8),
                                    _CopyWalletButton(
                                      onPressed: () =>
                                          _copyWalletNumber(walletNumber),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CardActionButton(
                          label: 'شحن',
                          icon: Icons.add_card_rounded,
                          onPressed: _recharge,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyWalletNumber(String walletNumber) async {
    await Clipboard.setData(
      ClipboardData(text: walletNumber),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 9),
              Text(
                'تم نسخ رقم المحفظة',
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
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
          behavior: SnackBarBehavior.floating,
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
  final VoidCallback onPressed;

  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyWalletButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CopyWalletButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
            ),
          ),
          child: const Icon(
            Icons.copy_rounded,
            color: Colors.white,
            size: 15,
          ),
        ),
      ),
    );
  }
}

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
      setState(() {
        _error = 'أدخل رقم محفظة المستلم';
      });
      return;
    }

    final amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'أدخل مبلغًا صحيحًا أكبر من صفر';
      });
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
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: mediaQuery.size.height * 0.86,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colors.textMuted.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 35,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(colors),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBalancePreview(colors),
                        const SizedBox(height: 18),
                        _buildField(
                          colors: colors,
                          controller: _numberController,
                          label: 'رقم محفظة المستلم',
                          hint: 'W12345678901',
                          icon: Icons.account_balance_wallet_outlined,
                          textDirection: TextDirection.ltr,
                          textInputType: TextInputType.text,
                          maxLength: 12,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          colors: colors,
                          controller: _amountController,
                          label: 'مبلغ التحويل',
                          hint: '0',
                          icon: Icons.payments_outlined,
                          textDirection: TextDirection.ltr,
                          textInputType: TextInputType.number,
                          suffix: 'عملة',
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          colors: colors,
                          controller: _descriptionController,
                          label: 'وصف العملية',
                          hint: 'اختياري',
                          icon: Icons.edit_note_rounded,
                          textDirection: TextDirection.rtl,
                          textInputType: TextInputType.text,
                          maxLines: 2,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _buildError(colors),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildActions(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(WaynColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF18A99A),
            Color(0xFF087F78),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحويل رصيد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'أرسل العملات إلى محفظة أخرى',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _sending
                  ? null
                  : () => Navigator.of(context).pop(false),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancePreview(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.brand.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: colors.brand,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرصيد المتاح',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.wallet.coinsBalance} عملة',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_user_outlined,
            color: colors.brand,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required WaynColors colors,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextDirection textDirection,
    required TextInputType textInputType,
    int? maxLength,
    int maxLines = 1,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 3, bottom: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.textMuted.withValues(alpha: 0.12),
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: !_sending,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: textInputType,
            textDirection: textDirection,
            textAlign: textDirection == TextDirection.ltr
                ? TextAlign.left
                : TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            cursorColor: colors.brand,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: colors.brand,
                    size: 19,
                  ),
                ),
              ),
              suffixText: suffix,
              suffixStyle: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.danger.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colors.danger,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: colors.danger,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.textMuted.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _sending
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(
                    color: colors.textMuted.withValues(alpha: 0.20),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brand,
                  disabledBackgroundColor:
                      colors.brand.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _sending
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          key: ValueKey('button'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send_rounded,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'تحويل الآن',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}