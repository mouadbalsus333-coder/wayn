import 'package:flutter/material.dart';

import '../theme/wayn_colors.dart';
import '../../features/community/community_page.dart';
import '../../features/explore/explore_page.dart';
import '../../features/map/map_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/store/store_page.dart';
import '../../models/user.dart';
import 'wayn_actions.dart';

class WaynShell extends StatefulWidget {
  final User? user;
  final VoidCallback? onLogout;

  const WaynShell({
    super.key,
    required this.user,
    this.onLogout,
  });

  @override
  State<WaynShell> createState() => _WaynShellState();
}

class _WaynShellState extends State<WaynShell> {
  static const int _profileTabIndex = 4;
  static const int _communityTabIndex = 3;

  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages(widget.user);
    waynGoToProfileRequest.addListener(_onGoToProfile);
  }

  @override
  void dispose() {
    waynGoToProfileRequest.removeListener(_onGoToProfile);
    super.dispose();
  }

  void _onGoToProfile() {
    if (!mounted) return;

    if (_currentIndex == _profileTabIndex) return;

    setState(() {
      _currentIndex = _profileTabIndex;
    });
  }

  List<Widget> _buildPages(User? user) {
    return [
      const ExplorePage(),
      const MapPage(),
      const StorePage(),
      const CommunityPage(),
      ProfilePage(
        user: user,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;
    final isGuest = widget.user == null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            // في تبويب المجتمع يعرض الصفحة إشعارها الخاص أسفل الهيدر،
            // لذا لا نظهر البنر العام هنا لتجنب التكرار.
            if (isGuest && _currentIndex != _communityTabIndex)
              _GuestLoginBanner(onLoginPressed: () {
                openLoginAndRebuild(context);
              }),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigation(colors),
      ),
    );
  }

  Widget _buildBottomNavigation(WaynColors colors) {
    const items = [
      (
        Icons.explore_rounded,
        'استكشف',
      ),
      (
        Icons.map_rounded,
        'الخريطة',
      ),
      (
        Icons.storefront_rounded,
        'المتجر',
      ),
      (
        Icons.groups_rounded,
        'المجتمع',
      ),
      (
        Icons.person_rounded,
        'حسابي',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 7,
          ),
          child: Row(
            children: List.generate(
              items.length,
              (index) {
                final selected = _currentIndex == index;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.surfaceAlt
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            items[index].$1,
                            size: 22,
                            color: selected
                                ? colors.brand
                                : colors.textMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            items[index].$2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: selected
                                  ? colors.brand
                                  : colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestLoginBanner extends StatelessWidget {
  final VoidCallback onLoginPressed;

  const _GuestLoginBanner({required this.onLoginPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.brand.withValues(alpha: 0.12),
                colors.brand.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.brand.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.brand.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: colors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً بك في وين!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سجّل دخولك للاستمتاع بجميع الميزات',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onLoginPressed,
                style: TextButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
