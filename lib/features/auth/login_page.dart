import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final ValueChanged<User> onAuthenticated;
  final VoidCallback? onContinueAsGuest;

  const LoginPage({
    super.key,
    required this.onAuthenticated,
    this.onContinueAsGuest,
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

    FocusManager.instance.primaryFocus?.unfocus();

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
  // Continue as guest
  // ============================================================

  void _continueAsGuest() {
    if (_loading) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    widget.onContinueAsGuest?.call();
  }

  // ============================================================
  // Register
  // ============================================================

  Future<void> _openRegisterPage() async {
    if (_loading) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

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

    FocusManager.instance.primaryFocus?.unfocus();

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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAFB),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  24 + keyboardInset,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 520,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: constraints.maxHeight > 720 ? 22 : 8,
                        ),

                        // ==================================================
                        // Logo
                        // ==================================================

                        Center(
                          child: Image.asset(
                            'assets/images/branding/wayn_logo.png',
                            width: constraints.maxHeight > 650 ? 132 : 104,
                            height: constraints.maxHeight > 650 ? 132 : 104,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ==================================================
                        // Welcome title
                        // ==================================================

                        const Text(
                          'مرحباً بك في تطبيق WAYN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF087F78),
                          ),
                        ),

                        const SizedBox(height: 28),

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

                        const SizedBox(height: 16),

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

                        const SizedBox(height: 6),

                        // ==================================================
                        // Forgot password - right side
                        // ==================================================

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : _openForgotPasswordPage,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF087F78),
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
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                        // ==================================================
                        // Error
                        // ==================================================

                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3F3),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF0D1D1),
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

                        const SizedBox(height: 18),

                        // ==================================================
                        // Login button
                        // ==================================================

                        SizedBox(
                          height: 58,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: _loading
                                  ? const []
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF18A99A)
                                            .withValues(alpha: 0.22),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                            ),
                            child: FilledButton(
                              onPressed: _loading ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF18A99A),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF8DD5CD),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(18),
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
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight:
                                                FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(
                                              alpha: 0.16,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_back_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // Continue as guest
                        // ==================================================

                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : _continueAsGuest,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  const Color(0xFF087F78),
                              disabledForegroundColor:
                                  const Color(0xFF9BBAB7),
                              side: BorderSide(
                                color: _loading
                                    ? const Color(0xFFD8E4E3)
                                    : const Color(0xFFB9DCD8),
                                width: 1.3,
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(18),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.explore_outlined,
                                  size: 21,
                                ),
                                SizedBox(width: 9),
                                Text(
                                  'الاستمرار كزائر',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

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
                                  fontWeight: FontWeight.w900,
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
            fontWeight: FontWeight.w800,
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
          textInputAction: obscureText
              ? TextInputAction.done
              : TextInputAction.next,
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

            // في RTL نستخدم prefixIcon مع اتجاه الحقل لضمان
            // بقاء أيقونة الحقل في الجهة اليسرى بصريًا.
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
                width: 1.6,
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
