import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _auth = AuthService();

  bool _loading = false;
  bool _codeSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // Send reset code
  // ============================================================

  Future<void> _sendResetCode() async {
    if (_loading) {
      return;
    }

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('يرجى إدخال بريد إلكتروني صحيح.');
      return;
    }

    _setLoading(true);

    try {
      await _auth.forgotPassword(
        email: email,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _codeSent = true;
        _error = null;
        _success =
            'تم إرسال رمز استعادة كلمة المرور إلى بريدك الإلكتروني.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _translateError(
          _extractErrorMessage(error),
        );
        _success = null;
      });
    }
  }

  // ============================================================
  // Reset password
  // ============================================================

  Future<void> _resetPassword() async {
    if (_loading) {
      return;
    }

    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.isEmpty) {
      _showError('يرجى إدخال رمز الاستعادة.');
      return;
    }

    if (code.length < 4) {
      _showError('رمز الاستعادة غير صحيح.');
      return;
    }

    if (password.length < 8) {
      _showError('كلمة المرور يجب أن تكون 8 أحرف على الأقل.');
      return;
    }

    if (password != confirmPassword) {
      _showError('كلمتا المرور غير متطابقتين.');
      return;
    }

    _setLoading(true);

    try {
      await _auth.resetPassword(
        email: email,
        code: code,
        newPassword: password,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = null;
        _success =
            'تم تغيير كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول.';
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 900),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _translateError(
          _extractErrorMessage(error),
        );
        _success = null;
      });
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value);
  }

  void _setLoading(bool value) {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = value;
      _error = null;
      if (value) {
        _success = null;
      }
    });
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = message;
      _success = null;
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

    // ----------------------------------------------------------
    // Invalid / expired code
    // ----------------------------------------------------------

    if (normalized.contains('invalid code') ||
        normalized.contains('invalid reset code') ||
        normalized.contains('expired code') ||
        normalized.contains('reset code') &&
            normalized.contains('invalid')) {
      return 'رمز الاستعادة غير صحيح أو منتهي الصلاحية.';
    }

    // ----------------------------------------------------------
    // Email
    // ----------------------------------------------------------

    if (normalized.contains('email not found') ||
        normalized.contains('user not found')) {
      return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
    }

    if (normalized.contains('email')) {
      if (normalized.contains('invalid')) {
        return 'البريد الإلكتروني غير صالح.';
      }
    }

    // ----------------------------------------------------------
    // Connection
    // ----------------------------------------------------------

    if (normalized.contains('connection refused') ||
        normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection reset') ||
        normalized.contains('network is unreachable')) {
      return 'تعذر الاتصال بالخادم. تأكد من تشغيل السيرفر وأن الجهاز متصل بنفس الشبكة.';
    }

    // ----------------------------------------------------------
    // Timeout
    // ----------------------------------------------------------

    if (normalized.contains('timeout') ||
        normalized.contains('timed out')) {
      return 'انتهت مهلة الاتصال بالخادم. حاول مرة أخرى.';
    }

    // ----------------------------------------------------------
    // HTTP errors
    // ----------------------------------------------------------

    if (normalized.contains('401')) {
      return 'رمز الاستعادة غير صحيح أو منتهي الصلاحية.';
    }

    if (normalized.contains('404')) {
      return 'خدمة استعادة كلمة المرور غير موجودة على الخادم.';
    }

    if (normalized.contains('422')) {
      return 'البيانات المدخلة غير صحيحة. راجع الحقول وحاول مرة أخرى.';
    }

    if (normalized.contains('429')) {
      return 'تم تجاوز عدد المحاولات المسموح بها. حاول مرة أخرى لاحقًا.';
    }

    if (normalized.contains('500')) {
      return 'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.';
    }

    // ----------------------------------------------------------
    // Password
    // ----------------------------------------------------------

    if (normalized.contains('password')) {
      return 'كلمة المرور غير صالحة. يجب أن تكون 8 أحرف على الأقل.';
    }

    // ----------------------------------------------------------
    // Preserve Arabic backend messages
    // ----------------------------------------------------------

    final hasArabic = RegExp(
      r'[\u0600-\u06FF]',
    ).hasMatch(message);

    if (hasArabic && message.isNotEmpty) {
      return message;
    }

    return 'تعذر إتمام عملية استعادة كلمة المرور. حاول مرة أخرى.';
  }

  // ============================================================
  // UI helpers
  // ============================================================

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFA1A9B5),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE3E8ED),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE3E8ED),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF18A99A),
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE8ECEF),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF30394A),
      ),
    );
  }

  Widget _messageBox({
    required String message,
    required bool success,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success
            ? const Color(0xFFE9F8F5)
            : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: success
              ? const Color(0xFF168B7E)
              : const Color(0xFFD34E4E),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
            'استعادة كلمة المرور',
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // ------------------------------------------------
                    // Icon
                    // ------------------------------------------------

                    Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F8F5),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Color(0xFF18A99A),
                          size: 38,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      _codeSent
                          ? 'أدخل رمز الاستعادة'
                          : 'هل نسيت كلمة المرور؟',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _codeSent
                          ? 'أدخل الرمز الذي أرسلناه إلى بريدك الإلكتروني ثم اختر كلمة مرور جديدة.'
                          : 'أدخل بريدك الإلكتروني وسنرسل لك رمزًا لإعادة تعيين كلمة المرور.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7A8494),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ------------------------------------------------
                    // Email
                    // ------------------------------------------------

                    _label('البريد الإلكتروني'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _emailController,
                      enabled: !_loading && !_codeSent,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: _decoration(
                        'example@email.com',
                      ),
                    ),

                    // ------------------------------------------------
                    // Code + new password
                    // ------------------------------------------------

                    if (_codeSent) ...[
                      const SizedBox(height: 18),

                      _label('رمز الاستعادة'),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _codeController,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        decoration: _decoration(
                          'أدخل الرمز',
                        ),
                      ),

                      const SizedBox(height: 18),

                      _label('كلمة المرور الجديدة'),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: _obscurePassword,
                        textDirection: TextDirection.ltr,
                        decoration: _decoration(
                          '••••••••',
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword =
                                          !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      _label('تأكيد كلمة المرور'),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _confirmPasswordController,
                        enabled: !_loading,
                        obscureText: _obscureConfirmPassword,
                        textDirection: TextDirection.ltr,
                        decoration: _decoration(
                          '••••••••',
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ------------------------------------------------
                    // Messages
                    // ------------------------------------------------

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _messageBox(
                        message: _error!,
                        success: false,
                      ),
                    ],

                    if (_success != null) ...[
                      const SizedBox(height: 12),
                      _messageBox(
                        message: _success!,
                        success: true,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ------------------------------------------------
                    // Main button
                    // ------------------------------------------------

                    FilledButton(
                      onPressed: _loading
                          ? null
                          : (_codeSent
                              ? _resetPassword
                              : _sendResetCode),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF18A99A),
                        disabledBackgroundColor:
                            const Color(0xFF9BD8D1),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _codeSent
                                  ? 'تغيير كلمة المرور'
                                  : 'إرسال رمز الاستعادة',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),

                    // ------------------------------------------------
                    // Resend
                    // ------------------------------------------------

                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : _sendResetCode,
                        child: const Text(
                          'إعادة إرسال الرمز',
                          style: TextStyle(
                            color: Color(0xFF18A99A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'العودة إلى تسجيل الدخول',
                        style: TextStyle(
                          color: Color(0xFF18A99A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
