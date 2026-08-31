import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import 'email_verification_page.dart';

class RegisterPage extends StatefulWidget {
  final ValueChanged<User> onAuthenticated;

  const RegisterPage({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  final AuthService _auth = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // Register
  // ============================================================

  Future<void> _register() async {
    if (_loading) {
      return;
    }

    final fullName = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();

    // ----------------------------------------------------------
    // Local validation
    // ----------------------------------------------------------

    if (fullName.length < 2) {
      _showError('يرجى إدخال الاسم الكامل.');
      return;
    }

    if (username.length < 3) {
      _showError('اسم المستخدم يجب أن يكون 3 أحرف على الأقل.');
      return;
    }

    if (email.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('يرجى إدخال بريد إلكتروني صحيح.');
      return;
    }

    if (password.length < 8) {
      _showError('كلمة المرور يجب أن تكون 8 أحرف على الأقل.');
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
      final result = await _auth.register(
        email: email,
        password: password,
        fullName: fullName,
        username: username,
        phone: phone.isEmpty ? null : phone,
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _loading = false;
          _error =
              'تعذر إنشاء الحساب. حاول مرة أخرى.';
        });
        return;
      }

      setState(() {
        _loading = false;
      });

      // --------------------------------------------------------
      // Email verification required
      // --------------------------------------------------------

      if (result.verificationRequired) {
        final verifiedUser =
            await Navigator.of(context).push<User>(
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: email,
            ),
          ),
        );

        if (!mounted || verifiedUser == null) {
          return;
        }

        widget.onAuthenticated(verifiedUser);
        return;
      }

      // --------------------------------------------------------
      // Registration completed without verification.
      //
      // The registration endpoint does not return an access
      // token, so we do NOT authenticate the user here.
      // Return to login and let the user sign in normally.
      // --------------------------------------------------------

      await _showSuccessAndReturnToLogin(
        result.message.isNotEmpty
            ? result.message
            : 'تم إنشاء الحساب بنجاح. يمكنك الآن تسجيل الدخول.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _extractErrorMessage(error);

      setState(() {
        _loading = false;
        _error = _translateError(message);
      });
    }
  }

  // ============================================================
  // Success
  // ============================================================

  Future<void> _showSuccessAndReturnToLogin(
    String message,
  ) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF18A99A),
                ),
                SizedBox(width: 10),
                Text(
                  'تم إنشاء الحساب',
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF5F6877),
                height: 1.5,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF18A99A),
                ),
                child: const Text(
                  'حسنًا',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ============================================================
  // Validation
  // ============================================================

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value);
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

    // ----------------------------------------------------------
    // Duplicate account data
    // ----------------------------------------------------------

    if (normalized.contains('email is already registered')) {
      return 'البريد الإلكتروني مستخدم بالفعل.';
    }

    if (normalized.contains('username is already taken')) {
      return 'اسم المستخدم مستخدم بالفعل.';
    }

    if (normalized.contains('phone number is already registered')) {
      return 'رقم الهاتف مستخدم بالفعل.';
    }

    if (normalized.contains('already registered') ||
        normalized.contains('already exists') ||
        normalized.contains('duplicate') ||
        normalized.contains('409')) {
      return 'البريد الإلكتروني أو اسم المستخدم مستخدم بالفعل.';
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
      return 'تعذر إتمام عملية المصادقة.';
    }

    if (normalized.contains('403')) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    }

    if (normalized.contains('404')) {
      return 'خدمة التسجيل غير موجودة على الخادم.';
    }

    if (normalized.contains('422')) {
      return 'البيانات المدخلة غير صحيحة. راجع الحقول وحاول مرة أخرى.';
    }

    if (normalized.contains('500')) {
      return 'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.';
    }

    // ----------------------------------------------------------
    // Validation messages
    // ----------------------------------------------------------

    if (normalized.contains('password')) {
      return 'كلمة المرور غير صالحة. يجب أن تكون 8 أحرف على الأقل.';
    }

    if (normalized.contains('username')) {
      return 'اسم المستخدم غير متاح أو غير صالح.';
    }

    if (normalized.contains('email')) {
      return 'البريد الإلكتروني غير صالح أو مستخدم بالفعل.';
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

    return 'تعذر إنشاء الحساب. حاول مرة أخرى.';
  }

  // ============================================================
  // Field
  // ============================================================

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    TextDirection? textDirection,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textDirection: textDirection ?? TextDirection.rtl,
        enabled: !_loading,
        onChanged: (_) {
          if (_error != null) {
            setState(() {
              _error = null;
            });
          }
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color(0xFFE1E6EB),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color(0xFFE1E6EB),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color(0xFF18A99A),
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color(0xFFE8ECEF),
            ),
          ),
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
          title: const Text(
            'إنشاء حساب',
            style: TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(
            color: Color(0xFF172033),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // ------------------------------------------------
                    // Brand
                    // ------------------------------------------------

                    const Text(
                      'WAYN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF18A99A),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'أنشئ حسابك وابدأ استكشاف وين',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A8494),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ------------------------------------------------
                    // Fields
                    // ------------------------------------------------

                    _field(
                      'الاسم الكامل',
                      _nameController,
                    ),

                    _field(
                      'اسم المستخدم',
                      _usernameController,
                    ),

                    _field(
                      'البريد الإلكتروني',
                      _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textDirection:
                          TextDirection.ltr,
                    ),

                    _field(
                      'رقم الهاتف (اختياري)',
                      _phoneController,
                      keyboardType:
                          TextInputType.phone,
                      textDirection:
                          TextDirection.ltr,
                    ),

                    _field(
                      'كلمة المرور',
                      _passwordController,
                      obscureText:
                          _obscurePassword,
                      textDirection:
                          TextDirection.ltr,
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
                              ? Icons
                                  .visibility_off_outlined
                              : Icons
                                  .visibility_outlined,
                        ),
                      ),
                    ),

                    // ------------------------------------------------
                    // Error
                    // ------------------------------------------------

                    if (_error != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFF1F1),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          textAlign:
                              TextAlign.right,
                          style: const TextStyle(
                            color:
                                Color(0xFFD34E4E),
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // ------------------------------------------------
                    // Register button
                    // ------------------------------------------------

                    FilledButton(
                      onPressed:
                          _loading ? null : _register,
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF18A99A),
                        disabledBackgroundColor:
                            const Color(0xFF9BD8D1),
                        minimumSize:
                            const Size.fromHeight(54),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(15),
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
                              'إنشاء الحساب',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),

                    const SizedBox(height: 12),

                    if (_loading)
                      const Text(
                        'جارٍ إنشاء الحساب...',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              Color(0xFF7A8494),
                          fontSize: 12,
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