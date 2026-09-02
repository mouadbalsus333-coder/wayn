import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// المثيل المشترك لمبدّل المظهر على مستوى التطبيق.
final ThemeController waynThemeController = ThemeController();

/// يحافظ على وضع المظهر (فاتح/داكن) على مستوى التطبيق ويخزّن الاختيار
/// محليًا ليظل محفوظًا بعد إغلاق التطبيق وإعادة فتحه.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light);

  static const String _storageKey = 'wayn_theme_mode';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// هل تم تحميل الاختيار المحفوظ؟
  bool loaded = false;

  /// يجلب الاختيار المخزّن ويطبّقه.
  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      value = _normalize(raw);
    } catch (_) {
      value = ThemeMode.light;
    }

    loaded = true;
  }

    /// تفعيل/تعطيل الوضع المظلم مع حفظ الاختيار.
  ///
  /// يُنبّه المستمعين فقط عندما يتغيّر الوضع بالفعل لتجنب
  /// إعادة بناء شجرة التطبيق بشكل غير ضروري.
  Future<void> setDarkMode(bool dark) async {
    final newMode = dark ? ThemeMode.dark : ThemeMode.light;

    // لا تُعيد الإشعار إذا لم يتغيّر الوضع — يمنع هذا
    // إعادة بناء كل الصفحات عند الضغط المتكرر على الزر.
    if (value == newMode) return;

    value = newMode;

    try {
      await _storage.write(
        key: _storageKey,
        value: dark ? 'dark' : 'light',
      );
    } catch (_) {
      // التخزين فاشل لا يجب أن يكسر الواجهة الحالية.
    }
  }

  static ThemeMode _normalize(String? raw) {
    return raw == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }
}
