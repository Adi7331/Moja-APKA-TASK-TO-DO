import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_task_store.dart';
import 'local_note_store.dart';
import 'cloud_migration.dart';
import 'task_sync_service.dart';
import 'notification_service.dart';
import 'task_item.dart';
import 'task_occurrence.dart';
import 'task_view.dart';
import 'google_sign_in_action.dart';
import 'app_theme.dart';
import 'remaster_theme.dart';
import 'remaster_login_page.dart';
import 'remaster_focus_mode_screen.dart';
import 'remaster_shell.dart';
import 'remaster_notes_screen.dart';
import 'remaster_tasks_screen.dart';
import 'remaster_weekly_calendar.dart';
import 'remaster_weekly_review.dart';
import 'note_editor_screen.dart';
import 'task_editor.dart';
import 'task_postpone_sheet.dart';
import 'task_schedule.dart';
import 'quick_task_parser.dart';
import 'focus_mode_screen.dart';
import 'today_screen.dart';
import 'weekly_calendar.dart';
import 'weekly_review.dart';
import 'weekly_review_screen.dart';
import 'note_item.dart';
import 'note_folder.dart';
import 'note_attachment_picker.dart';
import 'notes_screen.dart';
import 'note_sync_service.dart';

typedef WeekDayTaskMovePlan = ({TaskItem updatedTask, DateTime? reminderTime});

