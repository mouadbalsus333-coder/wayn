import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/wayn_colors.dart';
import '../widgets/wayn_guest_banner.dart';
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
  static const int _tabCount = 5;

  int _currentIndex = 0;

  // =========================================================
  // LAZY PAGES
  // =========================================================
  //
  // الصفحة تُنشأ فقط عند أول فتح لها.
  //
  // بعد إنشائها تبقى محفوظة حتى لا نفقد:
  // - scroll position
  // - page state
  // - loaded data
  // - map state
  // - أي state داخلي للصفحة
  //
  final List<Widget?> _pages = List<Widget?>.filled(
    _tabCount,
    null,
  );

  @override
  void initState() {
    super.initState();

    // الصفحة الأولى فقط تُنشأ عند تشغيل الـ Shell.
    _pages[0] = const ExplorePage();

    waynGoToProfileRequest.addListener(_onGoToProfile);
  }

  @override
  void dispose() {
    waynGoToProfileRequest.removeListener(_onGoToProfile);
    super.dispose();
  }

  // =========================================================
  // LAZY PAGE CREATION
  // =========================================================

  Widget _pageForIndex(int index) {
    final existingPage = _pages[index];

    if (existingPage != null) {
      return existingPage;
    }

    final Widget page;

    switch (index) {
      case 0:
        page = const ExplorePage();
        break;

      case 1:
        page = const MapPage();
        break;

      case 2:
        page = const StorePage();
        break;

      case 3:
        page = const CommunityPage();
        break;

      case 4:
        page = ProfilePage(
          user: widget.user,
        );
        break;

      default:
        page = const SizedBox.shrink();
    }

    _pages[index] = page;

    return page;
  }

  // =========================================================
  // PROFILE REQUEST
  // =========================================================

  void _onGoToProfile() {
    if (!mounted) return;

    if (_currentIndex == _profileTabIndex) return;

    HapticFeedback.selectionClick();

    setState(() {
      // نضمن إنشاء صفحة الحساب عند الانتقال إليها
      // مع الحفاظ على state بعد ذلك.
      _pages[_profileTabIndex] ??= ProfilePage(
        user: widget.user,
      );

      _currentIndex = _profileTabIndex;
    });
  }

  // =========================================================
  // TAB SELECTION
  // =========================================================

  void _selectTab(int index) {
    if (_currentIndex == index) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      // الصفحة يتم إنشاؤها هنا فقط عند أول دخول للتبويب.
      _pageForIndex(index);

      _currentIndex = index;
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

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
            // نستمع للتمرير فقط لإخفاء إشعار الزائر تلقائيًا
            // عند سحب الصفحة للأعلى أثناء التصفح.
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification &&
                    notification.dragDetails != null &&
                    (notification.scrollDelta ?? 0) > 0 &&
                    WaynGuestBannerDismissed.instance.value == false) {
                  WaynGuestBannerDismissed.instance.value = true;
                }

                return false;
              },
              child: IndexedStack(
                index: _currentIndex,
                children: List<Widget>.generate(
                  _tabCount,
                  (index) {
                    return _pages[index] ?? const SizedBox.shrink();
                  },
                ),
              ),
            ),

            // في تبويب المجتمع يعرض الصفحة إشعارها الخاص أسفل الهيدر،
            // لذا لا نظهر البنر العام هنا لتجنب التكرار.
            if (isGuest && _currentIndex != _communityTabIndex)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: WaynGuestBanner(),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigation(colors),
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

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
            vertical: 9,
          ),
          child: Row(
            children: List.generate(
              items.length,
              (index) {
                final selected = _currentIndex == index;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      splashFactory: InkRipple.splashFactory,
                      onTap: () => _selectTab(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.surfaceAlt
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                items[index].$1,
                                size: 24,
                                color: selected
                                    ? colors.brand
                                    : colors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: selected ? 12 : 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? colors.brand
                                    : colors.textMuted,
                              ),
                              child: Text(
                                items[index].$2,
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
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