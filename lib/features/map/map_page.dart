import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/models/place.dart';
import '../community/models/community_post.dart';
import '../community/repositories/community_repository.dart';
import '../../../services/place_service.dart';
import '../../../services/repositories/repository_factory.dart';
import '../../../services/auth_service.dart';
import '../../../core/config/backend_config.dart';
import '../community/community_page.dart';
import '../community/services/community_service.dart';
import '../community/widgets/comments_sheet.dart';
import '../../../core/widgets/wayn_header.dart';
import '../../../features/location/saved_locations_store.dart';

enum _MapStatusFilter { all, open, closed, near }

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // =================================================================
  // WAYN MAP COLORS
  // =================================================================

  static const Color _waynTeal = Color(0xFF18A99A);
  static const Color _waynTealLight = Color(0xFFE8F8F6);
  static const Color _waynBackground = Color(0xFFF7F9FC);
  static const Color _waynText = Color(0xFF172033);
  static const Color _waynMuted = Color(0xFF697386);

  static const String _mapStyle =
      'https://tiles.openfreemap.org/styles/positron';

  final Completer<MapLibreMapController> _mapController =
      Completer<MapLibreMapController>();

  final TextEditingController _searchController =
      TextEditingController();

  final PlaceService _placeService = PlaceService();

  late final CommunityRepository _communityRepository =
      createCommunityRepository();

  late final CommunityService _communityService =
      CommunityService(_communityRepository);

  final AuthService _authService = AuthService();

  Timer? _searchDebounce;

  Timer? _placeCarouselTimer;

  PageController? _placeCarouselController;

  int _placeCarouselIndex = 0;

  String? _currentUserId;

  Position? _currentPosition;

  List<Place> _places = [];

  Place? _selectedPlace;

  List<CommunityPost> _selectedPlacePosts = [];

  bool _isLoadingLocation = true;
  bool _isLoadingPlaces = true;
  bool _isLoadingPlacePosts = false;
  bool _isSearching = false;
  bool _mapReady = false;

  final bool _showPlaces = true;

  _MapStatusFilter _statusFilter = _MapStatusFilter.all;

  String? _categoryFilter;

  bool _showVisitorOpinions = false;

  String _searchQuery = '';

  double _mapAreaHeight = 0;

  /// إحداثيات موقع محفوظ مختار يصبح مرجع الخريطة، أو null عندما يكون المرجع GPS.
  LatLng? _referenceLatLng;

  /// نقطة المرجع الحالية: موقع محفوظ مختار إن وُجد وإلا موقع GPS الفعلي.
  LatLng? get _referenceOrGps {
    final reference = _referenceLatLng;
    if (reference != null) return reference;

    final position = _currentPosition;
    if (position == null) return null;

    return LatLng(position.latitude, position.longitude);
  }

  static const LatLng _defaultCenter = LatLng(
    32.8872,
    13.1913,
  );

  static const double _defaultZoom = 13.5;

  @override
  void initState() {
    super.initState();

    _initializeMap();
    _loadCurrentUser();

    SavedLocationsStore.instance.ensureLoaded();
    SavedLocationsStore.instance.addListener(_onSavedLocationsChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _placeCarouselTimer?.cancel();
    _placeCarouselController?.dispose();
    _searchController.dispose();
    SavedLocationsStore.instance.removeListener(_onSavedLocationsChanged);
    super.dispose();
  }

  void _onMenuPressed() {
    debugPrint('Map menu pressed');
  }

  void _onNotificationsPressed() {
    debugPrint('Map notifications pressed');
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentUserId = user?.id;
    });
  }

  // ===============================================================
  // INITIALIZATION
  // ===============================================================

  Future<void> _initializeMap() async {
    // نضمن تحميل المواقع المحفوظة أولًا حتى يستخدم المرجع الصحيح
    // (موقع محفوظ مختار سابقًا) عند تحميل الأماكن.
    await SavedLocationsStore.instance.ensureLoaded();
    await _loadCurrentLocation();
    await _loadPlaces();
  }

  // ===============================================================
  // MAP CREATED
  // ===============================================================

  Future<void> _onMapCreated(
    MapLibreMapController controller,
  ) async {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }

    controller.onSymbolTapped.add(_onSymbolTapped);

    if (!mounted) {
      return;
    }

    setState(() {
      _mapReady = true;
    });

    await _addPlaceMarkers();

    if (_currentPosition != null) {
      await _addCurrentLocationMarker();
    }
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) {
      return;
    }

    if (!_mapController.isCompleted) {
      return;
    }

    try {
      final controller = await _mapController.future;

      await _registerMarkerImages(controller);

      await _addPlaceMarkers();

      if (_currentPosition != null) {
        await _addCurrentLocationMarker();
      }
    } catch (e) {
      debugPrint('WAYN Map style error: $e');
    }
  }

  // ===============================================================
  // MARKER IMAGES
  // ===============================================================

  Future<void> _registerMarkerImages(
    MapLibreMapController controller,
  ) async {
    try {
      final placePin = await _createPinImage(
        icon: Icons.place_rounded,
        backgroundColor: _waynTeal,
        size: 128,
      );

      await controller.addImage(
        'wayn-place-pin',
        placePin,
      );

      final restaurantPin = await _createPinImage(
        icon: Icons.restaurant_rounded,
        backgroundColor: _waynTeal,
        size: 128,
      );

      await controller.addImage(
        'wayn-restaurant-pin',
        restaurantPin,
      );

      final parkPin = await _createPinImage(
        icon: Icons.park_rounded,
        backgroundColor: _waynTeal,
        size: 128,
      );

      await controller.addImage(
        'wayn-park-pin',
        parkPin,
      );

      final currentLocation = await _createCurrentLocationImage();

      await controller.addImage(
        'wayn-current-location',
        currentLocation,
      );
    } catch (e) {
      debugPrint('WAYN marker image error: $e');
    }
  }

  Future<Uint8List> _createPinImage({
    required IconData icon,
    required Color backgroundColor,
    required int size,
  }) async {
    final recorder = ui.PictureRecorder();

    final canvas = Canvas(recorder);

    final paint = Paint()
      ..isAntiAlias = true
      ..color = backgroundColor;

    final center = size / 2;

    final circleRadius = size * 0.32;

    canvas.drawCircle(
      Offset(center, center * 0.72),
      circleRadius,
      paint,
    );

    final path = ui.Path()
      ..moveTo(
        center - size * 0.17,
        center * 0.88,
      )
      ..lineTo(
        center,
        size * 0.98,
      )
      ..lineTo(
        center + size * 0.17,
        center * 0.88,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );

    final whitePaint = Paint()
      ..isAntiAlias = true
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.035;

    canvas.drawCircle(
      Offset(center, center * 0.72),
      circleRadius + size * 0.035,
      whitePaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(
          icon.codePoint,
        ),
        style: TextStyle(
          fontSize: size * 0.30,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        center - textPainter.width / 2,
        center * 0.72 - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();

    final image = await picture.toImage(
      size,
      size,
    );

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _createCurrentLocationImage() async {
    final recorder = ui.PictureRecorder();

    final canvas = Canvas(recorder);

    final size = 128.0;
    final center = size / 2;

    final glowPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(
        0xFF4285F4,
      ).withValues(alpha: 0.20);

    canvas.drawCircle(
      Offset(center, center),
      45,
      glowPaint,
    );

    final whitePaint = Paint()
      ..isAntiAlias = true
      ..color = Colors.white;

    canvas.drawCircle(
      Offset(center, center),
      25,
      whitePaint,
    );

    final bluePaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(
        0xFF4285F4,
      );

    canvas.drawCircle(
      Offset(center, center),
      17,
      bluePaint,
    );

    final picture = recorder.endRecording();

    final image = await picture.toImage(
      size.toInt(),
      size.toInt(),
    );

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  // ===============================================================
  // LOCATION
  // ===============================================================

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _setLocationLoading(false);
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
        _setLocationLoading(false);
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      if (_mapReady) {
        await _addCurrentLocationMarker();

        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (!mounted) {
              return;
            }

            _moveToCurrentLocation();
          },
        );
      }
    } catch (e) {
      debugPrint(
        'Map location error: $e',
      );

      _setLocationLoading(false);
    }
  }

  void _setLocationLoading(bool value) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingLocation = value;
    });
  }

  Future<void> _moveToCurrentLocation() async {
    final point = _referenceOrGps;

    if (point == null ||
        !_mapController.isCompleted) {
      return;
    }

    try {
      final controller =
          await _mapController.future;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: point,
            zoom: 15.0,
          ),
        ),
        duration:
            const Duration(milliseconds: 650),
      );
    } catch (e) {
      debugPrint(
        'Map move error: $e',
      );
    }
  }

  /// يُستدعى عند تغيّر الموقع الحالي من ورقة المواقع (موقع محفوظ أو GPS).
  /// يحوّل الخريطة إلى المرجع الجديد ويحمّل الأماكن القريبة منه.
  void _onSavedLocationsChanged() {
    final store = SavedLocationsStore.instance;
    final point = store.referencePoint;

    final newReference = point == null
        ? null
        : LatLng(point.latitude, point.longitude);

    final same = newReference?.latitude == _referenceLatLng?.latitude &&
        newReference?.longitude == _referenceLatLng?.longitude;

    _referenceLatLng = newReference;
    if (same || !mounted || !_mapReady) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moveToCurrentLocation();
      _loadPlaces();
    });
  }

  // ===============================================================
  // PLACES
  // ===============================================================

  Future<void> _loadPlaces() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingPlaces = true;
    });

    try {
      final point = _referenceOrGps;

      if (point == null) {
        final places =
            await _placeService.getPlaces();

        if (!mounted) {
          return;
        }

        setState(() {
          _places = _validPlaces(places);
          _isLoadingPlaces = false;
        });

        await _addPlaceMarkers();

        return;
      }

      final places =
          await _placeService.getNearbyPlaces(
        latitude: point.latitude,
        longitude: point.longitude,
        radius: 5000,
        limit: 50,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _places = _validPlaces(places);
        _isLoadingPlaces = false;
      });

      await _addPlaceMarkers();
    } catch (e) {
      debugPrint(
        'Map places error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPlaces = false;
      });
    }
  }

  List<Place> _validPlaces(
    List<Place> places,
  ) {
    return places.where((place) {
      final latitude = place.latitude;
      final longitude = place.longitude;

      return latitude != null &&
          longitude != null &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;
    }).toList();
  }

  // ===============================================================
  // PLACE MARKERS
  // ===============================================================

  Future<void> _addPlaceMarkers() async {
    if (!_mapReady ||
        !_mapController.isCompleted) {
      return;
    }

    try {
      final controller =
          await _mapController.future;

      await controller.clearSymbols();

      final visiblePlaces =
          _visiblePlaces;

      if (visiblePlaces.isEmpty) {
        if (_referenceOrGps != null) {
          await _addCurrentLocationMarker();
        }

        return;
      }

      final symbols =
          <SymbolOptions>[];

      final data =
          <Map<String, dynamic>>[];

      for (final place in visiblePlaces) {
        final latitude = place.latitude;
        final longitude = place.longitude;

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        symbols.add(
          SymbolOptions(
            geometry: LatLng(
              latitude,
              longitude,
            ),
            iconImage:
                _markerImageName(place),
            iconSize: 0.66,
            iconAnchor: 'bottom',
          ),
        );

        data.add({
          'placeId': place.id,
        });
      }

      if (symbols.isNotEmpty) {
        await controller.addSymbols(
          symbols,
          data,
        );
      }

      if (_referenceOrGps != null) {
        await _addCurrentLocationMarker();
      }
    } catch (e) {
      debugPrint(
        'WAYN place marker error: $e',
      );
    }
  }

  String _markerImageName(
    Place place,
  ) {
    if (_isRestaurant(place)) {
      return 'wayn-restaurant-pin';
    }

    if (_isPark(place)) {
      return 'wayn-park-pin';
    }

    return 'wayn-place-pin';
  }

  Future<void> _onSymbolTapped(
    Symbol symbol,
  ) async {
    final data = symbol.data;

    if (data == null) {
      return;
    }

    final placeId =
        data['placeId']?.toString();

    if (placeId == null ||
        placeId.isEmpty) {
      return;
    }

    Place? place;

    for (final item in _places) {
      if (item.id == placeId) {
        place = item;
        break;
      }
    }

    if (place == null) {
      place =
          await _placeService.getPlaceById(
        placeId,
      );
    }

    if (place == null ||
        !mounted) {
      return;
    }

    setState(() {
      _selectedPlace = place;
      _selectedPlacePosts = [];
      _isLoadingPlacePosts = true;
      _showVisitorOpinions = false;
    });

    _resetPlaceCarousel();

    await _moveToPlace(place);

    await _loadPlacePosts(place.id);
  }

  Future<void> _loadPlacePosts(
    String placeId,
  ) async {
    try {
      final posts =
          await _communityRepository.getPosts(
        placeId: placeId,
        page: 1,
        limit: 100,
      );

      if (!mounted ||
          _selectedPlace?.id != placeId) {
        return;
      }

      setState(() {
        _selectedPlacePosts = posts
            .where(
              (post) => post.isVisible,
            )
            .toList();
        _isLoadingPlacePosts = false;
      });

      _startPlaceCarousel();
    } catch (e) {
      debugPrint(
        'WAYN place community posts error: $e',
      );

      if (!mounted ||
          _selectedPlace?.id != placeId) {
        return;
      }

      setState(() {
        _selectedPlacePosts = [];
        _isLoadingPlacePosts = false;
      });
    }
  }

  // ===============================================================
  // PLACE CAROUSEL LIFECYCLE
  // ===============================================================

  List<String> get _selectedPlaceCarouselImages {
    final images = <String>[];

    for (final post in _selectedPlacePosts) {
      final url = BackendConfig.resolveMediaUrl(
        post.imageUrl,
      )?.trim();

      if (url != null &&
          url.isNotEmpty &&
          !images.contains(url)) {
        images.add(url);
      }
    }

    return images;
  }

  void _resetPlaceCarousel() {
    _placeCarouselTimer?.cancel();
    _placeCarouselTimer = null;

    _placeCarouselController?.dispose();
    _placeCarouselController = null;

    _placeCarouselIndex = 0;
  }

  void _startPlaceCarousel() {
    _placeCarouselTimer?.cancel();
    _placeCarouselTimer = null;

    final images =
        _selectedPlaceCarouselImages;

    if (images.length < 2 || !mounted) {
      return;
    }

    _placeCarouselController?.dispose();
    _placeCarouselController =
        PageController();

    _placeCarouselIndex = 0;

    setState(() {});

    _placeCarouselTimer =
        Timer.periodic(
      const Duration(seconds: 5),
      (_) => _advancePlaceCarousel(),
    );
  }

  void _advancePlaceCarousel() {
    if (!mounted || _selectedPlace == null) {
      _placeCarouselTimer?.cancel();
      _placeCarouselTimer = null;
      return;
    }

    final controller =
        _placeCarouselController;

    if (controller == null ||
        !controller.hasClients) {
      return;
    }

    final images =
        _selectedPlaceCarouselImages;

    if (images.length < 2) {
      _placeCarouselTimer?.cancel();
      _placeCarouselTimer = null;
      return;
    }

    final next =
        ((controller.page ?? 0).round() + 1) %
            images.length;

    controller.animateToPage(
      next,
      duration: const Duration(
        milliseconds: 450,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _moveToPlace(
    Place place,
  ) async {
    final latitude = place.latitude;
    final longitude = place.longitude;

    if (latitude == null ||
        longitude == null ||
        !_mapController.isCompleted) {
      return;
    }

    try {
      final controller =
          await _mapController.future;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              latitude,
              longitude,
            ),
            zoom: 15.5,
          ),
        ),
        duration:
            const Duration(milliseconds: 500),
      );
    } catch (e) {
      debugPrint(
        'WAYN place camera error: $e',
      );
    }
  }

  // ===============================================================
  // CURRENT LOCATION MARKER
  // ===============================================================

  Future<void> _addCurrentLocationMarker() async {
    if (!_mapReady ||
        !_mapController.isCompleted) {
      return;
    }

    final point = _referenceOrGps;

    if (point == null) {
      return;
    }

    try {
      final controller =
          await _mapController.future;

      final existingSymbols =
          controller.symbols.toList();

      final locationSymbols =
          existingSymbols.where(
        (symbol) =>
            symbol.data?['waynType'] ==
            'currentLocation',
      );

      await controller.removeSymbols(
        locationSymbols,
      );

      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(
            point.latitude,
            point.longitude,
          ),
          iconImage:
              'wayn-current-location',
          iconSize: 0.70,
          iconAnchor: 'center',
        ),
        {
          'waynType':
              'currentLocation',
        },
      );
    } catch (e) {
      debugPrint(
        'WAYN current location marker error: $e',
      );
    }
  }

  // ===============================================================
  // SEARCH
  // ===============================================================

  void _onSearchChanged(
    String value,
  ) {
    _searchDebounce?.cancel();

    final query =
        value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _isSearching = false;
        _selectedPlace = null;
        _selectedPlacePosts = [];
      });

      _loadPlaces();
      return;
    }

    _searchDebounce = Timer(
      const Duration(
        milliseconds: 450,
      ),
      () {
        _searchPlaces(query);
      },
    );
  }

  Future<void> _searchPlaces(
    String query,
  ) async {
    if (!mounted) {
      return;
    }

    final trimmedQuery =
        query.trim();

    if (trimmedQuery.isEmpty) {
      return;
    }

    setState(() {
      _searchQuery = trimmedQuery;
      _isSearching = true;
      _isLoadingPlaces = true;
      _selectedPlace = null;
      _selectedPlacePosts = [];
    });

    try {
      final places =
          await _placeService
              .searchPlaces(
        trimmedQuery,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _places =
            _validPlaces(places);
        _isSearching = false;
        _isLoadingPlaces = false;
      });

      await _addPlaceMarkers();

      _fitPlacesOnMap(
        _places,
      );
    } catch (e) {
      debugPrint(
        'Map search error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _isLoadingPlaces = false;
      });
    }
  }

  Future<void> _fitPlacesOnMap(
    List<Place> places,
  ) async {
    if (places.isEmpty ||
        !_mapController.isCompleted) {
      return;
    }

    final coordinates =
        places
            .where(
              (place) =>
                  place.latitude != null &&
                  place.longitude != null,
            )
            .map(
              (place) => LatLng(
                place.latitude!,
                place.longitude!,
              ),
            )
            .toList();

    if (coordinates.isEmpty) {
      return;
    }

    try {
      final controller =
          await _mapController.future;

      if (coordinates.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: coordinates.first,
              zoom: 15.0,
            ),
          ),
          duration:
              const Duration(milliseconds: 550),
        );

        return;
      }

      double minLatitude =
          coordinates.first.latitude;

      double maxLatitude =
          coordinates.first.latitude;

      double minLongitude =
          coordinates.first.longitude;

      double maxLongitude =
          coordinates.first.longitude;

      for (final point in coordinates) {
        if (point.latitude <
            minLatitude) {
          minLatitude =
              point.latitude;
        }

        if (point.latitude >
            maxLatitude) {
          maxLatitude =
              point.latitude;
        }

        if (point.longitude <
            minLongitude) {
          minLongitude =
              point.longitude;
        }

        if (point.longitude >
            maxLongitude) {
          maxLongitude =
              point.longitude;
        }
      }

      final bounds =
          LatLngBounds(
        southwest: LatLng(
          minLatitude,
          minLongitude,
        ),
        northeast: LatLng(
          maxLatitude,
          maxLongitude,
        ),
      );

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 70,
          top: 150,
          right: 70,
          bottom: 260,
        ),
        duration:
            const Duration(milliseconds: 650),
      );
    } catch (e) {
      debugPrint(
        'WAYN map fit error: $e',
      );
    }
  }

  // ===============================================================
  // FILTERING
  // ===============================================================

  List<Place> get _visiblePlaces {
    final result = _places.where((place) {
      if (!_showPlaces) {
        return false;
      }

      if (_statusFilter == _MapStatusFilter.open &&
          !place.isOpen) {
        return false;
      }

      if (_statusFilter == _MapStatusFilter.closed &&
          place.isOpen) {
        return false;
      }

      if (_statusFilter == _MapStatusFilter.near) {
        if (place.latitude == null ||
            place.longitude == null) {
          return false;
        }
      }

      if (_categoryFilter != null &&
          place.category != _categoryFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final searchText =
            '${place.name} '
            '${place.category} '
            '${place.city} '
            '${place.description ?? ''}'
                .toLowerCase();

        if (!searchText.contains(
          _searchQuery.toLowerCase(),
        )) {
          return false;
        }
      }

      return true;
    }).toList();

        if (_statusFilter == _MapStatusFilter.near &&
        _referenceOrGps != null) {
      result.sort(
        (a, b) =>
            _distanceToPlace(a).compareTo(
          _distanceToPlace(b),
        ),
      );
    }

    return result;
  }

  List<String> get _categoryOptions {
    final categories = <String>{};

    for (final place in _places) {
      final category = place.category.trim();

      if (category.isNotEmpty) {
        categories.add(category);
      }
    }

    final list = categories.toList()..sort();

    return list;
  }

    double _distanceToPlace(Place place) {
    final ref = _referenceOrGps;

    final latitude = place.latitude;
    final longitude = place.longitude;

        if (ref == null ||
        latitude == null ||
        longitude == null) {
      return double.infinity;
    }

    const earthRadius = 6371.0;

    final dLat =
        _toRadians(latitude - ref.latitude);

    final dLon =
        _toRadians(longitude - ref.longitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_toRadians(ref.latitude)) *
                math.cos(_toRadians(latitude)) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c =
        2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  bool _isRestaurant(
    Place place,
  ) {
    final value =
        '${place.category} ${place.name}'
            .toLowerCase();

    return value.contains(
          'restaurant',
        ) ||
        value.contains('مطعم') ||
        value.contains('مقهى') ||
        value.contains('cafe') ||
        value.contains('coffee');
  }

  bool _isPark(
    Place place,
  ) {
    final value =
        '${place.category} ${place.name}'
            .toLowerCase();

    return value.contains(
          'park',
        ) ||
        value.contains('حديقة') ||
        value.contains('منتزه') ||
        value.contains('منتزهات');
  }

  // ===============================================================
  // GOOGLE MAPS DIRECTIONS
  // ===============================================================

  Future<void> _openGoogleMapsDirections(
    Place place,
  ) async {
    final latitude = place.latitude;
    final longitude = place.longitude;

    if (latitude == null ||
        longitude == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude'
      '&travelmode=driving',
    );

    try {
      final launched =
          await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched &&
          mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر فتح خرائط Google',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'Google Maps launch error: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر فتح خرائط Google',
          ),
        ),
      );
    }
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            _waynBackground,
        // نبقي جسم الخريطة ثابت الحجم عند ظهور/إخفاء الكيبورد حتى لا تهتز.
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: WaynHeader(
                onMenuPressed: _onMenuPressed,
                onNotificationsPressed: _onNotificationsPressed,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context_, constraints) {
                  _mapAreaHeight = constraints.maxHeight;
                  return Stack(
                    children: [
                      _buildMap(),

            if (_isLoadingPlaces)
              Positioned(
                top:
                    86,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(
                            alpha: 0.10,
                          ),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    padding:
                        const EdgeInsets.all(
                      10,
                    ),
                    child:
                        const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _waynTeal,
                    ),
                  ),
                ),
              ),

            if (_selectedPlace == null)
              Positioned(
                left: 18,
                bottom: 84,
                child:
                    _buildLocationButton(),
              ),

                        if (_selectedPlace != null)
              AnimatedPositioned(
                left: 0,
                right: 0,
                bottom: 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: _buildPlacePreview(
                  _selectedPlace!,
                  _placeCardHeight,
                ),
              ),

            if (_selectedPlace == null)
              _buildSearchBar(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // MAP
  // ===============================================================

  Widget _buildMap() {
        final initialCenter =
        _referenceOrGps ?? _defaultCenter;

    return Positioned.fill(
      child: MapLibreMap(
        initialCameraPosition:
            CameraPosition(
          target: initialCenter,
          zoom: _defaultZoom,
        ),
        styleString: _mapStyle,
        minMaxZoomPreference:
            const MinMaxZoomPreference(
          3,
          19,
        ),
        compassEnabled: false,
        rotateGesturesEnabled:
            false,
        tiltGesturesEnabled:
            false,
        onMapCreated:
            _onMapCreated,
        onStyleLoadedCallback:
            _onStyleLoaded,
        onMapClick:
            (_, __) {
          if (!mounted) {
            return;
          }

          if (_selectedPlace !=
              null) {
            setState(() {
              _selectedPlace =
                  null;
              _selectedPlacePosts = [];
              _isLoadingPlacePosts = false;
            });

            _resetPlaceCarousel();
          }
        },
      ),
    );
  }

  // ===============================================================
  // SEARCH BAR
  // ===============================================================

  Widget _buildSearchBar() {
    return Positioned(
      left: 12,
      right: 12,
      top: 14,
      child: SafeArea(
        top: false,
        child: Container(
          height: 58,
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color:
                  const Color(
                0xFFE7EBF0,
              ),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.12,
                ),
                blurRadius: 24,
                offset:
                    const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 15,
              ),
              const Icon(
                Icons.search_rounded,
                size: 24,
                color: _waynTeal,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: TextField(
                  controller:
                      _searchController,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  textInputAction:
                      TextInputAction.search,
                  onChanged:
                      _onSearchChanged,
                  onSubmitted:
                      (value) {
                    _searchDebounce
                        ?.cancel();

                    _searchPlaces(
                      value,
                    );
                  },
                  decoration:
                      const InputDecoration(
                    hintText:
                        'شن تبي تلقى؟',
                    hintStyle:
                        TextStyle(
                      color:
                          Color(
                        0xFF9AA3B1,
                      ),
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w500,
                    ),
                    border:
                        InputBorder.none,
                    isCollapsed:
                        true,
                  ),
                ),
              ),
              if (_isSearching)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _waynTeal,
                  ),
                )
              else if (_searchController
                  .text
                  .isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController
                        .clear();

                    _searchDebounce
                        ?.cancel();

                    setState(() {
                      _searchQuery =
                          '';

                      _selectedPlace =
                          null;

                      _selectedPlacePosts =
                          [];
                    });

                    _loadPlaces();
                  },
                  child:
                      const Padding(
                    padding:
                        EdgeInsets
                            .symmetric(
                      horizontal: 4,
                    ),
                    child: Icon(
                      Icons
                          .close_rounded,
                      color:
                          _waynMuted,
                      size: 21,
                    ),
                  ),
                ),
              const SizedBox(
                width: 8,
              ),
              GestureDetector(
                onTap: _openFilterSheet,
                child: Container(
                  width: 43,
                  height: 43,
                  margin:
                      const EdgeInsets.only(
                    left: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        _waynTealLight,
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .tune_rounded,
                    color:
                        _waynTeal,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(
                width: 7,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // FILTER SHEET
  // ===============================================================

  List<({String label, _MapStatusFilter value})>
      get _statusOptions => const [
        (label: 'الكل', value: _MapStatusFilter.all),
        (label: 'مفتوح', value: _MapStatusFilter.open),
        (label: 'مغلق', value: _MapStatusFilter.closed),
        (label: 'قريب مني', value: _MapStatusFilter.near),
      ];

  Future<void> _openFilterSheet() async {
    final result =
        await showModalBottomSheet<(_MapStatusFilter, String?)>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _buildFilterSheet(),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _statusFilter = result.$1;
      _categoryFilter = result.$2;
    });

    await _addPlaceMarkers();
  }

  Widget _buildFilterSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        var status = _statusFilter;
        String? category = _categoryFilter;

        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.72,
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
                          color: const Color(0xFFE5E9EF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        'فلترة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _waynText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'الحالة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _waynText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      children: [
                        for (final item in _statusOptions)
                          _buildFilterOption(
                            label: item.label,
                            selected: status == item.value,
                            onTap: () {
                              setSheetState(() {
                                status = item.value;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'التصنيف',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _waynText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      children: [
                        _buildFilterOption(
                          label: 'الكل',
                          selected: category == null,
                          onTap: () {
                            setSheetState(() {
                              category = null;
                            });
                          },
                        ),
                        for (final item in _categoryOptions)
                          _buildFilterOption(
                            label: item,
                            selected: category == item,
                            onTap: () {
                              setSheetState(() {
                                category = item;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterActionButton(
                            label: 'إعادة تعيين',
                            backgroundColor: const Color(
                              0xFFF2F4F7,
                            ),
                            foregroundColor: _waynText,
                            onTap: () {
                              Navigator.of(context).pop(
                                (_MapStatusFilter.all, null),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFilterActionButton(
                            label: 'تطبيق الفلتر',
                            backgroundColor: _waynTeal,
                            foregroundColor: Colors.white,
                            onTap: () {
                              Navigator.of(context).pop(
                                (status, category),
                              );
                            },
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
      },
    );
  }


Widget _buildFilterOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
          color: selected ? _waynTeal : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _waynTeal
                : const Color(0xFFE5E9EF),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : const Color(0xFF596273),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterActionButton({
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
  // ===============================================================
  // LOCATION BUTTON
  // ===============================================================

  Widget _buildLocationButton() {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(
        17,
      ),
      elevation: 5,
      shadowColor:
          Colors.black.withValues(
        alpha: 0.15,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        onTap: () async {
          if (_currentPosition ==
              null) {
            await _loadCurrentLocation();

            if (!mounted) {
              return;
            }

            if (_currentPosition !=
                null) {
              await _loadPlaces();
            }
          } else {
            await _moveToCurrentLocation();
          }
        },
        child: SizedBox(
          width: 52,
          height: 52,
          child: _isLoadingLocation
              ? const Padding(
                  padding:
                      EdgeInsets.all(
                    15,
                  ),
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color:
                        _waynTeal,
                  ),
                )
              : const Icon(
                  Icons
                      .my_location_rounded,
                  color:
                      _waynTeal,
                  size: 23,
                ),
        ),
      ),
    );
  }

  // ===============================================================
  // PLACE PREVIEW
  // ===============================================================

  double get _placeCardHeight {
    final available = _mapAreaHeight;

    if (available <= 0) {
      return 460;
    }

    // المساحة الفعلية المتاحة للبطاقة داخل منطقة الخريطة (أسفل الهيدر).
    final maxCard =
        available <= 132 ? available : (available - 12);
    final lower = math.min(120.0, maxCard);

    if (_showVisitorOpinions) {
      // عند فتح "آراء الزوار" تتوقف البطاقة عند أسفل الهيدر تمامًا
      // دون أن تغطّيه أو تمتد لأعلى الشاشة.
      return maxCard;
    }

    return (available * 0.62).clamp(lower, maxCard);
  }

    Widget _buildPlacePreview(
    Place place,
    double height,
  ) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              22,
            ),
            border: Border.all(
              color: const Color(0xFFE7EBF0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              _buildPlaceGallery(),
              _buildPlaceHeader(place),
              _buildPlaceTabs(),

                        Flexible(
              child:
                  _showVisitorOpinions
                      ? _buildVisitorOpinions()
                      : _buildGeneralInformation(
                          place,
                        ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }


  Widget _buildPlaceHeader(
    Place place,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        10,
      ),
      child: Row(
        children: [
          _buildPlaceImage(place),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        _waynText,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  '${place.category} • ${place.city}',
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        Color(
                      0xFF8993A3,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color:
                          Color(
                        0xFFF5B942,
                      ),
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      place.rating
                          .toStringAsFixed(
                        1,
                      ),
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w700,
                        color:
                            Color(
                          0xFF596273,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Text(
                      '${place.reviewsCount} تقييم',
                      style:
                          const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w600,
                        color:
                            _waynMuted,
                      ),
                    ),

                    const SizedBox(
                      width: 9,
                    ),

                    Icon(
                      Icons.circle,
                      size: 7,
                      color:
                          place.isOpen
                              ? const Color(
                                  0xFF22B573,
                                )
                              : const Color(
                                  0xFFD95353,
                                ),
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      place.isOpen
                          ? 'مفتوح الآن'
                          : 'مغلق',
                      style:
                          TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w700,
                        color:
                            place.isOpen
                                ? const Color(
                                    0xFF22B573,
                                  )
                                : const Color(
                                    0xFFD95353,
                                  ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: () {
              if (!mounted) {
                return;
              }

              setState(() {
                _selectedPlace =
                    null;
                _selectedPlacePosts =
                    [];
                _isLoadingPlacePosts =
                    false;
              });

              _resetPlaceCarousel();
            },
            child: Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF2F4F7,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child:
                  const Icon(
                Icons.close_rounded,
                size: 19,
                color:
                    _waynMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTabs() {
    return Container(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      height: 43,
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF3F5F8,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPlaceTab(
              title: 'آراء الزوار',
              icon:
                  Icons.forum_outlined,
              selected:
                  _showVisitorOpinions,
              onTap: () {
                setState(() {
                  _showVisitorOpinions =
                      true;
                });
              },
            ),
          ),
          Expanded(
            child: _buildPlaceTab(
              title: 'معلومات عامة',
              icon:
                  Icons.info_outline_rounded,
              selected:
                  !_showVisitorOpinions,
              onTap: () {
                setState(() {
                  _showVisitorOpinions =
                      false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTab({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        margin:
            const EdgeInsets.all(
          3,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          boxShadow:
              selected
                  ? [
                      BoxShadow(
                        color: Colors
                            .black
                            .withValues(
                          alpha: 0.06,
                        ),
                        blurRadius: 7,
                        offset:
                            const Offset(
                          0,
                          2,
                        ),
                      ),
                    ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? _waynTeal
                  : _waynMuted,
            ),
            const SizedBox(
              width: 6,
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
                color: selected
                    ? _waynText
                    : _waynMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // VISITOR OPINIONS
  // ===============================================================

  Widget _buildVisitorOpinions() {
    if (_isLoadingPlacePosts) {
      return const Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(
            vertical: 30,
          ),
          child:
              CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _waynTeal,
          ),
        ),
      );
    }

    if (_selectedPlacePosts.isEmpty) {
      return SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(
          18,
          20,
          18,
          14,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration:
                  BoxDecoration(
                color:
                    _waynTealLight,
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .forum_outlined,
                color:
                    _waynTeal,
                size: 27,
              ),
            ),

            const SizedBox(
              height: 11,
            ),

            const Text(
              'لا توجد آراء من الزوار بعد',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
                color:
                    _waynText,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            const Text(
              'كن أول من يشارك تجربته مع هذا المكان.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 11,
                height: 1.4,
                color:
                    _waynMuted,
              ),
            ),

            const SizedBox(
              height: 13,
            ),

            _buildDirectionsButton(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        12,
        4,
        12,
        12,
      ),
      child: Column(
        children: [
          for (var index = 0;
              index <
                  _selectedPlacePosts
                      .length;
              index++)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child:
                  CommunityPostCardWidget(
                post: _selectedPlacePosts[
                    index],
                currentUserId:
                    _currentUserId,
                onLike: () =>
                    _togglePostLike(
                  index,
                ),
                onSave: () =>
                    _togglePostSave(
                  index,
                ),
                onComments: () =>
                    _showPostComments(
                  index,
                ),
                onDelete:
                    _currentUserId !=
                                null &&
                            _selectedPlacePosts[index]
                                    .userId ==
                                _currentUserId
                        ? () =>
                            _deleteVisitorPost(
                              index,
                            )
                        : null,
              ),
            ),
        ],
      ),
    );
  }

  // ===============================================================
  // VISITOR POST ACTIONS
  // ===============================================================

  bool _isValidPostIndex(int index) {
    return index >= 0 &&
        index < _selectedPlacePosts.length;
  }

  Future<void> _togglePostLike(
    int index,
  ) async {
    if (!_isValidPostIndex(index)) {
      return;
    }

    final previous =
        _selectedPlacePosts[index];

    setState(() {
      _selectedPlacePosts[index] =
          previous.copyWith(
        isLiked: !previous.isLiked,
        likesCount: previous.isLiked
            ? (previous.likesCount > 0
                ? previous.likesCount - 1
                : 0)
            : previous.likesCount + 1,
      );
    });

    try {
      if (previous.isLiked) {
        await _communityService.unlikePost(
          previous.id,
        );
      } else {
        await _communityService.likePost(
          previous.id,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_isValidPostIndex(index) &&
            _selectedPlacePosts[index]
                    .id ==
                previous.id) {
          _selectedPlacePosts[index] =
              previous;
        }
      });

      _showMapMessage(
        'تعذر تحديث الإعجاب',
      );
    }
  }

  Future<void> _togglePostSave(
    int index,
  ) async {
    if (!_isValidPostIndex(index)) {
      return;
    }

    final previous =
        _selectedPlacePosts[index];

    setState(() {
      _selectedPlacePosts[index] =
          previous.copyWith(
        isSaved: !previous.isSaved,
        savesCount: previous.isSaved
            ? (previous.savesCount > 0
                ? previous.savesCount - 1
                : 0)
            : previous.savesCount + 1,
      );
    });

    try {
      if (previous.isSaved) {
        await _communityService.unsavePost(
          previous.id,
        );
      } else {
        await _communityService.savePost(
          previous.id,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_isValidPostIndex(index) &&
            _selectedPlacePosts[index]
                    .id ==
                previous.id) {
          _selectedPlacePosts[index] =
              previous;
        }
      });

      _showMapMessage(
        'تعذر تحديث الحفظ',
      );
    }
  }


  void _showPostComments(int index) {
    if (!_isValidPostIndex(index)) {
      return;
    }

    final post =
        _selectedPlacePosts[index];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          CommentsSheet(
        post: post,
        communityService:
            _communityService,
        onCommentsCountChanged:
            (newCount) {
          if (!mounted) {
            return;
          }

          setState(() {
            if (_isValidPostIndex(
                  index,
                ) &&
                _selectedPlacePosts[index]
                        .id ==
                    post.id) {
              _selectedPlacePosts[index] =
                  _selectedPlacePosts[index]
                      .copyWith(
                commentsCount: newCount,
              );
            }
          });
        },
      ),
    );
  }

  Future<void> _deleteVisitorPost(
    int index,
  ) async {
    if (!_isValidPostIndex(index)) {
      return;
    }

    final post =
        _selectedPlacePosts[index];

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          Directionality(
        textDirection:
            TextDirection.rtl,
        child: AlertDialog(
          title:
              const Text('حذف المنشور'),
          content: const Text(
            'هل أنت تأكيد من رغبتك في حذف هذا المنشور؟',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              style: TextButton.styleFrom(
                foregroundColor:
                    Colors.red,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    try {
      await _communityService.deletePost(
        post.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPlacePosts.removeWhere(
          (item) => item.id == post.id,
        );
      });

      _startPlaceCarousel();

      _showMapMessage(
        'تم حذف المنشور بنجاح',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMapMessage(
        'تعذر حذف المنشور',
      );
    }
  }

  void _showMapMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          content: Text(
            message,
            textDirection:
                TextDirection.rtl,
          ),
        ),
      );
  }

  // ===============================================================
  // PLACE GALLERY (CAROUSEL)
  // ===============================================================

  Widget _buildPlaceGallery() {
    final images =
        _selectedPlaceCarouselImages;

    final controller =
        _placeCarouselController;

    if (images.isEmpty ||
        controller == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(
        top: Radius.circular(22),
      ),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: (index) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _placeCarouselIndex =
                      index;
                });
              },
              itemBuilder: (_, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder:
                      (_, __, ___) {
                    return Container(
                      color:
                          _waynTealLight,
                      child: const Icon(
                        Icons
                            .image_not_supported_outlined,
                        color: _waynTeal,
                        size: 34,
                      ),
                    );
                  },
                );
              },
            ),

            if (images.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: List.generate(
                    images.length,
                    (index) {
                      final active =
                          index ==
                              _placeCarouselIndex;

                      return Container(
                        width: active
                            ? 16
                            : 6,
                        height: 6,
                        margin: const EdgeInsets
                            .symmetric(
                          horizontal: 2,
                        ),
                        decoration:
                            BoxDecoration(
                          color: active
                              ? Colors
                                  .white
                              : Colors
                                  .white
                                  .withValues(
                                alpha: 0.55,
                              ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // GENERAL INFORMATION
  // ===============================================================

  Widget _buildGeneralInformation(
    Place place,
  ) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12,
      ),
      child: Column(
        children: [
          if (place.description != null &&
              place.description!
                  .trim()
                  .isNotEmpty)
            _buildInfoSection(
              icon:
                  Icons.description_outlined,
              title: 'عن المكان',
              child: Text(
                place.description!.trim(),
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                maxLines: 3,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color:
                      Color(
                    0xFF596273,
                  ),
                ),
              ),
            ),

          if (place.address != null &&
              place.address!
                  .trim()
                  .isNotEmpty)
            _buildInfoRow(
              icon:
                  Icons.location_on_outlined,
              title: 'العنوان',
              value:
                  place.address!.trim(),
            ),

          if (place.phone != null &&
              place.phone!
                  .trim()
                  .isNotEmpty)
            _buildInfoRow(
              icon:
                  Icons.phone_outlined,
              title: 'الهاتف',
              value:
                  place.phone!.trim(),
            ),

          if ((place.openingTime !=
                      null &&
                  place.openingTime!
                      .trim()
                      .isNotEmpty) ||
              (place.closingTime !=
                      null &&
                  place.closingTime!
                      .trim()
                      .isNotEmpty))
            _buildInfoRow(
              icon:
                  Icons.schedule_rounded,
              title: 'ساعات العمل',
              value: () {
                final opening = place
                    .openingTime
                    ?.trim();
                final closing = place
                    .closingTime
                    ?.trim();

                if ((opening ==
                            null ||
                        opening
                            .isEmpty) &&
                    closing !=
                        null &&
                    closing
                        .isNotEmpty) {
                  return closing;
                }

                if ((closing ==
                            null ||
                        closing
                            .isEmpty) &&
                    opening !=
                        null &&
                    opening
                        .isNotEmpty) {
                  return opening;
                }

                return '$opening - $closing';
              }(),
            ),

          if (place.website != null &&
              place.website!
                  .trim()
                  .isNotEmpty)
            _buildInfoRow(
              icon:
                  Icons.language_rounded,
              title: 'الموقع الإلكتروني',
              value:
                  place.website!.trim(),
            ),

          _buildInfoRow(
            icon:
                Icons.people_outline_rounded,
            title: 'زيارات',
            value:
                '${place.visitsCount}',
          ),

          const SizedBox(
            height: 4,
          ),

          _buildDirectionsButton(),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(
        11,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF8FAFB,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE8ECF1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color:
                    _waynTeal,
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      _waynText,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 7,
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 7,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF8FAFB,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE8ECF1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
                _waynTeal,
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color:
                  _waynText,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              value,
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.right,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w500,
                color:
                    _waynMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsButton() {
    final place = _selectedPlace;

    if (place == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 43,
      child: ElevatedButton.icon(
        onPressed: () {
          _openGoogleMapsDirections(
            place,
          );
        },
        icon: const Icon(
          Icons.directions_rounded,
          size: 20,
        ),
        label: const Text(
          'الحصول على الاتجاهات',
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              _waynTeal,
          foregroundColor:
              Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceImage(
    Place place,
  ) {
    final imageUrl =
        place.imageUrl.trim();

    if (imageUrl.isEmpty) {
      return _buildImageFallback();
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: Image.network(
        imageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return _buildImageFallback();
        },
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: 72,
      height: 72,
      decoration:
          BoxDecoration(
        color: _waynTealLight,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: const Icon(
        Icons.place_rounded,
        color: _waynTeal,
        size: 28,
      ),
    );
  }
}
