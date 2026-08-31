import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../admin/admin_login_page.dart';

/// صفحة الإعدادات المستقلة.
///
/// تحتوي على:
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

  String _friendlyError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  // ============================================================
  // تغيير اسم المستخدم
  // ============================================================

  Future<void> _editUsername() async {
    final controller = TextEditingController(
      text: _user?.username ?? '',
    );

    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('تغيير اسم المستخدم'),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 50,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم',
                    hintText: 'مثال: wayn_user',
                    helperText: 'بين 3 و 50 حرفًا',
                    errorText: error,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          FocusManager.instance.primaryFocus?.unfocus();

                          final value = controller.text.trim();

                          if (value.isEmpty) {
                            setDialogState(
                              () => error = 'اسم المستخدم مطلوب',
                            );
                            return;
                          }

                          if (value.length < 3) {
                            setDialogState(
                              () => error =
                                  'اسم المستخدم يجب ألا يقل عن 3 أحرف',
                            );
                            return;
                          }

                          if (value.length > 50) {
                            setDialogState(
                              () => error =
                                  'اسم المستخدم يجب ألا يتجاوز 50 حرفًا',
                            );
                            return;
                          }

                          setDialogState(() {
                            error = null;
                            saving = true;
                          });

                          try {
                            final updated = await _auth.updateProfile(
                              username: value,
                            );

                            if (!mounted) return;

                            if (updated == null) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  saving = false;
                                  error =
                                      'انتهت الجلسة، يرجى تسجيل الدخول مجددًا';
                                });
                              }
                              return;
                            }

                            setState(() {
                              _user = updated;
                            });

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            _message('تم تحديث اسم المستخدم بنجاح');
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              saving = false;
                              error = _friendlyError(e);
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18A99A),
                  ),
                  child: saving
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
          },
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // تغيير الوصف
  // ============================================================

  Future<void> _editBio() async {
    final controller = TextEditingController(
      text: _user?.bio ?? '',
    );

    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('تغيير الوصف'),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 2000,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'الوصف',
                    hintText: 'عرفنا عن نفسك قليلًا',
                    errorText: error,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          FocusManager.instance.primaryFocus?.unfocus();

                          final value = controller.text.trim();

                          if (value.length > 2000) {
                            setDialogState(
                              () => error =
                                  'الوصف يجب ألا يتجاوز 2000 حرف',
                            );
                            return;
                          }

                          setDialogState(() {
                            error = null;
                            saving = true;
                          });

                          try {
                            final updated = await _auth.updateProfile(
                              bio: value,
                            );

                            if (!mounted) return;

                            if (updated == null) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  saving = false;
                                  error =
                                      'انتهت الجلسة، يرجى تسجيل الدخول مجددًا';
                                });
                              }
                              return;
                            }

                            setState(() {
                              _user = updated;
                            });

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            _message('تم تحديث الوصف بنجاح');
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              saving = false;
                              error = _friendlyError(e);
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18A99A),
                  ),
                  child: saving
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
          },
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // تغيير كلمة المرور
  // ============================================================

  Future<void> _changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();

    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('تغيير كلمة المرور'),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPassword,
                      obscureText: true,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newPassword,
                      obscureText: true,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        helperText: '8 أحرف على الأقل',
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFFD95757),
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
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          FocusManager.instance.primaryFocus?.unfocus();

                          if (newPassword.text.length < 8) {
                            setDialogState(
                              () => error =
                                  'كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف',
                            );
                            return;
                          }

                          setDialogState(() {
                            error = null;
                            saving = true;
                          });

                          try {
                            await _auth.changePassword(
                              currentPassword: oldPassword.text,
                              newPassword: newPassword.text,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            _message('تم تغيير كلمة المرور');
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              saving = false;
                              error = _friendlyError(e);
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18A99A),
                  ),
                  child: saving
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
          },
        );
      },
    );

    oldPassword.dispose();
    newPassword.dispose();
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          child: Column(
            children: [
              _header(),
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
                          const Text(
                            'المظهر الشخصي',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _card(
                            children: [
                              _row(
                                icon: Icons.manage_accounts_rounded,
                                title: 'اسم المستخدم',
                                subtitle: _user?.username?.isNotEmpty ==
                                        true
                                    ? '@${_user!.username}'
                                    : 'أضف اسم مستخدم',
                                onPressed: _editUsername,
                              ),
                              _divider(),
                              _row(
                                icon: Icons.notes_rounded,
                                title: 'الوصف',
                                subtitle: _user?.bio?.trim().isNotEmpty ==
                                        true
                                    ? _user!.bio!.trim()
                                    : 'أضف وصفًا تعرّف به عن نفسك',
                                multiline: true,
                                onPressed: _editBio,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'الحساب والأمان',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _card(
                            children: [
                              _row(
                                icon: Icons.lock_outline_rounded,
                                title: 'تغيير كلمة المرور',
                                subtitle: 'تحديث كلمة المرور',
                                onPressed: _changePassword,
                              ),
                              _divider(),
                              _row(
                                icon: Icons.location_on_outlined,
                                title: 'تغيير الموقع',
                                subtitle: 'تحديث موقعك الجغرافي',
                                onPressed: _location,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'معلومات',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _card(
                            children: [
                              _row(
                                icon: Icons.info_outline_rounded,
                                title: 'عن WAYN',
                                subtitle:
                                    'دليل الأماكن والخدمات في ليبيا',
                                onPressed: _about,
                              ),
                              _divider(),
                              _row(
                                icon:
                                    Icons.admin_panel_settings_outlined,
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

  Widget _header() {
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF263247),
                size: 23,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'الإعدادات',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }

  Widget _card({
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _row({
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
          color: const Color(0xFFE8F8F6),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF18A99A),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF172033),
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: multiline ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF8B94A3),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_left_rounded,
        color: Color(0xFFB2B9C3),
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 75,
      endIndent: 15,
    );
  }
}
