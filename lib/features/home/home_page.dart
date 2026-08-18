import 'package:flutter/material.dart';

import '../../services/category_service.dart';
import '../../services/place_service.dart';
import '../places/place_details_page.dart';
import 'models/place.dart';
import 'widgets/home_filters.dart';
import 'widgets/home_header.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/place_card.dart';
import 'widgets/section_header.dart';
import '../../services/favorite_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PlaceService _placeService = PlaceService();
  final CategoryService _categoryService = CategoryService();
  final FavoriteService _favoriteService = FavoriteService();
  final Set<String> _favoriteIds = <String>{};

  int _selectedFilterIndex = 0;

  List<Place> _places = [];
  List<Category> _categories = [];

  bool _isLoading = true;
  CategoryLoadStatus _categoriesStatus = CategoryLoadStatus.loading;

  String? _errorMessage;

  String _searchQuery = '';

  String? _selectedCategory;
  String _selectedCategoryLabel = 'كل الأماكن';

  @override
  void initState() {
    super.initState();

    _loadPlaces();
    _loadCategories();
  }

  // ================================================================
  // LOAD PLACES
  // ================================================================

  Future<void> _loadPlaces() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final places = await _placeService.getPlaces();

      if (!mounted) return;

      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _errorMessage = error.toString();
      });

      debugPrint('Failed to load places: $error');
    }
  }

  // ================================================================
  // LOAD CATEGORIES
  // ================================================================

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _categoriesStatus = CategoryLoadStatus.loading;
      });
    }

    final result = await _categoryService.getCategories();

    if (!mounted) return;

    final uniqueCategories = <String, Category>{};

    for (final category in result.categories) {
      final key = category.nameAr.trim().toLowerCase();

      if (key.isEmpty) {
        continue;
      }

      final existing = uniqueCategories[key];

      // Prefer the category that has an icon configured. This also
      // protects the UI from accidental duplicate rows in the database.
      if (existing == null ||
          (existing.icon == null || existing.icon!.trim().isEmpty) &&
              category.icon != null &&
              category.icon!.trim().isNotEmpty) {
        uniqueCategories[key] = category;
      }
    }

    final categories = uniqueCategories.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    setState(() {
      _categories = categories;
      _categoriesStatus = result.status;
    });
  }

  // ================================================================
  // SEARCH
  // ================================================================

  Future<void> _searchPlaces(String query) async {
    final search = query.trim();

    setState(() {
      _searchQuery = search;
      _selectedCategory = null;
      _selectedCategoryLabel = 'كل الأماكن';

      _selectedFilterIndex = -1;

      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final places = await _placeService.searchPlaces(search);

      if (!mounted) return;

      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _errorMessage = error.toString();
      });

      debugPrint('Search failed: $error');
    }
  }

  // ================================================================
  // FILTER
  // ================================================================

  Future<void> _onFilterSelected(int index) async {
    setState(() {
      _selectedFilterIndex = index;

      _selectedCategory = null;
      _selectedCategoryLabel = 'كل الأماكن';

      _searchQuery = '';

      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Place> places;

      switch (index) {
        case 0:
          places = await _placeService.getPlaces();
          break;

        case 1:
          places = await _placeService.getOpenPlaces();
          break;

        case 2:
          places = await _placeService.getHighestRatedPlaces();
          break;

        case 3:
          places = await _placeService.getMostVisitedPlaces();
          break;

        default:
          places = await _placeService.getPlaces();
      }

      if (!mounted) return;

      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _errorMessage = error.toString();
      });

      debugPrint('Filter failed: $error');
    }
  }

  // ================================================================
  // CATEGORY
  // ================================================================

  Future<void> _onCategorySelected(Category category) async {
    setState(() {
      _selectedCategory = category.id;
      _selectedCategoryLabel = category.nameAr;

      _selectedFilterIndex = -1;
      _searchQuery = '';

      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final places = await _placeService.getPlacesByCategory(
        category.id,
      );

      if (!mounted) return;

      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _errorMessage = error.toString();
      });

      debugPrint(
        'Failed to load category ${category.nameAr}: $error',
      );
    }
  }

  // ================================================================
  // ALL PLACES
  // ================================================================

  Future<void> _selectAllPlaces() async {
    setState(() {
      _selectedCategory = null;
      _selectedCategoryLabel = 'كل الأماكن';

      _selectedFilterIndex = 0;
      _searchQuery = '';

      _isLoading = true;
      _errorMessage = null;
    });

    await _loadPlaces();
  }

  // ================================================================
  // CATEGORY SELECTOR
  // ================================================================

  void _onCategoryPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: _CategoryBottomSheet(
            categories: _categories,
            status: _categoriesStatus,
            selectedCategory: _selectedCategory,

            // كل الأماكن
            onAllPressed: () async {
              Navigator.of(sheetContext).pop();

              await _selectAllPlaces();
            },

            // اختيار فئة
            onCategoryPressed: (category) async {
              Navigator.of(sheetContext).pop();

              await _onCategorySelected(category);
            },

            iconFromName: _iconFromName,
          ),
        );
      },
    );
  }

  // ================================================================
  // OPEN PLACES
  // ================================================================

  Future<void> _openPlacesSuggestion() async {
    await _onFilterSelected(1);
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _loadPlaces(),
                _loadCategories(),
              ]);
            },
            color: const Color(0xFF18A99A),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // =====================================================
                // HEADER
                // =====================================================

                SliverToBoxAdapter(
                  child: HomeHeader(
                    onMenuPressed: _onMenuPressed,
                    onNotificationsPressed:
                        _onNotificationsPressed,
                  ),
                ),

                // =====================================================
                // SEARCH
                // =====================================================

                SliverToBoxAdapter(
                  child: HomeSearchBar(
                    selectedCategory: _selectedCategoryLabel,
                    onCategoryPressed: _onCategoryPressed,
                    onSearchChanged: _searchPlaces,
                  ),
                ),

                // =====================================================
                // FILTERS
                // =====================================================

                SliverToBoxAdapter(
                  child: HomeFilters(
                    selectedIndex: _selectedFilterIndex,
                    onFilterSelected: _onFilterSelected,
                  ),
                ),

                // =====================================================
                // EXPLORE BY CATEGORY
                // =====================================================

                SliverToBoxAdapter(
                  child: _buildExploreCategoriesSection(),
                ),

                // =====================================================
                // SUGGESTIONS
                // =====================================================

                SliverToBoxAdapter(
                  child: _buildSuggestionsSection(),
                ),

                // =====================================================
                // RESULTS HEADER
                // =====================================================

                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: _buildResultsTitle(),
                    action: 'عرض الكل',
                    onActionPressed: _onViewAllPressed,
                  ),
                ),

                // =====================================================
                // RESULTS
                // =====================================================

                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: _LoadingPlaces(),
                  )
                else if (_errorMessage != null)
                  SliverToBoxAdapter(
                    child: _buildErrorState(),
                  )
                else if (_places.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final place = _places[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: PlaceCard(
                            place: place,
                            onFavoritePressed: () {
                              _onFavoritePressed(place);
                            },
                            onPressed: () {
                              _onPlacePressed(place);
                            },
                          ),
                        );
                      },
                      childCount: _places.length,
                    ),
                  ),

                // =====================================================
                // BOTTOM SPACE
                // =====================================================

                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // RESULTS TITLE
  // ================================================================

  String _buildResultsTitle() {
    if (_searchQuery.isNotEmpty) {
      return 'نتائج البحث';
    }

    if (_selectedCategory != null) {
      return _selectedCategoryLabel;
    }

    switch (_selectedFilterIndex) {
      case 1:
        return 'مفتوح الآن';

      case 2:
        return 'الأعلى تقييمًا';

      case 3:
        return 'الأكثر زيارة';

      default:
        return 'الأكثر زيارة';
    }
  }

  // ================================================================
  // EXPLORE CATEGORIES
  // ================================================================

  Widget _buildExploreCategoriesSection() {
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            12,
          ),
          child: Text(
            'استكشف حسب الفئة',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ),

        SizedBox(
          height: 108,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            separatorBuilder: (_, _) {
              return const SizedBox(width: 12);
            },
            itemBuilder: (context, index) {
              final category = _categories[index];

              final isSelected =
                  _selectedCategory == category.id;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _onCategorySelected(category);
                },
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  width: 82,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8F8F6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF18A99A)
                          : const Color(0xFFE8EBF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.025,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F8F6),
                          borderRadius:
                              BorderRadius.circular(15),
                        ),
                        child: Icon(
                          _iconFromName(category.icon),
                          color: const Color(0xFF18A99A),
                          size: 24,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                        ),
                        child: Text(
                          category.nameAr,
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4E596B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================================================================
  // CATEGORY ICON
  // ================================================================

  IconData _iconFromName(String? iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant_rounded;

      case 'park':
        return Icons.park_rounded;

      case 'beach_access':
        return Icons.beach_access_rounded;

      case 'hotel':
        return Icons.hotel_rounded;

      case 'shopping_bag':
        return Icons.shopping_bag_rounded;

      case 'sports_soccer':
        return Icons.sports_soccer_rounded;

      case 'mosque':
        return Icons.mosque_rounded;

      case 'local_hospital':
        return Icons.local_hospital_rounded;

      case 'school':
        return Icons.school_rounded;

      case 'local_cafe':
        return Icons.local_cafe_rounded;

      case 'local_gas_station':
        return Icons.local_gas_station_rounded;

      case 'pharmacy':
        return Icons.local_pharmacy_rounded;

      case 'museum':
        return Icons.museum_rounded;

      case 'store':
        return Icons.store_rounded;

      case 'shopping_cart':
        return Icons.shopping_cart_rounded;

      case 'local_parking':
        return Icons.local_parking_rounded;

      case 'fitness_center':
        return Icons.fitness_center_rounded;

      case 'local_atm':
        return Icons.local_atm_rounded;

      case 'bank':
        return Icons.account_balance_rounded;

      case 'government':
        return Icons.account_balance_rounded;

      default:
        return Icons.place_rounded;
    }
  }

  // ================================================================
  // SUGGESTIONS
  // ================================================================

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            28,
            20,
            12,
          ),
          child: Text(
            'اقتراحات لك',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ),

        _buildSuggestionCard(
          title: 'أماكن قريبة منك',
          subtitle: 'أماكن مميزة حول موقعك الحالي',
          icon: Icons.near_me_rounded,
          iconColor: const Color(0xFF18A99A),
          onPressed: () {
            debugPrint('Nearby places pressed');
          },
        ),

        _buildSuggestionCard(
          title: 'أماكن مناسبة لك',
          subtitle: 'اقتراحات بناءً على اهتماماتك',
          icon: Icons.auto_awesome_rounded,
          iconColor: const Color(0xFF7B61D9),
          onPressed: () {
            debugPrint('Personalized places pressed');
          },
        ),

        _buildSuggestionCard(
          title: 'أماكن مفتوحة الآن',
          subtitle: 'اكتشف الأماكن المتاحة حاليًا',
          icon: Icons.access_time_rounded,
          iconColor: const Color(0xFF2997FF),
          onPressed: _openPlacesSuggestion,
        ),
      ],
    );
  }

  // ================================================================
  // SUGGESTION CARD
  // ================================================================

  Widget _buildSuggestionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 6,
      ),
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.04,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8993A3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: Color(0xFF9AA3B1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // ERROR STATE
  // ================================================================

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        10,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE8EBF0),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Color(0xFF9AA3B1),
            ),

            const SizedBox(height: 12),

            const Text(
              'تعذر تحميل الأماكن',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8993A3),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _loadPlaces,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF18A99A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _buildEmptyState() {
    String message = 'لا توجد أماكن متاحة حاليًا';

    if (_searchQuery.isNotEmpty) {
      message = 'لم نجد أماكن تطابق بحثك';
    } else if (_selectedCategory != null) {
      message = 'لا توجد أماكن في هذه الفئة';
    } else if (_selectedFilterIndex == 1) {
      message = 'لا توجد أماكن مفتوحة الآن';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        10,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE8EBF0),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 42,
              color: Color(0xFF9AA3B1),
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // HEADER ACTIONS
  // ================================================================

  void _onMenuPressed() {
    debugPrint('Menu pressed');
  }

  void _onNotificationsPressed() {
    debugPrint('Notifications pressed');
  }

  // ================================================================
  // VIEW ALL
  // ================================================================

  Future<void> _onViewAllPressed() async {
    await _selectAllPlaces();
  }

  // ================================================================
  // FAVORITE
  // ================================================================

  Future<void> _onFavoritePressed(Place place) async {
    try {
      if (_favoriteIds.contains(place.id)) {
        await _favoriteService.remove(place.id);
        if (mounted) setState(() => _favoriteIds.remove(place.id));
      } else {
        await _favoriteService.add(place.id);
        if (mounted) setState(() => _favoriteIds.add(place.id));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث المفضلة: $error')),
        );
      }
    }
  }

  // ================================================================
  // PLACE DETAILS
  // ================================================================

  void _onPlacePressed(Place place) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailsPage(
          place: place,
        ),
      ),
    );
  }
}

