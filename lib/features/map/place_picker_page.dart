import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../services/place_service.dart';
import '../home/models/place.dart';

/// Map-based WAYN place picker used by the community composer.
///
/// It deliberately reuses the same MapLibre stack, tile style, pin rendering
/// approach and [PlaceService] as [MapPage] — no parallel map system is
/// introduced and the user can only pick a real place returned by the
/// backend (never raw coordinates).
///
/// Flow: tap a place pin → its info card appears at the bottom → confirm →
/// the selected [Place] is returned via `Navigator.pop(Place)`.
class PlacePickerPage extends StatefulWidget {
  /// Place already attached to a draft post (e.g. when re-opening the
  /// picker). The map centers on it and preselects it.
  final Place? initialPlace;

  const PlacePickerPage({
    super.key,
    this.initialPlace,
  });

  @override
  State<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends State<PlacePickerPage> {
  static const Color _waynTeal = Color(0xFF18A99A);
  static const Color _waynText = Color(0xFF172033);
  static const Color _waynBackground = Color(0xFFF7F9FC);

  // Same tile style and default center (Tripoli) as MapPage.
  static const String _mapStyle =
      'https://tiles.openfreemap.org/styles/positron';

  static const LatLng _defaultCenter = LatLng(
    32.8872,
    13.1913,
  );

  static const double _defaultZoom = 12;

  static const String _pinImageName = 'wayn-place-pin';

  final Completer<MapLibreMapController> _mapController =
      Completer<MapLibreMapController>();

  final TextEditingController _searchController =
      TextEditingController();

  final PlaceService _placeService = PlaceService();

  List<Place> _places = [];

  Place? _selected;

  bool _mapReady = false;
  bool _isLoadingPlaces = true;
  bool _hasLoadError = false;

  String _query = '';

  @override
  void initState() {
    super.initState();

    _selected = widget.initialPlace;
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
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
      _hasLoadError = false;
    });

