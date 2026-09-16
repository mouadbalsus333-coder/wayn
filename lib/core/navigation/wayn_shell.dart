import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/wayn_colors.dart';
import '../widgets/wayn_guest_banner.dart';
import '../../features/community/community_page.dart';
import '../../features/explore/explore_page.dart';
import '../../features/map/map_page.dart';
import 'package:wayn/features/profile/profile_page.dart';
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

  final List<Widget?> _pages = List<Widget?>.filled(
    _tabCount,
    null,
  );

  @override
  void initState() {
    super.initState();

    _pages[0] = const ExplorePage();

    waynGoToProfileRequest.addListener(_onGoToProfile);
  }

  @override
  void dispose() {
    waynGoToProfileRequest.removeListener(_onGoToProfile);
    super.dispose();
  }

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

  void _onGoToProfile() {
    if (!mounted) return;

    if (_currentIndex == _profileTabIndex) return;

    HapticFeedback.selectionClick();

    setState(() {
      _pages[_profileTabIndex] ??= ProfilePage(
        user: widget.user,
      );

      _currentIndex = _profileTabIndex;
    });
  }

  void _selectTab(int index) {
    HapticFeedback.selectionClick();

    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _pageForIndex(index);
      _currentIndex = index;
    });
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
        bottomNavigationBar: _WaynBottomNavigation(
          currentIndex: _currentIndex,
          colors: colors,
          onChanged: _selectTab,
        ),
      ),
    );
  }
}

// =============================================================
// WAYN BOTTOM NAVIGATION
// =============================================================

class _WaynBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final WaynColors colors;
  final ValueChanged<int> onChanged;

  const _WaynBottomNavigation({
    required this.currentIndex,
    required this.colors,
    required this.onChanged,
  });

  static const _items = [
    (
      icon: Icons.explore_rounded,
      label: 'استكشف',
    ),
    (
      icon: Icons.map_rounded,
      label: 'الخريطة',
    ),
    (
      icon: Icons.storefront_rounded,
      label: 'المتجر',
    ),
    (
      icon: Icons.groups_rounded,
      label: 'المجتمع',
    ),
    (
      icon: Icons.person_rounded,
      label: 'حسابي',
    ),
  ];

  double _indicatorAlignmentX(int index) {
    return 1.0 - (index * 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.075),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, -7),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 78,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // =================================================
                    // MOVING ACTIVE BACKGROUND
                    // =================================================

                    IgnorePointer(
                      child: AnimatedAlign(
                        alignment: Alignment(
                          _indicatorAlignmentX(currentIndex),
                          0,
                        ),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 68,
                          height: 58,
                          decoration: BoxDecoration(
                            color: colors.brand.withValues(alpha: 0.105),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: colors.brand.withValues(alpha: 0.065),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.brand.withValues(alpha: 0.055),
                                blurRadius: 16,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // =================================================
                    // NAVIGATION BUTTONS
                    // =================================================

                    Row(
                      children: List.generate(
                        _items.length,
                        (index) {
                          final item = _items[index];

                          return Expanded(
                            child: _WaynNavigationButton(
                              icon: item.icon,
                              label: item.label,
                              selected: currentIndex == index,
                              colors: colors,
                              onTap: () => onChanged(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// WAYN NAVIGATION BUTTON
// =============================================================

class _WaynNavigationButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final WaynColors colors;
  final VoidCallback onTap;

  const _WaynNavigationButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_WaynNavigationButton> createState() =>
      _WaynNavigationButtonState();
}

class _WaynNavigationButtonState extends State<_WaynNavigationButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _liftAnimation;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 190),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.09,
    ).animate(curvedAnimation);

    _liftAnimation = Tween<double>(
      begin: 0.0,
      end: -3.0,
    ).animate(curvedAnimation);

    if (widget.selected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(
    covariant _WaynNavigationButton oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selected == widget.selected) {
      return;
    }

    if (widget.selected) {
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!mounted) return;

    setState(() {
      _pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (!mounted) return;

    setState(() {
      _pressed = false;
    });

    widget.onTap();
  }

  void _onTapCancel() {
    if (!mounted) return;

    setState(() {
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: SizedBox(
        height: 64,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pressScale = _pressed ? 0.93 : 1.0;

            return Transform.translate(
              offset: Offset(
                0,
                _liftAnimation.value,
              ),
              child: Transform.scale(
                scale: _scaleAnimation.value * pressScale,
                child: child,
              ),
            );
          },
          child: Center(
            child: SizedBox(
              width: 68,
              height: 58,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // =================================================
                  // ICON
                  // =================================================

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    height: widget.selected ? 29 : 30,
                    width: widget.selected ? 34 : 30,
                    alignment: Alignment.center,
                    child: Icon(
                      widget.icon,
                      size: widget.selected ? 29 : 26,
                      color: widget.selected
                          ? widget.colors.brand
                          : widget.colors.textMuted,
                    ),
                  ),

                  // =================================================
                  // LABEL
                  // =================================================

                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      reverseDuration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: widget.selected
                          ? Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                widget.label,
                                textDirection: TextDirection.rtl,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.1,
                                  color: widget.colors.brand,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}