import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
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
                        child: CircularProgressIndicator(),
                      )
                    : _error != null && _wallet == null
                        ? _errorState()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                _balanceCard(),
                                const SizedBox(height: 22),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'آخر العمليات',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _transfer,
                                      child: const Text('تحويل'),
                                    ),
                                  ],
                                ),
                                if (_transactions.isEmpty)
                                  _empty()
                                else
                                  ..._transactions.map(_transactionTile),
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

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: Color(0xFF9AA3B1),
            ),
            const SizedBox(height: 16),
            const Text(
              'تعذر تحميل المحفظة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8993A3),
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

  Widget _balanceCard() {
    final wallet = _wallet;

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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'رقم المحفظة',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            wallet?.walletNumber ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
    WalletTransaction transaction,
  ) {
    final positive = transaction.amount >= 0;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F6),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              positive
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: const Color(0xFF18A99A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ??
                      _type(transaction.type),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  transaction.createdAt
                      .toLocal()
                      .toString()
                      .substring(0, 16),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B94A3),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.amount > 0 ? '+' : ''}'
            '${transaction.amount}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: positive
                  ? const Color(0xFF18A99A)
                  : const Color(0xFFD95757),
            ),
          ),
        ],
      ),
    );
  }

  String _type(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase();
  }

  Widget _empty() {
    return const Padding(
      padding: EdgeInsets.all(35),
      child: Center(
        child: Text(
          'لا توجد عمليات بعد',
          style: TextStyle(
            color: Color(0xFF8B94A3),
          ),
        ),
      ),
    );
  }

  String _transferError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _transfer() async {
    final wallet = _wallet;

    if (wallet == null) return;

    final numberController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    String? error;
    var sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('تحويل من المحفظة'),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: numberController,
                        maxLength: 12,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'رقم محفظة المستلم',
                          hintText: 'مثال: W12345678901',
                        ),
                      ),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'مبلغ العملات',
                          helperText:
                              'الرصيد المتاح: ${wallet.coinsBalance}',
                        ),
                      ),
                      TextField(
                        controller: descriptionController,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'وصف اختياري',
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Color(0xFFD95757),
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
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          FocusManager.instance.primaryFocus?.unfocus();

                          final receiverNumber =
                              numberController.text.trim();

                          if (receiverNumber.isEmpty) {
                            setDialogState(
                              () => error = 'أدخل رقم محفظة المستلم',
                            );
                            return;
                          }

                          final amount =
                              int.tryParse(amountController.text.trim());

                          if (amount == null || amount <= 0) {
                            setDialogState(
                              () => error = 'أدخل مبلغًا صحيحًا أكبر من صفر',
                            );
                            return;
                          }

                          setDialogState(() {
                            error = null;
                            sending = true;
                          });

                          try {
                            await _service.transfer(
                              receiverWalletNumber: receiverNumber,
                              amount: amount,
                              description: descriptionController.text.trim(),
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop();

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تنفيذ التحويل'),
                              ),
                            );

                            await _load();
                          } catch (transferError) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              sending = false;
                              error = _transferError(transferError);
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18A99A),
                  ),
                  child: sending
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
          },
        );
      },
    );

    numberController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }
}