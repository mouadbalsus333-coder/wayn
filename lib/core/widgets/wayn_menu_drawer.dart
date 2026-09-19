import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/wayn_actions.dart';
import '../navigation/wayn_shell.dart';
import '../theme/wayn_colors.dart';
import '../../features/community/saved_posts_page.dart';
import '../../features/points/points_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/wallet/wallet_page.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'wayn_header.dart';

// ---------------------------------------------------------------------------
// بيانات القائمة: تُحمَّل عند الضغط على الزر (قبل بدء الحركة) وتُخزَّن،
// فلا يوجد setState داخل القائمة أثناء الحركة، وفتحها في المرة الثانية فوري.
// ---------------------------------------------------------------------------
@immutable
class _MenuData {
  final User? user;
  final int points;
  final bool loaded;

  const _MenuData({
    this.user,
    this.points = 0,
    this.loaded = false,
  });
}

final ValueNotifier<_MenuData> _menuData =
    ValueNotifier<_MenuData>(const _MenuData());

bool _refreshing = false;
bool _menuRouteActive = false;

Future<void> _refreshMenuData() async {
  if (_refreshing) return;
  _refreshing = true;

  try {
    User? user;

    try {
      user = await AuthService().getCurrentUser();
    } catch (_) {
      // يبقى وضع الزائر إذا تعذر تحميل المستخدم.
    }

    _menuData.value = _MenuData(
      user: user,
      points: user == null ? 0 : _menuData.value.points,
      loaded: true,
    );

    if (user == null) return;

    try {
      final points = await UserService().getMyPoints();
      _menuData.value = _MenuData(user: user, points: points, loaded: true);
    } catch (_) {
      // الرصيد اختياري ولا يمنع فتح القائمة.
    }
  } finally {
    _refreshing = false;
  }
}

/// يفتح قائمة WAYN الجانبية.
///
/// سبب التقطيع في النسخة القديمة: كانت الحركة تغيّر عرض اللوحة كل إطار
/// (ClipRect + widthFactor) فيُعاد حساب التخطيط لكل المحتوى، إضافةً إلى
/// Opacity على كامل اللوحة وsetState لتحميل المستخدم أثناء الحركة.
/// هنا اللوحة تنزلق بـ Transform فقط (بدون Layout) داخل RepaintBoundary.
Future<void> showWaynMenu(BuildContext context) async {
  if (_menuRouteActive) return;

  _menuRouteActive = true;
  waynMenuIsOpen.value = true;

  HapticFeedback.lightImpact();
  unawaited(_refreshMenuData());

  try {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => WaynMenuDrawer(animation: animation),
        // الحركة كلها داخل القائمة نفسها.
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  } finally {
    waynMenuIsOpen.value = false;
    _menuRouteActive = false;
  }
}

class WaynMenuDrawer extends StatefulWidget {
  final Animation<double> animation;

  const WaynMenuDrawer({
    super.key,
    required this.animation,
  });

  @override
  State<WaynMenuDrawer> createState() => _WaynMenuDrawerState();
}

class _WaynMenuDrawerState extends State<WaynMenuDrawer> {
  final AuthService _auth = AuthService();

  late final CurvedAnimation _panelCurve;
  late final Animation<Offset> _panelOffset;
  late final Animation<double> _scrim;

  @override
  void initState() {
    super.initState();

    _panelCurve = CurvedAnimation(
      parent: widget.animation,
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      reverseCurve: Curves.easeInOutCubic,
    );

    _panelOffset = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(_panelCurve);

    _scrim = CurveTween(curve: Curves.easeOut).animate(widget.animation);

    // زر الهيدر يبدأ العودة إلى ☰ مع بداية الإغلاق وليس بعد نهايته.
    widget.animation.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      waynMenuIsOpen.value = false;
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    _panelCurve.dispose();
    super.dispose();
  }

  // ----------------------------- الإجراءات -----------------------------

  void _close() {
    if (widget.animation.status == AnimationStatus.reverse) return;
    Navigator.of(context).pop();
  }

