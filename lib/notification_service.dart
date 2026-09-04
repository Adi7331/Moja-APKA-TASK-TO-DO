import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  var _isInitialized = false;

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
    );
    _isInitialized = true;
  }

  Future<void> scheduleTaskReminder({required String taskId, required String title, required DateTime when}) async {
    if (!_isInitialized) return;
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(id: taskId.hashCode, title: 'Przypomnienie o zadaniu', body: title, scheduledDate: tz.TZDateTime.from(when, tz.local), notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('task_reminders', 'Przypomnienia o zadaniach', channelDescription: 'Przypomnienia o zaplanowanych zadaniach', importance: Importance.high, priority: Priority.high, actions: [AndroidNotificationAction('done', 'Zrobione'), AndroidNotificationAction('snooze', 'Odłóż')])), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: taskId);
  }

  Future<void> schedule({required String taskId, required String title, required DateTime when}) =>
      scheduleTaskReminder(taskId: taskId, title: title, when: when);

  Future<void> cancel(String taskId) async {
    if (_isInitialized) await _plugin.cancel(id: taskId.hashCode);
  }
}
