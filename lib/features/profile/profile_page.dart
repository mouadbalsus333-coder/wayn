import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  final User user;

  const ProfilePage({
    super.key,
    required this.user,
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

  void _onMenuPressed() {
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    debugPrint('Profile notifications pressed');
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

                        if (updated == null || !mounted) {
                          return;
                        }

                        setState(() {
                          _user = updated;
                        });

                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      } catch (error) {
                        if (!mounted) {
                          return;
                        }

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          child: Column(
            children: [
              WaynHeader(
                onMenuPressed: _onMenuPressed,
                onNotificationsPressed: _onNotificationsPressed,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
                  children: [
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
                                ],
                              ),
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  color: Color(0xFF7A8494),
                                ),
                              ),
                              const SizedBox(height: 5),
                              _buildCopyableId(),
                            ],
                          ),
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
                            iconColor: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            icon: Icons.workspace_premium_rounded,
                            title: 'السمعة',
                            value: '${_user.reputationScore}',
                            subtitle: trustTitle,
                            iconColor: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // =========================
                    // Menu hint
                    // =========================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.menu_rounded,
                            color: Color(0xFF18A99A),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'من زر القائمة في الهيدر يمكنك الوصول إلى '
                              'المحفظة والمحفوظات والنشاط والإعدادات.',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Color(0xFF7A8494),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildCopyableId() {
    final id = _user.id;
    final displayId = id.length > 10 ? id.substring(0, 10) : id;
    final truncated = id.length > 10 ? '$displayId...' : displayId;

    return Row(
      children: [
        Text(
          'ID: $truncated',
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF7A8494),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _copyToClipboard(
            id,
            'تم نسخ المعرف',
          ),
          child: const Icon(
            Icons.copy_rounded,
            size: 14,
            color: Color(0xFF18A99A),
          ),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(
    String value,
    String message,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    Color iconColor = const Color(0xFF18A99A),
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
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
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
}
