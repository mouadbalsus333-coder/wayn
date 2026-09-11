import 'package:flutter/material.dart';

import '../../../core/theme/wayn_colors.dart';
import '../../../models/category.dart';

/// معيار الترتيب الفعّال الوحيد لقسم «الحالة».
///
/// رغم أن الواجهة تسمح بتحديد متعدد، فإن معايير الترتيب (الأكثر زيارة /
/// الأعلى تقييمًا / الأقرب إلي) هي **معيار واحد فعّال**: آخر ما يختاره
/// المستخدم هو المعيار المطبَّق ويلغي سابقه. «مفتوح الآن» فلتر مستقل
/// يُدمج مع أي معيار ترتيب.
enum PlaceSortCriterion { reviews, rating, distance }

/// نتيجة الفلترة الموحّدة التي يستهلكها كلٌّ من Explore و Map.
class PlaceFilter {
  final PlaceSortCriterion? sort;
  final bool openOnly;
  final List<String> categoryIds;

  const PlaceFilter({
    this.sort,
    this.openOnly = false,
    this.categoryIds = const [],
  });

  /// لا يوجد أي فلتر حالة (لا ترتيب ولا مفتوح الآن).
  bool get isAllStatus => sort == null && !openOnly;

  /// لا يوجد قيد تصنيف («الكل»).
  bool get allCategories => categoryIds.isEmpty;

  bool get isEmpty => isAllStatus && allCategories;
}

/// سلسلة query جاهزة تُرسل إلى endpoint /places المدمج.
class PlaceFilterQuery {
  final String? sortBy;
  final bool? isOpen;
  final List<String>? categoryIds;
  final double? latitude;
  final double? longitude;

  const PlaceFilterQuery({
    this.sortBy,
    this.isOpen,
    this.categoryIds,
    this.latitude,
    this.longitude,
  });

  /// يُرجع معاملات query مع إسقاط فرز «الأقرب إلي» تلقائيًا عند غياب
  /// الموقع حتى لا يحدث Crash (لا موقع افتراضي مخترَع).
  static PlaceFilterQuery fromFilter(PlaceFilter filter, {
    double? latitude,
    double? longitude,
  }) {
    String? sortBy;

    if (filter.sort == null) {
      sortBy = null;
    } else {
      switch (filter.sort) {
        case PlaceSortCriterion.reviews:
          sortBy = 'reviews';
        case PlaceSortCriterion.rating:
          sortBy = 'rating';
        case PlaceSortCriterion.distance:
          sortBy = 'distance';
        case null:
          sortBy = null;
      }
    }

    var lat = latitude;
    var lng = longitude;

    if (sortBy == 'distance' && (lat == null || lng == null)) {
      sortBy = null;
      lat = null;
      lng = null;
    }

    return PlaceFilterQuery(
      sortBy: sortBy,
      isOpen: filter.openOnly ? true : null,
      categoryIds: filter.allCategories
          ? null
          : filter.categoryIds.toList(),
      latitude: lat,
      longitude: lng,
    );
  }
}

typedef void PlaceFilterChanged(PlaceFilter value);

/// ورقة الفلترة الموحّدة (قسم الحالة + قسم التصنيف) المستخدمة من
/// Explore و Map عبر زر الفلتر داخل مستطيل البحث.
class PlaceFilterSheet extends StatefulWidget {
  final List<Category> categories;
  final PlaceFilter initial;
  final PlaceFilterChanged onApply;

  const PlaceFilterSheet({
    super.key,
    required this.categories,
    required this.initial,
    required this.onApply,
  });

  @override
  State<PlaceFilterSheet> createState() => _PlaceFilterSheetState();
}

class _PlaceFilterSheetState extends State<PlaceFilterSheet> {
  PlaceSortCriterion? _sort;
  bool _openOnly = false;
  final Set<String> _selectedCategoryIds = <String>{};

  @override
  void initState() {
    super.initState();
    _sort = widget.initial.sort;
    _openOnly = widget.initial.openOnly;
    _selectedCategoryIds.addAll(widget.initial.categoryIds);
  }

  void _clearStatus() {
    setState(() {
      _sort = null;
      _openOnly = false;
    });
  }

  void _toggleSort(PlaceSortCriterion criterion) {
    setState(() {
      // تحديد معيار ترتيب معين يجعلانه المعيار الفعّال الوحيد،
      // والضغط عليه مرة أخرى يلغي فرز «الحالة» تمامًا.
      _sort = (_sort == criterion) ? null : criterion;
    });
  }

  void _toggleOpen() {
    setState(() {
      _openOnly = !_openOnly;
    });
  }

  void _selectAllCategories() {
    setState(() {
      _selectedCategoryIds.clear();
    });
  }

  void _toggleCategory(String id) {
    setState(() {
      if (_selectedCategoryIds.contains(id)) {
        _selectedCategoryIds.remove(id);
      } else {
        _selectedCategoryIds.add(id);
      }
    });
  }

  void _apply() {
    widget.onApply(
      PlaceFilter(
        sort: _sort,
        openOnly: _openOnly,
        categoryIds: _selectedCategoryIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    final sortSelected = (PlaceSortCriterion? criterion) {
      return _sort == criterion;
    };

    final allPlacesSelected = _sort == null && !_openOnly;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'الفلاتر',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'الحالة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  children: [
                    _buildChip(
                      label: 'الأكثر زيارة',
                      selected: sortSelected(
                        PlaceSortCriterion.reviews,
                      ),
                      onTap: () {
                        _toggleSort(
                          PlaceSortCriterion.reviews,
                        );
                      },
                    ),
                    _buildChip(
                      label: 'الأعلى تقييمًا',
                      selected: sortSelected(
                        PlaceSortCriterion.rating,
                      ),
                      onTap: () {
                        _toggleSort(
                          PlaceSortCriterion.rating,
                        );
                      },
                    ),
                    _buildChip(
                      label: 'الأقرب إلي',
                      selected: sortSelected(
                        PlaceSortCriterion.distance,
                      ),
                      onTap: () {
                        _toggleSort(
                          PlaceSortCriterion.distance,
                        );
                      },
                    ),
                    _buildChip(
                      label: 'مفتوح الآن',
                      selected: _openOnly,
                      onTap: _toggleOpen,
                    ),
                    _buildChip(
                      label: 'كل الأماكن',
                      selected: allPlacesSelected,
                      onTap: _clearStatus,
                    ),
                  ],
                ),
const SizedBox(height: 20),
                Text(
                  'التصنيف',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.categories.isEmpty)
                  Text(
                    'لا توجد تصنيفات متاحة',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  )
                else
                  Wrap(
                    children: [
                      _buildChip(
                        label: 'الكل',
                        selected: _selectedCategoryIds.isEmpty,
                        onTap: _selectAllCategories,
                      ),
                      for (final category in widget.categories)
                        _buildChip(
                          label: category.nameAr.isEmpty
                              ? (category.nameEn ?? category.id)
                              : category.nameAr,
                          selected: _selectedCategoryIds.contains(
                            category.id,
                          ),
                          onTap: () =>
                              _toggleCategory(category.id),
                        ),
                    ],
                  ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'إعادة تعيين',
                        backgroundColor: colors.surfaceElevated,
                        foregroundColor: colors.textPrimary,
                        onTap: _clearStatus,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        label: 'تطبيق الفلتر',
                        backgroundColor: colors.brand,
                        foregroundColor: colors.onBrand,
                        onTap: _apply,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = context.waynColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(left: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.brand
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? colors.brand
                : colors.divider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? colors.onBrand
                : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}
