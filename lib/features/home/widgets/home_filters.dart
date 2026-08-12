import 'package:flutter/material.dart';

class HomeFilters extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onFilterSelected;

  const HomeFilters({
    super.key,
    required this.selectedIndex,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('الأقرب', Icons.near_me_rounded),
      ('مفتوح الآن', Icons.access_time_rounded),
      ('الأعلى تقييماً', Icons.star_rounded),
      ('الأكثر شعبية', Icons.local_fire_department_rounded),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedIndex == index;

          return GestureDetector(
            onTap: () => onFilterSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE8F8F6)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF36B7A6)
                      : const Color(0xFFE8EBF0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filter.$2,
                    size: 17,
                    color: selected
                        ? const Color(0xFF16A899)
                        : const Color(0xFF707B8C),
                  ),

                  const SizedBox(width: 6),

                  Text(
                    filter.$1,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFF168F83)
                          : const Color(0xFF5F6979),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}