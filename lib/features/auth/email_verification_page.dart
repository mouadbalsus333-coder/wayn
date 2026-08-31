import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends State<EmailVerificationPage> {
  final _codeController = TextEditingController();
  final AuthService _auth = AuthService();

  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ============================================================
  // Verify email
  // ============================================================

  Future<void> _verifyEmail() async {
    if (_loading) {
      return;
    }

    final code = _codeController.text.trim();

    if (code.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      _showError('يرجى إدخال رمز التحقق المكون من 6 أرقام.');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final result = await _auth.verifyEmail(
        email: widget.email,
        code: code,
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'تعذر التحقق من البريد الإلكتروني. حاول مرة أخرى.';
        });
        return;
      }

      setState(() {
        _loading = false;
      });

      // verifyEmail() stores the access token inside
      // FastApiAuthRepository before returning the user.
      Navigator.of(context).pop<User>(result.user);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _translateError(
          _extractErrorMessage(error),
        );
      });
    }
  }

  // ============================================================
  // Resend verification code
  // ============================================================

  Future<void> _resendCode() async {
    if (_loading || _resending) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _resending = true;
      _error = null;
      _message = null;
    });

    try {
      await _auth.resendVerificationCode(
        email: widget.email,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resending = false;
        _message = 'تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _resending = false;
        _error = _translateError(
          _extractErrorMessage(error),
        );
      });
    }
  }

  // ============================================================
  // Error helpers
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = message;
      _message = null;
    });
  }

  String _extractErrorMessage(Object error) {
    var message = error.toString().trim();

    message = message.replaceFirst(
      RegExp(r'^ApiClientException\([^)]*\):\s*'),
      '',
    );

    message = message.replaceFirst(
      'ApiClientException: ',
      '',
    );

    message = message.replaceFirst(
      'Exception: ',
      '',
    );

    return message.trim();
  }

  String _translateError(String message) {
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid') &&
        normalized.contains('code')) {
      return 'رمز التحقق غير صحيح أو منتهي الصلاحية.';
    }

    if (normalized.contains('expired')) {
      return 'انتهت صلاحية رمز التحقق. اطلب رمزًا جديدًا.';
    }

    if (normalized.contains('verification')) {
      if (normalized.contains('already')) {
        return 'البريد الإلكتروني تم التحقق منه بالفعل.';
      }
    }

    if (normalized.contains('404')) {
      return 'خدمة التحقق من البريد الإلكتروني غير موجودة على الخادم.';
    }

    if (normalized.contains('401')) {
      return 'رمز التحقق غير صحيح أو غير صالح.';
    }

    if (normalized.contains('422')) {
      return 'رمز التحقق يجب أن يتكون من 6 أرقام.';
    }

    if (normalized.contains('429')) {
      return 'تم طلب رموز كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';
    }

    if (normalized.contains('connection refused') ||
        normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection reset') ||
        normalized.contains('network is unreachable')) {
      return 'تعذر الاتصال بالخادم. تأكد من تشغيل السيرفر واتصال الجهاز بالشبكة.';
    }

    if (normalized.contains('timeout') ||
        normalized.contains('timed out')) {
      return 'انتهت مهلة الاتصال بالخادم. حاول مرة أخرى.';
    }

    if (normalized.contains('500')) {
      return 'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.';
    }

    final hasArabic = RegExp(
      r'[\u0600-\u06FF]',
    ).hasMatch(message);

    if (hasArabic && message.isNotEmpty) {
      return message;
    }

    return 'تعذر التحقق من البريد الإلكتروني. حاول مرة أخرى.';
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'تأكيد البريد الإلكتروني',
            style: TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: const IconThemeData(
            color: Color(0xFF172033),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // ------------------------------------------------
                    // Icon
                    // ------------------------------------------------

                    Center(
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F8F5),
                          borderRadius:
                              BorderRadius.circular(26),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          color: Color(0xFF18A99A),
                          size: 42,
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    const Text(
                      'تحقق من بريدك الإلكتروني',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'أرسلنا رمز تحقق مكونًا من 6 أرقام إلى البريد الإلكتروني:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF7A8494),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF18A99A),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ------------------------------------------------
                    // Code
                    // ------------------------------------------------

                    const Text(
                      'رمز التحقق',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF30394A),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _codeController,
                      enabled: !_loading,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: const TextStyle(
                          color: Color(0xFFB8BEC8),
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE3E8ED),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE3E8ED),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF18A99A),
                            width: 1.5,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (_) {
                        if (_error != null ||
                            _message != null) {
                          setState(() {
                            _error = null;
                            _message = null;
                          });
                        }
                      },
                    ),

                    // ------------------------------------------------
                    // Error
                    // ------------------------------------------------

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _MessageBox(
                        message: _error!,
                        isError: true,
                      ),
                    ],

                    // ------------------------------------------------
                    // Success message
                    // ------------------------------------------------

                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      _MessageBox(
                        message: _message!,
                        isError: false,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ------------------------------------------------
                    // Verify
                    // ------------------------------------------------

                    FilledButton(
                      onPressed:
                          _loading ? null : _verifyEmail,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF18A99A),
                        disabledBackgroundColor:
                            const Color(0xFF9BD8D1),
                        minimumSize:
                            const Size.fromHeight(54),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'تأكيد البريد الإلكتروني',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),

                    const SizedBox(height: 14),

                    // ------------------------------------------------
                    // Resend
                    // ------------------------------------------------

                    TextButton(
                      onPressed:
                          (_loading || _resending)
                              ? null
                              : _resendCode,
                      child: _resending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Color(0xFF18A99A),
                              ),
                            )
                          : const Text(
                              'إعادة إرسال رمز التحقق',
                              style: TextStyle(
                                color:
                                    Color(0xFF18A99A),
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'إذا لم تجد الرسالة، تحقق من مجلد البريد غير المرغوب فيه.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF8B94A3),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Message box
// ================================================================

class _MessageBox extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBox({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFFF1F1)
            : const Color(0xFFEAF9F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: isError
              ? const Color(0xFFD34E4E)
              : const Color(0xFF168F83),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
