import 'package:flutter/material.dart';

import '../../core/widgets/wayn_header.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../admin/admin_login_page.dart';
import '../community/saved_posts_page.dart';
import '../wallet/wallet_page.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late User _user;
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _onMenuOrNotificationsPressed() {
    debugPrint('Profile menu/notifications pressed');
  }

  String _trustTitle(String? trustLevel) {
    switch (trustLevel?.toLowerCase()) {
      case 'new':
      case 'beginner':
        return 'مستخدم جديد';
      case 'active':
        return 'مستخدم نشط';
      case 'trusted':
        return 'مستخدم موثوق';
      case 'expert':
        return 'خبير WAYN';
      case 'ambassador':
        return 'سفير WAYN';
      case 'vip':
        return 'عضو مميز';
      case 'legend':
        return 'أسطورة WAYN';
      default:
        return 'عضو WAYN';
    }
  }

  IconData _trustIcon(String? trustLevel) {
    switch (trustLevel?.toLowerCase()) {
      case 'active':
        return Icons.local_fire_department_rounded;
      case 'trusted':
        return Icons.verified_user_rounded;
      case 'expert':
        return Icons.workspace_premium_rounded;
      case 'ambassador':
        return Icons.shield_rounded;
      case 'vip':
        return Icons.star_rounded;
      case 'legend':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _user.displayName ?? '');
    final username = TextEditingController(text: _user.username ?? '');
    final phone = TextEditingController(text: _user.phone ?? '');
    final bio = TextEditingController(text: _user.bio ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعديل الملف الشخصي',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                    ),
                  ),
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                    ),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'الهاتف',
                    ),
                  ),
                  TextField(
                    controller: bio,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'نبذة',
                    ),
                  ),
                  const SizedBox(height: 15),
                  FilledButton(
                    onPressed: () async {
                      try {
                        final updated = await _auth.updateProfile(
                          fullName: name.text.trim(),
                          username: username.text.trim(),
                          phone: phone.text.trim(),
                          bio: bio.text.trim(),
                        );

                        if (updated == null || !mounted) return;

                        setState(() => _user = updated);

                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      } catch (error) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error.toString()),
                          ),
                        );
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    name.dispose();
    username.dispose();
    phone.dispose();
    bio.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user.displayName?.trim().isNotEmpty == true
        ? _user.displayName!.trim()
        : 'مستخدم WAYN';

    final username = _user.username?.trim() ?? '';

    final avatarLetter = displayName.isEmpty
        ? 'و'
        : displayName.substring(0, 1);

    final trustTitle = _trustTitle(_user.trustLevel);
    final trustIcon = _trustIcon(_user.trustLevel);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
            children: [
              WaynHeader(
                onMenuPressed: _onMenuOrNotificationsPressed,
                onNotificationsPressed: _onMenuOrNotificationsPressed,
              ),
              const SizedBox(height: 10),
              // =========================
              // Profile Header
              // =========================
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFE5F8F5),
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF18A99A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_user.isVerified) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_rounded,
                                size: 18,
                                color: Color(0xFF18A99A),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: Color(0xFF7A8494),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              trustIcon,
                              size: 15,
                              color: const Color(0xFF18A99A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trustTitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF18A99A),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),

              if (_user.bio?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _user.bio!,
                    style: const TextStyle(
                      color: Color(0xFF596273),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // =========================
              // User Stats
              // =========================
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.stars_rounded,
                      title: 'النقاط',
                      value: '${_user.pointsBalance}',
                      subtitle: 'نقاط WAYN',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: Icons.workspace_premium_rounded,
                      title: 'السمعة',
                      value: '${_user.reputationScore}',
                      subtitle: trustTitle,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // =========================
              // Account
              // =========================
              _card(
                children: [
                  _row(
                    Icons.account_balance_wallet_rounded,
                    'محفظتي',
                    'النقاط والعملات والتحويلات',
                    () => _push(const WalletPage()),
                  ),
                  _divider(),
                  _row(
                    Icons.bookmark_border_rounded,
                    'المحفوظات',
                    'منشوراتك وأماكنك المحفوظة',
                    () => _push(const SavedPostsPage()),
                  ),
                  _divider(),
                  _row(
                    Icons.history_rounded,
                    'النشاط',
                    'مراجعاتك وتفاعلاتك',
                    () => _message(
                      'سجل النشاط',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

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
                    Icons.lock_outline_rounded,
                    'تغيير كلمة المرور',
                    'تحديث كلمة المرور',
                    _changePassword,
                  ),
                  _divider(),
                  _row(
                    Icons.location_on_outlined,
                    'موقعي',
                    'تحديث موقعك الجغرافي',
                    _location,
                  ),
                  _divider(),
                  _row(
                    Icons.info_outline_rounded,
                    'عن WAYN',
                    'دليل الأماكن والخدمات في ليبيا',
                    () => _message(
                      'WAYN — دليلك المحلي الذكي',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              _card(
                children: [
                  _row(
                    Icons.admin_panel_settings_outlined,
                    'دخول لوحة الإدارة',
                    'للمستخدمين الإداريين فقط',
                    () => _push(
                      const AdminLoginPage(),
                    ),
                  ),
                  _divider(),
                  _row(
                    Icons.logout_rounded,
                    'تسجيل الخروج',
                    'الخروج من الحساب',
                    widget.onLogout,
                    destructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF18A99A),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B94A3),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8B94A3),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _row(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onPressed, {
    bool destructive = false,
  }) {
    final color = destructive
        ? const Color(0xFFD95757)
        : const Color(0xFF18A99A);

    return ListTile(
      onTap: onPressed,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFFFEEEE)
              : const Color(0xFFE8F8F6),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: destructive
              ? const Color(0xFFD95757)
              : const Color(0xFF172033),
        ),
      ),
      subtitle: Text(
        subtitle,
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

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                  ),
                ),
                TextField(
                  controller: newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await _auth.changePassword(
                    currentPassword: oldPassword.text,
                    newPassword: newPassword.text,
                  );

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop();

                  if (!mounted) return;

                  _message(
                    'تم تغيير كلمة المرور',
                  );
                } catch (error) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(error.toString()),
                    ),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    oldPassword.dispose();
    newPassword.dispose();
  }

  Future<void> _location() async {
    _message(
      'واجهة تحديث الموقع جاهزة، وسنربطها بخدمة الموقع عند إضافة صلاحيات الموقع للمشروع.',
    );
  }
}