    try {
      final places =
          await _placeService.getPlaces();

      if (!mounted) {
        return;
      }

      setState(() {
        _places = places;
        _isLoadingPlaces = false;
      });

      await _addPins();
    } catch (e) {
      debugPrint('WAYN place picker load error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPlaces = false;
        _hasLoadError = true;
      });
    }
  }

  bool get _hasQuery => _query.trim().isNotEmpty;

  List<Place> get _filteredPlaces {
    final query =
        _query.trim().toLowerCase();

    if (query.isEmpty) {
      return _places;
    }

    return _places.where((place) {
      return place.name.toLowerCase().contains(query) ||
          place.city.toLowerCase().contains(query) ||
          place.category.toLowerCase().contains(query);
    }).toList();
  }

  // ===============================================================
  // PINS
  // ===============================================================

  Future<void> _addPins() async {
    if (!_mapReady ||
        !_mapController.isCompleted) {
      return;
    }

    try {
      final controller =
          await _mapController.future;

      await controller.clearSymbols();

      for (final place in _filteredPlaces) {
        final latitude = place.latitude;
        final longitude = place.longitude;

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(
              latitude,
              longitude,
            ),
            iconImage: _pinImageName,
            iconSize: 0.48,
            iconAnchor: 'bottom',
          ),
          {'placeId': place.id},
        );
      }
    } catch (e) {
      debugPrint('WAYN place picker pins error: $e');
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);

    _addPins();
  }

  // ===============================================================
  // MAP CALLBACKS
  // ===============================================================

  Future<void> _onMapCreated(
    MapLibreMapController controller,
  ) async {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }

    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    try {
      final controller =
          await _mapController.future;

      await controller.addImage(
        _pinImageName,
        await _createPinImage(),
      );

      if (mounted) {
        setState(() => _mapReady = true);
      }

      await _addPins();

      final initial = widget.initialPlace;

      if (initial != null &&
          initial.latitude != null &&
          initial.longitude != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                initial.latitude!,
                initial.longitude!,
              ),
              zoom: 15,
            ),
          ),
          duration:
              const Duration(milliseconds: 400),
        );
      }
    } catch (e) {
      debugPrint('WAYN place picker style error: $e');

      if (mounted) {
        setState(() => _mapReady = true);
      }
    }
  }

  Future<void> _onSymbolTapped(
    Symbol symbol,
  ) async {
    final placeId =
        symbol.data?['placeId']?.toString();

    if (placeId == null || placeId.isEmpty) {
      return;
    }

    Place? place;

    for (final item in _places) {
      if (item.id == placeId) {
        place = item;
        break;
      }
    }

    if (place == null || !mounted) {
      return;
    }

    setState(() => _selected = place);

    final latitude = place.latitude;
    final longitude = place.longitude;

    if (latitude == null || longitude == null) {
      return;
    }

    try {
      final controller =
          await _mapController.future;

      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(latitude, longitude),
          15.5,
        ),
        duration: const Duration(milliseconds: 400),
      );
    } catch (e) {
      debugPrint('WAYN place picker camera error: $e');
    }
  }

  void _clearSelection() {
    setState(() => _selected = null);
  }

  void _confirmSelection() {
    final place = _selected;

    if (place == null || !mounted) {
      return;
    }

    Navigator.of(context).pop(place);
  }

  Future<Uint8List> _createPinImage() async {
    const size = 112;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..isAntiAlias = true
      ..color = _waynTeal;

    final center = size / 2;

    // Same teardrop pin language as MapPage markers.
    canvas.drawCircle(
      Offset(center, center * 0.72),
      size * 0.32,
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

    canvas.drawPath(path, paint);

    final border = Paint()
      ..isAntiAlias = true
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.035;

    canvas.drawCircle(
      Offset(center, center * 0.72),
      size * 0.32 + size * 0.035,
      border,
    );

    final iconPainter = TextPainter()
      ..textDirection = TextDirection.ltr
      ..text = TextSpan(
        text: String.fromCharCode(
          Icons.place_rounded.codePoint,
        ),
        style: TextStyle(
          fontSize: size * 0.34,
          fontFamily:
              Icons.place_rounded.fontFamily,
          package: Icons
              .place_rounded.fontPackage,
          color: Colors.white,
        ),
      );
    iconPainter.layout();

    iconPainter.paint(
      canvas,
      Offset(
        center - iconPainter.width / 2,
        center * 0.72 - iconPainter.height / 2,
      ),
    );

    final picture =
        recorder.endRecording();
    final image =
        await picture.toImage(size, size);
    final bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (bytes == null) {
      throw StateError(
        'Failed to render the place pin image.',
      );
    }

    return bytes.buffer.asUint8List();
  }

  Widget _buildPlaceImage(Place place) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 54,
        height: 54,
        child: place.imageUrl.trim().isEmpty
            ? Container(
                color: const Color(0xFFE8F8F6),
                child: const Icon(
                  Icons.place_rounded,
                  color: _waynTeal,
                  size: 24,
                ),
              )
            : Image.network(
                place.imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFE8F8F6),
                    child: const Icon(
                      Icons.place_rounded,
                      color: _waynTeal,
                      size: 24,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPlaceMetaRow(Place place) {
    final meta = [
      if (place.city.trim().isNotEmpty) place.city,
      if (place.category.trim().isNotEmpty)
        place.category,
    ].join(' • ');

    return Row(
      children: [
        Flexible(
          child: Text(
            meta.isEmpty ? '—' : meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8B94A3),
              fontSize: 12,
            ),
          ),
        ),

        if (place.rating > 0) ...[
          const SizedBox(width: 8),

          const Icon(
            Icons.star_rounded,
            size: 16,
            color: Color(0xFFF5A623),
          ),

          Text(
            place.rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFFF5A623),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpenBadge(Place place) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: place.isOpen
            ? const Color(0xFFE8F8F6)
            : const Color(0xFFECEEF2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        place.isOpen ? 'مفتوح' : 'مغلق',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: place.isOpen
              ? const Color(0xFF18A99A)
              : const Color(0xFF697386),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final filteredPlaces = _filteredPlaces;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _waynBackground,
        body: Stack(
          children: [
            Positioned.fill(
              child: MapLibreMap(
                initialCameraPosition:
                    const CameraPosition(
                  target: _defaultCenter,
                  zoom: _defaultZoom,
                ),
                styleString: _mapStyle,
                minMaxZoomPreference:
                    const MinMaxZoomPreference(3, 19),
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationEnabled: false,
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback:
                    _onStyleLoaded,
              ),
            ),

            // =========================================================
            // TOP SEARCH
            // =========================================================

            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.of(context)
                      .padding
                      .top +
                  14,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.search_rounded,
                      color: _waynTeal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller:
                            _searchController,
                        textDirection:
                            TextDirection.rtl,
                        textAlign: TextAlign.right,
                        onChanged: _onSearchChanged,
                        decoration:
                            const InputDecoration(
                          hintText:
                              'ابحث عن مكان لإرفاقه بالمنشور...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8B94A3),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_hasQuery)
                      IconButton(
                        tooltip: 'مسح',
                        visualDensity:
                            VisualDensity.compact,
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_isLoadingPlaces)
              Positioned(
                top: MediaQuery.of(context)
                        .padding
                        .top +
                    72,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.10),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child:
                        const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _waynTeal,
                    ),
                  ),
                ),
              ),

            if (!_isLoadingPlaces &&
                (_hasLoadError ||
                    filteredPlaces.isEmpty))
              Positioned(
                top: MediaQuery.of(context)
                        .padding
                        .top +
                    72,
                left: 24,
                right: 24,
                child: Container(
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.10,
                        ),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFFB07C00),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hasLoadError
                              ? 'تعذر تحميل الأماكن. تأكد من اتصالك ثم أعد المحاولة.'
                              : 'لا توجد أماكن مطابقة لبحثك.',
                          style: const TextStyle(
                            color: Color(0xFF697386),
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadPlaces,
                        child: const Text('تحديث'),
                      ),
                    ],
                  ),
                ),
              ),

            if (selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom:
                    MediaQuery.of(context).padding.bottom +
                        16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE7EBF0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.15,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _buildPlaceImage(selected),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    selected.name,
                                    maxLines: 1,
                                    overflow: TextOverflow
                                        .ellipsis,
                                    style: const TextStyle(
                                      color: _waynText,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),

                                  const SizedBox(height: 3),

                                  _buildPlaceMetaRow(selected),
                                ],
                              ),
                            ),

                            _buildOpenBadge(selected),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _confirmSelection,
                                style: ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                      _waynTeal,
                                  foregroundColor:
                                      Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets
                                      .symmetric(
                                    vertical: 12,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      14,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.check_rounded,
                                  size: 19,
                                ),
                                label: const Text(
                                  'اختيار هذا المكان',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            OutlinedButton(
                              onPressed: _clearSelection,
                              style:
                                  OutlinedButton.styleFrom(
                                foregroundColor: const Color(
                                  0xFF697386,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE7EBF0),
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    14,
                                  ),
                                ),
                                minimumSize: const Size(
                                  48,
                                  46,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


