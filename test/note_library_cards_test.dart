import 'dart:math' as math;

import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/note_library_cards.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget app(Widget child) => MaterialApp(
  home: Scaffold(body: SafeArea(child: child)),
);

void main() {
  setUpAll(() => initializeDateFormatting('pl_PL'));

  testWidgets(
    'neutral note uses a raised theme surface and checklist items are visible',
    (tester) async {
      final note = NoteItem(
        id: 'shopping',
        title: 'Zakupy',
        blocks: const [
          NoteBlock.checklist(
            id: 'list',
            items: [
              NoteChecklistItem(id: 'milk', text: 'Mleko'),
              NoteChecklistItem(id: 'bread', text: 'Chleb'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        app(NoteLibraryCard(note: note, onOpen: () {}, onMore: () {})),
      );

      expect(
        find.byKey(const ValueKey('note-library-card-shopping')),
        findsOneWidget,
      );
      expect(find.text('Mleko'), findsOneWidget);
      expect(find.text('Chleb'), findsOneWidget);
      final card = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('note-library-card-surface-shopping')),
      );
      final scheme = Theme.of(
        tester.element(
          find.byKey(const ValueKey('note-library-card-shopping')),
        ),
      ).colorScheme;
      expect(
        (card.decoration as BoxDecoration).color,
        scheme.surfaceContainerHigh,
      );
    },
  );

  test(
    'selected note colors are stable and readable against their surfaces',
    () {
      final scheme = ColorScheme.dark();
      const selected = [
        NoteColorKey.blue,
        NoteColorKey.lavender,
        NoteColorKey.mint,
        NoteColorKey.sand,
        NoteColorKey.peach,
      ];
      final pastelInk = noteLibraryCardInk;
      final pastelMuted = noteLibraryCardMutedInk;

      for (final colorKey in selected) {
        final note = NoteItem(id: colorKey.name, colorKey: colorKey);
        final surface = noteLibraryCardColor(note, scheme);
        expect(noteLibraryCardColor(note, scheme), surface);
        expect(_contrast(surface, pastelInk), greaterThanOrEqualTo(4.5));
        expect(_contrast(surface, pastelMuted), greaterThanOrEqualTo(4.5));
      }
      final neutral = NoteItem(id: 'neutral');
      expect(
        noteLibraryCardColor(neutral, scheme),
        scheme.surfaceContainerHigh,
      );
      expect(
        _contrast(scheme.surfaceContainerHigh, scheme.onSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.surfaceContainerHigh, scheme.onSurfaceVariant),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets('neutral card uses semantic foreground colors in dark mode', (
    tester,
  ) async {
    final theme = buildRemasterTheme(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: NoteLibraryCard(
            note: NoteItem(
              id: 'dark-neutral',
              title: 'Wieczorny plan',
              blocks: const [NoteBlock.text(id: 'body', text: 'Czytelny opis')],
            ),
            onOpen: () {},
            onMore: () {},
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Wieczorny plan'));
    final preview = tester.widget<Text>(find.text('Czytelny opis'));
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('note-library-card-surface-dark-neutral')),
    );

    expect(title.style?.color, theme.colorScheme.onSurface);
    expect(preview.style?.color, theme.colorScheme.onSurfaceVariant);
    expect((surface.decoration as BoxDecoration).border, isNotNull);
  });

  test('updated timestamp includes local Polish date and time', () {
    expect(
      formatNoteUpdatedAt(DateTime(2026, 9, 22, 14, 35)),
      '22.09.2026 · 14:35',
    );
  });

  testWidgets(
    'grid uses two columns on a phone and one with 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final grid = NoteMasonryGrid(
        notes: [
          NoteItem(id: 'one'),
          NoteItem(id: 'two'),
        ],
        folders: const [],
        onOpen: (_) {},
        onMore: (_, _) {},
      );

      await tester.pumpWidget(app(grid));
      expect(
        find.byKey(const ValueKey('note-library-column-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-library-column-1')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: grid,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('note-library-column-1')), findsNothing);
    },
  );

  testWidgets(
    'grid keeps stable reading order across columns despite card height',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final grid = NoteMasonryGrid(
        notes: [
          NoteItem(
            id: 'first',
            blocks: [
              NoteBlock.checklist(
                id: 'checklist',
                items: List.generate(
                  4,
                  (index) =>
                      NoteChecklistItem(id: '$index', text: 'Krok $index'),
                ),
              ),
            ],
          ),
          NoteItem(id: 'second'),
          NoteItem(id: 'third'),
          NoteItem(id: 'fourth'),
        ],
        folders: const [],
        onOpen: (_) {},
        onMore: (_, _) {},
      );

      await tester.pumpWidget(app(grid));
      for (final id in ['first', 'third']) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('note-library-column-0')),
            matching: find.byKey(ValueKey('note-library-card-$id')),
          ),
          findsOneWidget,
        );
      }
      for (final id in ['second', 'fourth']) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('note-library-column-1')),
            matching: find.byKey(ValueKey('note-library-card-$id')),
          ),
          findsOneWidget,
        );
      }
    },
  );
}

double _contrast(Color a, Color b) {
  final lighter = math.max(a.computeLuminance(), b.computeLuminance());
  final darker = math.min(a.computeLuminance(), b.computeLuminance());
  return (lighter + .05) / (darker + .05);
}
