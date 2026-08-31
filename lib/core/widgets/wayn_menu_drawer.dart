import 'dart:ui';

import 'package:flutter/material.dart';

import '../navigation/wayn_shell.dart';
import '../../features/auth/login_page.dart';
import '../../features/community/saved_posts_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/wallet/wallet_page.dart';
import '../../services/auth_service.dart';

/// يفتح قائمة WAYN الجانبية من زر القائمة في الهيدر.
///
/// القائمة تظهر من جهة اليمين (جهة RTL)، بعرض متوسط، مع خلفية ضبابية
/// خلفها، ولا تغطي الشاشة بالكامل.
Future<void> showWaynMenu(BuildContext context) async {
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'إغلاق القائمة',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const WaynMenuDrawer(),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.30, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}

/// لوحة القائمة الجانبية نفسها.
///
/// تعرض العناصر المنقولة من صفحة "حسابي":
/// المحفظة، المحفوظات، النشاط، الإعدادات، تسجيل الخروج.
class WaynMenuDrawer extends StatefulWidget {
  const WaynMenuDrawer({super.key});

  @override
  State<WaynMenuDrawer> createState() => _WaynMenuDrawerState();
}

class _WaynMenuDrawerState extends State<WaynMenuDrawer> {
  /// يغلق القائمة ثم يفتح الصفحة المطلوبة.
  void _open(Widget page) {
    final navigator = Navigator.of(context);

    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// يغلق القائمة ويعرض رسالة سريعة.
  void _showMessage(String message) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    navigator.pop();
    messenger
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

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);

    await AuthService().logout();

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onAuthenticated: (user) {
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => WaynShell(
                  user: user,
                ),
              ),
              (_) => false,
            );
          },
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.76)
        .clamp(250.0, 320.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // ============================================================
          // الخلفية الضبابية القابلة للنقر للإغلاق
          // ============================================================
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 2.4,
                  sigmaY: 2.4,
                ),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.38),
                ),
              ),
            ),
          ),

          // ============================================================
          // لوحة القائمة (بعرض متوسط، على جهة RTL)
          // ============================================================
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: Material(
                color: Colors.white,
                elevation: 16,
                child: SafeArea(
                  child: Column(
                    children: [
                      _header(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            14,
                            8,
                            14,
                            24,
                          ),
                          children: [
                            _MenuTile(
                              icon: Icons.account_balance_wallet_rounded,
                              title: 'المحفظة',
                              subtitle: 'النقاط والعملات والتحويلات',
                              onTap: () => _open(const WalletPage()),
                            ),
                            _MenuTile(
                              icon: Icons.bookmark_border_rounded,
                              title: 'المحفوظات',
                              subtitle: 'منشوراتك وأماكنك المحفوظة',
                              onTap: () => _open(
                                const SavedPostsPage(),
                              ),
                            ),
                            _MenuTile(
                              icon: Icons.history_rounded,
                              title: 'النشاط',
                              subtitle: 'مراجعاتك وتفاعلاتك',
                              onTap: () =>
                                  _showMessage('سجل النشاط'),
                            ),
                            const Divider(
                              height: 24,
                              indent: 14,
                              endIndent: 14,
                            ),
                            _MenuTile(
                              icon: Icons.settings_outlined,
                              title: 'الإعدادات',
                              subtitle: 'إدارة الحساب والتخصيص',
                              onTap: () => _open(
                                const SettingsPage(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                            ),
                            _MenuTile(
                              icon: Icons.logout_rounded,
                              title: 'تسجيل الخروج',
                              subtitle: 'الخروج من الحساب',
                              destructive: true,
                              onTap: _handleLogout,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF18A99A),
            Color(0xFF087F78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'وين WAYN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'قائمة حسابي',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// عنصر قائمة واحد داخل القائمة الجانبية.
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = destructive
        ? const Color(0xFFD95757)
        : const Color(0xFF18A99A);

    final background = destructive
        ? const Color(0xFFFFEEEE)
        : const Color(0xFFE8F8F6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: tint,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: destructive
                              ? const Color(0xFFD95757)
                              : const Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B94A3),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: destructive
                      ? const Color(0xFFE5BABA)
                      : const Color(0xFFB0B7C2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
