import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final ValueChanged<User> onAuthenticated;

  const LoginPage({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _auth = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // Login
  // ============================================================

  Future<void> _login() async {
    if (_loading) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني.');
      return;
    }

    if (password.isEmpty) {
      _showError('يرجى إدخال كلمة المرور.');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _auth.login(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'تعذر تسجيل الدخول. حاول مرة أخرى.';
        });
        return;
      }

      widget.onAuthenticated(user);
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
  // Register
  // ============================================================

  Future<void> _openRegisterPage() async {
    if (_loading) {
      return;
    }

    final user = await Navigator.of(context).push<User>(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          onAuthenticated: (user) {
            Navigator.of(context).pop(user);
          },
        ),
      ),
    );

    if (!mounted || user == null) {
      return;
    }

    widget.onAuthenticated(user);
  }

  // ============================================================
  // Forgot password
  // ============================================================

  Future<void> _openForgotPasswordPage() async {
    if (_loading) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );
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

    if (normalized.contains('invalid email or password') ||
        normalized.contains('invalid email') ||
        normalized.contains('401')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }

    if (normalized.contains('connection refused') ||
        normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection reset') ||
        normalized.contains('network is unreachable')) {
      return 'تعذر الاتصال بالخادم. تأكد من تشغيل السيرفر وأن الجهاز متصل بنفس الشبكة.';
    }

    if (normalized.contains('timeout') ||
        normalized.contains('timed out')) {
      return 'انتهت مهلة الاتصال بالخادم. حاول مرة أخرى.';
    }

    if (normalized.contains('403')) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    }

    if (normalized.contains('404')) {
      return 'خدمة تسجيل الدخول غير موجودة على الخادم.';
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

    return 'تعذر تسجيل الدخول. حاول مرة أخرى.';
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBFC),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                    maxWidth: 520,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ==================================================
                        // Logo
                        // ==================================================

                        Center(
                          child: Image.asset(
                            'assets/images/branding/wayn_logo.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ==================================================
                        // Welcome title
                        // ==================================================

                        const Text(
                          'مرحباً بك في تطبيق WAYN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF12677A),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'سجّل دخولك واستكشف الأماكن من حولك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Color(0xFF8A98A8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 34),

                        // ==================================================
                        // Email
                        // ==================================================

                        _AuthField(
                          controller: _emailController,
                          label: 'البريد الإلكتروني',
                          hint: 'example@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_loading,
                          textDirection: TextDirection.ltr,
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // Password
                        // ==================================================

                        _AuthField(
                          controller: _passwordController,
                          label: 'كلمة المرور',
                          hint: 'أدخل كلمة المرور',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          enabled: !_loading,
                          textDirection: TextDirection.ltr,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'إظهار كلمة المرور'
                                : 'إخفاء كلمة المرور',
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
                              color: const Color(0xFF8FA0AA),
                              size: 22,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ==================================================
                        // Forgot password
                        // ==================================================

                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : _openForgotPasswordPage,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  const Color(0xFF168B98),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'هل نسيت كلمة المرور؟',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        // ==================================================
                        // Error
                        // ==================================================

                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF2F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF4D4D4),
                              ),
                            ),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Color(0xFFD14D4D),
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ==================================================
                        // Login button
                        // ==================================================

                        SizedBox(
                          height: 58,
                          child: FilledButton(
                            onPressed: _loading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF18A99A),
                              disabledBackgroundColor:
                                  const Color(0xFF8DD5CD),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(30),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'تسجيل الدخول',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ==================================================
                        // Register prompt
                        // ==================================================

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'ليس لديك حساب؟',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF71808D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : _openRegisterPage,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    const Color(0xFF18A99A),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'إنشاء حساب',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Authentication field
// ================================================================

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextDirection? textDirection;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.enabled,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF34404D),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          obscureText: obscureText,
          textDirection: textDirection,
          textAlign: textDirection == TextDirection.ltr
              ? TextAlign.left
              : TextAlign.right,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF263442),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintTextDirection: textDirection,
            hintStyle: const TextStyle(
              color: Color(0xFFA3AFB9),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 14,
                end: 8,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF18A99A),
                size: 23,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(
                color: Color(0xFFDDE5EA),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(
                color: Color(0xFFDDE5EA),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(
                color: Color(0xFF18A99A),
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(
                color: Color(0xFFE7ECEF),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}