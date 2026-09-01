import 'package:flutter/material.dart';

/// ألوان هوية WAYN المدركة للوضع المظلم.
///
/// استخدم [BuildContext.waynColors] للوصول إليها بدل الألوان الثابتة
/// عند بناء واجهات تدعم الوضع المظلم.
@immutable
class WaynColors extends ThemeExtension<WaynColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color brand;
  final Color brandDark;
  final Color onBrand;
  final Color danger;
  final Color warning;
  final Color accentPurple;
  final Color shadow;

  const WaynColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.brand,
    required this.brandDark,
    required this.onBrand,
    required this.danger,
    required this.warning,
    required this.accentPurple,
    required this.shadow,
  });

  static const WaynColors light = WaynColors(
    background: Color(0xFFF7F9FC),
    surface: Colors.white,
    surfaceAlt: Color(0xFFE8F8F6),
    surfaceElevated: Colors.white,
    textPrimary: Color(0xFF172033),
    textSecondary: Color(0xFF7A8494),
    textMuted: Color(0xFF8B94A3),
    divider: Color(0xFFE3E8ED),
    brand: Color(0xFF18A99A),
    brandDark: Color(0xFF087F78),
    onBrand: Colors.white,
    danger: Color(0xFFD95757),
    warning: Color(0xFFF59E0B),
    accentPurple: Color(0xFF8B5CF6),
    shadow: Color(0x14000000),
  );

  static const WaynColors dark = WaynColors(
    background: Color(0xFF0F1517),
    surface: Color(0xFF182124),
    surfaceAlt: Color(0xFF223237),
    surfaceElevated: Color(0xFF1E292D),
    textPrimary: Color(0xFFF2F5F7),
    textSecondary: Color(0xFFA6B0B8),
    textMuted: Color(0xFF8A969E),
    divider: Color(0xFF2A353C),
    brand: Color(0xFF2BBDB0),
    brandDark: Color(0xFF18A99A),
    onBrand: Colors.white,
    danger: Color(0xFFE56969),
    warning: Color(0xFFF5B23A),
    accentPurple: Color(0xFFA78BFA),
    shadow: Color(0x40000000),
  );

  @override
  WaynColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? brand,
    Color? brandDark,
    Color? onBrand,
    Color? danger,
    Color? warning,
    Color? accentPurple,
    Color? shadow,
  }) {
    return WaynColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      brand: brand ?? this.brand,
      brandDark: brandDark ?? this.brandDark,
      onBrand: onBrand ?? this.onBrand,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      accentPurple: accentPurple ?? this.accentPurple,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  WaynColors lerp(
    covariant ThemeExtension<WaynColors>? other,
    double t,
  ) {
    if (other is! WaynColors) {
      return this;
    }

    return WaynColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceElevated: Color.lerp(
        surfaceElevated,
        other.surfaceElevated,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// الوصول السهل لألوان WAYN من الـ BuildContext.
extension WaynColorsX on BuildContext {
  WaynColors get waynColors {
    final colors = Theme.of(this).extension<WaynColors>();
    return colors ?? WaynColors.light;
  }
}
