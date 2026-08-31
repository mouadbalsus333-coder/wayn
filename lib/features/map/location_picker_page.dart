import 'dart:async';
import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Minimal location picker built on top of the existing WAYN map stack.
///
/// It deliberately reuses the same MapLibre implementation, tile style and
/// symbol-based pin approach as [MapPage] — it never introduces a parallel
/// map system or new dependencies.
///
/// Flow: tap anywhere on the map to place/move the pin → confirm → the picked
/// coordinates are returned to the caller via `Navigator.pop({
/// 'latitude', 'longitude'})`.
class LocationPickerPage extends StatefulWidget {
  /// Optional starting point (e.g. coordinates being edited). When provided
  /// the map opens centered on it with the pin already placed.
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const Color _waynTeal = Color(0xFF18A99A);
  static const Color _waynBackground = Color(0xFFF7F9FC);

  // Same tile style and default center (Tripoli) as MapPage.
  static const String _mapStyle =
      'https://tiles.openfreemap.org/styles/positron';

  static const LatLng _defaultCenter = LatLng(32.8872, 13.1913);
  static const double _defaultZoom = 13.5;

  static const String _pinImageName = 'wayn-location-picker-pin';

  final Completer<MapLibreMapController> _mapController =
      Completer<MapLibreMapController>();

  LatLng? get _initialPoint =>
      widget.initialLatitude != null && widget.initialLongitude != null
          ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
          : null;

  bool _mapReady = false;
  LatLng? _selected;
  Symbol? _pinSymbol;

  @override
  void initState() {
    super.initState();
    _selected = _initialPoint;
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
  }

  Future<void> _onStyleLoaded() async {
    try {
      final controller = await _mapController.future;

      await controller.addImage(_pinImageName, await _createPinImage());

      final point = _selected;
      if (point != null) {
        await _placePin(point);
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: point, zoom: 16),
          ),
          duration: const Duration(milliseconds: 400),
        );
      }

      if (mounted) {
        setState(() => _mapReady = true);
      }
    } catch (e) {
      debugPrint('WAYN location picker error: $e');

      if (mounted) {
        setState(() => _mapReady = true);
      }
    }
  }

  Future<void> _placePin(LatLng coordinates) async {
    try {
      final controller = await _mapController.future;

      final existing = _pinSymbol;
      if (existing != null) {
        await controller.removeSymbols([existing]);
      }

      final pin = await controller.addSymbol(
        SymbolOptions(
          geometry: coordinates,
          iconImage: _pinImageName,
          iconSize: 0.55,
          iconAnchor: 'bottom',
        ),
        {'waynType': 'pickedLocation'},
      );

      if (mounted) {
        setState(() {
          _pinSymbol = pin;
          _selected = coordinates;
        });
      }
    } catch (e) {
      debugPrint('WAYN location picker pin error: $e');
    }
  }

  void _onMapClick(Point<double> point, LatLng coordinates) {
    if (!mounted) {
      return;
    }

    // Tapping again simply repositions the pin so the admin can correct the
    // location freely before confirming.
    _placePin(coordinates);
  }

  Future<void> _confirm() async {
    final selected = _selected;

    if (selected == null || !mounted) {
      return;
    }

    Navigator.of(context).pop(<String, double>{
      'latitude': selected.latitude,
      'longitude': selected.longitude,
    });
  }

  Future<Uint8List> _createPinImage() async {
    const size = 112;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..isAntiAlias = true
      ..color = _waynTeal;

    final center = size / 2;

    // Same teardrop shape language as the WAYN pins on MapPage.
    canvas.drawCircle(
      Offset(center, center * 0.72),
      size * 0.32,
      paint,
    );

    final path = ui.Path()
      ..moveTo(center - size * 0.17, center * 0.88)
      ..lineTo(center, size * 0.98)
      ..lineTo(center + size * 0.17, center * 0.88)
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
        text: String.fromCharCode(Icons.location_on_rounded.codePoint),
        style: TextStyle(
          fontSize: size * 0.34,
          fontFamily: Icons.location_on_rounded.fontFamily,
          package: Icons.location_on_rounded.fontPackage,
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

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) {
      throw StateError('Failed to render the location pin image.');
    }

    return bytes.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _waynBackground,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'تحديد الموقع على الخريطة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: MapLibreMap(
                initialCameraPosition: CameraPosition(
                  target: _initialPoint ?? _defaultCenter,
                  zoom: _initialPoint != null ? 16 : _defaultZoom,
                ),
                styleString: _mapStyle,
                minMaxZoomPreference: const MinMaxZoomPreference(3, 19),
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationEnabled: false,
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                onMapClick: _onMapClick,
              ),
            ),

            if (!_mapReady)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: _waynBackground,
                    child: const Center(
                      child: Text(
                        'جارٍ تحميل الخريطة...',
                        style: TextStyle(
                          color: Color(0xFF697386),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selected != null
                                ? Icons.location_on_rounded
                                : Icons.travel_explore_rounded,
                            color: _waynTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selected == null
                                  ? 'اضغط على الخريطة لوضع دبوس مكان'
                                  : '${selected.latitude.toStringAsFixed(6)} , '
                                      '${selected.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected == null
                                    ? const Color(0xFF697386)
                                    : const Color(0xFF172033),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: selected == null ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _waynTeal,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE3E8EF),
                          disabledForegroundColor: const Color(0xFF9AA4B2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text(
                          'تأكيد الموقع',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
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

