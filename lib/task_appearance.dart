import 'package:flutter/material.dart';

class TaskAppearance {
  const TaskAppearance._();

  static const colorKeys = [
    'neutral',
    'blue',
    'lavender',
    'mint',
    'peach',
    'sand',
  ];

  static const labels = {
    'neutral': 'Neutralny',
    'blue': 'Niebieski',
    'lavender': 'Lawendowy',
    'mint': 'Miętowy',
    'peach': 'Brzoskwiniowy',
    'sand': 'Piaskowy',
  };

  static Color background(BuildContext context, String? key) {
    final scheme = Theme.of(context).colorScheme;
    if (key == null || key == 'neutral' || !colorKeys.contains(key)) {
      return scheme.surfaceContainerLow;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch ((key, dark)) {
      ('blue', true) => const Color(0xFF263B66),
      ('lavender', true) => const Color(0xFF45355E),
      ('mint', true) => const Color(0xFF245342),
      ('peach', true) => const Color(0xFF69473A),
      ('sand', true) => const Color(0xFF62562E),
      ('blue', false) => const Color(0xFFE5EEFF),
      ('lavender', false) => const Color(0xFFF0E8FF),
      ('mint', false) => const Color(0xFFDFF5EA),
      ('peach', false) => const Color(0xFFFFEBE1),
      ('sand', false) => const Color(0xFFF5EEDC),
      _ => scheme.surfaceContainerLow,
    };
  }

  static Color foreground(BuildContext context, String? key) {
    final scheme = Theme.of(context).colorScheme;
    if (key == null || key == 'neutral' || !colorKeys.contains(key)) {
      return scheme.onSurface;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) return const Color(0xFFF4F5FA);
    return switch (key) {
      'blue' => const Color(0xFF233657),
      'lavender' => const Color(0xFF3B2B55),
      'mint' => const Color(0xFF1F4537),
      'peach' => const Color(0xFF56392D),
      'sand' => const Color(0xFF493F25),
      _ => scheme.onSurface,
    };
  }

  static Color swatch(BuildContext context, String key) =>
      background(context, key);
}