// ==================================================================
// CATEGORY BOTTOM SHEET
// ==================================================================

class _CategoryBottomSheet extends StatelessWidget {
  final List<Category> categories;
  final CategoryLoadStatus status;
  final String? selectedCategory;

  final VoidCallback onAllPressed;
  final ValueChanged<Category> onCategoryPressed;

  final IconData Function(String?) iconFromName;

  const _CategoryBottomSheet({
    required this.categories,
    required this.status,
    required this.selectedCategory,
    required this.onAllPressed,
    required this.onCategoryPressed,
    required this.iconFromName,
  });

  bool get isLoading => status == CategoryLoadStatus.loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),

            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD9DEE7),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 18),

            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'اختر الفئة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: status == CategoryLoadStatus.error
                  ? const _CategoryStateMessage(
                      icon: Icons.cloud_off_rounded,
                      message: 'تعذر تحميل الفئات. تحقق من الاتصال وحاول مرة أخرى.',
                    )
                  : isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF18A99A),
                      ),
                    )
                  : categories.isEmpty
                      ? status == CategoryLoadStatus.permissionDenied
                          ? const _CategoryStateMessage(
                              icon: Icons.lock_outline_rounded,
                              message: 'تعذر الوصول إلى الفئات بسبب الصلاحيات.',
                            )
                          : status == CategoryLoadStatus.failure
                              ? const _CategoryStateMessage(
                                  icon: Icons.cloud_off_rounded,
                                  message: 'تعذر تحميل الفئات. حاول مرة أخرى.',
                                )
                              : Center(
                          child: Text(
                            'لا توجد فئات متاحة',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Color(0xFF8993A3),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            20,
                          ),
                          children: [
                            _buildAllTile(),

                            const SizedBox(height: 8),

                            ...categories.map(
                              (category) =>
                                  _buildCategoryTile(
                                context,
                                category,
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildEmptyState() {
    switch (status) {
      case CategoryLoadStatus.permissionDenied:
        return const _CategoryStateMessage(
          icon: Icons.lock_outline_rounded,
          message: 'تعذر الوصول إلى الفئات بسبب الصلاحيات.',
        );
      case CategoryLoadStatus.failure:
        return const _CategoryStateMessage(
          icon: Icons.cloud_off_rounded,
          message: 'تعذر تحميل الفئات. حاول مرة أخرى.',
        );
      case CategoryLoadStatus.loading:
      case CategoryLoadStatus.empty:
      case CategoryLoadStatus.loaded:
      case CategoryLoadStatus.error:
        return const Center(
          child: Text(
            'لا توجد فئات متاحة',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Color(0xFF8993A3)),
          ),
        );
    }
  }

  // ================================================================
  // ALL PLACES TILE
  // ================================================================

  Widget _buildAllTile() {
    final selected = selectedCategory == null;

    return InkWell(
      onTap: onAllPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE8F8F6)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF18A99A)
                : const Color(0xFFE8EBF0),
          ),
        ),
        child: Row(
          children: [
            _iconContainer(
              Icons.apps_rounded,
            ),

            const SizedBox(width: 14),

            const Expanded(
              child: Text(
                'كل الأماكن',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF283247),
                ),
              ),
            ),

            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF18A99A),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // CATEGORY TILE
  // ================================================================

  Widget _buildCategoryTile(
    BuildContext context,
    Category category,
  ) {
    final selected = selectedCategory == category.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          onCategoryPressed(category);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE8F8F6)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF18A99A)
                  : const Color(0xFFE8EBF0),
            ),
          ),
          child: Row(
            children: [
              _iconContainer(
                iconFromName(category.icon),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  category.nameAr,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF283247),
                  ),
                ),
              ),

              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF18A99A),
                  size: 22,
                )
              else
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: Color(0xFFB0B7C3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // ICON CONTAINER
  // ================================================================

  Widget _iconContainer(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF18A99A),
        size: 23,
      ),
    );
  }
}

// ==================================================================
// LOADING
// ==================================================================

class _CategoryStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _CategoryStateMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF8993A3)),
            const SizedBox(height: 10),
            Text(
              message,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8993A3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPlaces extends StatelessWidget {
  const _LoadingPlaces();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 45,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF18A99A),
        ),
      ),
    );
  }
}
