import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
final ValueChanged<User> onAuthenticated;
final VoidCallback onContinueAsGuest;

const LoginPage({
super.key,
required this.onAuthenticated,
required this.onContinueAsGuest,
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

static const _brand = Color(0xFF18A99A);
static const _brandDark = Color(0xFF087F78);
static const _background = Color(0xFFF6FAF9);
static const _text = Color(0xFF172033);
static const _muted = Color(0xFF788591);
static const _border = Color(0xFFDDE7E5);

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
// Guest
// ============================================================

void _continueAsGuest() {
if (_loading) {
return;
}

FocusManager.instance.primaryFocus?.unfocus();

widget.onContinueAsGuest();

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
return Directionality(
textDirection: TextDirection.rtl,
child: Scaffold(
backgroundColor: _background,

    // الصفحة ثابتة تمامًا عند ظهور لوحة المفاتيح.
    resizeToAvoidBottomInset: false,

    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth > 560
              ? 520.0
              : constraints.maxWidth - 32.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              const _LoginBackground(),

              Center(
                child: SizedBox(
                  width: cardWidth.clamp(280.0, 520.0),
                  child: _LoginCard(
                    loading: _loading,
                    error: _error,
                    obscurePassword: _obscurePassword,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    onLogin: _login,
                    onGuest: _continueAsGuest,
                    onRegister: _openRegisterPage,
                    onForgotPassword: _openForgotPasswordPage,
                    onTogglePassword: () {
                      if (_loading) {
                        return;
                      }

                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
);

}
}

// ================================================================
// Background
// ================================================================

class _LoginBackground extends StatelessWidget {
const _LoginBackground();

@override
Widget build(BuildContext context) {
return Stack(
fit: StackFit.expand,
children: [
Container(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topRight,
end: Alignment.bottomLeft,
colors: [
Color(0xFFF8FCFB),
Color(0xFFF1F8F7),
Color(0xFFF7FAFC),
],
),
),
),

    Positioned(
      top: -100,
      right: -80,
      child: _BlurCircle(
        size: 260,
        color: const Color(0xFF18A99A).withValues(
          alpha: 0.13,
        ),
      ),
    ),

    Positioned(
      top: 170,
      left: -120,
      child: _BlurCircle(
        size: 300,
        color: const Color(0xFF087F78).withValues(
          alpha: 0.08,
        ),
      ),
    ),

    Positioned(
      bottom: -120,
      right: 40,
      child: _BlurCircle(
        size: 280,
        color: const Color(0xFF67CFC5).withValues(
          alpha: 0.09,
        ),
      ),
    ),

    Positioned(
      bottom: 80,
      left: -100,
      child: _BlurCircle(
        size: 220,
        color: const Color(0xFFB6D9D5).withValues(
          alpha: 0.14,
        ),
      ),
    ),
  ],
);

}
}

class _BlurCircle extends StatelessWidget {
final double size;
final Color color;

const _BlurCircle({
required this.size,
required this.color,
});

@override
Widget build(BuildContext context) {
return ImageFiltered(
imageFilter: ImageFilter.blur(
sigmaX: 55,
sigmaY: 55,
),
child: Container(
width: size,
height: size,
decoration: BoxDecoration(
color: color,
shape: BoxShape.circle,
),
),
);
}
}

// ================================================================
// Login Card
// ================================================================

class _LoginCard extends StatelessWidget {
final bool loading;
final String? error;
final bool obscurePassword;

final TextEditingController emailController;
final TextEditingController passwordController;

final VoidCallback onLogin;
final VoidCallback onGuest;
final VoidCallback onRegister;
final VoidCallback onForgotPassword;
final VoidCallback onTogglePassword;

const _LoginCard({
required this.loading,
required this.error,
required this.obscurePassword,
required this.emailController,
required this.passwordController,
required this.onLogin,
required this.onGuest,
required this.onRegister,
required this.onForgotPassword,
required this.onTogglePassword,
});

@override
Widget build(BuildContext context) {
return ClipRRect(
borderRadius: BorderRadius.circular(28),
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 18,
sigmaY: 18,
),
child: Container(
padding: const EdgeInsets.fromLTRB(
24,
28,
24,
22,
),
decoration: BoxDecoration(
color: Colors.white.withValues(
alpha: 0.88,
),
borderRadius: BorderRadius.circular(28),
border: Border.all(
color: Colors.white.withValues(
alpha: 0.85,
),
width: 1.2,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(
alpha: 0.055,
),
blurRadius: 35,
spreadRadius: 2,
offset: const Offset(0, 18),
),
],
),
child: _LoginContent(
loading: loading,
error: error,
obscurePassword: obscurePassword,
emailController: emailController,
passwordController: passwordController,
onLogin: onLogin,
onGuest: onGuest,
onRegister: onRegister,
onForgotPassword: onForgotPassword,
onTogglePassword: onTogglePassword,
),
),
),
);
}
}

// ================================================================
// Login Content
// ================================================================

class _LoginContent extends StatelessWidget {
final bool loading;
final String? error;
final bool obscurePassword;

final TextEditingController emailController;
final TextEditingController passwordController;

final VoidCallback onLogin;
final VoidCallback onGuest;
final VoidCallback onRegister;
final VoidCallback onForgotPassword;
final VoidCallback onTogglePassword;

const _LoginContent({
required this.loading,
required this.error,
required this.obscurePassword,
required this.emailController,
required this.passwordController,
required this.onLogin,
required this.onGuest,
required this.onRegister,
required this.onForgotPassword,
required this.onTogglePassword,
});

@override
Widget build(BuildContext context) {
return Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
// ========================================================
// Welcome
// ========================================================

    const Text(
      'مرحباً بك في WAYN',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w900,
        color: _LoginPageState._text,
        letterSpacing: -0.4,
      ),
    ),

    const SizedBox(height: 26),

    // ========================================================
    // Email
    // ========================================================

    const Text(
      'البريد الإلكتروني',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF34404D),
      ),
    ),

    const SizedBox(height: 7),

    _AuthField(
      controller: emailController,
      hint: 'example@email.com',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      enabled: !loading,
      textDirection: TextDirection.ltr,
    ),

    const SizedBox(height: 15),

    // ========================================================
    // Password
    // ========================================================

    const Text(
      'كلمة المرور',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF34404D),
      ),
    ),

    const SizedBox(height: 7),

    _AuthField(
      controller: passwordController,
      hint: 'أدخل كلمة المرور',
      icon: Icons.lock_outline_rounded,
      obscureText: obscurePassword,
      enabled: !loading,
      textDirection: TextDirection.ltr,
      suffixIcon: IconButton(
        tooltip: obscurePassword
            ? 'إظهار كلمة المرور'
            : 'إخفاء كلمة المرور',
        onPressed: loading ? null : onTogglePassword,
        icon: Icon(
          obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF91A09F),
          size: 21,
        ),
      ),
    ),

    const SizedBox(height: 4),

    // ========================================================
    // Forgot password
    // ========================================================

    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: loading ? null : onForgotPassword,
        style: TextButton.styleFrom(
          foregroundColor: _LoginPageState._brandDark,
          padding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 7,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'هل نسيت كلمة المرور؟',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),

    // ========================================================
    // Error
    // ========================================================

    if (error != null) ...[
      const SizedBox(height: 7),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F3).withValues(
            alpha: 0.92,
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: const Color(0xFFF1D5D2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: Color(0xFFD0524D),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                error!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFC34A46),
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ],

    const SizedBox(height: 18),

    // ========================================================
    // Login button
    // ========================================================

    SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading
              ? const []
              : [
                  BoxShadow(
                    color: _LoginPageState._brand.withValues(
                      alpha: 0.23,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: FilledButton(
          onPressed: loading ? null : onLogin,
          style: FilledButton.styleFrom(
            backgroundColor: _LoginPageState._brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                const Color(0xFF9DD8D1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 9),
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    ),

    const SizedBox(height: 13),

    // ========================================================
    // Guest button
    // ========================================================

    SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onGuest,
        style: OutlinedButton.styleFrom(
          foregroundColor: _LoginPageState._brandDark,
          disabledForegroundColor:
              const Color(0xFF9FB4B1),
          backgroundColor: Colors.white.withValues(
            alpha: 0.55,
          ),
          side: BorderSide(
            color: loading
                ? const Color(0xFFE0E9E7)
                : const Color(0xFFC8E2DE),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'الاستمرار كزائر',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),

    const SizedBox(height: 17),

    // ========================================================
    // Register
    // ========================================================

    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'ليس لديك حساب؟',
          style: TextStyle(
            fontSize: 13.5,
            color: _LoginPageState._muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 5),
        TextButton(
          onPressed: loading ? null : onRegister,
          style: TextButton.styleFrom(
            foregroundColor:
                _LoginPageState._brandDark,
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 5,
            ),
            minimumSize: Size.zero,
            tapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'إنشاء حساب',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),

    const SizedBox(height: 7),

    // ========================================================
    // Footer
    // ========================================================

    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: _LoginPageState._brand,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'WAYN • اكتشف أكثر',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA0AAA9),
          ),
        ),
      ],
    ),
  ],
);

}
}

