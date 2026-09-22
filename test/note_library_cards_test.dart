import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/note_library_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child) => MaterialApp(
  home: Scaffold(body: SafeArea(child: child)),
);

void main() {
  testWidgets(
    'neutral note still uses a pastel card and checklist items are visible',
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
        app(
          NoteLibraryCard(
            note: note,
            visualIndex: 0,
            onOpen: () {},
            onMore: () {},
          ),
        ),
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
      expect(
        (card.decoration as BoxDecoration).color,
        isNot(const Color(0xff0e1116)),
      );
    },
  );

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
        onMore: (_, __) {},
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
}
