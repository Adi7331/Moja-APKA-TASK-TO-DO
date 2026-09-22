import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/remaster_notes_screen.dart';
import 'package:dzien_po_dniu/remaster_tasks_screen.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: buildRemasterTheme(Brightness.dark),
    home: Scaffold(body: child),
  );

  RemasterNotesScreen notesApp({
    String greetingName = 'Adrian',
    List<NoteItem> notes = const [],
    List<NoteFolder> folders = const [],
    NewRemasterNote? onNewNote,
    ValueChanged<NoteItem>? onOpenNote,
    Future<void> Function(NoteItem)? onSave,
    Future<void> Function(NoteItem)? onDelete,
  }) => RemasterNotesScreen(
    greetingName: greetingName,
    notes: notes,
    folders: folders,
    onNewNote: onNewNote ?? ({folderId}) {},
    onOpenNote: onOpenNote ?? (_) {},
    onSave: onSave ?? (_) async {},
    onDelete: onDelete ?? (_) async {},
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

  testWidgets(
    'phone library has greeting, one filter strip and cards without legacy sections',
    (tester) async {
      await tester.pumpWidget(
        app(
          notesApp(
            notes: [NoteItem(id: 'plan', title: 'Plan na tydzień')],
            folders: [NoteFolder(id: 'work', name: 'Praca')],
          ),
        ),
      );

      expect(find.text('Dzień dobry, Adrian!'), findsOneWidget);
      expect(find.byKey(const ValueKey('notes-filter-strip')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('note-library-card-plan')),
        findsOneWidget,
      );
      expect(find.text('Przypomnienia'), findsNothing);
      expect(find.text('Archiwum'), findsNothing);
      expect(find.text('Kosz'), findsNothing);
    },
  );

  testWidgets('more menu exposes reminders archive and trash', (tester) async {
    await tester.pumpWidget(app(notesApp()));

    await tester.tap(find.byTooltip('Więcej widoków notatek'));
    await tester.pumpAndSettle();

    expect(find.text('Przypomnienia'), findsOneWidget);
    expect(find.text('Archiwum'), findsOneWidget);
    expect(find.text('Kosz'), findsOneWidget);
  });

  testWidgets('new note inherits the active folder from the one filter strip', (
    tester,
  ) async {
    String? createdInFolder;
    await tester.pumpWidget(
      app(
        notesApp(
          folders: [NoteFolder(id: 'work', name: 'Praca')],
          onNewNote: ({folderId}) => createdInFolder = folderId,
        ),
      ),
    );

    await tester.tap(find.text('Praca'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('notes-new-note')));

    expect(createdInFolder, 'work');
  });

  testWidgets('card actions archive without opening the note', (tester) async {
    NoteItem? saved;
    await tester.pumpWidget(
      app(
        notesApp(
          notes: [NoteItem(id: 'archive-me', title: 'Rachunki')],
          onSave: (note) async => saved = note,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Opcje notatki'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archiwizuj'));
    await tester.pump();

    expect(saved?.isArchived, isTrue);
  });

  testWidgets('sync error stays visible with the local card', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      app(
        RemasterNotesScreen(
          notes: [NoteItem(id: 'offline', title: 'Lokalna notatka')],
          syncStatus: 'Błąd synchronizacji',
          onRetrySync: () async => retried = true,
          onNewNote: ({folderId}) {},
          onOpenNote: (_) {},
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('notes-sync-status')), findsOneWidget);
    expect(find.text('Lokalna notatka'), findsOneWidget);
    await tester.tap(find.byTooltip('Ponów synchronizację notatek'));
    expect(retried, isTrue);
  });

  testWidgets('phone library survives 200 percent text without an exception', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: notesApp(
            notes: [NoteItem(id: 'plan', title: 'Plan na tydzień')],
            folders: [
              NoteFolder(id: 'work', name: 'Bardzo długi folder Praca'),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop shows folders and keeps selection after opening editor',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          RemasterNotesScreen(
            notes: [
              NoteItem(id: 'work-note', title: 'Oferta', folderId: 'work'),
            ],
            folders: [NoteFolder(id: 'work', name: 'Praca')],
            editorBuilder: (note, onClose) => Text('Edytor: ${note.title}'),
            onNewNote: ({folderId}) {},
            onOpenNote: (_) {},
            onSave: (_) async {},
            onDelete: (_) async {},
          ),
        ),
      );

      await tester.tap(find.text('Praca').last);
      await tester.tap(
        find.byKey(const ValueKey('note-library-card-work-note')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('notes-desktop-sidebar')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('notes-detail-panel')), findsOneWidget);
      expect(find.text('Edytor: Oferta'), findsOneWidget);
      expect(find.text('Praca').last, findsOneWidget);
    },
  );
}