  void _openProfile() {
    final navigator = Navigator.of(context);

    navigator.pop();
    waynGoToProfileRequest.value++;
  }

  void _open(Widget page) {
    final navigator = Navigator.of(context);

    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _showMessage(String message) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    navigator.pop();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message, textDirection: TextDirection.rtl),
        ),
      );
  }

  Future<void> _handleLogout() async {
    await _auth.logout();

    // تصفير البيانات المخزنة حتى لا يظهر المستخدم السابق في القائمة.
    _menuData.value = const _MenuData(loaded: true);

    if (!mounted) return;

    openLoginAndRebuild(context);
  }

  void _navigateToLogin() {
    openLoginAndRebuild(context);
  }

  // ------------------------------- البناء -------------------------------

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.8).clamp(280.0, 340.0);
    final colors = context.waynColors;

    const radius = BorderRadius.horizontal(left: Radius.circular(30));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: _scrim,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const ColoredBox(
                color: Color.fromRGBO(0, 0, 0, 0.36),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: _panelOffset,
              child: RepaintBoundary(
                child: GestureDetector(
                  // سحب سريع لليمين = إغلاق.
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 280) _close();
                  },
                  child: SizedBox(
                    width: width,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.14),
                            blurRadius: 28,
                            offset: const Offset(-6, 0),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Material(
                          color: colors.surface,
                          child: ValueListenableBuilder<_MenuData>(
                            valueListenable: _menuData,
                            builder: (context, data, _) =>
                                _content(context, data),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, _MenuData data) {
    final colors = context.waynColors;
    final signedIn = data.user != null;
    final isGuest = data.loaded && !signedIn;

    var index = 1;
    Widget reveal(Widget child) => _Reveal(
          animation: widget.animation,
          index: index++,
          child: child,
        );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            MediaQuery.paddingOf(context).top + 14,
            14,
            8,
          ),
          child: _Reveal(
            animation: widget.animation,
            index: 0,
            child: _ProfileCard(
              user: data.user,
              points: data.points,
              loaded: data.loaded,
              onTap: isGuest ? _navigateToLogin : _openProfile,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
            children: [
              if (isGuest)
                reveal(
                  _MenuTile(
                    icon: Icons.login_rounded,
                    title: 'تسجيل الدخول',
                    subtitle: 'ادخل للاستمتاع بمزايا وين الكاملة',
                    onTap: _navigateToLogin,
                  ),
                ),
              if (signedIn) ...[
                reveal(
                  _MenuTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'المحفظة',
                    subtitle: 'النقاط والعملات والتحويلات',
                    onTap: () => _open(const WalletPage()),
                  ),
                ),
                reveal(
                  _MenuTile(
                    icon: Icons.stars_rounded,
                    title: 'نقاطي',
                    subtitle: '${data.points} نقطة',
                    onTap: () => _open(const PointsPage()),
                  ),
                ),
                reveal(
                  _MenuTile(
                    icon: Icons.bookmark_rounded,
                    title: 'المحفوظات',
                    subtitle: 'منشوراتك وأماكنك المحفوظة',
                    onTap: () => _open(const SavedPostsPage()),
                  ),
                ),
                reveal(
                  _MenuTile(
                    icon: Icons.bolt_rounded,
                    title: 'النشاط',
                    subtitle: 'مراجعاتك وتفاعلاتك',
                    onTap: () => _showMessage('سجل النشاط'),
                  ),
                ),
              ],
              reveal(
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: Divider(height: 1, color: colors.divider),
                ),
              ),
              reveal(
                _MenuTile(
                  icon: Icons.settings_rounded,
                  title: 'الإعدادات',
                  subtitle: 'إدارة الحساب والتخصيص',
                  onTap: () => _open(const SettingsPage()),
                ),
              ),
            ],
          ),
        ),
        if (signedIn)
          reveal(
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                MediaQuery.paddingOf(context).bottom + 10,
              ),
              child: _MenuTile(
                icon: Icons.logout_rounded,
                title: 'تسجيل الخروج',
                subtitle: 'الخروج من الحساب',
                destructive: true,
                onTap: _handleLogout,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ظهور متتابع للعناصر (Fade + انزلاق بسيط)، مربوط بنفس Animation الخاصة
// بالمسار، فيعمل عند الفتح والإغلاق بدون Controllers إضافية.
// ---------------------------------------------------------------------------
class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final Widget child;

  const _Reveal({
    required this.animation,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.12 + (index * 0.055), 0.6);
    final end = math.min(start + 0.4, 1.0);

    final curved = CurveTween(
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ).animate(animation);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.16, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة المستخدم.
// ---------------------------------------------------------------------------
class _ProfileCard extends StatelessWidget {
  final User? user;
  final int points;
  final bool loaded;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.user,
    required this.points,
    required this.loaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final signedIn = user != null;

    final displayName = !loaded
        ? ''
        : !signedIn
            ? 'زائر'
            : (user!.displayName?.trim().isNotEmpty == true
                ? user!.displayName!.trim()
                : 'مستخدم WAYN');

    final avatarLetter = displayName.isEmpty ? 'و' : displayName.substring(0, 1);

    final userId = user?.id ?? '';
    final shortId = userId.length > 10 ? userId.substring(0, 10) : userId;

    final subtitle = !loaded
        ? ''
        : signedIn
            ? 'عرض حسابي'
            : 'سجّل دخولك لمزايا وين الكاملة';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [
              _WaynMenuDrawerStateColors.tealA,
              _WaynMenuDrawerStateColors.tealB,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: _WaynMenuDrawerStateColors.tealB.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned(
                top: -34,
                left: -24,
                child: _Bubble(size: 120, alpha: 0.09),
              ),
              Positioned(
                bottom: -46,
                right: 40,
                child: _Bubble(size: 96, alpha: 0.06),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              avatarLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: loaded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _Bar(width: 90, height: 14),
                                    SizedBox(height: 8),
                                    _Bar(width: 130, height: 10),
                                  ],
                                ),
                        ),
                        const Icon(
                          Icons.chevron_left_rounded,
                          size: 26,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    if (signedIn) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(
                            icon: Icons.stars_rounded,
                            label: '$points نقطة',
                          ),
                          if (shortId.isNotEmpty)
                            _Chip(
                              icon: Icons.tag_rounded,
                              label: shortId,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ألوان البطاقة (ثوابت ليمكن استخدامها داخل const).
class _WaynMenuDrawerStateColors {
  static const Color tealA = Color(0xFF1FBFAE);
  static const Color tealB = Color(0xFF087F78);
}

class _Bubble extends StatelessWidget {
  final double size;
  final double alpha;

  const _Bubble({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
      child: SizedBox(width: size, height: size),
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;

  const _Bar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(height),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عنصر القائمة: أيقونة ممتلئة داخل مربع ناعم، عند الضغط تتوهج وتتصغر
// والسهم ينزاح.
// ---------------------------------------------------------------------------
class _MenuTile extends StatefulWidget {
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
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;
    final tint = widget.destructive ? colors.danger : colors.brand;

    const duration = Duration(milliseconds: 140);
    const curve = Curves.easeOutCubic;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: duration,
          curve: curve,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: _pressed
                ? tint.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              AnimatedScale(
                duration: duration,
                curve: curve,
                scale: _pressed ? 0.90 : 1.0,
                child: AnimatedContainer(
                  duration: duration,
                  curve: curve,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: _pressed ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(_pressed ? 22 : 15),
                  ),
                  child: Icon(widget.icon, size: 23, color: tint),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: widget.destructive
                            ? colors.danger
                            : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSlide(
                duration: duration,
                curve: curve,
                offset: Offset(_pressed ? -0.25 : 0.0, 0),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: (widget.destructive ? colors.danger : colors.textMuted)
                      .withValues(alpha: _pressed ? 0.9 : 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}