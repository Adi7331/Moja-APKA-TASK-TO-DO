import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/remaster_notes_screen.dart';
import 'package:dzien_po_dniu/remaster_tasks_screen.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: buildRemasterTheme(Brightness.light),
    home: Scaffold(body: child),
  );

  testWidgets('task row exposes the status actions without a menu', (
    tester,
  ) async {
    String? selectedStatus;
    await tester.pumpWidget(
      app(
        RemasterTasksScreen(
          tasks: const [
            TaskItem(id: 'task-1', title: 'Dopracować widok', status: 'todo'),
          ],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          onOpenTask: (_) {},
          onStatusSelected: (_, status) => selectedStatus = status,
          onDeleteTask: (_) {},
          onPostponeTask: (_) {},
          onQuickAdd: () {},
          onOpenWeek: () {},
          onOpenWeeklyReview: () {},
        ),
      ),
    );

    final action = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.timelapse_rounded),
        matching: find.byType(IconButton),
      ),
    );
    action.onPressed!.call();
    expect(selectedStatus, 'doing');
  });

  testWidgets('notes composer starts another new note immediately', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: const [],
          onNewNote: ({String? folderId}) => created++,
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Utwórz notatkę'));
    expect(created, 1);
    expect(find.text('Nie masz jeszcze notatek'), findsOneWidget);
  });

  testWidgets('a phone tap opens a note directly', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 844,
          child: Scaffold(
            body: RemasterNotesScreen(
              notes: [NoteItem(id: 'note-1', title: 'Szybka notatka')],
              onNewNote: ({String? folderId}) {},
              onOpenNote: (_) => opened++,
              onSave: (_) async {},
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Szybka notatka'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('notes show a compact checklist summary on a card', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(
              id: 'note-1',
              title: 'Zakupy',
              blocks: [
                NoteBlock.checklist(
                  id: 'block-1',
                  items: const [
                    NoteChecklistItem(id: 'item-1', text: 'Mleko'),
                    NoteChecklistItem(
                      id: 'item-2',
                      text: 'Chleb',
                      isDone: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.text('1 z 2 ukończone'), findsOneWidget);
  });

  testWidgets('a note card exposes a preview for its image attachment', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(
              id: 'note-1',
              title: 'Plan podróży',
              attachments: [
                NoteAttachment(
                  id: 'image-1',
                  fileName: 'mapa.png',
                  mimeType: 'image/png',
                  byteSize: 1024,
                  localPath: 'C:/brakujacy-plik/mapa.png',
                ),
              ],
            ),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Podgląd zdjęcia: mapa.png'), findsOneWidget);
  });

  testWidgets('a note card identifies an attached document', (tester) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(
              id: 'note-1',
              title: 'Formalności',
              attachments: [
                NoteAttachment(
                  id: 'document-1',
                  fileName: 'budżet.pdf',
                  mimeType: 'application/pdf',
                  byteSize: 2048,
                ),
              ],
            ),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.text('budżet.pdf'), findsOneWidget);
    expect(find.text('PDF · 2 KB'), findsOneWidget);
  });

  testWidgets('new note keeps the selected folder', (tester) async {
    String? createdInFolder;
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: const [],
          folders: [NoteFolder(id: 'work', name: 'Praca')],
          onNewNote: ({String? folderId}) => createdInFolder = folderId,
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Praca'));
    await tester.pump();
    await tester.tap(find.byTooltip('Utwórz notatkę'));

    expect(createdInFolder, 'work');
  });

  testWidgets('a note card identifies its folder without opening the note', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(id: 'note-1', title: 'Wymiana opon', folderId: 'car'),
          ],
          folders: [NoteFolder(id: 'car', name: 'Samochód')],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    // One label is the folder filter; the other is the context marker on the
    // card itself, visible before opening the note.
    expect(find.text('Samochód'), findsNWidgets(2));
  });

  testWidgets('a note label filter limits the visible note cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(
              id: 'work',
              title: 'Dopiąć ofertę',
              labels: const ['Praca'],
            ),
            NoteItem(id: 'home', title: 'Kupić kawę', labels: const ['Dom']),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Praca'));
    await tester.pump();

    expect(find.text('Dopiąć ofertę'), findsOneWidget);
    expect(find.text('Kupić kawę'), findsNothing);
  });

  testWidgets('a note card archives a note without opening its editor', (
    tester,
  ) async {
    NoteItem? saved;
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [NoteItem(id: 'note-1', title: 'Rachunki')],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (note) async => saved = note,
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Archiwizuj notatkę'));
    await tester.pump();

    expect(saved?.isArchived, isTrue);
  });

  testWidgets('a trashed note can be restored directly from the trash view', (
    tester,
  ) async {
    NoteItem? saved;
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(
              id: 'note-1',
              title: 'Rachunki',
              deletedAt: DateTime(2026, 9, 11),
            ),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (note) async => saved = note,
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Kosz'));
    await tester.pump();
    await tester.tap(find.byTooltip('Przywróć notatkę z kosza'));
    await tester.pump();

    expect(saved?.isDeleted, isFalse);
  });

  testWidgets('a trashed note requires confirmation before permanent deletion', (
    tester,
  ) async {
    var permanentlyDeleted = false;
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(
              id: 'note-1',
              title: 'Rachunki',
              deletedAt: DateTime(2026, 9, 11),
            ),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
          onPermanentlyDelete: (_) async => permanentlyDeleted = true,
        ),
      ),
    );

    await tester.tap(find.text('Kosz'));
    await tester.pump();
    await tester.tap(find.byTooltip('Usuń notatkę trwale'));
    await tester.pumpAndSettle();
    expect(find.text('Usunąć notatkę trwale?'), findsOneWidget);

    await tester.tap(find.text('Usuń trwale'));
    await tester.pumpAndSettle();

    expect(permanentlyDeleted, isTrue);
  });

  testWidgets('a note card makes its reminder visible before opening', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(
              id: 'note-1',
              title: 'Rachunki',
              reminderAt: DateTime(2026, 9, 12, 10, 30),
            ),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.textContaining('Przypomnienie'), findsOneWidget);
  });

  testWidgets('pinned notes and remaining notes have separate sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(id: 'pinned', title: 'Najważniejsza', pinned: true),
            NoteItem(id: 'regular', title: 'Na później'),
          ],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.text('PRZYPIĘTE'), findsOneWidget);
    expect(find.text('POZOSTAŁE'), findsOneWidget);
  });

  testWidgets('note section filters stay within a 390 pixel phone viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          key: const ValueKey('phone-viewport'),
          width: 390,
          height: 844,
          child: Scaffold(
            body: RemasterNotesScreen(
              notes: const <NoteItem>[],
              onNewNote: ({String? folderId}) {},
              onOpenNote: (_) {},
              onSave: (_) async {},
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );

    final viewport = tester.getRect(
      find.byKey(const ValueKey('phone-viewport')),
    );
    for (final label in ['Notatki', 'Przypomnienia', 'Archiwum', 'Kosz']) {
      expect(
        tester.getRect(find.text(label).last).right,
        lessThanOrEqualTo(viewport.right),
      );
    }
  });

  testWidgets('note section filters wrap at 200 percent phone text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: SizedBox(
          key: const ValueKey('large-text-phone-viewport'),
          width: 390,
          height: 844,
          child: Scaffold(
            body: RemasterNotesScreen(
              notes: const <NoteItem>[],
              onNewNote: ({String? folderId}) {},
              onOpenNote: (_) {},
              onSave: (_) async {},
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );

    final viewport = tester.getRect(
      find.byKey(const ValueKey('large-text-phone-viewport')),
    );
    for (final label in ['Notatki', 'Przypomnienia', 'Archiwum', 'Kosz']) {
      expect(
        tester.getRect(find.text(label).last).right,
        lessThanOrEqualTo(viewport.right),
      );
    }
  });

  testWidgets('note search also finds notes by their folder name', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [
            NoteItem(id: 'note-1', title: 'Wymiana opon', folderId: 'car'),
          ],
          folders: [NoteFolder(id: 'car', name: 'Samochód')],
          onNewNote: ({String? folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'samochód');
    await tester.pump();

    expect(find.text('Wymiana opon'), findsOneWidget);
  });
}
