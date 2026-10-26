import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 앱 테마. 세부 컴포넌트 모양은 design_system/widgets 에서 토큰으로 직접 그린다.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.surfaceMuted,
      dividerColor: AppColors.divider,
      textTheme: TextTheme(
        displaySmall: AppTypography.display,
        headlineSmall: AppTypography.title1,
        titleLarge: AppTypography.title2,
        titleMedium: AppTypography.heading,
        bodyLarge: AppTypography.body1,
        bodyMedium: AppTypography.body1,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.button,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.placeholder,
        selectionHandleColor: AppColors.primary,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg))),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: AppTypography.body2Medium.copyWith(color: AppColors.white),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.md))),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
