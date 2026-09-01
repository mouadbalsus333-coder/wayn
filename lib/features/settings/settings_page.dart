import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/wayn_colors.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../admin/admin_login_page.dart';

/// صفحة الإعدادات المستقلة.
///
/// تحتوي على:
/// - الوضع المظلم
/// - تغيير اسم المستخدم
/// - تغيير الوصف
/// - تغيير كلمة المرور
/// - تغيير الموقع
/// - عن WAYN
/// - دخول لوحة الإدارة
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = AuthService();

  User? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _auth.getCurrentUser();

      if (!mounted) return;

      setState(() {
        _user = user;
        _loadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadingUser = false);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  // ============================================================
  // تغيير اسم المستخدم
  // ============================================================

  Future<void> _editUsername() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TextFieldDialog(
        title: 'تغيير اسم المستخدم',
        labelText: 'اسم المستخدم',
        hintText: 'مثال: wayn_user',
        helperText: 'بين 3 و 50 حرفًا',
        maxLength: 50,
        initialValue: _user?.username ?? '',
        validate: (value) {
          if (value.isEmpty) {
            return 'اسم المستخدم مطلوب';
          }

          if (value.length < 3) {
            return 'اسم المستخدم يجب ألا يقل عن 3 أحرف';
          }

          if (value.length > 50) {
            return 'اسم المستخدم يجب ألا يتجاوز 50 حرفًا';
          }

          return null;
        },
        submit: (value) async {
          final updated = await _auth.updateProfile(username: value);

          if (updated == null) {
            return 'انتهت الجلسة، يرجى تسجيل الدخول مجددًا';
          }

          if (mounted) {
            setState(() => _user = updated);
          }

          return null;
        },
      ),
    );

    if (saved == true && mounted) {
      _message('تم تحديث اسم المستخدم بنجاح');
    }
  }

  // ============================================================
  // تغيير الوصف
  // ============================================================

  Future<void> _editBio() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TextFieldDialog(
        title: 'تغيير الوصف',
        labelText: 'الوصف',
        hintText: 'عرفنا عن نفسك قليلًا',
        maxLines: 4,
        maxLength: 2000,
        initialValue: _user?.bio ?? '',
        validate: (value) {
          if (value.length > 2000) {
            return 'الوصف يجب ألا يتجاوز 2000 حرف';
          }

          return null;
        },
        submit: (value) async {
          final updated = await _auth.updateProfile(bio: value);

          if (updated == null) {
            return 'انتهت الجلسة، يرجى تسجيل الدخول مجددًا';
          }

          if (mounted) {
            setState(() => _user = updated);
          }

          return null;
        },
      ),
    );

    if (saved == true && mounted) {
      _message('تم تحديث الوصف بنجاح');
    }
  }

  // ============================================================
  // تغيير كلمة المرور
  // ============================================================

  Future<void> _changePassword() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordDialog(
        submit: (current, next) async {
          await _auth.changePassword(
            currentPassword: current,
            newPassword: next,
          );
        },
      ),
    );

    if (saved == true && mounted) {
      _message('تم تغيير كلمة المرور');
    }
  }

  // ============================================================
  // الموقع / عن WAYN / لوحة الإدارة
  // ============================================================

  Future<void> _location() async {
    _message(
      'واجهة تحديث الموقع جاهزة، وسنربطها بخدمة الموقع عند إضافة صلاحيات الموقع للمشروع.',
    );
  }

  void _about() {
    _message('WAYN — دليلك المحلي الذكي');
  }

  void _adminPanel() {
    _push(const AdminLoginPage());
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              _header(colors),
              Expanded(
                child: _loadingUser
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF18A99A),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          30,
                        ),
                        children: [
                          _sectionTitle(colors, 'التخصيص'),
                          const SizedBox(height: 10),
                          _card(
                            colors,
                            children: [
                              _darkModeTile(colors),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _sectionTitle(colors, 'المظهر الشخصي'),
                          const SizedBox(height: 10),
                          _card(
                            colors,
                            children: [
                              _row(
                                colors,
                                icon: Icons.manage_accounts_rounded,
                                title: 'اسم المستخدم',
                                subtitle: _user?.username?.isNotEmpty == true
                                    ? '@${_user!.username}'
                                    : 'أضف اسم مستخدم',
                                onPressed: _editUsername,
                              ),
                              _divider(colors),
                              _row(
                                colors,
                                icon: Icons.notes_rounded,
                                title: 'الوصف',
                                subtitle: _user?.bio?.trim().isNotEmpty == true
                                    ? _user!.bio!.trim()
                                    : 'أضف وصفًا تعرّف به عن نفسك',
                                multiline: true,
                                onPressed: _editBio,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _sectionTitle(colors, 'الحساب والأمان'),
                          const SizedBox(height: 10),
                          _card(
                            colors,
                            children: [
                              _row(
                                colors,
                                icon: Icons.lock_outline_rounded,
                                title: 'تغيير كلمة المرور',
                                subtitle: 'تحديث كلمة المرور',
                                onPressed: _changePassword,
                              ),
                              _divider(colors),
                              _row(
                                colors,
                                icon: Icons.location_on_outlined,
                                title: 'تغيير الموقع',
                                subtitle: 'تحديث موقعك الجغرافي',
                                onPressed: _location,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _sectionTitle(colors, 'معلومات'),
                          const SizedBox(height: 10),
                          _card(
                            colors,
                            children: [
                              _row(
                                colors,
                                icon: Icons.info_outline_rounded,
                                title: 'عن WAYN',
                                subtitle: 'دليل الأماكن والخدمات في ليبيا',
                                onPressed: _about,
                              ),
                              _divider(colors),
                              _row(
                                colors,
                                icon: Icons.admin_panel_settings_outlined,
                                title: 'دخول لوحة الإدارة',
                                subtitle: 'للمستخدمين الإداريين فقط',
                                onPressed: _adminPanel,
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

  Widget _sectionTitle(WaynColors colors, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      ),
    );
  }

  Widget _darkModeTile(WaynColors colors) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: waynThemeController,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        return SwitchListTile(
          value: isDark,
          onChanged: (value) => waynThemeController.setDarkMode(value),
          secondary: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: colors.brand,
            ),
          ),
          title: Text(
            'الوضع المظلم',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          subtitle: Text(
            'تفعيل الألوان الداكنة للتطبيق',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        );
      },
    );
  }

  Widget _header(WaynColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: colors.textPrimary,
                size: 23,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'الإعدادات',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }

  Widget _card(
    WaynColors colors, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _row(
    WaynColors colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    bool multiline = false,
  }) {
    return ListTile(
      onTap: onPressed,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: colors.brand,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: multiline ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: colors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: colors.textMuted,
      ),
    );
  }

  Widget _divider(WaynColors colors) {
    return Divider(
      height: 1,
      indent: 75,
      endIndent: 15,
      color: colors.divider,
    );
  }
}

// ============================================================
// حوار حقل نصي واحد (يمتلك الـ Controller داخل الـ State)
// ============================================================

class _TextFieldDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final String hintText;
  final String? helperText;
  final int maxLines;
  final int maxLength;
  final String initialValue;
  final String? Function(String value) validate;
  final Future<String?> Function(String value) submit;

  const _TextFieldDialog({
    required this.title,
    required this.labelText,
    required this.hintText,
    this.helperText,
    this.maxLines = 1,
    this.maxLength = 2000,
    required this.initialValue,
    required this.validate,
    required this.submit,
  });

  @override
  State<_TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<_TextFieldDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final value = _controller.text.trim();
    final validation = widget.validate(value);

    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final result = await widget.submit(value);

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _saving = false;
          _error = result;
        });
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return AlertDialog(
      title: Text(widget.title),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helperText: widget.helperText,
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.brand,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

// ============================================================
// حوار تغيير كلمة المرور
// ============================================================

class _PasswordDialog extends StatefulWidget {
  final Future<void> Function(String current, String next) submit;

  const _PasswordDialog({required this.submit});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  late final TextEditingController _currentController =
      TextEditingController();
  late final TextEditingController _newController =
      TextEditingController();

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_newController.text.length < 8) {
      setState(
        () => _error = 'كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف',
      );
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await widget.submit(
        _currentController.text,
        _newController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الحالية',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newController,
              obscureText: true,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                helperText: '8 أحرف على الأقل',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.brand,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

String _friendlyError(Object error) {
  if (error is ApiClientException) {
    return error.message;
  }

  return error.toString().replaceFirst('Exception: ', '');
}
