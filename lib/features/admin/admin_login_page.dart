import 'package:flutter/material.dart';

import '../../core/network/wayn_api.dart';
import 'admin_panel.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = Map<String, dynamic>.from(
        await waynAdminApi.post(
          '/api/v1/admin/auth/login',
          body: {
            'email': _email.text.trim(),
            'password': _password.text,
          },
        ),
      );

      final token = data['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('لم يتم استلام رمز دخول لوحة الإدارة.');
      }

      await waynAdminApi.setAuthToken(token);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminPanel(
            adminName: data['full_name']?.toString() ?? 'مدير',
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: const Text('دخول الإدارة'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F6),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 42,
                      color: Color(0xFF18A99A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'لوحة إدارة WAYN',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFD95757)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _login,
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
                            'دخول لوحة الإدارة',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
