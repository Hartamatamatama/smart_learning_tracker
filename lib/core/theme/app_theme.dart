import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema "Focus Ritual" — bold, kontras tegas, nuansa deep work.
/// Display: Space Grotesk (geometris/tegas). Body: Inter (nyaman dibaca).
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.dBg : AppColors.lBg;
    final surface = isDark ? AppColors.dSurface : AppColors.lSurface;
    final elevated =
        isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceElevated;
    final textPrimary = isDark ? AppColors.dTextPrimary : AppColors.lTextPrimary;
    final textMuted = isDark ? AppColors.dTextMuted : AppColors.lTextMuted;
    final border = isDark ? AppColors.dBorder : AppColors.lBorder;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.lime,
      onPrimary: AppColors.onLime,
      primaryContainer: isDark ? const Color(0xFF2A3414) : const Color(0xFFEAF7C2),
      onPrimaryContainer: isDark ? AppColors.lime : AppColors.limeDeep,
      secondary: AppColors.coral,
      onSecondary: AppColors.onCoral,
      secondaryContainer:
          isDark ? const Color(0xFF3A1F1B) : const Color(0xFFFFE2DD),
      onSecondaryContainer: AppColors.coral,
      tertiary: AppColors.coral,
      onTertiary: AppColors.onCoral,
      tertiaryContainer:
          isDark ? const Color(0xFF3A1F1B) : const Color(0xFFFFE2DD),
      onTertiaryContainer: AppColors.coral,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF3A1A1A) : const Color(0xFFFFDAD6),
      onErrorContainer: AppColors.error,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerLowest: bg,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: elevated,
      surfaceContainerHighest: elevated,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: textPrimary,
      onInverseSurface: bg,
      inversePrimary: AppColors.limeDeep,
    );

    // Typography
    final baseText = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    TextStyle grotesk(TextStyle? s, {FontWeight w = FontWeight.w700}) =>
        GoogleFonts.spaceGrotesk(textStyle: s, fontWeight: w);
    final textTheme = baseText
        .copyWith(
          displayLarge: grotesk(baseText.displayLarge),
          displayMedium: grotesk(baseText.displayMedium),
          displaySmall: grotesk(baseText.displaySmall),
          headlineLarge: grotesk(baseText.headlineLarge),
          headlineMedium: grotesk(baseText.headlineMedium),
          headlineSmall: grotesk(baseText.headlineSmall),
          titleLarge: grotesk(baseText.titleLarge, w: FontWeight.w600),
        )
        .apply(bodyColor: textPrimary, displayColor: textPrimary);

    OutlineInputBorder inputBorder(Color c, [double w = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: grotesk(textTheme.titleLarge, w: FontWeight.w600)
            .copyWith(color: textPrimary, fontSize: 22),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onLime,
          disabledBackgroundColor: border,
          disabledForegroundColor: textMuted,
          textStyle: grotesk(textTheme.titleMedium, w: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onLime,
          elevation: 0,
          textStyle: grotesk(textTheme.titleMedium, w: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.lime : AppColors.limeDeep,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textMuted),
        floatingLabelStyle:
            const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w600),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(AppColors.lime, 2),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 2),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.lime,
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: AppColors.onLime),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: grotesk(textTheme.titleLarge, w: FontWeight.w600)
            .copyWith(color: textPrimary),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: TextStyle(color: textPrimary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lime,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.lime : surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.onLime
                  : textPrimary),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.onLime : textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.lime : surface),
        trackOutlineColor: WidgetStatePropertyAll(border),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        textColor: textPrimary,
      ),
    );
  }
}