// ================================================================
// Authentication field
// ================================================================

class _AuthField extends StatelessWidget {
final TextEditingController controller;
final String hint;
final IconData icon;
final TextInputType? keyboardType;
final bool enabled;
final bool obscureText;
final Widget? suffixIcon;
final TextDirection? textDirection;

const _AuthField({
required this.controller,
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
return Directionality(
textDirection: TextDirection.ltr,
child: SizedBox(
height: 54,
child: TextField(
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
fontSize: 14.5,
color: Color(0xFF263442),
fontWeight: FontWeight.w500,
),
decoration: InputDecoration(
hintText: hint,
hintTextDirection: textDirection,
hintStyle: const TextStyle(
color: Color(0xFFA3AFB9),
fontSize: 14,
fontWeight: FontWeight.w400,
),
prefixIcon: Padding(
padding: const EdgeInsets.only(
left: 14,
right: 9,
),
child: Icon(
icon,
color: _LoginPageState._brand,
size: 21,
),
),
prefixIconConstraints: const BoxConstraints(
minWidth: 48,
minHeight: 48,
),
suffixIcon: suffixIcon,
filled: true,
fillColor: const Color(0xFFFBFDFC),
contentPadding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 16,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: const BorderSide(
color: _LoginPageState._border,
width: 1,
),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: const BorderSide(
color: _LoginPageState._border,
width: 1,
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: const BorderSide(
color: _LoginPageState._brand,
width: 1.5,
),
),
disabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: const BorderSide(
color: Color(0xFFE7EEEC),
width: 1,
),
),
),
),
),
);
}
}
