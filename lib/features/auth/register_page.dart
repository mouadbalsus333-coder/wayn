import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  final ValueChanged<User> onAuthenticated;

  const RegisterPage({super.key, required this.onAuthenticated});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    final controllers = [
      _name,
      _username,
      _email,
      _password,
      _phone,
    ];
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_name.text.trim().length < 2 ||
        _username.text.trim().length < 3 ||
        _email.text.trim().isEmpty ||
        _password.text.length < 8) {
      setState(() {
        _error = 'تحقق من البيانات: كلمة المرور 8 أحرف على الأقل';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _auth.register(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _name.text.trim(),
        username: _username.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );

      if (user != null && mounted) {
        widget.onAuthenticated(user);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? type,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: obscureText,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE1E6EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE1E6EB)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('إنشاء حساب'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                _field('الاسم الكامل', _name),
                _field('اسم المستخدم', _username),
                _field(
                  'البريد الإلكتروني',
                  _email,
                  type: TextInputType.emailAddress,
                ),
                _field(
                  'رقم الهاتف (اختياري)',
                  _phone,
                  type: TextInputType.phone,
                ),
                _field(
                  'كلمة المرور',
                  _password,
                  obscureText: true,
                ),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFD34E4E)),
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _loading ? null : _register,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18A99A),
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'إنشاء الحساب',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
