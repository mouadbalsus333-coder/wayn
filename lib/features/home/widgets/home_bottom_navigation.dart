import 'package:flutter/material.dart';

class HomeBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const HomeBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
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
                final selected = currentIndex == index;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onItemSelected(index),
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