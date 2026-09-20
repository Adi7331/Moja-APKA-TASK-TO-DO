import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_schedule.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
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
          appName: 'Dzień po dniu',
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
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final notifications = await android.requestNotificationsPermission() ??
        false;
    if (!notifications) return false;
    if (exactAlarm) {
      await android.requestExactAlarmsPermission();
    }
    return true;
  }

  Future<void> showTestNotification() async {
    if (!_isInitialized) return;
    await _plugin.show(
      id: 'test'.hashCode,
      title: 'Przypomnienia działają',
      body: 'To jest testowe powiadomienie z Dzień po dniu.',
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

  Future<void> scheduleDailyPlan({
    required bool enabled,
    required int hour,
    required int minute,
    required int pendingTaskCount,
  }) async {
    await cancelDailyPlan();
    if (!_isInitialized || pendingTaskCount == 0) return;
    final when = nextDailyPlanAt(
      now: DateTime.now(),
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
    if (when == null) return;
    await _plugin.zonedSchedule(
      id: dailyPlanNotificationId,
      title: 'Plan na dziś',
      body: pendingTaskCount == 1
          ? 'Masz 1 niewykonane zadanie.'
          : 'Masz $pendingTaskCount niewykonanych zadań.',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
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

  Future<void> cancelDailyPlan() async {
    if (_isInitialized) await _plugin.cancel(id: dailyPlanNotificationId);
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

  Future<void> cancel(String taskId) async {
    if (_isInitialized) await _plugin.cancel(id: taskId.hashCode);
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
const dailyPlanNotificationId = 0x4441494c;
