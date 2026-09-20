import 'dart:async';

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
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colors.brand,
                        ),
                      )
                    : _error != null && _wallet == null
                        ? _errorState(colors)
                        : RefreshIndicator(
                            color: colors.brand,
                            onRefresh: _load,
                            child: ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
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
                                const SizedBox(height: 11),
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

    final walletNumber =
        (wallet?.walletNumber ?? '').trim().isNotEmpty
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
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  17,
                ),
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
                                color:
                                    Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.25),
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

    final success = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return WalletTransferPage(
            wallet: wallet,
            service: _service,
          );
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );

    if (success != true || !mounted) return;

    await _load();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'تم تنفيذ التحويل بنجاح',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }
}

/* ========================================================================= */
/* TRANSFER PAGE                                                             */
/* ========================================================================= */

enum _TransferStep {
  recipient,
  amount,
  description,
  processing,
  success,
  failure,
}

class WalletTransferPage extends StatefulWidget {
  final Wallet wallet;
  final WalletService service;

  const WalletTransferPage({
    super.key,
    required this.wallet,
    required this.service,
  });

  @override
  State<WalletTransferPage> createState() =>
      _WalletTransferPageState();
}

class _WalletTransferPageState extends State<WalletTransferPage>
    with WidgetsBindingObserver {
  static const int _walletNumberLength = 12;

  final _numberController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _numberFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  final _scrollController = ScrollController();

  Timer? _lookupTimer;

  _TransferStep _step = _TransferStep.recipient;

  String? _recipientName;
  String? _lookupError;
  String? _error;
  String? _resultMessage;

  String? _lastLookupNumber;

  bool _lookingUp = false;
  bool _keyboardVisible = false;
  bool _suppressKeyboardCloseLookup = false;

  int _lookupRequestId = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _numberController.addListener(_onWalletNumberChanged);
    _numberFocusNode.addListener(_onNumberFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _lookupTimer?.cancel();

    _numberController.removeListener(_onWalletNumberChanged);
    _numberFocusNode.removeListener(_onNumberFocusChanged);

    _scrollController.dispose();

    _numberController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();

    _numberFocusNode.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;

    if (views.isEmpty) return;

    final bottomInset = views.first.viewInsets.bottom;
    final visible = bottomInset > 0;

    if (_keyboardVisible && !visible) {
      if (_suppressKeyboardCloseLookup) {
        _suppressKeyboardCloseLookup = false;
      } else {
        final number = _numberController.text.trim();

        if (_step == _TransferStep.recipient &&
            number.length == _walletNumberLength) {
          _lookupTimer?.cancel();

          _lookupTimer = Timer(
            const Duration(milliseconds: 100),
            () {
              if (!mounted) return;

              _lookupRecipient(
                number,
                force: true,
              );
            },
          );
        }
      }
    }

    _keyboardVisible = visible;
  }

  String _friendlyError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  void _onWalletNumberChanged() {
    if (_step != _TransferStep.recipient) return;

    final number = _numberController.text.trim();

    _lookupTimer?.cancel();

    if (_recipientName != null ||
        _lookupError != null ||
        _error != null ||
        _lastLookupNumber != null) {
      setState(() {
        _recipientName = null;
        _lookupError = null;
        _error = null;
        _lastLookupNumber = null;
      });
    }

    if (number.isEmpty) {
      if (_lookingUp) {
        setState(() {
          _lookingUp = false;
        });
      }
      return;
    }

    if (number.length < _walletNumberLength) {
      if (_lookingUp) {
        setState(() {
          _lookingUp = false;
        });
      }
      return;
    }

    if (number.length > _walletNumberLength) {
      return;
    }

    _lookupTimer = Timer(
      const Duration(milliseconds: 420),
      () {
        _lookupRecipient(number);
      },
    );
  }

  void _onNumberFocusChanged() {
    if (_numberFocusNode.hasFocus) return;

    final number = _numberController.text.trim();

    if (number.length != _walletNumberLength) return;

    _lookupTimer?.cancel();

    _lookupTimer = Timer(
      const Duration(milliseconds: 80),
      () {
        if (!mounted) return;

        _lookupRecipient(
          number,
          force: true,
        );
      },
    );
  }

  Future<void> _lookupRecipient(
    String walletNumber, {
    bool force = false,
  }) async {
    final normalized = walletNumber.trim();

    if (normalized.length != _walletNumberLength) return;

    if (!force &&
        normalized == _lastLookupNumber &&
        _recipientName != null) {
      return;
    }

    final requestId = ++_lookupRequestId;

    if (mounted) {
      setState(() {
        _lookingUp = true;
        _lookupError = null;
        _error = null;
      });
    }

    try {
      final name = await widget.service.lookupRecipientName(
        normalized,
      );

      if (!mounted ||
          requestId != _lookupRequestId ||
          normalized != _numberController.text.trim()) {
        return;
      }

      final cleanName = name.trim();

      setState(() {
        _lookingUp = false;
        _lastLookupNumber = normalized;
        _recipientName =
            cleanName.isEmpty ? null : cleanName;
        _lookupError = cleanName.isEmpty
            ? 'لم يتم العثور على هذه المحفظة'
            : null;
      });

      if (cleanName.isNotEmpty) {
        HapticFeedback.selectionClick();
      }
    } catch (error) {
      if (!mounted ||
          requestId != _lookupRequestId ||
          normalized != _numberController.text.trim()) {
        return;
      }

      setState(() {
        _lookingUp = false;
        _lastLookupNumber = normalized;
        _recipientName = null;
        _lookupError = _friendlyError(error);
      });
    }
  }

  bool get _recipientReady {
    return _recipientName != null &&
        _recipientName!.trim().isNotEmpty &&
        !_lookingUp &&
        _lookupError == null;
  }

  int? get _enteredAmount {
    final value = _amountController.text.trim();

    if (value.isEmpty) return null;

    return int.tryParse(value);
  }

  Future<void> _goNext() async {
    if (_step == _TransferStep.recipient) {
      final number = _numberController.text.trim();

      if (number.length != _walletNumberLength) {
        setState(() {
          _error = 'أدخل رقم محفظة صحيح';
        });
        return;
      }

      if (!_recipientReady) {
        if (!_lookingUp) {
          await _lookupRecipient(
            number,
            force: true,
          );
        }

        if (!mounted) return;

        if (!_recipientReady) {
          setState(() {
            _error = _lookupError ??
                (_lookingUp
                    ? 'جارٍ التحقق من رقم المحفظة...'
                    : 'تعذر التحقق من المحفظة');
          });
          return;
        }
      }

      await _changeStep(_TransferStep.amount);

      if (!mounted) return;

      _focusNextField(_amountFocusNode);
      return;
    }

    if (_step == _TransferStep.amount) {
      final enteredAmount = _enteredAmount;

      if (enteredAmount == null || enteredAmount <= 0) {
        setState(() {
          _error = 'أدخل مبلغًا صحيحًا أكبر من صفر';
        });
        return;
      }

      final balance = widget.wallet.coinsBalance;

      if (enteredAmount > balance) {
        setState(() {
          _error = 'الرصيد المتاح غير كافٍ';
        });
        return;
      }

      await _changeStep(_TransferStep.description);

      if (!mounted) return;

      // لا نفتح الكيبورد تلقائيًا هنا.
      // المستخدم يدخل الوصف عند الضغط على الحقل.
      return;
    }

    if (_step == _TransferStep.description) {
      await _submitTransfer();
    }
  }

  Future<void> _changeStep(
    _TransferStep next,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    _lookupTimer?.cancel();

    if (_keyboardVisible) {
      _suppressKeyboardCloseLookup = true;
    }

    if (!mounted) return;

    setState(() {
      _error = null;
      _step = next;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _focusNextField(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }

      Future.delayed(
        const Duration(milliseconds: 80),
        () {
          if (!mounted) return;

          node.requestFocus();
        },
      );
    });
  }

  void _scrollToField(FocusNode node) {
    if (!node.hasFocus) {
      node.requestFocus();
    }
  }

  void _back() {
    if (_step == _TransferStep.processing) {
      return;
    }

    if (_step == _TransferStep.recipient) {
      _close();
      return;
    }

    if (_step == _TransferStep.amount) {
      _changeStep(
        _TransferStep.recipient,
      ).then((_) {
        if (!mounted) return;

        _focusNextField(_numberFocusNode);
      });

      return;
    }

    if (_step == _TransferStep.description) {
      _changeStep(
        _TransferStep.amount,
      ).then((_) {
        if (!mounted) return;

        _focusNextField(_amountFocusNode);
      });

      return;
    }

    if (_step == _TransferStep.failure) {
      _changeStep(
        _TransferStep.description,
      );
    }
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop(false);
  }

  Future<void> _submitTransfer() async {
    final receiverNumber = _numberController.text.trim();
    final enteredAmount = _enteredAmount;

    if (!_recipientReady ||
        receiverNumber.isEmpty ||
        enteredAmount == null ||
        enteredAmount <= 0) {
      setState(() {
        _error = 'بيانات التحويل غير مكتملة';
      });
      return;
    }

    final balance = widget.wallet.coinsBalance;

    if (enteredAmount > balance) {
      setState(() {
        _error = 'الرصيد المتاح غير كافٍ';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    if (_keyboardVisible) {
      _suppressKeyboardCloseLookup = true;
    }

    await _changeStep(_TransferStep.processing);

    if (!mounted) return;

    HapticFeedback.mediumImpact();

    try {
      await widget.service.transfer(
        receiverWalletNumber: receiverNumber,
        amount: enteredAmount,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _resultMessage =
            'تم إرسال $enteredAmount عملة إلى ${_recipientName ?? 'المستلم'}';
        _step = _TransferStep.success;
      });

      HapticFeedback.heavyImpact();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _resultMessage = _friendlyError(error);
        _step = _TransferStep.failure;
      });

      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(colors),
        body: SafeArea(
          top: false,
          child: ListView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.fromSTEB(
              20,
              10,
              20,
              28,
            ),
            children: [
              _buildBalance(colors),
              const SizedBox(height: 14),
              _buildStepBody(colors),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    WaynColors colors,
  ) {
    return AppBar(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 18,
          end: 18,
        ),
        child: Row(
          children: [
            _CircleButton(
              colors: colors,
              icon: _step == _TransferStep.recipient
                  ? Icons.close_rounded
                  : Icons.arrow_forward_rounded,
              onTap: _step == _TransferStep.processing
                  ? null
                  : _back,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (_stepNumber > 0 &&
                _step != _TransferStep.success &&
                _step != _TransferStep.failure &&
                _step != _TransferStep.processing)
              _StepCounter(
                colors: colors,
                current: _stepNumber,
              ),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (_step) {
      case _TransferStep.recipient:
        return 'إلى من؟';
      case _TransferStep.amount:
        return 'كم تريد؟';
      case _TransferStep.description:
        return 'تفاصيل التحويل';
      case _TransferStep.processing:
        return 'جارٍ التحويل';
      case _TransferStep.success:
        return 'تم التحويل';
      case _TransferStep.failure:
        return 'تعذر التحويل';
    }
  }

  int get _stepNumber {
    switch (_step) {
      case _TransferStep.recipient:
        return 1;
      case _TransferStep.amount:
        return 2;
      case _TransferStep.description:
        return 3;
      default:
        return 0;
    }
  }

  Widget _buildBalance(
    WaynColors colors,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: colors.textMuted.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: colors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرصيد المتاح',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.wallet.coinsBalance} عملة',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _BalanceBadge(
            colors: colors,
            amount: widget.wallet.coinsBalance,
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(
    WaynColors colors,
  ) {
    return _buildCurrentStep(colors);
  }

  Widget _buildCurrentStep(
    WaynColors colors,
  ) {
    switch (_step) {
      case _TransferStep.recipient:
        return _recipientStep(colors);
      case _TransferStep.amount:
        return _amountStep(colors);
      case _TransferStep.description:
        return _descriptionStep(colors);
      case _TransferStep.processing:
        return _processingStep(colors);
      case _TransferStep.success:
        return _successStep(colors);
      case _TransferStep.failure:
        return _failureStep(colors);
    }
  }

  Widget _recipientStep(
    WaynColors colors,
  ) {
    final ready = _recipientReady;

    return _StepSurface(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressIndicator(
            colors: colors,
            current: 1,
          ),
          const SizedBox(height: 20),
          Text(
            'رقم محفظة المستلم',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'أدخل الرقم وسنتحقق من صاحبه تلقائيًا',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _WalletNumberField(
            controller: _numberController,
            focusNode: _numberFocusNode,
            colors: colors,
            loading: _lookingUp,
            ready: ready,
            onSubmitted: (_) => _goNext(),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _lookingUp
                ? Padding(
                    key: const ValueKey('lookup'),
                    padding: const EdgeInsets.only(top: 10),
                    child: _LookupStatus(colors: colors),
                  )
                : ready
                    ? Padding(
                        key: const ValueKey('recipient'),
                        padding: const EdgeInsets.only(top: 10),
                        child: _RecipientCard(
                          colors: colors,
                          name: _recipientName!,
                        ),
                      )
                    : _lookupError != null
                        ? Padding(
                            key: const ValueKey('lookup-error'),
                            padding: const EdgeInsets.only(top: 10),
                            child: _ErrorCard(
                              colors: colors,
                              message: _lookupError!,
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('empty'),
                          ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _ErrorCard(
              colors: colors,
              message: _error!,
            ),
          ],
          const SizedBox(height: 18),
          _PrimaryButton(
            colors: colors,
            label: _lookingUp ? 'جارٍ التحقق...' : 'متابعة',
            icon: Icons.arrow_back_rounded,
            onPressed: _goNext,
          ),
          const SizedBox(height: 8),
          Text(
            'اسم صاحب المحفظة يظهر تلقائيًا بعد التحقق.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountStep(
    WaynColors colors,
  ) {
    final amount = _enteredAmount;
    final balance = widget.wallet.coinsBalance;

    final valid = amount != null &&
        amount > 0 &&
        amount <= balance;

    final tooMuch = amount != null && amount > balance;

    return _StepSurface(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressIndicator(
            colors: colors,
            current: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'المبلغ الذي تريد إرساله',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'حدد قيمة التحويل من رصيدك الحالي',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _AmountField(
            controller: _amountController,
            focusNode: _amountFocusNode,
            colors: colors,
            valid: valid,
            tooMuch: tooMuch,
            onChanged: (_) {
              if (_error != null) {
                setState(() {
                  _error = null;
                });
              } else {
                setState(() {});
              }
            },
            onSubmitted: (_) => _goNext(),
          ),
          const SizedBox(height: 10),
          _AmountFeedback(
            colors: colors,
            amount: amount,
            balance: balance,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _ErrorCard(
              colors: colors,
              message: _error!,
            ),
          ],
          const SizedBox(height: 18),
          _PrimaryButton(
            colors: colors,
            label: 'متابعة',
            icon: Icons.arrow_back_rounded,
            onPressed: _goNext,
          ),
        ],
      ),
    );
  }

  Widget _descriptionStep(
    WaynColors colors,
  ) {
    final amountText = _amountController.text.trim();

    return _StepSurface(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressIndicator(
            colors: colors,
            current: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'أضف وصفًا للتحويل',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'اختياري — يمكنك تركه فارغًا',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _TransferSummary(
            colors: colors,
            recipient: _recipientName ?? 'المستلم',
            amount: amountText,
          ),
          const SizedBox(height: 14),
          _DescriptionField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            colors: colors,
            onChanged: (_) {
              if (_error != null) {
                setState(() {
                  _error = null;
                });
              }
            },
            onSubmitted: (_) => _submitTransfer(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _ErrorCard(
              colors: colors,
              message: _error!,
            ),
          ],
          const SizedBox(height: 18),
          _PrimaryButton(
            colors: colors,
            label: 'تحويل الآن',
            icon: Icons.send_rounded,
            onPressed: _submitTransfer,
          ),
        ],
      ),
    );
  }

  Widget _processingStep(
    WaynColors colors,
  ) {
    return _StateSurface(
      colors: colors,
      child: Column(
        children: [
          const SizedBox(height: 30),
          _AnimatedLoader(colors: colors),
          const SizedBox(height: 20),
          Text(
            'جارٍ تنفيذ التحويل',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'يتم الآن تحديث أرصدة المحفظتين...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _successStep(
    WaynColors colors,
  ) {
    return _StateSurface(
      colors: colors,
      child: Column(
        children: [
          const SizedBox(height: 22),
          _SuccessIcon(colors: colors),
          const SizedBox(height: 17),
          Text(
            'تم التحويل بنجاح',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _resultMessage ?? 'تم تنفيذ العملية.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            colors: colors,
            label: 'تم',
            icon: Icons.check_rounded,
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  Widget _failureStep(
    WaynColors colors,
  ) {
    return _StateSurface(
      colors: colors,
      child: Column(
        children: [
          const SizedBox(height: 22),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.danger.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: colors.danger,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            'تعذر التحويل',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _ErrorCard(
            colors: colors,
            message:
                _resultMessage ?? 'حدث خطأ أثناء تنفيذ التحويل.',
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            colors: colors,
            label: 'المحاولة مرة أخرى',
            icon: Icons.refresh_rounded,
            onPressed: _back,
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

/* ========================================================================= */
/* TRANSFER UI COMPONENTS                                                    */
/* ========================================================================= */

class _StepSurface extends StatelessWidget {
  final WaynColors colors;
  final Widget child;

  const _StepSurface({
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.textMuted.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StateSurface extends StatelessWidget {
  final WaynColors colors;
  final Widget child;

  const _StateSurface({
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.textMuted.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final WaynColors colors;
  final int current;

  const _ProgressIndicator({
    required this.colors,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) {
          final active = index < current;

          return Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsetsDirectional.only(
                end: index == 2 ? 0 : 5,
              ),
              decoration: BoxDecoration(
                color: active
                    ? colors.brand
                    : colors.textMuted.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final WaynColors colors;
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.colors,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: colors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _StepCounter extends StatelessWidget {
  final WaynColors colors;
  final int current;

  const _StepCounter({
    required this.colors,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '$current/3',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: colors.brand,
        ),
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  final WaynColors colors;
  final int amount;

  const _BalanceBadge({
    required this.colors,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '$amount',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: colors.brand,
        ),
      ),
    );
  }
}

/* ========================================================================= */
/* CLEAN INPUTS                                                              */
/* ========================================================================= */

class _WalletNumberField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final WaynColors colors;
  final bool loading;
  final bool ready;
  final ValueChanged<String>? onSubmitted;

  const _WalletNumberField({
    required this.controller,
    required this.focusNode,
    required this.colors,
    required this.loading,
    required this.ready,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;

        final borderColor = ready
            ? colors.brand
            : focused
                ? colors.brand.withValues(alpha: 0.60)
                : colors.textMuted.withValues(alpha: 0.10);

        return Container(
          height: 58,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: borderColor,
              width: focused || ready ? 1.3 : 1,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.left,
              maxLength:
                  _WalletTransferPageState._walletNumberLength,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[A-Za-z0-9]'),
                ),
              ],
              onSubmitted: onSubmitted,
              cursorColor: colors.brand,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'W12345678901',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted.withValues(alpha: 0.55),
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon: loading
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.brand,
                          ),
                        ),
                      )
                    : ready
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colors.brand,
                            size: 21,
                          )
                        : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final WaynColors colors;
  final bool valid;
  final bool tooMuch;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.colors,
    required this.valid,
    required this.tooMuch,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;

        final borderColor = tooMuch
            ? colors.danger
            : valid
                ? colors.brand
                : focused
                    ? colors.brand.withValues(alpha: 0.60)
                    : colors.textMuted.withValues(alpha: 0.10);

        return Container(
          height: 62,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: borderColor,
              width: focused || valid || tooMuch ? 1.3 : 1,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: colors.brand,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: colors.textMuted.withValues(alpha: 0.35),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: 14,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'عملة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: colors.brand,
                      ),
                    ),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 17,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final WaynColors colors;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _DescriptionField({
    required this.controller,
    required this.focusNode,
    required this.colors,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;

        return Container(
          constraints: const BoxConstraints(
            minHeight: 116,
            maxHeight: 116,
          ),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: focused
                  ? colors.brand.withValues(alpha: 0.65)
                  : colors.textMuted.withValues(alpha: 0.10),
              width: focused ? 1.3 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 4,
            maxLines: 4,
            maxLength: 300,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            cursorColor: colors.brand,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'مثال: مقابل الخدمة...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: colors.textMuted.withValues(alpha: 0.55),
              ),
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                15,
                14,
                15,
                14,
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ========================================================================= */
/* SUPPORT COMPONENTS                                                        */
/* ========================================================================= */

class _RecipientCard extends StatelessWidget {
  final WaynColors colors;
  final String name;

  const _RecipientCard({
    required this.colors,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: colors.brand.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: colors.brand,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم العثور على المحفظة',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_rounded,
            color: colors.brand,
            size: 21,
          ),
        ],
      ),
    );
  }
}

class _LookupStatus extends StatelessWidget {
  final WaynColors colors;

  const _LookupStatus({
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'جارٍ التحقق من صاحب المحفظة...',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountFeedback extends StatelessWidget {
  final WaynColors colors;
  final int? amount;
  final int balance;

  const _AmountFeedback({
    required this.colors,
    required this.amount,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final enteredAmount = amount;

    if (enteredAmount == null || enteredAmount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 17,
              color: colors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              'الرصيد المتاح',
              style: TextStyle(
                fontSize: 10,
                color: colors.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              '$balance عملة',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (enteredAmount > balance) {
      return _FeedbackContainer(
        colors: colors,
        icon: Icons.warning_amber_rounded,
        message: 'المبلغ أكبر من رصيدك المتاح',
        color: colors.danger,
      );
    }

    final remaining = balance - enteredAmount;

    return _FeedbackContainer(
      colors: colors,
      icon: Icons.check_circle_outline_rounded,
      message: remaining == 0
          ? 'سيتم استخدام كامل رصيدك'
          : 'سيبقى لديك $remaining عملة',
      color: colors.brand,
    );
  }
}

class _FeedbackContainer extends StatelessWidget {
  final WaynColors colors;
  final IconData icon;
  final String message;
  final Color color;

  const _FeedbackContainer({
    required this.colors,
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferSummary extends StatelessWidget {
  final WaynColors colors;
  final String recipient;
  final String amount;

  const _TransferSummary({
    required this.colors,
    required this.recipient,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: colors.textMuted.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: colors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إلى',
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recipient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$amount عملة',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: colors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final WaynColors colors;
  final String message;

  const _ErrorCard({
    required this.colors,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: colors.danger.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: colors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final WaynColors colors;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.colors,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 9),
            Icon(
              icon,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLoader extends StatefulWidget {
  final WaynColors colors;

  const _AnimatedLoader({
    required this.colors,
  });

  @override
  State<_AnimatedLoader> createState() => _AnimatedLoaderState();
}

class _AnimatedLoaderState extends State<_AnimatedLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 6.283185,
          child: child,
        );
      },
      child: Container(
        width: 76,
        height: 76,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: widget.colors.brand.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: widget.colors.brand,
        ),
      ),
    );
  }
}

class _SuccessIcon extends StatefulWidget {
  final WaynColors colors;

  const _SuccessIcon({
    required this.colors,
  });

  @override
  State<_SuccessIcon> createState() => _SuccessIconState();
}

class _SuccessIconState extends State<_SuccessIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.colors.brand.withValues(alpha: 0.10),
        ),
        child: Icon(
          Icons.check_rounded,
          size: 44,
          color: widget.colors.brand,
        ),
      ),
    );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
          ),
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