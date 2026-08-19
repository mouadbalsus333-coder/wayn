import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
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

      // Authentication succeeded.
      // AuthGate will switch from LoginPage to WaynShell.
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
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
                    const SizedBox(height: 30),

                    const _Brand(),

                    const SizedBox(height: 36),

                    const Text(
                      'مرحباً بك من جديد',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'سجّل دخولك واستكشف وين من حولك',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Color(0xFF7A8494),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const _Label(
                      'البريد الإلكتروني',
                    ),

                    const SizedBox(height: 7),

                    _Field(
                      controller: _emailController,
                      hint: 'example@email.com',
                      keyboardType:
                          TextInputType.emailAddress,
                      enabled: !_loading,
                    ),

                    const SizedBox(height: 16),

                    const _Label(
                      'كلمة المرور',
                    ),

                    const SizedBox(height: 7),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_loading,
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

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFFD34E4E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed:
                          _loading ? null : _login,
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                    ),

                    const SizedBox(height: 14),

                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : _openRegisterPage,
                      style:
                          OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(54),
                        side: const BorderSide(
                          color: Color(0xFFDCE2E8),
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'إنشاء حساب جديد',
                        style: TextStyle(
                          color: Color(0xFF172033),
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

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F8F5),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF18A99A),
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'WAYN',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w900,
            color: Color(0xFF18A99A),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF30394A),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool enabled;

  const _Field({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      textDirection: TextDirection.ltr,
      decoration: _decoration(hint),
    );
  }
}

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
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
  );
}