WeekDayTaskMovePlan planTaskMoveToWeekDay(TaskItem task, DateTime day) {
  final reminderFollowsDueAt =
      task.reminderAt == null || task.reminderAt == task.dueAt;
  var updatedTask = moveTaskToDay(task, day);
  if (task.reminderAt != null && reminderFollowsDueAt) {
    updatedTask = updatedTask.copyWith(reminderAt: updatedTask.dueAt);
  }
  return (
    updatedTask: updatedTask,
    reminderTime: reminderFollowsDueAt
        ? updatedTask.reminderAt ?? updatedTask.dueAt
        : null,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool localMode = false;
  bool cloudMode = false;
  bool _notesCloudAvailable = false;
  bool _foldersCloudAvailable = false;
  bool _notesMode = false;
  bool _remasterPreview = true;
  String _syncStatus = 'Lokalnie';
  late Future<void> _localRestoreFuture;
  late Future<void> _localNotesRestoreFuture;
  bool _cloudTransitionInProgress = false;
  String _searchQuery = '';
  String _statusFilter = 'all';
  TaskView _selectedView = TaskView.today;
  ThemeMode _themeMode = ThemeMode.system;
  String? _successNotice;
  final _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _noticeTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _taskSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _subtaskSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _noteSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _folderSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  var _nextLocalTaskId = 4;
  LocalTaskStore? _localStore;
  LocalNoteStore? _localNoteStore;
  final tasks = <TaskItem>[
    const TaskItem(
      id: 'local-1',
      title: 'Wykosić trawnik',
      status: 'todo',
      category: 'Dom',
    ),
    const TaskItem(
      id: 'local-2',
      title: 'Poprawić grafikę',
      status: 'todo',
      category: 'Praca',
    ),
    const TaskItem(
      id: 'local-3',
      title: 'Kreacje do reklamy',
      status: 'todo',
      category: 'Praca',
    ),
  ];
  final notes = <NoteItem>[];
  final folders = <NoteFolder>[];
  late final TaskSyncService _sync = TaskSyncService(Supabase.instance.client);
  late final NoteSyncService _noteSync = NoteSyncService(
    Supabase.instance.client,
  );

  @override
  void initState() {
    super.initState();
    _localRestoreFuture = _restoreLocalTasks();
    _localNotesRestoreFuture = _restoreLocalNotes();
    _restoreCloudSession();
  }

  void _restoreCloudSession() {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession != null) {
        _enterCloudMode();
      }
      _authSubscription = auth.onAuthStateChange.listen((state) {
        if (state.session != null && !cloudMode) {
          _enterCloudMode();
        }
      });
    } on AssertionError {
      // Widget tests intentionally construct MyApp without Supabase.initialize.
    }
  }

  Future<void> _restoreLocalTasks() async {
    final preferences = await SharedPreferences.getInstance();
    final store = LocalTaskStore(preferences);
    final storedTasks = await store.load();
    if (!mounted) return;
    setState(() {
      _localStore = store;
      _themeMode = _themeModeFromStorage(preferences.getString('theme_mode'));
      _remasterPreview = true;
      if (storedTasks.isNotEmpty) {
        tasks
          ..clear()
          ..addAll(storedTasks);
        _nextLocalTaskId = tasks.length + 1;
      }
    });
  }

  Future<void> _restoreLocalNotes() async {
    final store = LocalNoteStore();
    final restored = await Future.wait([store.load(), store.loadFolders()]);
    final storedNotes = restored[0] as List<NoteItem>;
    final storedFolders = restored[1] as List<NoteFolder>;
    if (!mounted) return;
    setState(() {
      _localNoteStore = store;
      notes
        ..clear()
        ..addAll(storedNotes);
      folders
        ..clear()
        ..addAll(storedFolders);
    });
  }

  Future<void> _saveLocalTasks() async {
    if (!cloudMode) await _localStore?.save(tasks);
  }

  Future<void> _saveLocalNotes() async {
    if (!cloudMode) await _localNoteStore?.save(notes);
  }

  Future<void> _saveLocalFolders() async {
    // Folder schema deployment is deliberately opt-in. Until it is applied in
    // Supabase, local folders stay available without risking existing notes.
    await _localNoteStore?.saveFolders(folders);
  }

  Future<void> _createFolder(String name, NoteColorKey colorKey) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final folder = NoteFolder(
      id: newNoteId(),
      name: trimmed,
      colorKey: colorKey,
    );
    if (cloudMode && _foldersCloudAvailable) {
      await _noteSync.saveFolder(folder);
      await _loadCloudFolders();
      return;
    }
    setState(() => folders.add(folder));
    await _saveLocalFolders();
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    if (cloudMode && _foldersCloudAvailable) {
      await _noteSync.deleteFolder(folder);
      await _loadCloudFolders();
      await _loadCloudNotes();
      return;
    }
    setState(() {
      folders.removeWhere((item) => item.id == folder.id);
      for (var index = 0; index < notes.length; index++) {
        if (notes[index].folderId == folder.id) {
          notes[index] = notes[index].copyWith(
            folderId: null,
            updatedAt: DateTime.now(),
          );
        }
      }
    });
    await _saveLocalFolders();
    await _saveLocalNotes();
  }

  Future<void> _renameFolder(NoteFolder folder) async {
    final updated = folder.copyWith(updatedAt: DateTime.now());
    if (cloudMode && _foldersCloudAvailable) {
      await _noteSync.saveFolder(updated);
      await _loadCloudFolders();
      return;
    }
    setState(() {
      final index = folders.indexWhere((item) => item.id == folder.id);
      if (index != -1) folders[index] = updated;
    });
    await _saveLocalFolders();
  }

  Future<void> _moveNoteToFolder(NoteItem note, String? folderId) async {
    final updated = note.copyWith(
      folderId: folderId,
      updatedAt: DateTime.now(),
    );
    if (cloudMode && !_foldersCloudAvailable) {
      // The present production schema may not have folder_id yet. Store the
      // local association without changing the proven cloud notes payload.
      setState(() {
        final index = notes.indexWhere((item) => item.id == note.id);
        if (index != -1) notes[index] = updated;
      });
      await _localNoteStore?.save(notes);
      return;
    }
    await _saveNote(updated);
  }

  Future<void> _changeThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('theme_mode', mode.name);
  }

  Future<void> _loadCloudTasks() async {
    final rows = await _sync.loadTasks();
    final cloudTasks = await Future.wait(
      rows.map((row) async {
        final subtasks = await _sync.loadSubtasks(row['id'] as String);
        return TaskItem.fromRow({...row, 'subtasks': subtasks});
      }),
    );
    if (!mounted) return;
    setState(() {
      tasks
        ..clear()
        ..addAll(cloudTasks);
    });
  }

  Future<void> _enterCloudMode() async {
    if (_cloudTransitionInProgress || cloudMode) return;
    _cloudTransitionInProgress = true;
    if (mounted) {
      setState(() {
        localMode = true;
        _syncStatus = 'Synchronizowanie…';
      });
    }
    try {
      await _localRestoreFuture;
      await _localNotesRestoreFuture;
      final localTasks = await _localStore?.load() ?? const <TaskItem>[];
      final cloudRows = await _sync.loadTasks();
      final store = _localStore;
      final decision = decideLocalTaskMigration(
        localTaskCount: localTasks.length,
        cloudTaskCount: cloudRows.length,
        migrationCompleted: store?.cloudMigrationCompleted ?? false,
      );
      if (decision.shouldImport) {
        await _sync.importLocalTasks(localTasks);
        await store?.markCloudMigrationCompleted();
      }
      await _loadCloudTasks();
      try {
        final localNotes = await _localNoteStore?.load() ?? const <NoteItem>[];
        final cloudNotes = await _noteSync.loadNotes();
        final noteMigrationCompleted =
            await _localNoteStore?.cloudMigrationCompleted ?? false;
        if (localNotes.isNotEmpty &&
            cloudNotes.isEmpty &&
            !noteMigrationCompleted) {
          await _noteSync.importLocalNotes(localNotes);
          await _localNoteStore?.markCloudMigrationCompleted();
        }
        await _loadCloudNotes();
        _notesCloudAvailable = true;
      } catch (_) {
        // The task workspace remains usable while the optional notes SQL is deployed.
        _notesCloudAvailable = false;
      }
      if (_notesCloudAvailable) {
        try {
          final localFolders =
              await _localNoteStore?.loadFolders() ?? const <NoteFolder>[];
          final cloudFolders = await _noteSync.loadFolders();
          if (localFolders.isNotEmpty && cloudFolders.isEmpty) {
            await _noteSync.importLocalFolders(localFolders);
          }
          await _loadCloudFolders();
          _foldersCloudAvailable = true;
        } catch (_) {
          // Folder SQL is a separate, backwards-compatible migration. Notes
          // continue syncing normally until the user enables it.
          _foldersCloudAvailable = false;
        }
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('Brak aktywnej sesji.');
      await _taskSubscription?.cancel();
      _taskSubscription = Supabase.instance.client
          .from('tasks')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .listen((_) => unawaited(_refreshCloudTasks()));
      await _subtaskSubscription?.cancel();
      _subtaskSubscription = Supabase.instance.client
          .from('subtasks')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .listen((_) => unawaited(_refreshCloudTasks()));
      if (_notesCloudAvailable) {
        await _noteSubscription?.cancel();
        _noteSubscription = Supabase.instance.client
            .from('notes')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .listen((_) => unawaited(_refreshCloudNotes()));
      }
      if (_foldersCloudAvailable) {
        await _folderSubscription?.cancel();
        _folderSubscription = Supabase.instance.client
            .from('note_folders')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .listen((_) => unawaited(_loadCloudFolders()));
      }
      if (!mounted) return;
      setState(() {
        cloudMode = true;
        _syncStatus = 'Zsynchronizowano';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        cloudMode = false;
        _syncStatus = 'Błąd synchronizacji';
      });
    } finally {
      _cloudTransitionInProgress = false;
    }
  }

  Future<void> _refreshCloudTasks() async {
    try {
      await _loadCloudTasks();
      if (mounted) setState(() => _syncStatus = 'Zsynchronizowano');
    } catch (_) {
      if (mounted) setState(() => _syncStatus = 'Błąd synchronizacji');
    }
  }

  Future<void> _loadCloudNotes() async {
    final loaded = await _noteSync.loadNotes(includeTrash: true);
    if (!mounted) return;
    setState(() {
      notes
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _loadCloudFolders() async {
    final loaded = await _noteSync.loadFolders();
    if (!mounted) return;
    setState(() {
      folders
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _refreshCloudNotes() async {
    try {
      await _loadCloudNotes();
      if (mounted) setState(() => _syncStatus = 'Zsynchronizowano');
    } catch (_) {
      if (mounted) setState(() => _syncStatus = 'Błąd synchronizacji');
    }
  }

  Future<void> _saveNote(NoteItem note) async {
    if (cloudMode && _notesCloudAvailable) {
      try {
        final isNew = !notes.any((item) => item.id == note.id);
        await _noteSync.saveNote(
          note,
          expectedRevision: isNew ? null : note.revision - 1,
          includeFolderId: _foldersCloudAvailable,
        );
      } on NoteConflictException {
        final conflict = await _noteSync.createConflictCopy(note);
        if (mounted) {
          setState(() {
            notes.removeWhere((item) => item.id == note.id);
            notes.add(conflict);
          });
        }
        return;
      }
      await _loadCloudNotes();
      await _scheduleNoteReminder(note);
      return;
    }
    if (mounted) {
      setState(() {
        final index = notes.indexWhere((item) => item.id == note.id);
        if (index == -1) {
          notes.insert(0, note);
        } else {
          notes[index] = note;
        }
      });
    }
    await _saveLocalNotes();
    await _scheduleNoteReminder(note);
  }

  Future<NoteAttachment> _attachNoteFile(
    NoteItem note,
    NoteAttachmentCandidate candidate,
  ) async {
    final attachment = NoteAttachment(
      id: newNoteId(),
      fileName: candidate.fileName,
      mimeType: candidate.mimeType,
      byteSize: candidate.byteSize,
    );
    if (cloudMode && _notesCloudAvailable) {
      // Storage metadata references the note row, so create a just-started
      // note before uploading its first attachment.
      if (!notes.any((item) => item.id == note.id)) {
        await _noteSync.saveNote(
          note,
          expectedRevision: null,
          includeFolderId: _foldersCloudAvailable,
        );
      }
      return _noteSync.uploadAttachment(
        attachment: attachment,
        noteId: note.id,
        file: candidate.file,
      );
    }
    final store = _localNoteStore;
    if (store == null) {
      return NoteAttachment(
        id: attachment.id,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        byteSize: attachment.byteSize,
        localPath: candidate.file.path,
      );
    }
    return store.copyAttachment(
      noteId: note.id,
      attachmentId: attachment.id,
      source: candidate.file,
      fileName: candidate.fileName,
      mimeType: candidate.mimeType,
    );
  }

  Future<String?> _openNoteAttachment(NoteAttachment attachment) async {
    if (!cloudMode || !_notesCloudAvailable) return null;
    return _noteSync.createAttachmentUrl(attachment);
  }

  Future<void> _deleteNoteAttachment(NoteAttachment attachment) async {
    if (cloudMode && _notesCloudAvailable) {
      await _noteSync.deleteAttachment(attachment);
      return;
    }
    await _localNoteStore?.deleteAttachment(attachment);
  }

  Future<void> _scheduleNoteReminder(NoteItem note) async {
    await NotificationService.instance.cancelNote(note.id);
    final reminder = note.reminderAt;
    if (reminder != null) {
      await NotificationService.instance.scheduleNoteReminder(
        noteId: note.id,
        title: note.title.isEmpty ? 'Notatka' : note.title,
        when: reminder,
      );
    }
  }

  Future<void> _deleteNote(NoteItem note) async {
    final trashed = note.copyWith(
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _saveNote(trashed);
  }

  Future<void> _permanentlyDeleteNote(NoteItem note) async {
    if (cloudMode && _notesCloudAvailable) {
      await _noteSync.permanentlyDeleteNote(note);
      await _loadCloudNotes();
      return;
    }
    setState(() => notes.removeWhere((item) => item.id == note.id));
    await _saveLocalNotes();
  }

  Future<void> _showTaskForm(BuildContext context, {TaskItem? task}) async {
    final modalContext = _navigatorKey.currentContext;
    if (modalContext == null) return;
    var saved = false;
    await showTaskEditor(
      modalContext,
      task: task,
      remastered: _remasterPreview,
      onSave: (draft) async {
        late final String taskId;
        if (task != null) {
          taskId = task.id;
          if (cloudMode) {
            await _sync.updateTask(
              taskId,
              title: draft.title,
              note: draft.note,
              category: draft.category,
              priority: draft.priority,
              dueAt: draft.dueAt,
            );
            final originalSteps = {
              for (final item in task.subtasks) item.id: item,
            };
            final editedSteps = {
              for (final item in draft.subtasks) item.id: item,
            };
            for (final removed in originalSteps.keys.where(
              (id) => !editedSteps.containsKey(id),
            )) {
              await _sync.deleteSubtask(removed);
            }
            for (final step in draft.subtasks) {
              final original = originalSteps[step.id];
              if (original == null) {
                await _sync.addSubtask(taskId, step.title, step.position);
              } else if (original.isDone != step.isDone) {
                await _sync.setSubtaskDone(step.id, step.isDone);
              }
            }
            await _loadCloudTasks();
          } else {
            setState(() {
              final index = tasks.indexOf(task);
              tasks[index] = task.copyWith(
                title: draft.title,
                note: draft.note,
                category: draft.category,
                priority: draft.priority,
                dueAt: draft.dueAt,
                reminderAt: draft.reminderAt,
                repeatRule: draft.repeatRule,
                subtasks: draft.subtasks,
              );
            });
            await _saveLocalTasks();
          }
        } else if (cloudMode) {
          final row = await _sync.addTask(
            draft.title,
            note: draft.note,
            category: draft.category,
            priority: draft.priority,
            dueAt: draft.dueAt,
          );
          taskId = row['id'] as String;
          for (final step in draft.subtasks) {
            await _sync.addSubtask(taskId, step.title, step.position);
          }
          await _loadCloudTasks();
        } else {
          taskId = 'local-${_nextLocalTaskId++}';
          setState(
            () => tasks.add(
              TaskItem(
                id: taskId,
                title: draft.title,
                status: 'todo',
                note: draft.note,
                category: draft.category,
                priority: draft.priority,
                dueAt: draft.dueAt,
                reminderAt: draft.reminderAt,
                repeatRule: draft.repeatRule,
                subtasks: draft.subtasks,
              ),
            ),
          );
          await _saveLocalTasks();
        }
        await NotificationService.instance.cancel(taskId);
        final reminderTime = draft.reminderAt ?? draft.dueAt;
        if (reminderTime != null) {
          await NotificationService.instance.scheduleTaskReminder(
            taskId: taskId,
            title: draft.title,
            when: reminderTime,
          );
        }
        saved = true;
      },
    );
    if (saved) _showSuccessNotice();
  }

  void _showSuccessNotice([String message = 'Zapisano zadanie']) {
    _noticeTimer?.cancel();
    setState(() => _successNotice = message);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _successNotice = null);
    });
  }

  Future<void> _signOut() async {
    await _taskSubscription?.cancel();
    await _subtaskSubscription?.cancel();
    await _noteSubscription?.cancel();
    await _folderSubscription?.cancel();
    _taskSubscription = null;
    _subtaskSubscription = null;
    _noteSubscription = null;
    _folderSubscription = null;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // The local UI still needs to leave cloud mode if the network is down.
    }
    if (!mounted) return;
    setState(() {
      localMode = false;
      cloudMode = false;
      _notesCloudAvailable = false;
      _foldersCloudAvailable = false;
      _notesMode = false;
      _syncStatus = 'Lokalnie';
    });
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    _subtaskSubscription?.cancel();
    _noteSubscription?.cancel();
    _folderSubscription?.cancel();
    _authSubscription?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  Future<void> _changeTaskStatus(TaskItem task, String status) async {
    final completedAt = status == 'done' ? DateTime.now() : null;
    final updated = task.copyWith(
      status: status,
      pinnedToday: status == 'done' ? false : task.pinnedToday,
      completedAt: completedAt,
    );
    final next = status == 'done' && task.repeatRule != null
        ? createNextOccurrence(
            task,
            completedAt!,
            'local-${_nextLocalTaskId++}',
          )
        : null;
    if (cloudMode) {
      await _sync.completeAndCreateNext(updated, next);
      await _loadCloudTasks();
    } else {
      setState(() {
        final index = tasks.indexOf(task);
        tasks[index] = updated;
        if (next != null) tasks.add(next);
      });
      await _saveLocalTasks();
    }
    if (status == 'done') await NotificationService.instance.cancel(task.id);
    if (status == 'done' && task.repeatRule == null) {
      _showUndoSnackBar(
        'Zadanie oznaczone jako gotowe',
        () => _restoreTaskState(task),
      );
    }
  }

  Future<void> _restoreTaskState(TaskItem task) async {
    if (cloudMode) {
      await _sync.updateOrganizerTask(task);
      await _loadCloudTasks();
    } else {
      final index = tasks.indexWhere((item) => item.id == task.id);
      if (index == -1) return;
      setState(() => tasks[index] = task);
      await _saveLocalTasks();
    }
    final reminderTime = task.reminderAt ?? task.dueAt;
    if (reminderTime != null) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        title: task.title,
        when: reminderTime,
      );
    }
  }

  Future<void> _postponeTask(TaskItem task) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final option = await showTaskPostponeSheet(context);
    if (option == null) return;
    final plan = planTaskPostponement(task, DateTime.now(), option);
    if (cloudMode) {
      await _sync.updateOrganizerTask(plan.updatedTask);
      await _loadCloudTasks();
    } else {
      final index = tasks.indexWhere((item) => item.id == task.id);
      if (index == -1) return;
      setState(() => tasks[index] = plan.updatedTask);
      await _saveLocalTasks();
    }
    await NotificationService.instance.cancel(task.id);
    if (plan.reminderTime != null) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        title: task.title,
        when: plan.reminderTime!,
      );
    }
    _showSuccessNotice('Zadanie odłożone');
  }

  Future<void> _quickAddTask(String rawText, {String? sourceNoteId}) async {
    final parsed = parseQuickTask(rawText, DateTime.now());
    if (parsed.title.isEmpty) {
      _showSuccessNotice('Wpisz nazwę zadania.');
      return;
    }
    late final String taskId;
    if (cloudMode) {
      final row = await _sync.addTask(
        parsed.title,
        dueAt: parsed.dueAt,
        sourceNoteId: sourceNoteId,
      );
      taskId = row['id'] as String;
      await _loadCloudTasks();
    } else {
      taskId = 'local-${_nextLocalTaskId++}';
      setState(
        () => tasks.add(
          TaskItem(
            id: taskId,
            title: parsed.title,
            status: 'todo',
            dueAt: parsed.dueAt,
            sourceNoteId: sourceNoteId,
          ),
        ),
      );
      await _saveLocalTasks();
    }
    if (parsed.dueAt != null) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: taskId,
        title: parsed.title,
        when: parsed.dueAt!,
      );
    }
    _showSuccessNotice();
  }

  void _openFocusTask(TaskItem task) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (routeContext) => _remasterPreview
            ? RemasterFocusModeScreen(
                task: task,
                onComplete: () async {
                  await _changeTaskStatus(task, 'done');
                  if (routeContext.mounted) Navigator.of(routeContext).pop();
                },
                onPostpone: () => _postponeTask(task),
              )
            : FocusModeScreen(
                task: task,
                onComplete: () async {
                  await _changeTaskStatus(task, 'done');
                  if (routeContext.mounted) Navigator.of(routeContext).pop();
                },
                onPostpone: () => _postponeTask(task),
              ),
      ),
    );
  }

  Future<void> _togglePinnedToday(TaskItem task) async {
    if (!task.pinnedToday && pinnedTodayTasks(tasks).length >= 3) {
      _showSuccessNotice('Plan dnia może mieć najwyżej 3 zadania.');
      return;
    }
    final updated = task.copyWith(pinnedToday: !task.pinnedToday);
    if (cloudMode) {
      await _sync.updateOrganizerTask(updated);
      await _loadCloudTasks();
    } else {
      setState(() => tasks[tasks.indexOf(task)] = updated);
      await _saveLocalTasks();
    }
  }

  Future<void> _moveTaskToWeekDay(TaskItem task, DateTime day) async {
    final plan = planTaskMoveToWeekDay(task, day);
    final updated = plan.updatedTask;
    if (cloudMode) {
      await _sync.updateOrganizerTask(updated);
      await _loadCloudTasks();
    } else {
      setState(() {
        final index = tasks.indexWhere((item) => item.id == task.id);
        tasks[index] = updated;
      });
      await _saveLocalTasks();
    }
    if (plan.reminderTime != null) {
      await NotificationService.instance.cancel(task.id);
      await NotificationService.instance.scheduleTaskReminder(
        taskId: updated.id,
        title: updated.title,
        when: plan.reminderTime!,
      );
    }
  }

  Future<void> _confirmDeleteTask(BuildContext context, TaskItem task) async {
    final modalContext = _navigatorKey.currentContext ?? context;
    final accepted = await showDialog<bool>(
      context: modalContext,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć zadanie?'),
        content: Text('„${task.title}” zniknie z Twojej listy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final localIndex = tasks.indexOf(task);
    if (cloudMode) {
      await _sync.deleteTask(task.id);
      await _loadCloudTasks();
    } else {
      setState(() => tasks.remove(task));
      await _saveLocalTasks();
    }
    await NotificationService.instance.cancel(task.id);
    _showUndoSnackBar(
      'Zadanie usunięte',
      () => _restoreDeletedTask(task, localIndex),
    );
  }

  Future<void> _restoreDeletedTask(TaskItem task, int localIndex) async {
    if (cloudMode) {
      await _sync.restoreTask(task.id);
      await _loadCloudTasks();
    } else {
      if (tasks.any((item) => item.id == task.id)) return;
      final restoreIndex = localIndex.clamp(0, tasks.length).toInt();
      setState(() => tasks.insert(restoreIndex, task));
      await _saveLocalTasks();
    }
    final reminderTime = task.reminderAt ?? task.dueAt;
    if (reminderTime != null) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        title: task.title,
        when: reminderTime,
      );
    }
  }

  void _showUndoSnackBar(String message, Future<void> Function() onUndo) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Cofnij',
          onPressed: () => unawaited(onUndo()),
        ),
      ),
    );
  }

  List<TaskItem> _matchingTasks(
    Iterable<TaskItem> source, {
    bool applyStatusFilter = false,
  }) {
    final query = _searchQuery.trim().toLowerCase();
    return source
        .where(
          (task) =>
              !applyStatusFilter ||
              _statusFilter == 'all' ||
              task.status == _statusFilter,
        )
        .where(
          (task) =>
              query.isEmpty ||
              task.title.toLowerCase().contains(query) ||
              task.note.toLowerCase().contains(query),
        )
        .toList();
  }

  List<TaskItem> get _visibleTasks => _matchingTasks(
    tasksForView(tasks, _selectedView, DateTime.now()),
    applyStatusFilter: _selectedView == TaskView.today,
  );

  List<TaskItem> get _laterTasks {
    if (_selectedView != TaskView.today) return const [];
    return _matchingTasks(
      tasksForView(tasks, TaskView.upcoming, DateTime.now()),
    );
  }

  List<TaskItem> get _todayTasks => _visibleTasks;

  Future<void> _setRemasterPreview(bool value) async {
    setState(() => _remasterPreview = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('ui_remaster_v2', value);
  }

  Future<void> _openStartNote(
    NoteItem note, {
    bool initialImagePicker = false,
    bool initialFilePicker = false,
    bool initialChecklist = false,
  }) async {
    await _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          onSave: _saveNote,
          onDelete: _deleteNote,
          onCreateTask: (note, title) =>
              _quickAddTask(title, sourceNoteId: note.id),
          onAttach: _attachNoteFile,
          onDeleteAttachment: _deleteNoteAttachment,
          onOpenAttachment: _openNoteAttachment,
          initialImagePicker: initialImagePicker,
          initialFilePicker: initialFilePicker,
          initialChecklist: initialChecklist,
          remastered: _remasterPreview,
        ),
      ),
    );
  }

  Future<void> _openNewRemasterNote({
    bool checklist = false,
    bool image = false,
    bool file = false,
    String? folderId,
  }) => _openStartNote(
    NoteItem(
      id: newNoteId(),
      title: 'Nowa notatka',
      folderId: folderId,
      blocks: [
        NoteBlock.text(id: newNoteId()),
        if (checklist) NoteBlock.checklist(id: newNoteId(), position: 1),
      ],
    ),
    initialImagePicker: image,
    initialFilePicker: file,
    initialChecklist: checklist,
  );

  String? _profileValue(String key) {
    if (!cloudMode) return null;
    return Supabase.instance.client.auth.currentUser?.userMetadata?[key]
        as String?;
  }

  Widget _notesWorkspace(BuildContext context) {
    if (_remasterPreview) {
      return RemasterNotesScreen(
        notes: notes,
        folders: folders,
        onNewNote: ({String? folderId}) =>
            _openNewRemasterNote(folderId: folderId),
        onNewChecklist: ({String? folderId}) =>
            _openNewRemasterNote(checklist: true, folderId: folderId),
        // The editor opens the system picker itself; keeping the creation
        // route identical prevents an attachment-only note from being lost.
        onNewImage: ({String? folderId}) =>
            _openNewRemasterNote(image: true, folderId: folderId),
        onNewFile: ({String? folderId}) =>
            _openNewRemasterNote(file: true, folderId: folderId),
        onOpenNote: _openStartNote,
        onSave: _saveNote,
        onDelete: _deleteNote,
        onPermanentlyDelete: _permanentlyDeleteNote,
        onMoveToFolder: _moveNoteToFolder,
        onCreateFolder: _createFolder,
        onRenameFolder: _renameFolder,
        onDeleteFolder: _deleteFolder,
      );
    }
    return NotesScreen(
      notes: notes,
      embedded: _remasterPreview,
      onOpenTasks: () => _remasterPreview
          ? RemasterShell.select(context, AppSpace.tasks)
          : setState(() => _notesMode = false),
      onSave: _saveNote,
      onDelete: _deleteNote,
      onCreateTask: (note, title) =>
          _quickAddTask(title, sourceNoteId: note.id),
      onAttach: _attachNoteFile,
      onDeleteAttachment: _deleteNoteAttachment,
      onOpenAttachment: _openNoteAttachment,
      onPermanentlyDelete: _permanentlyDeleteNote,
      syncStatus: _syncStatus,
    );
  }

  Widget _tasksWorkspace(BuildContext context) {
    if (_remasterPreview) {
      return RemasterTasksScreen(
        tasks: tasks,
        selectedView: _selectedView,
        onViewChanged: (view) => setState(() {
          _selectedView = view;
          if (view != TaskView.today) _statusFilter = 'all';
        }),
        onOpenTask: (task) => _showTaskForm(context, task: task),
        onStatusSelected: _changeTaskStatus,
        onDeleteTask: (task) => _confirmDeleteTask(context, task),
        onPostponeTask: _postponeTask,
        onQuickAdd: () => _showTaskForm(context),
        onOpenWeek: () => _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (routeContext) => RemasterWeeklyCalendarScreen(
              tasks: tasks,
              initialWeek: DateTime.now(),
              onOpenTask: (task) => _showTaskForm(routeContext, task: task),
              onMoveTask: _moveTaskToWeekDay,
              onQuickAdd: () => _showTaskForm(routeContext),
            ),
          ),
        ),
        onOpenWeeklyReview: () => _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => RemasterWeeklyReviewScreen(
              review: buildWeeklyReview(tasks, DateTime.now()),
              onOpenDailyPlan: () {
                _navigatorKey.currentState?.pop();
                setState(() => _selectedView = TaskView.today);
              },
            ),
          ),
        ),
      );
    }
    return TodayScreen(
      visibleTasks: _todayTasks,
      embedded: _remasterPreview,
      laterTasks: _laterTasks,
      selectedView: _selectedView,
      onViewChanged: (view) => setState(() {
        _selectedView = view;
        if (view != TaskView.today) _statusFilter = 'all';
      }),
      themeMode: _themeMode,
      onThemeModeChanged: _changeThemeMode,
      successNotice: _successNotice,
      syncStatus: _syncStatus,
      searchQuery: _searchQuery,
      onSearchChanged: (value) => setState(() => _searchQuery = value),
      selectedFilter: _statusFilter,
      onFilterChanged: (value) => setState(() => _statusFilter = value),
      onOpenTask: (task) => _showTaskForm(context, task: task),
      onCompleteTask: (task) => _changeTaskStatus(task, 'done'),
      onStatusSelected: (task, status) => _changeTaskStatus(task, status),
      onDeleteTask: (task) => _confirmDeleteTask(context, task),
      onPostponeTask: _postponeTask,
      onQuickAddText: _quickAddTask,
      onOpenFocus: _openFocusTask,
      onSignOut: _signOut,
      pinnedTasks: pinnedTodayTasks(tasks),
      onTogglePin: _togglePinnedToday,
      onOpenWeek: () => _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (routeContext) => WeeklyCalendarScreen(
            tasks: tasks,
            initialWeek: DateTime.now(),
            onOpenTask: (task) => _showTaskForm(routeContext, task: task),
            onMoveTask: _moveTaskToWeekDay,
            onQuickAdd: () => _showTaskForm(routeContext),
          ),
        ),
      ),
      onOpenWeeklyReview: () => _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => WeeklyReviewScreen(
            review: buildWeeklyReview(tasks, DateTime.now()),
            onOpenDailyPlan: () {
              _navigatorKey.currentState?.pop();
              setState(() => _selectedView = TaskView.today);
            },
          ),
        ),
      ),
      onQuickAdd: () => _showTaskForm(context),
      onOpenNotes: () => _remasterPreview
          ? RemasterShell.select(context, AppSpace.notes)
          : setState(() => _notesMode = true),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: _navigatorKey,
    theme: _remasterPreview
        ? buildRemasterTheme(Brightness.light)
        : buildLightTheme(),
    darkTheme: _remasterPreview
        ? buildRemasterTheme(Brightness.dark)
        : buildDarkTheme(),
    themeMode: _themeMode,
    home: Builder(
      builder: (context) {
        if (!localMode) {
          if (_remasterPreview) {
            return RemasterLoginPage(
              onLocalMode: () => setState(() => localMode = true),
              onSignedIn: _enterCloudMode,
              onGoogleSignIn: () =>
                  SupabaseGoogleSignInAction(Supabase.instance.client).start(),
            );
          }
          return LoginPage(
            onLocalMode: () => setState(() => localMode = true),
            onSignedIn: _enterCloudMode,
            onGoogleSignIn: () =>
                SupabaseGoogleSignInAction(Supabase.instance.client).start(),
          );
        }
        if (_remasterPreview) {
          return RemasterShell(
            tasks: tasks,
            notes: notes,
            tasksContent: Builder(
              builder: (context) => _tasksWorkspace(context),
            ),
            notesContent: Builder(
              builder: (context) => _notesWorkspace(context),
            ),
            onAddTask: () => _showTaskForm(context),
            onAddNote: () => _openNewRemasterNote(),
            onOpenTask: (task) => _showTaskForm(context, task: task),
            onOpenNote: _openStartNote,
            onCompleteTask: (task) =>
                _changeTaskStatus(task, task.isDone ? 'todo' : 'done'),
            onOpenFocus: _openFocusTask,
            onLegacy: () => _setRemasterPreview(false),
            themeMode: _themeMode,
            onThemeMode: _changeThemeMode,
            syncStatus: _syncStatus,
            name: _profileValue('full_name'),
            avatarUrl: _profileValue('avatar_url'),
            onSignOut: cloudMode ? _signOut : null,
          );
        }
        return Stack(
          children: [
            _notesMode ? _notesWorkspace(context) : _tasksWorkspace(context),
            Positioned(
              right: 12,
              top: 4,
              child: SafeArea(
                child: IconButton.filledTonal(
                  tooltip: 'Podgląd nowego interfejsu',
                  onPressed: () => _setRemasterPreview(true),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

ThemeMode _themeModeFromStorage(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLocalMode,
    required this.onSignedIn,
    required this.onGoogleSignIn,
  });

  final VoidCallback onLocalMode;
  final Future<void> Function() onSignedIn;

  final Future<void> Function() onGoogleSignIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _googleLoading = false;
  String? _googleError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _startGoogleSignIn() async {
    setState(() {
      _googleLoading = true;
      _googleError = null;
    });
    try {
      await widget.onGoogleSignIn();
    } catch (_) {
      if (mounted) {
        setState(
          () => _googleError =
              'Nie udało się połączyć z Google. Spróbuj ponownie.',
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.check_circle_outline, size: 56),
                  const SizedBox(height: 18),
                  Text(
                    'Zaloguj się',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Synchronizuj zadania między telefonem i komputerem.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Adres e-mail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Hasło',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signInWithPassword(
                        email: _email.text.trim(),
                        password: _password.text,
                      );
                      if (Supabase.instance.client.auth.currentSession !=
                          null) {
                        await widget.onSignedIn();
                      }
                    },
                    child: const Text('Zaloguj e-mail'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signUp(
                        email: _email.text.trim(),
                        password: _password.text,
                      );
                    },
                    child: const Text('Załóż konto'),
                  ),
                  if (_googleError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _googleError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  FilledButton.icon(
                    onPressed: _googleLoading ? null : _startGoogleSignIn,
                    icon: const Icon(Icons.g_mobiledata),
                    label: Text(
                      _googleLoading ? 'Łączę z Google…' : 'Kontynuuj z Google',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onLocalMode,
                    child: const Text('Tryb lokalny'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
