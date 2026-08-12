import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  // نستخدم خط النظام مؤقتًا حتى نضيف خط WAYN لاحقًا.
  static const String fontFamily = 'sans';

  // =========================
  // Light Theme
  // =========================

  static const TextTheme lightTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryLight,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryLight,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryLight,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryLight,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondaryLight,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryLight,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryLight,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryLight,
    ),
  );

  // =========================
  // Dark Theme
  // =========================

  static const TextTheme darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryDark,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryDark,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryDark,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryDark,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondaryDark,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryDark,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryDark,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryDark,
    ),
  );
}