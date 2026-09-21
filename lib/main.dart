import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_task_store.dart';
import 'local_task_category_store.dart';
import 'local_note_store.dart';
import 'cloud_migration.dart';
import 'task_sync_service.dart';
import 'task_sync_outbox.dart';
import 'task_category.dart';
import 'task_category_sync_service.dart';
import 'task_category_sync_outbox.dart';
import 'task_categories_screen.dart';
import 'notification_service.dart';
import 'task_item.dart';
import 'subtask_item.dart';
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
import 'note_sync_outbox.dart';
import 'note_folder_sync_outbox.dart';
import 'focus_session.dart';
import 'focus_session_store.dart';
import 'focus_session_sync_service.dart';
import 'calendar_event.dart';
import 'calendar_store.dart';
import 'calendar_credentials.dart';
import 'update_gate.dart';
import 'update_service.dart';
import 'google_calendar_service.dart';
import 'organizer_settings.dart';
import 'android_widget_bridge.dart';
import 'android_widget_snapshot.dart';

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
  const MyApp({super.key, this.remasterPreviewOverride});

  /// Allows legacy UI regression tests to exercise the still-supported view.
  final bool? remasterPreviewOverride;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const _appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const _updateManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/latest/download/update.json',
  );
  final _updateGateKey = GlobalKey<UpdateGateState>();
  bool localMode = false;
  bool cloudMode = false;
  bool _notesCloudAvailable = false;
  bool _foldersCloudAvailable = false;
  bool _focusSessionsCloudAvailable = false;
  bool _notesMode = false;
  bool _remasterPreview = true;
  String _syncStatus = 'Lokalnie';
  final _updateCheckStatus = ValueNotifier<String>('');
  late Future<void> _localRestoreFuture;
  late Future<void> _localNotesRestoreFuture;
  bool _cloudTransitionInProgress = false;
  String _searchQuery = '';
  String _statusFilter = 'all';
  TaskView _selectedView = TaskView.today;
  ThemeMode _themeMode = ThemeMode.system;
  OrganizerSettings _organizerSettings = const OrganizerSettings();
  bool? _notificationPermissionGranted;
  OrganizerSettingsStore? _organizerSettingsStore;
  String? _successNotice;
  final _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _noticeTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _taskSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _taskCategorySubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _subtaskSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _noteSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _folderSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _focusSessionSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  var _nextLocalTaskId = 4;
  LocalTaskStore? _localStore;
  LocalTaskCategoryStore? _localTaskCategoryStore;
  TaskSyncOutbox? _taskSyncOutbox;
  TaskCategorySyncOutbox? _taskCategorySyncOutbox;
  LocalNoteStore? _localNoteStore;
  NoteSyncOutbox? _noteSyncOutbox;
  NoteFolderSyncOutbox? _noteFolderSyncOutbox;
  FocusSessionStore? _focusSessionStore;
  CalendarStore? _calendarStore;
  final _calendarCredentials = CalendarCredentialStore.secure();
  DateTime? _calendarLastSyncedAt;
  CalendarConnectionStatus _calendarStatus =
      CalendarConnectionStatus.disconnected;
  String? _calendarAccessToken;
  bool _calendarAuthorizationPending = false;
  final _androidWidgetBridge = AndroidWidgetBridge();
  String? _selectedAndroidWidgetNoteId;
  List<GoogleCalendarInfo> _availableCalendars = const [];
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
  final taskCategories = <TaskCategory>[];
  final notes = <NoteItem>[];
  final folders = <NoteFolder>[];
  final calendarEvents = <CalendarEvent>[];
  final focusSessions = <FocusSession>[];
  late final TaskSyncService _sync = TaskSyncService(Supabase.instance.client);
  late final TaskCategorySyncService _categorySync = TaskCategorySyncService(
    Supabase.instance.client,
  );
  late final NoteSyncService _noteSync = NoteSyncService(
    Supabase.instance.client,
  );
  late final FocusSessionSyncService _focusSync = FocusSessionSyncService(
    Supabase.instance.client,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.onResponse = _handleNotificationResponse;
    _localRestoreFuture = _restoreLocalTasks();
    _localNotesRestoreFuture = _restoreLocalNotes();
    unawaited(_refreshNotificationPermissionStatus());
    unawaited(_consumeLaunchNotification());
    _restoreCloudSession();
  }

  Future<void> _consumeLaunchNotification() async {
    final response = await NotificationService.instance.consumeLaunchResponse();
    if (response == null) return;
    await _localRestoreFuture;
    await _localNotesRestoreFuture;
    if (!mounted) return;
    _handleNotificationResponse(response);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final taskId = response.payload;
    if (taskId == null || taskId.isEmpty || taskId.startsWith('note:')) return;
    final task = tasks.where((item) => item.id == taskId).firstOrNull;
    if (task == null) return;
    switch (response.actionId) {
      case 'done':
        unawaited(_changeTaskStatus(task, 'done'));
      case 'snooze':
        unawaited(_snoozeTaskFromNotification(task));
    }
  }

  Future<void> _snoozeTaskFromNotification(TaskItem task) async {
    final updated = task.copyWith(
      reminderAt: DateTime.now().add(
        Duration(minutes: _organizerSettings.defaultSnoozeMinutes),
      ),
    );
    if (cloudMode) {
      try {
        await _sync.updateOrganizerTask(updated);
        await _loadCloudTasks();
      } catch (_) {
        final index = tasks.indexWhere((item) => item.id == task.id);
        if (index == -1) return;
        setState(() => tasks[index] = updated);
        await _saveLocalTasks();
        await _taskSyncOutbox?.enqueueUpdate(updated);
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      final index = tasks.indexWhere((item) => item.id == task.id);
      if (index == -1) return;
      setState(() => tasks[index] = updated);
      await _saveLocalTasks();
    }
    await _syncTaskNotifications(updated);
    _showSuccessNotice(
      'Zadanie odłożone o ${_organizerSettings.defaultSnoozeMinutes} min',
    );
  }

  void _restoreCloudSession() {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession != null) {
        _enterCloudMode();
      }
      _authSubscription = auth.onAuthStateChange.listen((state) {
        if (_calendarAuthorizationPending &&
            state.session?.providerToken?.isNotEmpty == true) {
          unawaited(_finishCalendarConnection(state.session!.providerToken));
        }
        if (state.session != null && !cloudMode) {
          _enterCloudMode();
        }
      });
    } on AssertionError {
      // Widget tests intentionally construct MyApp without Supabase.initialize.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (cloudMode) {
      unawaited(_retryPendingTaskSync());
      unawaited(_retryPendingTaskCategorySync());
      unawaited(_retryPendingFolderSync());
      unawaited(_retryPendingNoteSync());
    }
    unawaited(_refreshOverdueTaskNotifications());
    unawaited(_refreshNotificationPermissionStatus());
    if (!_calendarAuthorizationPending) return;
    final token = Supabase.instance.client.auth.currentSession?.providerToken;
    if (token?.isNotEmpty == true) {
      unawaited(_finishCalendarConnection(token));
    }
  }

  Future<void> _restoreLocalTasks() async {
    final preferences = await SharedPreferences.getInstance();
    final store = LocalTaskStore(preferences);
    final storedTasks = await store.load();
    final categoryStore = LocalTaskCategoryStore(preferences);
    final storedCategories = await categoryStore.load();
    final calendarStore = CalendarStore(preferences);
    final organizerSettingsStore = OrganizerSettingsStore(preferences);
    final organizerSettings = await organizerSettingsStore.load();
    final noteSyncOutbox = NoteSyncOutbox(preferences);
    final noteFolderSyncOutbox = NoteFolderSyncOutbox(preferences);
    final taskSyncOutbox = TaskSyncOutbox(preferences);
    final taskCategorySyncOutbox = TaskCategorySyncOutbox(preferences);
    final calendarCache = await calendarStore.loadCache();
    final storedCalendarStatus = await calendarStore.loadConnectionStatus();
    // A connected status is only restored when this device still has the
    // matching token in its secure store. Cached events remain available even
    // when the token is missing or the device is offline.
    final calendarStatus =
        storedCalendarStatus == CalendarConnectionStatus.connected &&
            _calendarAccessToken == null
        ? CalendarConnectionStatus.offline
        : storedCalendarStatus;
    if (calendarStatus != storedCalendarStatus) {
      unawaited(calendarStore.saveConnectionStatus(calendarStatus));
    }
    if (!mounted) return;
    setState(() {
      _localStore = store;
      _localTaskCategoryStore = categoryStore;
      _focusSessionStore = FocusSessionStore(preferences);
      _calendarStore = calendarStore;
      _organizerSettingsStore = organizerSettingsStore;
      _organizerSettings = organizerSettings;
      _noteSyncOutbox = noteSyncOutbox;
      _noteFolderSyncOutbox = noteFolderSyncOutbox;
      _taskSyncOutbox = taskSyncOutbox;
      _taskCategorySyncOutbox = taskCategorySyncOutbox;
      _calendarLastSyncedAt = calendarCache.lastSyncedAt;
      _calendarStatus = calendarStatus;
      calendarEvents
        ..clear()
        ..addAll(calendarCache.events);
      _themeMode = _themeModeFromStorage(preferences.getString('theme_mode'));
      _selectedAndroidWidgetNoteId = preferences.getString(
        'android_widget_selected_note_id',
      );
      _remasterPreview = widget.remasterPreviewOverride ?? true;
      if (storedTasks.isNotEmpty) {
        tasks
          ..clear()
          ..addAll(storedTasks);
        _nextLocalTaskId = tasks.length + 1;
      }
      taskCategories
        ..clear()
        ..addAll(storedCategories);
    });
    unawaited(
      _restoreCalendarCredential(
        wasConnected:
            storedCalendarStatus == CalendarConnectionStatus.connected,
      ),
    );
    final sessions = await _focusSessionStore!.load();
    if (!mounted) return;
    setState(() {
      focusSessions
        ..clear()
        ..addAll(sessions);
    });
    await _refreshDailyPlanNotification();
    await _refreshOverdueTaskNotifications();
    _refreshAndroidWidgets();
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
    _refreshAndroidWidgets();
  }

  void _refreshAndroidWidgets({bool clear = false}) {
    final selectedNote = clear
        ? null
        : notes
                  .where(
                    (note) =>
                        !note.isDeleted &&
                        note.id == _selectedAndroidWidgetNoteId,
                  )
                  .firstOrNull ??
              notes
                  .where((note) => !note.isDeleted && note.pinned)
                  .firstOrNull ??
              notes.where((note) => !note.isDeleted).firstOrNull;
    final snapshot = AndroidWidgetSnapshot.fromData(
      tasks: clear
          ? const []
          : tasks
                .map(
                  (task) => WidgetTaskData(
                    id: task.id,
                    title: task.title,
                    isDone: task.isDone,
                  ),
                )
                .toList(growable: false),
      selectedNote: selectedNote == null
          ? null
          : WidgetNoteData(
              id: selectedNote.id,
              title: selectedNote.title.isEmpty
                  ? 'Notatka'
                  : selectedNote.title,
              preview: selectedNote.previewText,
            ),
    );
    unawaited(_androidWidgetBridge.update(snapshot));
  }

  Future<void> _setAndroidWidgetNote(NoteItem? note) async {
    final preferences = await SharedPreferences.getInstance();
    _selectedAndroidWidgetNoteId = note?.id;
    if (note == null) {
      await preferences.remove('android_widget_selected_note_id');
    } else {
      await preferences.setString('android_widget_selected_note_id', note.id);
    }
    _refreshAndroidWidgets();
    _showSuccessNotice(
      note == null
          ? 'Widżet pokaże przypiętą notatkę'
          : 'Ustawiono notatkę dla widżetu',
    );
  }

  Future<void> _saveLocalTasks() async {
    await _localStore?.save(tasks);
  }

  Future<void> _changeOrganizerSettings(OrganizerSettings settings) async {
    setState(() => _organizerSettings = settings);
    await _organizerSettingsStore?.save(settings);
    if (settings.dailyPlanEnabled ||
        settings.overdueReminderIntervalMinutes > 0) {
      final permission = await NotificationService.instance
          .requestPermissions();
      if (!permission && mounted) {
        _showSuccessNotice(
          'Włącz powiadomienia systemowe, aby dostawać przypomnienia.',
        );
      }
      await _refreshNotificationPermissionStatus();
    }
    await NotificationService.instance.scheduleDailyPlan(
      enabled: settings.dailyPlanEnabled,
      hour: settings.dailyPlanHour,
      minute: settings.dailyPlanMinute,
      pendingTaskCount: tasks.where((task) => !task.isDone).length,
    );
    await _refreshOverdueTaskNotifications();
  }

  Future<void> _sendReminderTest() async {
    try {
      final allowed = await NotificationService.instance.requestPermissions();
      if (!allowed) {
        await _refreshNotificationPermissionStatus();
        _showSuccessNotice(
          'Powiadomienia są wyłączone w ustawieniach systemu.',
        );
        return;
      }
      await NotificationService.instance.showTestNotification();
      await _refreshNotificationPermissionStatus();
      _showSuccessNotice('Wysłano testowe powiadomienie.');
    } catch (_) {
      _showSuccessNotice('Nie udało się wysłać testowego powiadomienia.');
    }
  }

  Future<void> _refreshNotificationPermissionStatus() async {
    final enabled = await NotificationService.instance
        .areNotificationsEnabled();
    if (enabled != null && mounted) {
      setState(() => _notificationPermissionGranted = enabled);
    }
  }

  Future<void> _openNotificationSettings() async {
    await NotificationService.instance.openNotificationSettings();
    await _refreshNotificationPermissionStatus();
  }

  Future<void> _refreshDailyPlanNotification() =>
      NotificationService.instance.scheduleDailyPlan(
        enabled: _organizerSettings.dailyPlanEnabled,
        hour: _organizerSettings.dailyPlanHour,
        minute: _organizerSettings.dailyPlanMinute,
        pendingTaskCount: tasks.where((task) => !task.isDone).length,
      );

  bool _subtasksChanged(List<SubtaskItem> before, List<SubtaskItem> after) {
    if (before.length != after.length) return true;
    for (var index = 0; index < before.length; index++) {
      final previous = before[index];
      final next = after[index];
      if (previous.id != next.id ||
          previous.title != next.title ||
          previous.isDone != next.isDone ||
          previous.position != next.position) {
        return true;
      }
    }
    return false;
  }

  Future<void> _syncTaskNotifications(TaskItem task) async {
    await NotificationService.instance.cancel(task.id);
    if (task.isDone) return;
    final reminderTime = task.reminderAt ?? task.dueAt;
    if (reminderTime != null) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        title: task.title,
        when: reminderTime,
      );
    }
    final interval = _organizerSettings.overdueReminderIntervalMinutes;
    if (task.dueAt != null && interval > 0) {
      await NotificationService.instance.scheduleOverdueTaskReminders(
        taskId: task.id,
        title: task.title,
        dueAt: task.dueAt!,
        intervalMinutes: interval,
      );
    }
  }

  Future<void> _refreshOverdueTaskNotifications() async {
    final currentTasks = List<TaskItem>.of(tasks);
    for (final task in currentTasks) {
      if (task.isDone || task.dueAt == null) {
        await NotificationService.instance.cancelOverdueTaskReminders(task.id);
        continue;
      }
      final interval = _organizerSettings.overdueReminderIntervalMinutes;
      if (interval == 0) {
        await NotificationService.instance.cancelOverdueTaskReminders(task.id);
      } else {
        await NotificationService.instance.scheduleOverdueTaskReminders(
          taskId: task.id,
          title: task.title,
          dueAt: task.dueAt!,
          intervalMinutes: interval,
        );
      }
    }
  }

  Future<void> _saveLocalNotes() async {
    await _localNoteStore?.save(notes);
  }

  Future<void> _saveLocalFolders() async {
    // Folder schema deployment is deliberately opt-in. Until it is applied in
    // Supabase, local folders stay available without risking existing notes.
    await _localNoteStore?.saveFolders(folders);
  }

  Future<void> _saveFocusSession(FocusSession session) async {
    var store = _focusSessionStore;
    if (store == null) {
      store = FocusSessionStore(await SharedPreferences.getInstance());
      _focusSessionStore = store;
    }
    await store.add(session);
    if (mounted) {
      setState(() {
        focusSessions.removeWhere((item) => item.id == session.id);
        focusSessions.insert(0, session);
      });
    }
    if (cloudMode && _focusSessionsCloudAvailable) {
      try {
        await _focusSync.save(session);
      } catch (_) {
        if (mounted) setState(() => _syncStatus = 'Błąd synchronizacji');
      }
    }
  }

  Future<CalendarStore> _calendarStoreOrCreate() async {
    final existing = _calendarStore;
    if (existing != null) return existing;
    final store = CalendarStore(await SharedPreferences.getInstance());
    _calendarStore = store;
    return store;
  }

  Future<void> _clearCalendarCredentials() async {
    try {
      await _calendarCredentials.clear();
    } catch (_) {
      // Some test or desktop environments may not expose a secure store.
    }
  }

  Future<void> _restoreCalendarCredential({required bool wasConnected}) async {
    String? token;
    try {
      token = await _calendarCredentials.read();
    } catch (_) {
      return;
    }
    if (token == null || token.isEmpty || !mounted) return;
    _calendarAccessToken = token;
    if (wasConnected) {
      await _setCalendarStatus(CalendarConnectionStatus.connected);
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setCalendarStatus(CalendarConnectionStatus status) async {
    if (mounted) setState(() => _calendarStatus = status);
    final store = await _calendarStoreOrCreate();
    await store.saveConnectionStatus(status);
  }

  CalendarConnectionStatus _calendarStatusForError(Object error) {
    if (error is CalendarTransportException &&
        (error.statusCode == 401 || error.statusCode == 403)) {
      return CalendarConnectionStatus.expired;
    }
    return CalendarConnectionStatus.offline;
  }

  Future<void> _startCalendarConnection() async {
    if (!cloudMode) {
      _showSuccessNotice('Zaloguj się, aby połączyć Google Calendar.');
      return;
    }
    if (mounted) setState(() => _calendarAuthorizationPending = true);
    await _setCalendarStatus(CalendarConnectionStatus.connecting);
    try {
      await SupabaseCalendarConnectionAction(Supabase.instance.client).start();
    } catch (_) {
      await _setCalendarStatus(CalendarConnectionStatus.disconnected);
      if (mounted) setState(() => _calendarAuthorizationPending = false);
      _showSuccessNotice(
        'Nie udało się otworzyć połączenia z Google Calendar.',
      );
    }
  }

  Future<void> _finishCalendarConnection(String? providerToken) async {
    if (providerToken == null || providerToken.isEmpty) {
      await _setCalendarStatus(CalendarConnectionStatus.disconnected);
      if (mounted) setState(() => _calendarAuthorizationPending = false);
      _showSuccessNotice(
        'Google nie przekazał dostępu do Kalendarza. Spróbuj ponownie.',
      );
      return;
    }
    try {
      _calendarAccessToken = providerToken;
      try {
        await _calendarCredentials.save(providerToken);
      } catch (_) {
        // Keep this session usable if the platform secure store is unavailable.
      }
      _availableCalendars = await GoogleCalendarService().loadCalendars(
        providerToken,
      );
      if (!mounted) return;
      await _chooseCalendars(_availableCalendars);
      await _setCalendarStatus(CalendarConnectionStatus.connected);
      if (mounted) setState(() => _calendarAuthorizationPending = false);
    } catch (error) {
      final status = _calendarStatusForError(error);
      if (status == CalendarConnectionStatus.expired) {
        _calendarAccessToken = null;
        await _clearCalendarCredentials();
      }
      await _setCalendarStatus(status);
      if (mounted) setState(() => _calendarAuthorizationPending = false);
      _showSuccessNotice('Nie udało się pobrać listy kalendarzy.');
    }
  }

  Future<void> _chooseCalendars(List<GoogleCalendarInfo> options) async {
    if (options.isEmpty) {
      _showSuccessNotice(
        'Nie znaleziono kalendarzy dostępnych dla tego konta.',
      );
      return;
    }
    final store = await _calendarStoreOrCreate();
    final initial = (await store.loadSelection()).toSet();
    if (initial.isEmpty) {
      initial.addAll(
        options.where((item) => item.isPrimary).map((item) => item.id),
      );
    }
    final selected = await showDialog<Set<String>>(
      context: _navigatorKey.currentContext!,
      builder: (context) {
        final current = {...initial};
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Wybierz kalendarze'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final calendar in options)
                      CheckboxListTile(
                        value: current.contains(calendar.id),
                        onChanged: (checked) => update(() {
                          if (checked == true) {
                            current.add(calendar.id);
                          } else {
                            current.remove(calendar.id);
                          }
                        }),
                        title: Text(calendar.title),
                        subtitle: calendar.isPrimary
                            ? const Text('Główny kalendarz')
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, current),
                child: const Text('Zapisz'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await store.saveSelection(selected.toList());
    await _refreshCalendar();
  }

  Future<void> _refreshCalendar() async {
    final token = _calendarAccessToken;
    if (token == null) {
      if (_calendarStatus == CalendarConnectionStatus.connected) {
        await _setCalendarStatus(CalendarConnectionStatus.offline);
      }
      _showSuccessNotice(
        'Połącz Google Calendar ponownie, aby odświeżyć dane.',
      );
      return;
    }
    try {
      final store = await _calendarStoreOrCreate();
      var selected = await store.loadSelection();
      if (selected.isEmpty) {
        if (_availableCalendars.isEmpty) {
          _availableCalendars = await GoogleCalendarService().loadCalendars(
            token,
          );
        }
        await _chooseCalendars(_availableCalendars);
        selected = await store.loadSelection();
        if (selected.isEmpty) return;
      }
      final now = DateTime.now();
      final events = await GoogleCalendarService().loadEvents(
        token,
        calendarIds: selected,
        from: DateTime(now.year, now.month, now.day),
        until: DateTime(now.year, now.month, now.day + 30),
      );
      final syncedAt = DateTime.now();
      await store.saveCache(events, syncedAt);
      if (!mounted) return;
      setState(() {
        calendarEvents
          ..clear()
          ..addAll(events);
        _calendarLastSyncedAt = syncedAt;
      });
      await _setCalendarStatus(CalendarConnectionStatus.connected);
      _showSuccessNotice('Kalendarz odświeżony');
    } catch (error) {
      final status = _calendarStatusForError(error);
      if (status == CalendarConnectionStatus.expired) {
        _calendarAccessToken = null;
        await _clearCalendarCredentials();
      }
      await _setCalendarStatus(status);
      _showSuccessNotice(
        status == CalendarConnectionStatus.expired
            ? 'Sesja Google Calendar wygasła. Połącz go ponownie.'
            : 'Nie udało się odświeżyć Calendar. Pokazuję ostatni zapis offline.',
      );
    }
  }

  Future<void> _editCalendarSelection() async {
    final token = _calendarAccessToken;
    if (token == null) {
      _showSuccessNotice('Połącz Google Calendar ponownie, aby zmienić wybór.');
      return;
    }
    try {
      if (_availableCalendars.isEmpty) {
        _availableCalendars = await GoogleCalendarService().loadCalendars(
          token,
        );
      }
      await _chooseCalendars(_availableCalendars);
    } catch (error) {
      final status = _calendarStatusForError(error);
      if (status == CalendarConnectionStatus.expired) {
        _calendarAccessToken = null;
        await _clearCalendarCredentials();
      }
      await _setCalendarStatus(status);
      _showSuccessNotice(
        status == CalendarConnectionStatus.expired
            ? 'Sesja Google Calendar wygasła. Połącz go ponownie.'
            : 'Nie udało się pobrać listy kalendarzy. Spróbuj ponownie online.',
      );
    }
  }

  Future<void> _disconnectCalendar() async {
    await _clearCalendarCredentials();
    final store = await _calendarStoreOrCreate();
    await store.clear();
    if (!mounted) return;
    setState(() {
      _calendarAccessToken = null;
      _calendarStatus = CalendarConnectionStatus.disconnected;
      _availableCalendars = const [];
      _calendarLastSyncedAt = null;
      calendarEvents.clear();
    });
    _showSuccessNotice('Google Calendar odłączony');
  }

  Future<void> _createFolder(String name, NoteColorKey colorKey) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final folder = NoteFolder(
      id: newNoteId(),
      name: trimmed,
      colorKey: colorKey,
    );
    setState(() => folders.add(folder));
    await _saveLocalFolders();
    if (cloudMode && _foldersCloudAvailable) {
      try {
        await _noteSync.saveFolder(folder);
        await _noteFolderSyncOutbox?.remove(folder.id);
        await _loadCloudFolders();
        if (mounted) setState(() => _syncStatus = 'Zsynchronizowano');
      } catch (_) {
        await _noteFolderSyncOutbox?.enqueueUpsert(folder);
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    }
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    final changedNotes = notes
        .where((item) => item.folderId == folder.id)
        .map((item) => item.copyWith(folderId: null, updatedAt: DateTime.now()))
        .toList();
    setState(() {
      folders.removeWhere((item) => item.id == folder.id);
      for (final changed in changedNotes) {
        final index = notes.indexWhere((item) => item.id == changed.id);
        if (index != -1) notes[index] = changed;
      }
    });
    await _saveLocalFolders();
    await _saveLocalNotes();
    if (cloudMode && _foldersCloudAvailable) {
      try {
        await _noteSync.deleteFolder(folder);
        await _noteFolderSyncOutbox?.remove(folder.id);
        await _loadCloudFolders();
        await _loadCloudNotes();
        if (mounted) setState(() => _syncStatus = 'Zsynchronizowano');
      } catch (_) {
        await _noteFolderSyncOutbox?.enqueueDelete(folder);
        for (final changed in changedNotes) {
          await _noteSyncOutbox?.enqueue(
            changed,
            expectedRevision: changed.revision - 1,
            includeFolderId: true,
          );
        }
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    }
  }

  Future<void> _renameFolder(NoteFolder folder) async {
    final updated = folder.copyWith(updatedAt: DateTime.now());
    setState(() {
      final index = folders.indexWhere((item) => item.id == folder.id);
      if (index != -1) folders[index] = updated;
    });
    await _saveLocalFolders();
    if (cloudMode && _foldersCloudAvailable) {
      try {
        await _noteSync.saveFolder(updated);
        await _noteFolderSyncOutbox?.remove(updated.id);
        await _loadCloudFolders();
        if (mounted) setState(() => _syncStatus = 'Zsynchronizowano');
      } catch (_) {
        await _noteFolderSyncOutbox?.enqueueUpsert(updated);
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    }
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
    final pending = await _taskSyncOutbox?.load() ?? const <PendingTaskSync>[];
    final mergedTasks = [...cloudTasks];
    for (final operation in pending) {
      final index = mergedTasks.indexWhere((task) => task.id == operation.id);
      if (index == -1) {
        mergedTasks.insert(0, operation.task);
      } else {
        mergedTasks[index] = operation.task;
      }
    }
    if (!mounted) return;
    setState(() {
      tasks
        ..clear()
        ..addAll(mergedTasks);
    });
    _refreshAndroidWidgets();
  }

  Future<void> _retryPendingTaskSync() async {
    final outbox = _taskSyncOutbox;
    if (outbox == null) return;
    final pending = await outbox.load();
    var changed = false;
    for (final operation in pending) {
      try {
        final task = operation.task;
        switch (operation.kind) {
          case TaskSyncOperationKind.create:
            await _sync.addTask(
              task.title,
              id: task.id,
              note: task.note,
              category: task.category,
              categoryId: task.categoryId,
              priority: task.priority,
              dueAt: task.dueAt,
              reminderAt: task.reminderAt,
              sourceNoteId: task.sourceNoteId,
            );
            for (final step in task.subtasks) {
              await _sync.addSubtask(task.id, step.title, step.position);
            }
          case TaskSyncOperationKind.update:
            await _sync.updateOrganizerTask(task);
            if (operation.syncSubtasks) {
              await _sync.syncSubtasks(task.id, task.subtasks);
            }
          case TaskSyncOperationKind.delete:
            await _sync.deleteTask(task.id);
        }
        await outbox.remove(operation.id);
        changed = true;
      } catch (_) {
        break;
      }
    }
    if (changed) await _loadCloudTasks();
  }

  Future<void> _loadCloudTaskCategories() async {
    final loaded = await _categorySync.loadCategories();
    if (!mounted) return;
    setState(() {
      taskCategories
        ..clear()
        ..addAll(loaded);
    });
    await _localTaskCategoryStore?.save(taskCategories);
  }

  Future<void> _retryPendingTaskCategorySync() async {
    final outbox = _taskCategorySyncOutbox;
    if (outbox == null) return;
    final pending = await outbox.load();
    for (final operation in pending) {
      try {
        if (operation.kind == TaskCategorySyncOperationKind.upsert) {
          await _categorySync.save(operation.category);
        } else {
          await _categorySync.delete(operation.category.id);
        }
        await outbox.remove(operation.id);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> _retryPendingFolderSync() async {
    final outbox = _noteFolderSyncOutbox;
    if (outbox == null || !_foldersCloudAvailable) return;
    final pending = await outbox.load();
    var changed = false;
    for (final operation in pending) {
      try {
        if (operation.kind == NoteFolderSyncOperationKind.upsert) {
          await _noteSync.saveFolder(operation.folder);
        } else {
          await _noteSync.deleteFolder(operation.folder);
        }
        await outbox.remove(operation.id);
        changed = true;
      } catch (_) {
        break;
      }
    }
    if (changed) {
      await _loadCloudFolders();
      await _loadCloudNotes();
    }
  }

  Future<void> _saveTaskCategory(TaskCategory category) async {
    setState(() {
      final index = taskCategories.indexWhere((item) => item.id == category.id);
      if (index == -1) {
        taskCategories.add(category);
      } else {
        taskCategories[index] = category;
      }
    });
    await _localTaskCategoryStore?.save(taskCategories);
    if (!cloudMode) return;
    try {
      final synced = await _categorySync.save(category);
      if (!mounted) return;
      setState(() {
        final index = taskCategories.indexWhere((item) => item.id == synced.id);
        if (index == -1) {
          taskCategories.add(synced);
        } else {
          taskCategories[index] = synced;
        }
        _syncStatus = 'Zsynchronizowano';
      });
      await _localTaskCategoryStore?.save(taskCategories);
    } catch (_) {
      await _taskCategorySyncOutbox?.enqueueUpsert(category);
      if (mounted) {
        setState(
          () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
        );
      }
    }
  }

  Future<void> _deleteTaskCategory(TaskCategory category) async {
    final changedTasks = tasks
        .where((task) => task.categoryId == category.id)
        .map((task) => task.copyWith(categoryId: null))
        .toList();
    setState(() {
      for (final task in changedTasks) {
        final index = tasks.indexWhere((item) => item.id == task.id);
        if (index != -1) tasks[index] = task;
      }
      taskCategories.removeWhere((item) => item.id == category.id);
    });
    await _saveLocalTasks();
    await _localTaskCategoryStore?.save(taskCategories);
    if (!cloudMode) return;
    try {
      for (final task in changedTasks) {
        await _sync.updateOrganizerTask(task);
      }
      await _categorySync.delete(category.id);
      if (mounted) setState(() => _syncStatus = 'Zsynchronizowano');
    } catch (_) {
      for (final task in changedTasks) {
        await _taskSyncOutbox?.enqueueUpdate(task);
      }
      await _taskCategorySyncOutbox?.enqueueDelete(category);
      if (mounted) {
        setState(
          () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
        );
      }
    }
  }

  Future<void> _openTaskCategories() async {
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'local-user';
    await _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => TaskCategoriesScreen(
          categories: List<TaskCategory>.from(taskCategories),
          userId: userId,
          onSave: _saveTaskCategory,
          onDelete: _deleteTaskCategory,
        ),
      ),
    );
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
      await _retryPendingTaskSync();
      await _retryPendingTaskCategorySync();
      await _refreshOverdueTaskNotifications();
      try {
        await _loadCloudTaskCategories();
      } catch (_) {
        // Categories remain available from the local cache until their
        // additive migration is enabled in Supabase.
      }
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
        await _retryPendingNoteSync();
        try {
          await _noteSync.purgeExpiredTrash(NoteTrashRetention.thirtyDays);
        } catch (_) {
          // Purging old trash must never make usable note sync unavailable.
        }
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
          _foldersCloudAvailable = true;
          await _retryPendingFolderSync();
          await _loadCloudFolders();
          await _retryPendingNoteSync();
        } catch (_) {
          // Folder SQL is a separate, backwards-compatible migration. Notes
          // continue syncing normally until the user enables it.
          _foldersCloudAvailable = false;
        }
      }
      try {
        await _loadCloudFocusSessions();
        _focusSessionsCloudAvailable = true;
      } catch (_) {
        // This is an additive migration. Focus remains fully usable locally
        // until the owner enables focus_sessions.sql in Supabase.
        _focusSessionsCloudAvailable = false;
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
      await _taskCategorySubscription?.cancel();
      _taskCategorySubscription = Supabase.instance.client
          .from('task_categories')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .listen((_) => unawaited(_loadCloudTaskCategories()));
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
      if (_focusSessionsCloudAvailable) {
        await _focusSessionSubscription?.cancel();
        _focusSessionSubscription = Supabase.instance.client
            .from('focus_sessions')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .listen((_) => unawaited(_loadCloudFocusSessions()));
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
      await _refreshOverdueTaskNotifications();
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
    _refreshAndroidWidgets();
  }

  Future<void> _retryPendingNoteSync() async {
    final outbox = _noteSyncOutbox;
    if (outbox == null) return;
    final pending = await outbox.load();
    for (final operation in pending) {
      try {
        if (operation.kind == NoteSyncOperationKind.delete) {
          await _noteSync.permanentlyDeleteNote(operation.note);
        } else {
          await _noteSync.saveNote(
            operation.note,
            expectedRevision: operation.expectedRevision,
            includeFolderId: operation.includeFolderId,
          );
        }
        await outbox.remove(operation.id);
      } on NoteConflictException {
        final conflict = await _noteSync.createConflictCopy(operation.note);
        await outbox.remove(operation.id);
        if (!mounted) continue;
        setState(() {
          notes.removeWhere((item) => item.id == operation.note.id);
          notes.add(conflict);
        });
      } catch (_) {
        // Keep the operation for the next successful sign-in/resume.
        break;
      }
    }
    if (pending.isNotEmpty) {
      await _loadCloudNotes();
      await _saveLocalNotes();
    }
  }

  Future<void> _retryAllPendingSync() async {
    if (!cloudMode) {
      _showSuccessNotice('Zaloguj się, aby ponowić synchronizację.');
      return;
    }
    if (mounted) setState(() => _syncStatus = 'Synchronizowanie…');
    try {
      await _retryPendingTaskSync();
      await _retryPendingTaskCategorySync();
      await _retryPendingFolderSync();
      await _retryPendingNoteSync();
      final taskPending = await _taskSyncOutbox?.load() ?? const [];
      final categoryPending = await _taskCategorySyncOutbox?.load() ?? const [];
      final notePending = await _noteSyncOutbox?.load() ?? const [];
      final folderPending = await _noteFolderSyncOutbox?.load() ?? const [];
      if (!mounted) return;
      setState(() {
        _syncStatus =
            taskPending.isEmpty &&
                categoryPending.isEmpty &&
                notePending.isEmpty &&
                folderPending.isEmpty
            ? 'Zsynchronizowano'
            : 'Czeka na synchronizację';
      });
    } catch (_) {
      if (mounted) setState(() => _syncStatus = 'Błąd synchronizacji');
    }
  }

  Future<void> _loadCloudFolders() async {
    final loaded = await _noteSync.loadFolders();
    if (!mounted) return;
    setState(() {
      folders
        ..clear()
        ..addAll(loaded);
    });
    await _saveLocalFolders();
  }

  Future<void> _loadCloudFocusSessions() async {
    final loaded = await _focusSync.load();
    if (!mounted) return;
    setState(() {
      focusSessions
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
    final isNew = !notes.any((item) => item.id == note.id);
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
    if (cloudMode && _notesCloudAvailable) {
      try {
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
        await _noteSyncOutbox?.remove(note.id);
        return;
      } catch (_) {
        await _noteSyncOutbox?.enqueue(
          note,
          expectedRevision: isNew ? null : note.revision - 1,
          includeFolderId: _foldersCloudAvailable,
        );
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
        throw StateError(
          'Notatka jest zapisana lokalnie i czeka na synchronizację.',
        );
      }
      await _noteSyncOutbox?.remove(note.id);
      await _loadCloudNotes();
      try {
        await _noteSync.purgeExpiredTrash(NoteTrashRetention.thirtyDays);
      } catch (_) {
        // The current note was synchronized; cleanup can retry later.
      }
      await _scheduleNoteReminder(note);
      _refreshAndroidWidgets();
      return;
    }
    await _scheduleNoteReminder(note);
    _refreshAndroidWidgets();
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
    if (mounted) setState(() => notes.removeWhere((item) => item.id == note.id));
    await _saveLocalNotes();
    if (cloudMode && _notesCloudAvailable) {
      try {
        await _noteSync.permanentlyDeleteNote(note);
        await _noteSyncOutbox?.remove(note.id);
        await _loadCloudNotes();
      } catch (_) {
        await _noteSyncOutbox?.enqueueDelete(note);
        if (mounted) {
          setState(
            () => _syncStatus = 'Usunięto lokalnie · czeka na synchronizację',
          );
        }
      }
    }
  }

  Future<void> _showTaskForm(BuildContext context, {TaskItem? task}) async {
    final modalContext = _navigatorKey.currentContext;
    if (modalContext == null) return;
    var saved = false;
    await showTaskEditor(
      modalContext,
      task: task,
      categories: taskCategories,
      remastered: _remasterPreview,
      onSave: (draft) async {
        late final String taskId;
        if (task != null) {
          taskId = task.id;
          final updatedTask = task.copyWith(
            title: draft.title,
            note: draft.note,
            category: draft.category,
            categoryId: draft.categoryId,
            priority: draft.priority,
            dueAt: draft.dueAt,
            reminderAt: draft.reminderAt,
            repeatRule: draft.repeatRule,
            subtasks: draft.subtasks,
          );
          if (cloudMode) {
            try {
              await _sync.updateTask(
                taskId,
                title: draft.title,
                note: draft.note,
                category: draft.category,
                categoryId: draft.categoryId,
                priority: draft.priority,
                dueAt: draft.dueAt,
                reminderAt: draft.reminderAt,
              );
              if (_subtasksChanged(task.subtasks, draft.subtasks)) {
                await _sync.syncSubtasks(taskId, draft.subtasks);
              }
              await _loadCloudTasks();
            } catch (_) {
              setState(() {
                final index = tasks.indexWhere((item) => item.id == task.id);
                if (index != -1) tasks[index] = updatedTask;
              });
              await _saveLocalTasks();
              await _taskSyncOutbox?.enqueueUpdate(
                updatedTask,
                syncSubtasks: _subtasksChanged(task.subtasks, draft.subtasks),
              );
              if (mounted) {
                setState(
                  () => _syncStatus =
                      'Zapisano lokalnie · czeka na synchronizację',
                );
              }
            }
          } else {
            setState(() {
              final index = tasks.indexOf(task);
              tasks[index] = updatedTask;
            });
            await _saveLocalTasks();
          }
        } else if (cloudMode) {
          final provisionalId = newNoteId();
          try {
            final row = await _sync.addTask(
              draft.title,
              note: draft.note,
              category: draft.category,
              categoryId: draft.categoryId,
              priority: draft.priority,
              dueAt: draft.dueAt,
              reminderAt: draft.reminderAt,
            );
            taskId = row['id'] as String;
            for (final step in draft.subtasks) {
              await _sync.addSubtask(taskId, step.title, step.position);
            }
            await _loadCloudTasks();
          } catch (_) {
            final pendingTask = TaskItem(
              id: provisionalId,
              title: draft.title,
              status: 'todo',
              note: draft.note,
              category: draft.category,
              categoryId: draft.categoryId,
              priority: draft.priority,
              dueAt: draft.dueAt,
              reminderAt: draft.reminderAt,
              repeatRule: draft.repeatRule,
              subtasks: draft.subtasks,
            );
            setState(() => tasks.insert(0, pendingTask));
            await _saveLocalTasks();
            await _taskSyncOutbox?.enqueue(pendingTask);
            if (mounted) {
              setState(
                () =>
                    _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
              );
            }
            taskId = provisionalId;
          }
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
                categoryId: draft.categoryId,
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
        final taskForNotifications =
            tasks.where((item) => item.id == taskId).firstOrNull ??
            (task?.copyWith(
                  title: draft.title,
                  note: draft.note,
                  category: draft.category,
                  categoryId: draft.categoryId,
                  priority: draft.priority,
                  dueAt: draft.dueAt,
                  reminderAt: draft.reminderAt,
                  repeatRule: draft.repeatRule,
                  subtasks: draft.subtasks,
                ) ??
                TaskItem(
                  id: taskId,
                  title: draft.title,
                  status: 'todo',
                  note: draft.note,
                  category: draft.category,
                  categoryId: draft.categoryId,
                  priority: draft.priority,
                  dueAt: draft.dueAt,
                  reminderAt: draft.reminderAt,
                  repeatRule: draft.repeatRule,
                  subtasks: draft.subtasks,
                ));
        await _syncTaskNotifications(taskForNotifications);
        await _refreshDailyPlanNotification();
        _refreshAndroidWidgets();
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
    await _taskCategorySubscription?.cancel();
    await _subtaskSubscription?.cancel();
    await _noteSubscription?.cancel();
    await _folderSubscription?.cancel();
    await _focusSessionSubscription?.cancel();
    _taskSubscription = null;
    _taskCategorySubscription = null;
    _subtaskSubscription = null;
    _noteSubscription = null;
    _folderSubscription = null;
    _focusSessionSubscription = null;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // The local UI still needs to leave cloud mode if the network is down.
    }
    await _clearCalendarCredentials();
    if (!mounted) return;
    setState(() {
      localMode = false;
      cloudMode = false;
      _notesCloudAvailable = false;
      _foldersCloudAvailable = false;
      _focusSessionsCloudAvailable = false;
      _notesMode = false;
      _syncStatus = 'Lokalnie';
      _selectedAndroidWidgetNoteId = null;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('android_widget_selected_note_id');
    _refreshAndroidWidgets(clear: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskSubscription?.cancel();
    _taskCategorySubscription?.cancel();
    _subtaskSubscription?.cancel();
    _noteSubscription?.cancel();
    _folderSubscription?.cancel();
    _focusSessionSubscription?.cancel();
    _authSubscription?.cancel();
    _noticeTimer?.cancel();
    _updateCheckStatus.dispose();
    super.dispose();
  }

  Future<ReleaseInfo?> _checkForUpdate() => const UpdateService().check(
    _updateManifestUrl,
    currentVersion: _appVersion,
  );

  Future<void> _checkForUpdateFromSettings() async {
    _updateCheckStatus.value = 'Sprawdzanie…';
    try {
      final release =
          await (_updateGateKey.currentState?.checkNow() ?? _checkForUpdate());
      if (!mounted) return;
      _updateCheckStatus.value = release == null
          ? 'Masz najnowszą wersję.'
          : 'Dostępna aktualizacja ${release.version}. Baner jest gotowy.';
    } catch (_) {
      if (mounted) {
        _updateCheckStatus.value = 'Nie udało się sprawdzić aktualizacji.';
      }
    }
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
      try {
        await _sync.completeAndCreateNext(updated, next);
        await _loadCloudTasks();
      } catch (_) {
        setState(() {
          final index = tasks.indexWhere((item) => item.id == task.id);
          if (index != -1) tasks[index] = updated;
          if (next != null) tasks.add(next);
        });
        await _saveLocalTasks();
        await _taskSyncOutbox?.enqueueUpdate(updated);
        if (next != null) await _taskSyncOutbox?.enqueue(next);
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      setState(() {
        final index = tasks.indexOf(task);
        tasks[index] = updated;
        if (next != null) tasks.add(next);
      });
      await _saveLocalTasks();
    }
    await _syncTaskNotifications(updated);
    if (next != null) await _syncTaskNotifications(next);
    await _refreshDailyPlanNotification();
    _refreshAndroidWidgets();
    if (status == 'done' && task.repeatRule == null) {
      _showUndoSnackBar(
        'Zadanie oznaczone jako gotowe',
        () => _restoreTaskState(task),
      );
    }
  }

  Future<void> _restoreTaskState(TaskItem task) async {
    if (cloudMode) {
      try {
        await _sync.updateOrganizerTask(task);
        await _loadCloudTasks();
      } catch (_) {
        final index = tasks.indexWhere((item) => item.id == task.id);
        if (index != -1) {
          setState(() => tasks[index] = task);
          await _saveLocalTasks();
          await _taskSyncOutbox?.enqueueUpdate(task);
        }
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      final index = tasks.indexWhere((item) => item.id == task.id);
      if (index == -1) return;
      setState(() => tasks[index] = task);
      await _saveLocalTasks();
    }
    await _syncTaskNotifications(task);
    await _refreshDailyPlanNotification();
    _refreshAndroidWidgets();
  }

  Future<void> _postponeTask(TaskItem task) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final option = await showTaskPostponeSheet(context);
    if (option == null) return;
    final plan = planTaskPostponement(task, DateTime.now(), option);
    if (cloudMode) {
      try {
        await _sync.updateOrganizerTask(plan.updatedTask);
        await _loadCloudTasks();
      } catch (_) {
        final index = tasks.indexWhere((item) => item.id == task.id);
        if (index != -1) {
          setState(() => tasks[index] = plan.updatedTask);
          await _saveLocalTasks();
          await _taskSyncOutbox?.enqueueUpdate(plan.updatedTask);
        }
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      final index = tasks.indexWhere((item) => item.id == task.id);
      if (index == -1) return;
      setState(() => tasks[index] = plan.updatedTask);
      await _saveLocalTasks();
    }
    await _syncTaskNotifications(plan.updatedTask);
    _showSuccessNotice('Zadanie odłożone');
    _refreshAndroidWidgets();
  }

  Future<void> _quickAddTask(String rawText, {String? sourceNoteId}) async {
    final parsed = parseQuickTask(rawText, DateTime.now());
    if (parsed.title.isEmpty) {
      _showSuccessNotice('Wpisz nazwę zadania.');
      return;
    }
    late final String taskId;
    if (cloudMode) {
      try {
        final row = await _sync.addTask(
          parsed.title,
          dueAt: parsed.dueAt,
          sourceNoteId: sourceNoteId,
        );
        taskId = row['id'] as String;
        await _loadCloudTasks();
      } catch (_) {
        taskId = 'local-${_nextLocalTaskId++}';
        final pendingTask = TaskItem(
          id: taskId,
          title: parsed.title,
          status: 'todo',
          dueAt: parsed.dueAt,
          sourceNoteId: sourceNoteId,
        );
        setState(() => tasks.insert(0, pendingTask));
        await _saveLocalTasks();
        await _taskSyncOutbox?.enqueue(pendingTask);
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
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
    final taskForNotifications =
        tasks.where((item) => item.id == taskId).firstOrNull ??
        TaskItem(
          id: taskId,
          title: parsed.title,
          status: 'todo',
          dueAt: parsed.dueAt,
          sourceNoteId: sourceNoteId,
        );
    await _syncTaskNotifications(taskForNotifications);
    await _refreshDailyPlanNotification();
    _refreshAndroidWidgets();
    _showSuccessNotice();
  }

  Future<void> _openFocusTask(TaskItem task) async {
    if (!mounted) return;
    await _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (routeContext) => _remasterPreview
            ? RemasterFocusModeScreen(
                task: task,
                onComplete: () async {
                  await _changeTaskStatus(task, 'done');
                  if (routeContext.mounted) Navigator.of(routeContext).pop();
                },
                onPostpone: () => _postponeTask(task),
                onSessionSaved: _saveFocusSession,
                recentSessions: focusSessions,
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
      try {
        await _sync.updateOrganizerTask(updated);
        await _loadCloudTasks();
      } catch (_) {
        setState(() => tasks[tasks.indexOf(task)] = updated);
        await _saveLocalTasks();
        await _taskSyncOutbox?.enqueueUpdate(updated);
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      setState(() => tasks[tasks.indexOf(task)] = updated);
      await _saveLocalTasks();
    }
    _refreshAndroidWidgets();
  }

  Future<void> _moveTaskToWeekDay(TaskItem task, DateTime day) async {
    final plan = planTaskMoveToWeekDay(task, day);
    final updated = plan.updatedTask;
    if (cloudMode) {
      try {
        await _sync.updateOrganizerTask(updated);
        await _loadCloudTasks();
      } catch (_) {
        final index = tasks.indexWhere((item) => item.id == task.id);
        if (index != -1) {
          setState(() => tasks[index] = updated);
          await _saveLocalTasks();
          await _taskSyncOutbox?.enqueueUpdate(updated);
        }
        if (mounted) {
          setState(
            () => _syncStatus = 'Zapisano lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      setState(() {
        final index = tasks.indexWhere((item) => item.id == task.id);
        tasks[index] = updated;
      });
      await _saveLocalTasks();
    }
    await _syncTaskNotifications(updated);
    _refreshAndroidWidgets();
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
      try {
        await _sync.deleteTask(task.id);
        await _loadCloudTasks();
      } catch (_) {
        setState(() => tasks.removeWhere((item) => item.id == task.id));
        await _saveLocalTasks();
        await _taskSyncOutbox?.enqueueDelete(task);
        if (mounted) {
          setState(
            () => _syncStatus = 'Usunięto lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      setState(() => tasks.remove(task));
      await _saveLocalTasks();
    }
    await NotificationService.instance.cancel(task.id);
    await _refreshDailyPlanNotification();
    _refreshAndroidWidgets();
    _showUndoSnackBar(
      'Zadanie usunięte',
      () => _restoreDeletedTask(task, localIndex),
    );
  }

  Future<void> _restoreDeletedTask(TaskItem task, int localIndex) async {
    if (cloudMode) {
      try {
        await _sync.restoreTask(task.id);
        await _loadCloudTasks();
      } catch (_) {
        final restoreIndex = localIndex.clamp(0, tasks.length).toInt();
        setState(() => tasks.insert(restoreIndex, task));
        await _saveLocalTasks();
        await _taskSyncOutbox?.enqueueUpdate(task);
        if (mounted) {
          setState(
            () =>
                _syncStatus = 'Przywrócono lokalnie · czeka na synchronizację',
          );
        }
      }
    } else {
      if (tasks.any((item) => item.id == task.id)) return;
      final restoreIndex = localIndex.clamp(0, tasks.length).toInt();
      setState(() => tasks.insert(restoreIndex, task));
      await _saveLocalTasks();
    }
    await _syncTaskNotifications(task);
    await _refreshDailyPlanNotification();
    _refreshAndroidWidgets();
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
        onSetWidgetNote: _setAndroidWidgetNote,
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
              calendarEvents: calendarEvents,
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
    locale: const Locale('pl', 'PL'),
    supportedLocales: const [Locale('pl', 'PL')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    navigatorKey: _navigatorKey,
    theme: _remasterPreview
        ? buildRemasterTheme(Brightness.light)
        : buildLightTheme(),
    darkTheme: _remasterPreview
        ? buildRemasterTheme(Brightness.dark)
        : buildDarkTheme(),
    themeMode: _themeMode,
    builder: (context, child) => UpdateGate(
      key: _updateGateKey,
      currentVersion: _appVersion,
      checkForUpdate: _checkForUpdate,
      child: child ?? const SizedBox.shrink(),
    ),
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
            calendarEvents: calendarEvents,
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
            appVersion: _appVersion,
            onCheckForUpdate: _checkForUpdateFromSettings,
            updateCheckStatus: _updateCheckStatus,
            name: _profileValue('full_name'),
            avatarUrl: _profileValue('avatar_url'),
            onSignOut: cloudMode ? _signOut : null,
            calendarConnected: _calendarAccessToken != null,
            calendarConnecting: _calendarAuthorizationPending,
            calendarStatus: _calendarStatus,
            calendarCachedEventCount: calendarEvents.length,
            calendarLastSyncedAt: _calendarLastSyncedAt,
            onConnectCalendar: () => unawaited(_startCalendarConnection()),
            onChooseCalendars: () => unawaited(_editCalendarSelection()),
            onRefreshCalendar: () => unawaited(_refreshCalendar()),
            onDisconnectCalendar: () => unawaited(_disconnectCalendar()),
            onManageTaskCategories: () => unawaited(_openTaskCategories()),
            organizerSettings: _organizerSettings,
            onOrganizerSettings: (settings) =>
                unawaited(_changeOrganizerSettings(settings)),
            onTestReminder: () => unawaited(_sendReminderTest()),
            notificationPermissionGranted: _notificationPermissionGranted,
            onOpenNotificationSettings: _openNotificationSettings,
            onRetrySync: _retryAllPendingSync,
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
