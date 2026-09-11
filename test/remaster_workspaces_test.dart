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
}
