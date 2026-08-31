/// موقع محفوظ اختاره المستخدم يدويًا.
///
/// يُخزَّن محليًا (عبر [SavedLocationsStore]) مع الإحداثيات والاسم،
/// ويبقى محفوظًا بعد إعادة تشغيل التطبيق.
class SavedLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.toIso8601String(),
      };

  factory SavedLocation.fromJson(Map<String, dynamic> data) {
    double? num(dynamic v) =>
        v is int ? (v).toDouble() : (v is double ? v : double.tryParse(v.toString()));

    return SavedLocation(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString().trim() ?? '',
      latitude: num(data['latitude']) ?? 0,
      longitude: num(data['longitude']) ?? 0,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}