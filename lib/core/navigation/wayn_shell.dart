import 'package:flutter/material.dart';

import '../../features/home/home_page.dart';
import '../../features/profile/profile_page.dart';

class WaynShell extends StatefulWidget {
  const WaynShell({super.key});

  @override
  State<WaynShell> createState() => _WaynShellState();
}

class _WaynShellState extends State<WaynShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = const [
      HomePage(),
      _PlaceholderPage(
        icon: Icons.map_rounded,
        title: 'الخريطة',
        description: 'خريطة WAYN ستكون هنا.',
      ),
      _PlaceholderPage(
        icon: Icons.groups_rounded,
        title: 'المجتمع',
        description: 'مجتمع WAYN سيكون هنا.',
      ),
      _PlaceholderPage(
        icon: Icons.local_offer_rounded,
        title: 'العروض',
        description: 'عروض WAYN ستكون هنا.',
      ),
      ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
      (Icons.home_rounded, 'الرئيسية'),
      (Icons.map_rounded, 'الخريطة'),
      (Icons.groups_rounded, 'المجتمع'),
      (Icons.local_offer_rounded, 'العروض'),
      (Icons.person_rounded, 'حسابي'),
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
            horizontal: 8,
            vertical: 8,
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
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE6F8F5)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              items[index].$1,
                              size: 22,
                              color: selected
                                  ? const Color(0xFF16A899)
                                  : const Color(0xFF8B94A3),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            items[index].$2,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: selected
                                  ? const Color(0xFF16A899)
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

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F8F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: const Color(0xFF18A99A),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A8494),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}