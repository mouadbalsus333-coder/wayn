import 'package:flutter/material.dart';

class MapFilterChips extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MapFilterChips({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      'الكل',
      'مطاعم',
      'منتزهات',
      'شواطئ',
      'فنادق',
      'أسواق',
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;

          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF18A99A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF18A99A)
                      : const Color(0xFFE5E9EF),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                filters[index],
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF667085),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}