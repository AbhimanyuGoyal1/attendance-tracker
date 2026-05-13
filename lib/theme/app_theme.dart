import 'package:flutter/material.dart';

class AppTheme {
  static const _radius = 18.0;

  static const Map<String, Color> seedColors = {
    'ocean': Color(0xFF0F6FA2),
    'emerald': Color(0xFF0E9F6E),
    'sunset': Color(0xFFD97706),
    'rose': Color(0xFFBE185D),
    'slate': Color(0xFF334155),
  };

  static ThemeData light({
    Color? seedColor,
    Color? secondaryColor,
    bool gradientEnabled = true,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor ?? seedColors['ocean']!,
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      secondary: gradientEnabled
          ? (secondaryColor ?? base.secondary)
          : base.primary,
    );
    return _base(scheme);
  }

  static ThemeData dark({
    Color? seedColor,
    Color? secondaryColor,
    bool gradientEnabled = true,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor ?? seedColors['ocean']!,
      brightness: Brightness.dark,
    );
    final scheme = base.copyWith(
      secondary: gradientEnabled
          ? (secondaryColor ?? base.secondary)
          : base.primary,
    );
    return _base(scheme);
  }

  static Color resolveSeed(String key) => seedColors[key] ?? seedColors['ocean']!;

  static ThemeData _base(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0B1119) : const Color(0xFFF4F7FB);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 3;
            return 1;
          }),
          animationDuration: const Duration(milliseconds: 180),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? colorScheme.primary.withValues(alpha: 0.12)
                : null,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
