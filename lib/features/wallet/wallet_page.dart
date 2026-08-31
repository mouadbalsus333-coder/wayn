import 'package:flutter/material.dart';

import '../../core/widgets/wayn_header.dart';
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
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
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
                onMenuPressed: _onMenuOrNotificationsPressed,
                onNotificationsPressed: _onMenuOrNotificationsPressed,
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
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

  void _onMenuOrNotificationsPressed() {
    debugPrint('Wallet menu/notifications pressed');
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

  Future<void> _transfer() async {
    final wallet = _wallet;

    if (wallet == null) return;

    final numberController =
        TextEditingController();
    final amountController =
        TextEditingController();
    final descriptionController =
        TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'تحويل من المحفظة',
          ),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: numberController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'رقم محفظة المستلم',
                    ),
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                      labelText: 'مبلغ العملات',
                    ),
                  ),
                  TextField(
                    controller:
                        descriptionController,
                    decoration:
                        const InputDecoration(
                      labelText: 'وصف اختياري',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final amount = int.parse(
                    amountController.text.trim(),
                  );

                  await _service.transfer(
                    receiverWalletNumber:
                        numberController.text.trim(),
                    amount: amount,
                    description:
                        descriptionController
                            .text
                            .trim(),
                  );

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext)
                      .pop();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم تنفيذ التحويل',
                      ),
                    ),
                  );

                  await _load();
                } catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    SnackBar(
                      content:
                          Text(error.toString()),
                    ),
                  );
                }
              },
              child: const Text('تحويل'),
            ),
          ],
        );
      },
    );

    numberController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }
}