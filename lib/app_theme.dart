import 'package:flutter/material.dart';

const _seedBlue = Color(0xff0a7aff);

ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedBlue,
    brightness: brightness,
  ).copyWith(
    surface: brightness == Brightness.dark ? const Color(0xff181a20) : null,
    surfaceContainerLowest:
        brightness == Brightness.dark ? const Color(0xff14161b) : null,
    surfaceContainerLow:
        brightness == Brightness.dark ? const Color(0xff20232b) : null,
    surfaceContainer:
        brightness == Brightness.dark ? const Color(0xff262a34) : null,
    surfaceContainerHigh:
        brightness == Brightness.dark ? const Color(0xff2d323d) : null,
    outline: brightness == Brightness.dark ? const Color(0xff4b5362) : null,
    outlineVariant:
        brightness == Brightness.dark ? const Color(0xff343b49) : null,
    onSurface: brightness == Brightness.dark ? const Color(0xfff2f4f8) : null,
    onSurfaceVariant:
        brightness == Brightness.dark ? const Color(0xffbdc5d3) : null,
    secondaryContainer:
        brightness == Brightness.dark ? const Color(0xff33405b) : null,
    onSecondaryContainer:
        brightness == Brightness.dark ? const Color(0xffe8eeff) : null,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        brightness == Brightness.light ? const Color(0xfff7f8fc) : const Color(0xff181a20),
    splashFactory: InkSparkle.splashFactory,
    hoverColor: scheme.primary.withValues(alpha: brightness == Brightness.light ? .08 : .16),
    focusColor: scheme.primary.withValues(alpha: .16),
    highlightColor: scheme.primary.withValues(alpha: .12),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? const Color(0xfff2f2f7)
          : const Color(0xff242831),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
