import 'package:flutter/material.dart';

import 'widgets/profile_header.dart';
import 'widgets/profile_menu_item.dart';
import 'widgets/profile_stats.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ProfileHeader(
                  onEditPressed: () {
                    debugPrint('Edit profile pressed');
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: ProfileStats(),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle('حسابي'),
              ),

              SliverToBoxAdapter(
                child: _buildMenuCard(
                  children: [
                    ProfileMenuItem(
                      icon: Icons.bookmark_border_rounded,
                      title: 'الأماكن المحفوظة',
                      subtitle: 'الأماكن التي حفظتها للرجوع إليها لاحقًا',
                      onPressed: () {
                        debugPrint('Saved places pressed');
                      },
                    ),
                    _buildDivider(),
                    ProfileMenuItem(
                      icon: Icons.favorite_border_rounded,
                      title: 'إعجاباتي',
                      subtitle: 'الأماكن والمنشورات التي أعجبتك',
                      onPressed: () {
                        debugPrint('Likes pressed');
                      },
                    ),
                    _buildDivider(),
                    ProfileMenuItem(
                      icon: Icons.history_rounded,
                      title: 'سجل النشاط',
                      subtitle: 'الأماكن التي زرتها وتفاعلت معها',
                      onPressed: () {
                        debugPrint('Activity history pressed');
                      },
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle('الإعدادات'),
              ),

              SliverToBoxAdapter(
                child: _buildMenuCard(
                  children: [
                    ProfileMenuItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'الإشعارات',
                      subtitle: 'إدارة إشعارات وين',
                      onPressed: () {
                        debugPrint('Notifications settings pressed');
                      },
                    ),
                    _buildDivider(),
                    ProfileMenuItem(
                      icon: Icons.language_rounded,
                      title: 'اللغة',
                      subtitle: 'العربية',
                      onPressed: () {
                        debugPrint('Language pressed');
                      },
                    ),
                    _buildDivider(),
                    ProfileMenuItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'الخصوصية',
                      subtitle: 'إدارة إعدادات الخصوصية',
                      onPressed: () {
                        debugPrint('Privacy pressed');
                      },
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle('المساعدة'),
              ),

              SliverToBoxAdapter(
                child: _buildMenuCard(
                  children: [
                    ProfileMenuItem(
                      icon: Icons.help_outline_rounded,
                      title: 'مركز المساعدة',
                      subtitle: 'هل تحتاج إلى مساعدة؟',
                      onPressed: () {
                        debugPrint('Help pressed');
                      },
                    ),
                    _buildDivider(),
                    ProfileMenuItem(
                      icon: Icons.info_outline_rounded,
                      title: 'عن وين',
                      subtitle: 'معلومات عن التطبيق',
                      onPressed: () {
                        debugPrint('About pressed');
                      },
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  child: _buildMenuCard(
                    children: [
                      ProfileMenuItem(
                        icon: Icons.logout_rounded,
                        title: 'تسجيل الخروج',
                        onPressed: () {
                          _showLogoutDialog(context);
                        },
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(
        title,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF172033),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(right: 71),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFEFF1F4),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
            content: const Text(
              'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF697386),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Color(0xFF7A8494),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  debugPrint('Logout confirmed');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE05252),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تسجيل الخروج',
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
  }
}