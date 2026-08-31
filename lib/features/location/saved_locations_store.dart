import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/saved_location.dart';

/// إدارة المواقع المحفوظة والموقع الحالي.
///
/// - يستخدم [FlutterSecureStorage] (نفس أداة التخزين المستخدمة للتوكنز في
///   المشروع) لضمان بقاء المواقع محفوظة بعد إغلاق التطبيق وإعادة فتحه.
/// - الموقع الحالي إما:
///    1. موقع GPS حالي (`_selectedId == null`)، أو
///    2. موقع محفوظ اختاره المستخدم يدويًا.
/// - يُخطر المستمعين (مثل الهيدر والخريطة) عند أي تغيير.
class SavedLocationsStore extends ChangeNotifier {
  SavedLocationsStore._();

  static final SavedLocationsStore instance = SavedLocationsStore._();

  static const String _locationsKey = 'wayn_saved_locations';
  static const String _selectedKey = 'wayn_selected_location';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<SavedLocation> _locations = <SavedLocation>[];
  String? _selectedId;
  bool _loaded = false;

  List<SavedLocation> get locations => List.unmodifiable(_locations);

  bool get isLoaded => _loaded;

  /// `true` عندما يكون الموقع الحالي موقعًا محفوظًا (وليس GPS).
  bool get usesSavedLocation => _selectedId != null;

  SavedLocation? get selectedLocation {
    final id = _selectedId;
    if (id == null) return null;

    for (final location in _locations) {
      if (location.id == id) return location;
    }

    return null;
  }

  /// نقطة الإحداثيات المرجعية الحالية (موقع محفوظ مختار) أو `null` إذا كان
  /// المرجع هو GPS.
  ({double latitude, double longitude})? get referencePoint {
    final selected = selectedLocation;
    if (selected == null) return null;

    return (latitude: selected.latitude, longitude: selected.longitude);
  }

  /// نص يظهر في الهيدر بجانب دبوس الموقع.
  String get currentLabel => selectedLocation?.name ?? 'الموقع الحالي';

  /// يُحمَّل مرة واحدة عند أول وصول.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
  }

  Future<void> _load() async {
    try {
      final rawLocations = await _storage.read(key: _locationsKey);
      final rawSelected = await _storage.read(key: _selectedKey);

      final List<SavedLocation> loaded = <SavedLocation>[];
      if (rawLocations != null && rawLocations.isNotEmpty) {
        final decoded = jsonDecode(rawLocations);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              loaded.add(SavedLocation.fromJson(item));
            }
          }
        }
      }

      _locations = loaded;
      _selectedId = rawSelected;

      // إذا كان الموقع المختار لم يعد موجودًا نعود إلى GPS.
      if (_selectedId != null && selectedLocation == null) {
        _selectedId = null;
      }

      _loaded = true;
      notifyListeners();
    } catch (error) {
      debugPrint('WAYN saved locations load error: $error');
      _loaded = true;
    }
  }

  /// إضافة موقع محفوظ جديد ثم اختياره كموقع حالي.
  Future<void> add({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    await ensureLoaded();

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final location = SavedLocation(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );

    _locations = <SavedLocation>[..._locations, location];
    _selectedId = location.id;

    notifyListeners();
    await _persist();
  }

  Future<void> select(String id) async {
    await ensureLoaded();

    final exists = _locations.any((location) => location.id == id);
    if (!exists) return;

    _selectedId = id;
    notifyListeners();
    await _persist();
  }

  /// العودة إلى موقع GPS الحالي.
  Future<void> selectGps() async {
    await ensureLoaded();

    if (_selectedId == null) return;

    _selectedId = null;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();

    if (!_locations.any((location) => location.id == id)) return;

    _locations = _locations.where((location) => location.id != id).toList();

    if (_selectedId == id) {
      _selectedId = null;
    }

    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final encoded = jsonEncode(
        _locations.map((location) => location.toJson()).toList(),
      );

      await _storage.write(key: _locationsKey, value: encoded);
      await _storage.write(key: _selectedKey, value: _selectedId ?? 'gps');
    } catch (error) {
      debugPrint('WAYN saved locations persist error: $error');
    }
  }
}