import 'package:flutter/material.dart';

import '../../features/auth/login_page.dart';
import '../../features/community/community_page.dart';
import '../../features/explore/explore_page.dart';
import '../../features/map/map_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/store/store_page.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';

class WaynShell extends StatefulWidget {
  final User user;

  const WaynShell({
    super.key,
    required this.user,
  });

  @override
  State<WaynShell> createState() => _WaynShellState();
}

class _WaynShellState extends State<WaynShell> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages(widget.user);
  }

  List<Widget> _buildPages(User user) {
    return [
      const ExplorePage(),
      const MapPage(),
      const StorePage(),
      const CommunityPage(),
      ProfilePage(
        user: user,
        onLogout: _logout,
      ),
    ];
  }

  Future<void> _logout() async {
    await AuthService().logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onAuthenticated: (user) {
            Navigator.of(context).pushAndRemoveUntil(
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // نبقي جسم الشل متغير الحجم ثابتًا عند ظهور الكيبورد حتى لا تهتز
        // المكوّنات داخله (خصوصًا الخريطة في تبويب الخريطة).
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildBottomNavigation() {
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            items[index].$1,
                            size: 22,
                            color: selected
                                ? const Color(0xFF18A99A)
                                : const Color(0xFF8B94A3),
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
                                  ? const Color(0xFF18A99A)
                                  : const Color(0xFF8B94A3),
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