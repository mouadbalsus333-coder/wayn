import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/models/place.dart';
import 'place_repository.dart';

class SupabasePlaceRepository implements PlaceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<List<Place>> getPlaces() async {
    final response = await _supabase
        .from('places')
        .select()
        .eq('is_active', true)
        .order('visits_count', ascending: false);

    return (response as List)
        .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<Place?> getPlaceById(String id) async {
    final response = await _supabase
        .from('places')
        .select()
        .eq('id', id)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return _placeFromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<List<Place>> getPlacesByCategory(String categoryId) async {
    final response = await _supabase
        .from('places')
        .select()
        .eq('is_active', true)
        .eq('category_id', categoryId)
        .order('visits_count', ascending: false);

    return (response as List)
        .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<List<Place>> getOpenPlaces() async {
    final response = await _supabase
        .from('places')
        .select()
        .eq('is_active', true)
        .eq('is_open', true)
        .order('visits_count', ascending: false);

    return (response as List)
        .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<List<Place>> getHighestRatedPlaces({int limit = 10}) async {
    final response = await _supabase
        .from('places')
        .select()
        .eq('is_active', true)
        .order('rating', ascending: false)
        .limit(limit);

    return (response as List)
        .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<List<Place>> getMostVisitedPlaces({int limit = 10}) async {
    final response = await _supabase
        .from('places')
        .select()
        .eq('is_active', true)
        .order('visits_count', ascending: false)
        .limit(limit);

    return (response as List)
        .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<List<Place>> searchPlaces(String query) async {
    final search = query.trim();
    if (search.isEmpty) {
      return getPlaces();
    }

    final response = await _supabase
        .from('places')
        .select()
        .eq('is_active', true)
        .or(
          'name.ilike.%$search%,'
          'city.ilike.%$search%,'
          'category.ilike.%$search%,'
          'description.ilike.%$search%',
        )
        .order('visits_count', ascending: false);

    return (response as List)
        .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Place _placeFromMap(Map<String, dynamic> data) {
    return Place(
      id: _stringValue(data['id']),
      categoryId: _nullableString(data['category_id']),
      name: _stringValue(data['name']),
      city: _stringValue(data['city']),
      category: _stringValue(data['category']),
      imageUrl: _stringValue(data['image_url']),
      rating: _doubleValue(data['rating']),
      isOpen: _boolValue(data['is_open']),
      description: _nullableString(data['description']),
      address: _nullableString(data['address']),
      phone: _nullableString(data['phone']),
      website: _nullableString(data['website']),
      latitude: _nullableDouble(data['latitude']),
      longitude: _nullableDouble(data['longitude']),
      images: _stringList(data['images']),
      services: _stringList(data['services']),
      openingTime: _timeValue(data['opening_time']),
      closingTime: _timeValue(data['closing_time']),
      reviewsCount: _intValue(data['reviews_count']),
      visitsCount: _intValue(data['visits_count']),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }

  double _doubleValue(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    if (value is num) {
      return value != 0;
    }

    return false;
  }

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  String? _timeValue(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    return [];
  }
}
