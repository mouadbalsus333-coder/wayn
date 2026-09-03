import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/category_service.dart';
import '../../services/place_service.dart';
import '../../services/repositories/place_repository.dart';
import '../places/place_details_page.dart';
import '../home/models/place.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../core/theme/wayn_colors.dart';
import '../../features/notifications/notifications_page.dart';
import '../home/widgets/home_filters.dart';
import '../home/widgets/home_search_bar.dart';
import '../home/widgets/place_card.dart';
import '../home/widgets/section_header.dart';
import '../../services/favorite_service.dart';
import '../../features/location/saved_locations_store.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final PlaceService _placeService = PlaceService();
  final CategoryService _categoryService = CategoryService();
  final FavoriteService _favoriteService = FavoriteService();
  final ScrollController _scrollController = ScrollController();

  final Set<String> _favoriteIds = <String>{};

  static const int _pageSize = 20;

  int _selectedFilterIndex = 0;

  List<Place> _places = [];
  List<Category> _categories = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;

  int _currentPage = 1;
  int _totalPages = 0;

  CategoryLoadStatus _categoriesStatus =
      CategoryLoadStatus.loading;

  String? _errorMessage;

  String _searchQuery = '';

  String? _selectedCategory;
  String _selectedCategoryLabel = 'كل الأماكن';

  Position? _currentPosition;

  bool _showingAllPlaces = true;

  ({double latitude, double longitude})?
      _lastLoadedReference;

  // ================================================================
  // PAGINATION
  // ================================================================

  bool get _hasMorePages =>
      _totalPages > 0 && _currentPage < _totalPages;

  // ================================================================
  // INIT
  // ================================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    SavedLocationsStore.instance.addListener(
      _onSavedLocationChanged,
    );

    _initializeExplore();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMorePages) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >=
        position.maxScrollExtent - 600) {
      _loadNextPage();
    }
  }

  void _onSavedLocationChanged() {
    if (!mounted) return;

    final ref = _referencePoint;
    final last = _lastLoadedReference;

    final changed = (ref == null) != (last == null) ||
        (ref != null &&
            last != null &&
            (ref.latitude != last.latitude ||
                ref.longitude != last.longitude));

    if (changed) {
      _loadNearbyPlaces();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    SavedLocationsStore.instance.removeListener(
      _onSavedLocationChanged,
    );

    super.dispose();
  }

  Future<void> _initializeExplore() async {
    await _loadCurrentLocation();

    await Future.wait([
      _loadPlaces(),
      _loadCategories(),
    ]);
  }

  // ================================================================
  // LOCATION
  // ================================================================

  Future<void> _loadCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _hasLocationPermission = false;
          });
        }
        return;
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _hasLocationPermission = false;
          });
        }
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _hasLocationPermission = true;
      });
    } catch (error) {
      debugPrint(
        'Explore location error: $error',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingLocation = false;
        _hasLocationPermission = false;
      });
    }
  }

  // ================================================================
  // LOAD ALL PLACES
  // ================================================================

  Future<void> _loadPlaces({
    bool reset = true,
  }) async {
    if (!mounted) return;

    if (reset) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _errorMessage = null;
        _currentPage = 1;
        _totalPages = 0;
        _places = [];
        _showingAllPlaces = true;
      });
    }

    try {
      final result =
          await _placeService.getPlacesPage(
        page: reset ? 1 : _currentPage,
        limit: _pageSize,
      );

      if (!mounted) return;

      final prepared =
          _preparePlaces(result.items);

      setState(() {
        if (reset) {
          _places = prepared;
        } else {
          _places = [
            ..._places,
            ...prepared,
          ];
        }

        _currentPage = result.page;
        _totalPages = result.pages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (reset) {
          _places = [];
          _isLoading = false;
        }

        _isLoadingMore = false;
        _errorMessage = error.toString();
      });

      debugPrint(
        'Failed to load places: $error',
      );
    }
  }

  // ================================================================
  // LOAD NEXT PAGE
  // ================================================================

  Future<void> _loadNextPage() async {
    if (!mounted ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMorePages) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _currentPage + 1;

    try {
      final result =
          await _loadPageForCurrentState(
        page: nextPage,
      );

      if (!mounted) return;

      final prepared =
          _preparePlaces(result.items);

      var combinedPlaces = [
        ..._places,
        ...prepared,
      ];

      if (_selectedFilterIndex == 0 &&
          !_showingAllPlaces) {
        final ref = _referencePoint;

        if (ref != null) {
          final refPos = _positionFromReference(
            ref,
          );

          combinedPlaces = _sortByDistance(
            combinedPlaces,
            refPos,
          );
        }
      }

      setState(() {
        _places = combinedPlaces;
        _currentPage = result.page;
        _totalPages = result.pages;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });

      debugPrint(
        'Failed to load next Explore page: $error',
      );
    }
  }

  // ================================================================
  // LOAD PAGE FOR CURRENT VIEW
  // ================================================================

  Future<PaginatedPlaces>
      _loadPageForCurrentState({
    required int page,
  }) async {
    if (_showingAllPlaces) {
      return _placeService.getPlacesPage(
        page: page,
        limit: _pageSize,
      );
    }

    if (_searchQuery.isNotEmpty) {
      return _placeService.searchPlacesPage(
        _searchQuery,
        page: page,
        limit: _pageSize,
      );
    }

    if (_selectedCategory != null) {
      return _placeService.getPlacesByCategoryPage(
        _selectedCategory!,
        page: page,
        limit: _pageSize,
      );
    }

    switch (_selectedFilterIndex) {
      case 0:
        final ref = _referencePoint;

        if (ref != null) {
          return _placeService.getNearbyPlacesPage(
            latitude: ref.latitude,
            longitude: ref.longitude,
            radius: 5000,
            page: page,
            limit: _pageSize,
          );
        }

        return _placeService.getPlacesPage(
          page: page,
          limit: _pageSize,
        );

      case 1:
        return _placeService.getOpenPlacesPage(
          page: page,
          limit: _pageSize,
        );

      case 2:
        return _placeService.getHighestRatedPlacesPage(
          page: page,
          limit: _pageSize,
        );

      case 3:
        return _placeService.getMostVisitedPlacesPage(
          page: page,
          limit: _pageSize,
        );

      default:
        return _placeService.getPlacesPage(
          page: page,
          limit: _pageSize,
        );
    }
  }

  // ================================================================
  // REFERENCE POINT
  // ================================================================

  ({double latitude, double longitude})?
      get _referencePoint {
    final saved =
        SavedLocationsStore.instance.referencePoint;

    if (saved != null) {
      return saved;
    }

    final gps = _currentPosition;

    if (gps != null) {
      return (
        latitude: gps.latitude,
        longitude: gps.longitude,
      );
    }

    return null;
  }

  Position _positionFromReference(
    ({double latitude, double longitude}) ref,
  ) {
    return Position(
      latitude: ref.latitude,
      longitude: ref.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  // ================================================================
  // LOAD NEARBY PLACES
  // ================================================================

  Future<void> _loadNearbyPlaces() async {
    final ref = _referencePoint;

    if (ref == null) {
      await _loadCurrentLocation();
    }

    final currentRef = _referencePoint;

    if (currentRef == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فعّل الموقع حتى نقدر نعرض الأماكن القريبة منك.',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }

      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _selectedFilterIndex = 0;
      _selectedCategory = null;
      _selectedCategoryLabel = 'كل الأماكن';
      _searchQuery = '';
      _currentPage = 1;
      _totalPages = 0;
      _places = [];
      _showingAllPlaces = false;
    });

    try {
      final result =
          await _placeService.getNearbyPlacesPage(
        latitude: currentRef.latitude,
        longitude: currentRef.longitude,
        radius: 5000,
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      final refPos =
          _positionFromReference(
        currentRef,
      );

      setState(() {
        _places = _sortByDistance(
          _preparePlaces(result.items),
          refPos,
        );

        _currentPage = result.page;
        _totalPages = result.pages;

        _lastLoadedReference = (
          latitude: currentRef.latitude,
          longitude: currentRef.longitude,
        );

        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = error.toString();
      });

      debugPrint(
        'Nearby places error: $error',
      );
    }
  }

  // ================================================================
  // PREPARE PLACES
  // ================================================================

  List<Place> _preparePlaces(
    List<Place> places,
  ) {
    return places
        .where(
          (place) =>
              place.latitude != null &&
              place.longitude != null &&
              place.latitude! >= -90 &&
              place.latitude! <= 90 &&
              place.longitude! >= -180 &&
              place.longitude! <= 180,
        )
        .toList();
  }

  // ================================================================
  // DISTANCE
  // ================================================================

  double? _distanceToPlace(
    Place place,
  ) {
    final ref = _referencePoint;

    if (ref == null ||
        place.latitude == null ||
        place.longitude == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      ref.latitude,
      ref.longitude,
      place.latitude!,
      place.longitude!,
    );
  }

  List<Place> _sortByDistance(
    List<Place> places,
    Position position,
  ) {
    final sorted =
        List<Place>.from(places);

    sorted.sort((a, b) {
      if (a.latitude == null ||
          a.longitude == null) {
        return 1;
      }

      if (b.latitude == null ||
          b.longitude == null) {
        return -1;
      }

      final distanceA =
          Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        a.latitude!,
        a.longitude!,
      );

      final distanceB =
          Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        b.latitude!,
        b.longitude!,
      );

      return distanceA.compareTo(
        distanceB,
      );
    });

    return sorted;
  }

  String _formatDistance(
    double? meters,
  ) {
    if (meters == null) {
      return '';
    }

    if (meters < 1000) {
      return '${meters.round()} م';
    }

    final kilometers = meters / 1000;

    if (kilometers < 10) {
      return '${kilometers.toStringAsFixed(1)} كم';
    }

    return '${kilometers.round()} كم';
  }

  // ================================================================
  // LOAD CATEGORIES
  // ================================================================

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _categoriesStatus =
            CategoryLoadStatus.loading;
      });
    }

    final result =
        await _categoryService.getCategories();

    if (!mounted) return;

    final uniqueCategories =
        <String, Category>{};

    for (final category
        in result.categories) {
      final key = category.nameAr
          .trim()
          .toLowerCase();

      if (key.isEmpty) {
        continue;
      }

      final existing =
          uniqueCategories[key];

      if (existing == null ||
          ((existing.icon == null ||
                  existing.icon!
                      .trim()
                      .isEmpty) &&
              category.icon != null &&
              category.icon!
                  .trim()
                  .isNotEmpty)) {
        uniqueCategories[key] =
            category;
      }
    }

    final categories =
        uniqueCategories.values.toList()
          ..sort(
            (a, b) =>
                a.sortOrder.compareTo(
              b.sortOrder,
            ),
          );

    setState(() {
      _categories = categories;
      _categoriesStatus =
          result.status;
    });
  }

  // ================================================================
  // SEARCH
  // ================================================================

  Future<void> _searchPlaces(
    String query,
  ) async {
    final search = query.trim();

    if (search.isEmpty) {
      await _selectAllPlaces();
      return;
    }

    if (!mounted) return;

    setState(() {
      _searchQuery = search;
      _selectedCategory = null;
      _selectedCategoryLabel = 'كل الأماكن';
      _selectedFilterIndex = -1;
      _showingAllPlaces = false;
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
      _totalPages = 0;
      _places = [];
    });

    try {
      final result =
          await _placeService.searchPlacesPage(
        search,
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _places =
            _preparePlaces(result.items);
        _currentPage = result.page;
        _totalPages = result.pages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = error.toString();
      });

      debugPrint(
        'Search failed: $error',
      );
    }
  }

  // ================================================================
  // FILTER
  // ================================================================

  Future<void> _onFilterSelected(
    int index,
  ) async {
    if (!mounted) return;

    setState(() {
      _selectedFilterIndex = index;
      _selectedCategory = null;
      _selectedCategoryLabel = 'كل الأماكن';
      _searchQuery = '';
      _showingAllPlaces = false;
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
      _totalPages = 0;
      _places = [];
    });

    try {
      final result =
          await _loadPageForCurrentState(
        page: 1,
      );

      if (!mounted) return;

      var places =
          _preparePlaces(result.items);

      if (index == 0) {
        final ref = _referencePoint;

        if (ref != null) {
          final refPos =
              _positionFromReference(
            ref,
          );

          places =
              _sortByDistance(
            places,
            refPos,
          );
        }
      }

      setState(() {
        _places = places;
        _currentPage = result.page;
        _totalPages = result.pages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = error.toString();
      });

      debugPrint(
        'Filter failed: $error',
      );
    }
  }

  // ================================================================
  // CATEGORY
  // ================================================================

  Future<void> _onCategorySelected(
    Category category,
  ) async {
    if (!mounted) return;

    setState(() {
      _selectedCategory = category.id;
      _selectedCategoryLabel = category.nameAr;
      _selectedFilterIndex = -1;
      _searchQuery = '';
      _showingAllPlaces = false;
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
      _totalPages = 0;
      _places = [];
    });

    try {
      final result =
          await _placeService.getPlacesByCategoryPage(
        category.id,
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _places =
            _preparePlaces(result.items);
        _currentPage = result.page;
        _totalPages = result.pages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = error.toString();
      });

      debugPrint(
        'Failed to load category '
        '${category.nameAr}: $error',
      );
    }
  }

  // ================================================================
  // ALL PLACES
  // ================================================================

  Future<void> _selectAllPlaces() async {
    if (!mounted) return;

    setState(() {
      _selectedCategory = null;
      _selectedCategoryLabel = 'كل الأماكن';
      _selectedFilterIndex = -1;
      _searchQuery = '';
      _showingAllPlaces = true;
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
      _totalPages = 0;
      _places = [];
    });

    try {
      final result =
          await _placeService.getPlacesPage(
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _places =
            _preparePlaces(result.items);
        _currentPage = result.page;
        _totalPages = result.pages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _places = [];
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = error.toString();
      });

      debugPrint(
        'Failed to load all places: $error',
      );
    }
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
            onAllPressed: () async {
              Navigator.of(
                sheetContext,
              ).pop();

              await _selectAllPlaces();
            },
            onCategoryPressed:
                (category) async {
              Navigator.of(
                sheetContext,
              ).pop();

              await _onCategorySelected(
                category,
              );
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
    final colors =
        context.waynColors;

    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            colors.background,
        resizeToAvoidBottomInset:
            false,
        body: SafeArea(
          child: Column(
            children: [
              WaynHeader(
                onMenuPressed:
                    _onMenuPressed,
                onNotificationsPressed:
                    _onNotificationsPressed,
              ),
              HomeSearchBar(
                selectedCategory:
                    _selectedCategoryLabel,
                onCategoryPressed:
                    _onCategoryPressed,
                onSearchChanged:
                    _searchPlaces,
              ),
              Expanded(
                child:
                    RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _loadCurrentLocation(),
                      _loadCategories(),
                    ]);

                    await _reloadCurrentView();
                  },
                  color: colors.brand,
                  child: ListView(
                    controller:
                        _scrollController,
                    physics:
                        const BouncingScrollPhysics(
                      parent:
                          AlwaysScrollableScrollPhysics(),
                    ),
                    padding:
                        EdgeInsets.zero,
                    children: [
                      HomeFilters(
                        selectedIndex:
                            _selectedFilterIndex,
                        onFilterSelected:
                            _onFilterSelected,
                      ),
                      _buildExploreCategoriesSection(),
                      _buildSuggestionsSection(),
                      SectionHeader(
                        title:
                            _buildResultsTitle(),
                        action:
                            'عرض الكل',
                        onActionPressed:
                            _onViewAllPressed,
                      ),
                      if (_isLoading)
                        const _LoadingPlaces()
                      else if (_errorMessage !=
                          null)
                        _buildErrorState()
                      else if (_places.isEmpty)
                        _buildEmptyState()
                      else
                        ...List.generate(
                          _places.length,
                          (index) {
                            final place =
                                _places[index];

                            final distance =
                                _distanceToPlace(
                              place,
                            );

                            return Padding(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .stretch,
                                children: [
                                  PlaceCard(
                                    place:
                                        place,
                                    onFavoritePressed:
                                        () {
                                      _onFavoritePressed(
                                        place,
                                      );
                                    },
                                    onPressed:
                                        () {
                                      _onPlacePressed(
                                        place,
                                      );
                                    },
                                  ),
                                  if (distance !=
                                      null)
                                    Padding(
                                      padding:
                                          const EdgeInsets
                                              .only(
                                        top: 5,
                                        right: 8,
                                      ),
                                      child:
                                          Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .start,
                                        children: [
                                          const Icon(
                                            Icons
                                                .near_me_rounded,
                                            size:
                                                14,
                                            color:
                                                Color(
                                              0xFF18A99A,
                                            ),
                                          ),
                                          const SizedBox(
                                            width:
                                                4,
                                          ),
                                          Text(
                                            _formatDistance(
                                              distance,
                                            ),
                                            textDirection:
                                                TextDirection
                                                    .rtl,
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  11,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                              color:
                                                  colors
                                                      .textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (_isLoadingMore)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            vertical: 20,
                          ),
                          child: Center(
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.2,
                              color:
                                  Color(
                                0xFF18A99A,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(
                        height: 100,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // RELOAD CURRENT VIEW
  // ================================================================

  Future<void> _reloadCurrentView() async {
    if (!mounted) return;

    if (_showingAllPlaces) {
      await _selectAllPlaces();
      return;
    }

    if (_searchQuery.isNotEmpty) {
      await _searchPlaces(
        _searchQuery,
      );
      return;
    }

    if (_selectedCategory != null) {
      final categoryId =
          _selectedCategory!;

      final category = _categories
          .where(
            (item) =>
                item.id == categoryId,
          )
          .firstOrNull;

      if (category != null) {
        await _onCategorySelected(
          category,
        );
      }

      return;
    }

    if (_selectedFilterIndex == 0) {
      await _loadNearbyPlaces();
      return;
    }

    await _onFilterSelected(
      _selectedFilterIndex,
    );
  }

  // ================================================================
  // RESULTS TITLE
  // ================================================================

  String _buildResultsTitle() {
    if (_showingAllPlaces) {
      return 'كل الأماكن';
    }

    if (_searchQuery.isNotEmpty) {
      return 'نتائج البحث';
    }

    if (_selectedCategory != null) {
      return _selectedCategoryLabel;
    }

    switch (_selectedFilterIndex) {
      case 0:
        return 'أماكن قريبة منك';

      case 1:
        return 'مفتوح الآن';

      case 2:
        return 'الأعلى تقييمًا';

      case 3:
        return 'الأكثر زيارة';

      default:
        return 'كل الأماكن';
    }
  }

  // ================================================================
  // EXPLORE CATEGORIES
  // ================================================================

  Widget _buildExploreCategoriesSection() {
    final colors =
        context.waynColors;

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            12,
          ),
          child: Text(
            'استكشف حسب الفئة',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.w800,
              color:
                  colors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 108,
          child:
              ListView.separated(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            itemCount:
                _categories.length,
            separatorBuilder:
                (_, _) {
              return const SizedBox(
                width: 12,
              );
            },
            itemBuilder:
                (context, index) {
              final category =
                  _categories[index];

              final isSelected =
                  _selectedCategory ==
                      category.id;

              return GestureDetector(
                behavior:
                    HitTestBehavior.opaque,
                onTap: () {
                  _onCategorySelected(
                    category,
                  );
                },
                child:
                    AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 180,
                  ),
                  width: 82,
                  decoration:
                      BoxDecoration(
                    color: isSelected
                        ? colors.surfaceAlt
                        : colors.surface,
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                    border:
                        Border.all(
                      color: isSelected
                          ? colors.brand
                          : colors.divider,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            colors.shadow,
                        blurRadius: 10,
                        offset:
                            const Offset(
                          0,
                          3,
                        ),
                      ),
                    ],
                  ),
                  child:
                      Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration:
                            BoxDecoration(
                          color:
                              colors.surfaceAlt,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                        ),
                        child: Icon(
                          _iconFromName(
                            category.icon,
                          ),
                          color:
                              colors.brand,
                          size: 24,
                        ),
                      ),
                      const SizedBox(
                        height: 7,
                      ),
                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 5,
                        ),
                        child: Text(
                          category
                              .nameAr,
                          textDirection:
                              TextDirection
                                  .rtl,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              TextStyle(
                            fontSize:
                                11,
                            fontWeight:
                                FontWeight
                                    .w700,
                            color: colors
                                .textSecondary,
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

  IconData _iconFromName(
    String? iconName,
  ) {
    switch (iconName) {
      case 'restaurant':
        return Icons
            .restaurant_rounded;

      case 'park':
        return Icons.park_rounded;

      case 'beach_access':
        return Icons
            .beach_access_rounded;

      case 'hotel':
        return Icons
            .hotel_rounded;

      case 'shopping_bag':
        return Icons
            .shopping_bag_rounded;

      case 'sports_soccer':
        return Icons
            .sports_soccer_rounded;

      case 'mosque':
        return Icons
            .mosque_rounded;

      case 'local_hospital':
        return Icons
            .local_hospital_rounded;

      case 'school':
        return Icons.school_rounded;

      case 'local_cafe':
        return Icons
            .local_cafe_rounded;

      case 'local_gas_station':
        return Icons
            .local_gas_station_rounded;

      case 'pharmacy':
        return Icons
            .local_pharmacy_rounded;

      case 'museum':
        return Icons
            .museum_rounded;

      case 'store':
        return Icons.store_rounded;

      case 'shopping_cart':
        return Icons
            .shopping_cart_rounded;

      case 'local_parking':
        return Icons
            .local_parking_rounded;

      case 'fitness_center':
        return Icons
            .fitness_center_rounded;

      case 'local_atm':
        return Icons
            .local_atm_rounded;

      case 'bank':
        return Icons
            .account_balance_rounded;

      case 'government':
        return Icons
            .account_balance_rounded;

      default:
        return Icons.place_rounded;
    }
  }

  // ================================================================
  // SUGGESTIONS
  // ================================================================

  Widget _buildSuggestionsSection() {
    final colors =
        context.waynColors;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            28,
            20,
            12,
          ),
          child: Text(
            'اقتراحات لك',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.w800,
              color:
                  colors.textPrimary,
            ),
          ),
        ),
        _buildSuggestionCard(
          title: 'أماكن قريبة منك',
          subtitle:
              _hasLocationPermission
                  ? 'أماكن مميزة حول موقعك الحالي'
                  : 'فعّل موقعك لاكتشاف الأماكن القريبة',
          icon:
              Icons.near_me_rounded,
          iconColor:
              const Color(0xFF18A99A),
          onPressed:
              _loadNearbyPlaces,
        ),
        _buildSuggestionCard(
          title: 'أماكن مناسبة لك',
          subtitle:
              'اقتراحات بناءً على اهتماماتك',
          icon:
              Icons.auto_awesome_rounded,
          iconColor:
              const Color(0xFF7B61D9),
          onPressed: () {
            debugPrint(
              'Personalized places pressed',
            );
          },
        ),
        _buildSuggestionCard(
          title: 'أماكن مفتوحة الآن',
          subtitle:
              'اكتشف الأماكن المتاحة حاليًا',
          icon:
              Icons.access_time_rounded,
          iconColor:
              const Color(0xFF2997FF),
          onPressed:
              _openPlacesSuggestion,
        ),
        if (_isLoadingLocation)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 6,
            ),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      colors.brand,
                ),
              ),
            ),
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
    final colors =
        context.waynColors;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 6,
      ),
      child: GestureDetector(
        onTap: onPressed,
        behavior:
            HitTestBehavior.opaque,
        child: Container(
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 14,
                offset:
                    const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color:
                      iconColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 25,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      textDirection:
                          TextDirection
                              .rtl,
                      style:
                          TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight
                                .w800,
                        color: colors
                            .textPrimary,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      subtitle,
                      textDirection:
                          TextDirection
                              .rtl,
                      style:
                          TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w500,
                        color: colors
                            .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Icon(
                Icons
                    .arrow_back_ios_new_rounded,
                size: 15,
                color:
                    colors.textMuted,
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
    final colors =
        context.waynColors;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        10,
      ),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(22),
        decoration:
            BoxDecoration(
          color: colors.surface,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border: Border.all(
            color: colors.divider,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color:
                  colors.textMuted,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              'تعذر تحميل الأماكن',
              textDirection:
                  TextDirection.rtl,
              style:
                  TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.w800,
                color:
                    colors.textPrimary,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 12,
                color:
                    colors.textSecondary,
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            ElevatedButton(
              onPressed:
                  _reloadCurrentView,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    colors.brand,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
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
    String message =
        'لا توجد أماكن متاحة حاليًا';

    if (_searchQuery.isNotEmpty) {
      message =
          'لم نجد أماكن تطابق بحثك';
    } else if (_selectedCategory !=
        null) {
      message =
          'لا توجد أماكن في هذه الفئة';
    } else if (_selectedFilterIndex ==
        1) {
      message =
          'لا توجد أماكن مفتوحة الآن';
    } else if (_selectedFilterIndex ==
            0 &&
        _hasLocationPermission) {
      message =
          'لا توجد أماكن قريبة منك حاليًا';
    }

    final colors =
        context.waynColors;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        10,
      ),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(22),
        decoration:
            BoxDecoration(
          color: colors.surface,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border: Border.all(
            color: colors.divider,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons
                  .location_off_rounded,
              size: 42,
              color:
                  colors.textMuted,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              message,
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.w800,
                color:
                    colors.textPrimary,
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
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    openNotifications(context);
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

  Future<void> _onFavoritePressed(
    Place place,
  ) async {
    try {
      if (_favoriteIds.contains(
        place.id,
      )) {
        await _favoriteService
            .remove(place.id);

        if (mounted) {
          setState(() {
            _favoriteIds.remove(
              place.id,
            );
          });
        }
      } else {
        await _favoriteService
            .add(place.id);

        if (mounted) {
          setState(() {
            _favoriteIds.add(
              place.id,
            );
          });
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تحديث المفضلة: $error',
            ),
          ),
        );
      }
    }
  }

  // ================================================================
  // PLACE DETAILS
  // ================================================================

  void _onPlacePressed(
    Place place,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlaceDetailsPage(
          place: place,
        ),
      ),
    );
  }
}

// ==================================================================
// CATEGORY BOTTOM SHEET
// ==================================================================

class _CategoryBottomSheet
    extends StatelessWidget {
  final List<Category> categories;
  final CategoryLoadStatus status;
  final String? selectedCategory;

  final VoidCallback onAllPressed;
  final ValueChanged<Category>
      onCategoryPressed;

  final IconData Function(String?)
      iconFromName;

  const _CategoryBottomSheet({
    required this.categories,
    required this.status,
    required this.selectedCategory,
    required this.onAllPressed,
    required this.onCategoryPressed,
    required this.iconFromName,
  });

  bool get isLoading =>
      status ==
      CategoryLoadStatus.loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context)
                    .size
                    .height *
                0.75,
      ),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(
              height: 12,
            ),
            Container(
              width: 42,
              height: 5,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFD9DEE7,
                ),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Align(
                alignment:
                    Alignment.centerRight,
                child: Text(
                  'اختر الفئة',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(0xFF172033),
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            Expanded(
              child: status ==
                      CategoryLoadStatus
                          .error
                  ? const _CategoryStateMessage(
                      icon: Icons
                          .cloud_off_rounded,
                      message:
                          'تعذر تحميل الفئات. تحقق من الاتصال وحاول مرة أخرى.',
                    )
                  : isLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(
                            color: Color(
                              0xFF18A99A,
                            ),
                          ),
                        )
                      : categories.isEmpty
                          ? status ==
                                  CategoryLoadStatus
                                      .permissionDenied
                              ? const _CategoryStateMessage(
                                  icon: Icons
                                      .lock_outline_rounded,
                                  message:
                                      'تعذر الوصول إلى الفئات بسبب الصلاحيات.',
                                )
                              : status ==
                                      CategoryLoadStatus
                                          .failure
                                  ? const _CategoryStateMessage(
                                      icon: Icons
                                          .cloud_off_rounded,
                                      message:
                                          'تعذر تحميل الفئات. حاول مرة أخرى.',
                                    )
                                  : const Center(
                                      child:
                                          Text(
                                        'لا توجد فئات متاحة',
                                        textDirection:
                                            TextDirection.rtl,
                                        style:
                                            TextStyle(
                                          color:
                                              Color(0xFF8993A3),
                                        ),
                                      ),
                                    )
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                20,
                              ),
                              children: [
                                _buildAllTile(),
                                const SizedBox(
                                  height: 8,
                                ),
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

  // ================================================================
  // ALL PLACES TILE
  // ================================================================

  Widget _buildAllTile() {
    final selected =
        selectedCategory == null;

    return InkWell(
      onTap: onAllPressed,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(14),
        decoration:
            BoxDecoration(
          color: selected
              ? const Color(
                  0xFFE8F8F6,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: selected
                ? const Color(
                    0xFF18A99A,
                  )
                : const Color(
                    0xFFE8EBF0,
                  ),
          ),
        ),
        child: Row(
          children: [
            _iconContainer(
              Icons.apps_rounded,
            ),
            const SizedBox(
              width: 14,
            ),
            const Expanded(
              child: Text(
                'كل الأماكن',
                textDirection:
                    TextDirection.rtl,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF283247),
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons
                    .check_circle_rounded,
                color:
                    Color(0xFF18A99A),
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
    final selected =
        selectedCategory ==
            category.id;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: InkWell(
        onTap: () {
          onCategoryPressed(
            category,
          );
        },
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(14),
          decoration:
              BoxDecoration(
            color: selected
                ? const Color(
                    0xFFE8F8F6,
                  )
                : Colors.white,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: selected
                  ? const Color(
                      0xFF18A99A,
                    )
                  : const Color(
                      0xFFE8EBF0,
                    ),
            ),
          ),
          child: Row(
            children: [
              _iconContainer(
                iconFromName(
                  category.icon,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Text(
                  category.nameAr,
                  textDirection:
                      TextDirection.rtl,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF283247),
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons
                      .check_circle_rounded,
                  color:
                      Color(0xFF18A99A),
                  size: 22,
                )
              else
                const Icon(
                  Icons
                      .arrow_back_ios_new_rounded,
                  size: 14,
                  color:
                      Color(0xFFB0B7C3),
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

  Widget _iconContainer(
    IconData icon,
  ) {
    return Container(
      width: 46,
      height: 46,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFE8F8F6),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Icon(
        icon,
        color:
            const Color(0xFF18A99A),
        size: 23,
      ),
    );
  }
}

// ==================================================================
// CATEGORY STATE
// ==================================================================

class _CategoryStateMessage
    extends StatelessWidget {
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
        padding:
            const EdgeInsets.symmetric(
          horizontal: 28,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  const Color(
                0xFF8993A3,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              message,
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Color(0xFF8993A3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// LOADING
// ==================================================================

class _LoadingPlaces
    extends StatelessWidget {
  const _LoadingPlaces();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        vertical: 45,
      ),
      child: Center(
        child:
            CircularProgressIndicator(
          strokeWidth: 2.5,
          color:
              Color(0xFF18A99A),
        ),
      ),
    );
  }
}