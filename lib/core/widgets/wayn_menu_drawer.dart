import 'dart:ui';

import 'package:flutter/material.dart';

import '../navigation/wayn_actions.dart';
import '../navigation/wayn_shell.dart';
import '../theme/wayn_colors.dart';
import '../../features/auth/login_page.dart';
import '../../features/community/saved_posts_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/wallet/wallet_page.dart';
import '../../models/user.dart';
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
  final _auth = AuthService();

  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _auth.getCurrentUser();

      if (mounted) {
        setState(() => _user = user);
      }
    } catch (_) {
      // يبقى الرأس العام إذا تعذر تحميل المستخدم.
    }
  }

  /// يغلق القائمة ويفتح صفحة حسابي.
  void _openProfile() {
    final navigator = Navigator.of(context);

    navigator.pop();
    waynGoToProfileRequest.value++;
  }

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

  void _navigateToLogin() {
    openLoginAndRebuild(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.76)
        .clamp(250.0, 320.0);

    final colors = context.waynColors;
    final isGuest = _user == null;

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
                  sigmaX: 8,
                  sigmaY: 8,
                ),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12),
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
                color: colors.surface,
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
                            if (isGuest)
                              _MenuTile(
                                icon: Icons.login_rounded,
                                title: 'تسجيل الدخول',
                                subtitle: 'ادخل للاستمتاع بمزايا وين الكاملة',
                                onTap: _navigateToLogin,
                              )
                            else ...[
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
                            ],
                            Divider(
                              height: 24,
                              indent: 14,
                              endIndent: 14,
                              color: colors.divider,
                            ),
                            _MenuTile(
                              icon: Icons.settings_outlined,
                              title: 'الإعدادات',
                              subtitle: 'إدارة الحساب والتخصيص',
                              onTap: () => _open(
                                const SettingsPage(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // زر تسجيل الخروج مثبت أسفل القائمة تمامًا
                      // ولا يتحرك مع Scroll مهما زادت عناصر القائمة.
                      if (!isGuest) ...[
                        Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: colors.divider,
                        ),
                        _MenuTile(
                          icon: Icons.logout_rounded,
                          title: 'تسجيل الخروج',
                          subtitle: 'الخروج من الحساب',
                          destructive: true,
                          onTap: _handleLogout,
                        ),
                      ],
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
    final isGuest = _user == null;

    final displayName = isGuest
        ? 'زائر'
        : (_user!.displayName?.trim().isNotEmpty == true
            ? _user!.displayName!.trim()
            : 'مستخدم WAYN');

    // يُعرض اسم الحساب فقط مع الـ ID تحته، بدون الـ Username.

    final avatarLetter = displayName.isEmpty
        ? 'و'
        : displayName.substring(0, 1);

    final userId = _user?.id ?? '';

    final shortId = userId.length > 10
        ? userId.substring(0, 10)
        : userId;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openProfile,
      child: Container(
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(
                    alpha: 0.2,
                  ),
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isGuest
                            ? 'سجّل دخولك لمزايا وين الكاملة'
                            : (shortId.isEmpty
                                ? 'العودة لحسابي'
                                : 'ID: $shortId'),
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
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
    final colors = context.waynColors;

    final tint = destructive
        ? colors.danger
        : colors.brand;

    final background = destructive
        ? colors.danger.withValues(alpha: 0.12)
        : colors.surfaceAlt;

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
                              ? colors.danger
                              : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: destructive
                      ? colors.danger.withValues(alpha: 0.5)
                      : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
