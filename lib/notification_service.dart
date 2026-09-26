import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_schedule.dart';
import 'task_item.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _taskDigestChannel = MethodChannel('dzien_po_dniu/task_digest');
  var _isInitialized = false;
  void Function(NotificationResponse response)? onResponse;
  NotificationResponse? _launchResponse;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: 'Dniówka',
          appUserModelId: 'pl.dzienpodniu.taskapp',
          guid: 'b6ce9851-cad2-45c4-903a-c93e236173e6',
        ),
      ),
      onDidReceiveNotificationResponse: _dispatchResponse,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _launchResponse = launchDetails?.notificationResponse;
    }
    _isInitialized = true;
  }

  /// Returns an action that launched a cold application exactly once.
  Future<NotificationResponse?> consumeLaunchResponse() async {
    final response = _launchResponse;
    _launchResponse = null;
    return response;
  }

  void _dispatchResponse(NotificationResponse response) {
    final callback = onResponse;
    if (callback == null) {
      _launchResponse = response;
    } else {
      callback(response);
    }
  }

  /// Requests notification permission only when the user has enabled a
  /// reminder setting. Android 14 exact alarms remain optional; all regular
  /// reminders use the safe inexact fallback.
  Future<bool> requestPermissions({bool exactAlarm = false}) async {
    if (!_isInitialized) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final notifications =
        await android.requestNotificationsPermission() ?? false;
    if (!notifications) return false;
    if (exactAlarm) {
      await android.requestExactAlarmsPermission();
    }
    return true;
  }

  /// Returns the current notification permission when the platform exposes
  /// it. A null value means the plugin is not initialized yet or the target
  /// does not provide a query API.
  Future<bool?> areNotificationsEnabled() async {
    if (!_isInitialized) return null;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return android.areNotificationsEnabled();
  }

  Future<void> openNotificationSettings() async {
    if (!_isInitialized) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.openAppNotificationSettings();
  }

  Future<void> showTestNotification() async {
    if (!_isInitialized) return;
    await _plugin.show(
      id: 'test'.hashCode,
      title: 'Przypomnienia działają',
      body: 'To jest testowe powiadomienie z Dniówki.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Przypomnienia o zadaniach',
          channelDescription: 'Przypomnienia o zaplanowanych zadaniach',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> showTaskDigest(List<TaskItem> tasks) async {
    if (!_isInitialized || tasks.isEmpty) return;
    final digest = formatTaskDigest(tasks);
    await _plugin.show(
      id: taskDigestNotificationId(0),
      title: digest.title,
      body: digest.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_digest',
          'Przypomnienia o zadaniach',
          channelDescription: 'Zbiorcze przypomnienia o zadaniach na dziś',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'task-digest',
    );
  }

  Future<void> scheduleDailyPlan({
    required bool enabled,
    required int hour,
    required int minute,
    required int pendingTaskCount,
  }) async {
    await cancelDailyPlan();
    if (!_isInitialized || pendingTaskCount == 0) return;
    final times = dailyPlanTimes(
      now: DateTime.now(),
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
    if (times.isEmpty) return;
    final body = pendingTaskCount == 1
        ? 'Masz 1 niewykonane zadanie.'
        : 'Masz $pendingTaskCount niewykonanych zadań.';
    for (var index = 0; index < times.length; index++) {
      await _plugin.zonedSchedule(
        id: dailyPlanNotificationIdForOccurrence(index),
        title: 'Plan na dziś',
        body: body,
        scheduledDate: tz.TZDateTime.from(times[index], tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_plan',
            'Plan dnia',
            channelDescription: 'Poranne przypomnienie o zadaniach',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'daily-plan',
      );
    }
  }

  Future<void> cancelDailyPlan() async {
    if (!_isInitialized) return;
    await Future.wait([
      for (var index = 0; index < dailyPlanOccurrenceCount; index++)
        _plugin.cancel(id: dailyPlanNotificationIdForOccurrence(index)),
    ]);
  }

  /// Schedules one grouped reminder per configured interval for a bounded
  /// rolling window. Existing notifications are replaced before rebuilding,
  /// so changing tasks or settings cannot leave duplicate alarms behind.
  Future<void> scheduleTaskDigest({
    required bool enabled,
    required int intervalMinutes,
    required int startMinute,
    required int endMinute,
    required List<TaskItem> tasks,
  }) async {
    if (Platform.isAndroid) {
      await _taskDigestChannel.invokeMethod<void>('schedule', {
        'enabled': enabled,
        'interval': intervalMinutes,
        'start': startMinute,
        'end': endMinute,
      });
      return;
    }
    await cancelTaskDigest();
    if (!_isInitialized || !enabled) return;
    final eligible = tasksForTaskDigest(tasks, now: DateTime.now());
    if (eligible.isEmpty) return;
    final times = taskDigestTimes(
      now: DateTime.now(),
      intervalMinutes: intervalMinutes,
      startMinute: startMinute,
      endMinute: endMinute,
    );
    if (times.isEmpty) return;
    final digest = formatTaskDigest(eligible);
    for (var index = 0; index < times.length; index++) {
      await _plugin.zonedSchedule(
        id: taskDigestNotificationId(index),
        title: digest.title,
        body: digest.body,
        scheduledDate: tz.TZDateTime.from(times[index], tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_digest',
            'Przypomnienia o zadaniach',
            channelDescription: 'Zbiorcze przypomnienia o zadaniach na dziś',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task-digest',
      );
    }
  }

  Future<void> cancelTaskDigest() async {
    if (Platform.isAndroid) {
      await _taskDigestChannel.invokeMethod<void>('cancel');
      return;
    }
    if (!_isInitialized) return;
    await Future.wait([
      for (var index = 0; index < taskDigestOccurrenceCount; index++)
        _plugin.cancel(id: taskDigestNotificationId(index)),
    ]);
  }

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime when,
  }) async {
    if (!_isInitialized) return;
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: taskId.hashCode,
      title: 'Przypomnienie o zadaniu',
      body: title,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Przypomnienia o zadaniach',
          channelDescription: 'Przypomnienia o zaplanowanych zadaniach',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'done',
              'Zrobione',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'snooze',
              'Odłóż',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: taskId,
    );
  }

  /// Schedules a bounded window of reminders after a task becomes overdue.
  ///
  /// One-shot alarms are used instead of a platform repeating alarm so the
  /// first reminder can start exactly at due time + interval. The window is
  /// rebuilt on resume and after task/settings changes.
  Future<void> scheduleOverdueTaskReminders({
    required String taskId,
    required String title,
    required DateTime dueAt,
    required int intervalMinutes,
  }) async {
    await cancelOverdueTaskReminders(taskId);
    if (!_isInitialized) return;
    final times = overdueReminderTimes(
      dueAt: dueAt,
      intervalMinutes: intervalMinutes,
    );
    if (times.isEmpty) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Przypomnienia o zadaniach',
        channelDescription: 'Przypomnienia o zaplanowanych zadaniach',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            'done',
            'Zrobione',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'snooze',
            'Odłóż',
            showsUserInterface: true,
          ),
        ],
      ),
    );
    for (var index = 0; index < times.length; index++) {
      await _plugin.zonedSchedule(
        id: overdueReminderNotificationId(taskId, index),
        title: 'Zaległe zadanie',
        body: title,
        scheduledDate: tz.TZDateTime.from(times[index], tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: taskId,
      );
    }
  }

  Future<void> cancelOverdueTaskReminders(String taskId) async {
    if (!_isInitialized) return;
    await Future.wait([
      for (var index = 0; index < overdueReminderOccurrenceCount; index++)
        _plugin.cancel(id: overdueReminderNotificationId(taskId, index)),
    ]);
  }

  Future<void> schedule({
    required String taskId,
    required String title,
    required DateTime when,
  }) => scheduleTaskReminder(taskId: taskId, title: title, when: when);

  Future<void> scheduleNoteReminder({
    required String noteId,
    required String title,
    required DateTime when,
  }) async {
    if (!_isInitialized) return;
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _noteNotificationId(noteId),
      title: 'Przypomnienie o notatce',
      body: title,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'note_reminders',
          'Przypomnienia o notatkach',
          channelDescription:
              'Jednorazowe przypomnienia zapisane przy notatkach',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'note:$noteId',
    );
  }

  Future<void> scheduleCostReminder({
    required String id,
    required String title,
    required int amountCents,
    required DateTime when,
    required int daysBefore,
  }) async {
    if (!_isInitialized || !when.isAfter(DateTime.now())) return;
    final amount = (amountCents / 100).toStringAsFixed(2).replaceAll('.', ',');
    await _plugin.zonedSchedule(
      id: costReminderNotificationId(id, daysBefore),
      title: 'Zbliża się płatność: $title',
      body:
          '$amount zł · płatność za $daysBefore ${daysBefore == 1 ? 'dzień' : 'dni'}',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cost_reminders',
          'Przypomnienia o płatnościach',
          channelDescription:
              'Przypomnienia o nadchodzących kosztach i subskrypcjach',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'cost:$id',
    );
  }

  Future<void> cancelCostReminders(String id) async {
    if (!_isInitialized) return;
    await Future.wait([
      _plugin.cancel(id: costReminderNotificationId(id, 3)),
      _plugin.cancel(id: costReminderNotificationId(id, 1)),
    ]);
  }

  Future<void> cancel(String taskId) async {
    if (!_isInitialized) return;
    await Future.wait([
      _plugin.cancel(id: taskId.hashCode),
      cancelOverdueTaskReminders(taskId),
    ]);
  }

  Future<void> cancelNote(String noteId) async {
    if (_isInitialized) await _plugin.cancel(id: _noteNotificationId(noteId));
  }

  Future<void> scheduleFocusSessionEnd({
    required String taskId,
    required String title,
    required DateTime when,
  }) async {
    if (!_isInitialized || !when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: focusNotificationId(taskId),
      title: 'Sesja skupienia zakończona',
      body: title,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_sessions',
          'Sesje skupienia',
          channelDescription: 'Powiadomienia o końcu sesji skupienia',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'focus:$taskId',
    );
  }

  Future<void> cancelFocusSession(String taskId) async {
    if (_isInitialized) await _plugin.cancel(id: focusNotificationId(taskId));
  }
}

int _noteNotificationId(String noteId) => noteId.hashCode ^ 0x4e4f5445;
int focusNotificationId(String taskId) => taskId.hashCode ^ 0x464f4355;
int costReminderNotificationId(String id, int daysBefore) =>
    id.hashCode ^ 0x434f5354 ^ daysBefore;
const dailyPlanNotificationId = 0x4441494c;

int dailyPlanNotificationIdForOccurrence(int occurrence) =>
    dailyPlanNotificationId ^ occurrence;
const taskDigestOccurrenceCount = 96;
int taskDigestNotificationId(int occurrence) => 0x54444700 ^ occurrence;
