import 'package:flutter/material.dart';

import '../../../core/theme/wayn_colors.dart';

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
    final colors = context.waynColors;

    final filters = [
      ('كل الأماكن', Icons.apps_rounded),
      ('مفتوح الآن', Icons.access_time_rounded),
      ('الأعلى تقييماً', Icons.star_rounded),
      ('الأكثر زيارة', Icons.local_fire_department_rounded),
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
                color: selected ? colors.surfaceAlt : colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? colors.brand : colors.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filter.$2,
                    size: 17,
                    color: selected ? colors.brand : colors.textMuted,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    filter.$1,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? colors.brand : colors.textSecondary,
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
