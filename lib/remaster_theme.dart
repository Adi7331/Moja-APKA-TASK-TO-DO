import 'package:flutter/material.dart';

import 'note_item.dart';

/// The preview is independently themed so the original UI remains comparable.
ThemeData buildRemasterTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff2f6fed),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xffa9c6ff) : const Color(0xff245dcd),
        onPrimary: dark ? const Color(0xff10294f) : Colors.white,
        surface: dark ? const Color(0xff0e1116) : const Color(0xfff5f7fa),
        surfaceContainerLow: dark ? const Color(0xff171b22) : Colors.white,
        surfaceContainer: dark
            ? const Color(0xff202631)
            : const Color(0xffedf1f7),
        surfaceContainerHigh: dark
            ? const Color(0xff29313e)
            : const Color(0xffe4eaf3),
        onSurface: dark ? const Color(0xfff0f3f8) : const Color(0xff172337),
        onSurfaceVariant: dark
            ? const Color(0xffb7c1d0)
            : const Color(0xff526177),
        outline: dark ? const Color(0xff8794a7) : const Color(0xff6e7b8f),
        outlineVariant: dark
            ? const Color(0xff303946)
            : const Color(0xffdce3ed),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -.9,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -.6,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: scheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    visualDensity: VisualDensity.standard,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

Duration remasterMotion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

Color remasterNoteColor(BuildContext context, int index) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  const light = [
    Color(0xffdceafa),
    Color(0xffe9e1fa),
    Color(0xffdcefe5),
    Color(0xfff5ebd3),
    Color(0xfff8dfd8),
  ];
  const dim = [
    Color(0xff203148),
    Color(0xff30283f),
    Color(0xff20382f),
    Color(0xff3a3224),
    Color(0xff402d2a),
  ];
  return (dark ? dim : light)[index % light.length];
}

/// Soft note-card fills inspired by paper notes; dark foregrounds keep the
/// card readable even when the surrounding app is in dark mode.
Color remasterNoteCardColor(int index) {
  const colors = [
    Color(0xffdceafa),
    Color(0xffe9e1fa),
    Color(0xffdcefe5),
    Color(0xfff5ebd3),
    Color(0xfff8dfd8),
  ];
  return colors[index % colors.length];
}

/// The Notes library deliberately keeps its paper-like cards light in both
/// app themes. The surrounding chrome may be dark, but the content itself is
/// always read as a physical, pastel note rather than another dark container.
const noteLibraryPastelPalette = <Color>[
  Color(0xffc4dcff),
  Color(0xffdccbff),
  Color(0xffbfead5),
  Color(0xfff5d9a8),
  Color(0xffffc7bb),
];

const noteLibraryCardInk = Color(0xff172337);
const noteLibraryCardMutedInk = Color(0xff3c5069);

Color noteLibrarySurfaceForColor(NoteColorKey colorKey, ColorScheme scheme) =>
    switch (colorKey) {
      NoteColorKey.neutral => scheme.surfaceContainerHigh,
      NoteColorKey.blue => noteLibraryPastelPalette[0],
      NoteColorKey.lavender => noteLibraryPastelPalette[1],
      NoteColorKey.mint => noteLibraryPastelPalette[2],
      NoteColorKey.sand => noteLibraryPastelPalette[3],
      NoteColorKey.peach => noteLibraryPastelPalette[4],
    };
