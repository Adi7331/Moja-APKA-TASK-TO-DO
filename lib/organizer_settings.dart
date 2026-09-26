import 'package:shared_preferences/shared_preferences.dart';

class OrganizerSettings {
  const OrganizerSettings({
    this.defaultReminderMinutes = 0,
    this.defaultSnoozeMinutes = 15,
    this.weeklyReviewHour = 0,
    this.weeklyReviewMinute = 0,
    this.dailyPlanEnabled = false,
    this.dailyPlanHour = 9,
    this.dailyPlanMinute = 0,
    this.overdueReminderIntervalMinutes = 0,
    this.taskRemindersEnabled = false,
    this.taskReminderIntervalMinutes = 60,
    this.taskReminderStartMinute = 9 * 60,
    this.taskReminderEndMinute = 21 * 60,
    this.windowsStartWithSystem = false,
  });

  final int defaultReminderMinutes;
  final int defaultSnoozeMinutes;
  final int weeklyReviewHour;
  final int weeklyReviewMinute;
  final bool dailyPlanEnabled;
  final int dailyPlanHour;
  final int dailyPlanMinute;
  final int overdueReminderIntervalMinutes;
  final bool taskRemindersEnabled;
  final int taskReminderIntervalMinutes;
  final int taskReminderStartMinute;
  final int taskReminderEndMinute;
  final bool windowsStartWithSystem;

  @override
  bool operator ==(Object other) =>
      other is OrganizerSettings &&
      other.defaultReminderMinutes == defaultReminderMinutes &&
      other.defaultSnoozeMinutes == defaultSnoozeMinutes &&
      other.weeklyReviewHour == weeklyReviewHour &&
      other.weeklyReviewMinute == weeklyReviewMinute &&
      other.dailyPlanEnabled == dailyPlanEnabled &&
      other.dailyPlanHour == dailyPlanHour &&
      other.dailyPlanMinute == dailyPlanMinute &&
      other.overdueReminderIntervalMinutes == overdueReminderIntervalMinutes &&
      other.taskRemindersEnabled == taskRemindersEnabled &&
      other.taskReminderIntervalMinutes == taskReminderIntervalMinutes &&
      other.taskReminderStartMinute == taskReminderStartMinute &&
      other.taskReminderEndMinute == taskReminderEndMinute &&
      other.windowsStartWithSystem == windowsStartWithSystem;

  @override
  int get hashCode => Object.hash(
    defaultReminderMinutes,
    defaultSnoozeMinutes,
    weeklyReviewHour,
    weeklyReviewMinute,
    dailyPlanEnabled,
    dailyPlanHour,
    dailyPlanMinute,
    overdueReminderIntervalMinutes,
    taskRemindersEnabled,
    taskReminderIntervalMinutes,
    taskReminderStartMinute,
    taskReminderEndMinute,
    windowsStartWithSystem,
  );
}

class OrganizerSettingsStore {
  OrganizerSettingsStore(this._preferences);
  final SharedPreferences _preferences;

  static const _reminderKey = 'organizer_default_reminder_minutes';
  static const _snoozeKey = 'organizer_default_snooze_minutes';
  static const _reviewHourKey = 'organizer_weekly_review_hour';
  static const _reviewMinuteKey = 'organizer_weekly_review_minute';
  static const _dailyPlanEnabledKey = 'organizer_daily_plan_enabled';
  static const _dailyPlanHourKey = 'organizer_daily_plan_hour';
  static const _dailyPlanMinuteKey = 'organizer_daily_plan_minute';
  static const _overdueIntervalKey = 'organizer_overdue_interval_minutes';
  static const _taskRemindersEnabledKey = 'organizer_task_reminders_enabled';
  static const _taskReminderIntervalKey = 'organizer_task_reminder_interval';
  static const _taskReminderStartKey = 'organizer_task_reminder_start';
  static const _taskReminderEndKey = 'organizer_task_reminder_end';
  static const _windowsStartKey = 'organizer_windows_start_with_system';

  Future<OrganizerSettings> load() async => OrganizerSettings(
    defaultReminderMinutes: _preferences.getInt(_reminderKey) ?? 0,
    defaultSnoozeMinutes: _preferences.getInt(_snoozeKey) ?? 15,
    weeklyReviewHour: _preferences.getInt(_reviewHourKey) ?? 0,
    weeklyReviewMinute: _preferences.getInt(_reviewMinuteKey) ?? 0,
    dailyPlanEnabled: _preferences.getBool(_dailyPlanEnabledKey) ?? false,
    dailyPlanHour: _preferences.getInt(_dailyPlanHourKey) ?? 9,
    dailyPlanMinute: _preferences.getInt(_dailyPlanMinuteKey) ?? 0,
    overdueReminderIntervalMinutes:
        _preferences.getInt(_overdueIntervalKey) ?? 0,
    taskRemindersEnabled:
        _preferences.getBool(_taskRemindersEnabledKey) ?? false,
    taskReminderIntervalMinutes:
        _preferences.getInt(_taskReminderIntervalKey) ?? 60,
    taskReminderStartMinute:
        _preferences.getInt(_taskReminderStartKey) ?? 9 * 60,
    taskReminderEndMinute: _preferences.getInt(_taskReminderEndKey) ?? 21 * 60,
    windowsStartWithSystem: _preferences.getBool(_windowsStartKey) ?? false,
  );

  Future<void> save(OrganizerSettings settings) async {
    await Future.wait([
      _preferences.setInt(_reminderKey, settings.defaultReminderMinutes),
      _preferences.setInt(_snoozeKey, settings.defaultSnoozeMinutes),
      _preferences.setInt(_reviewHourKey, settings.weeklyReviewHour),
      _preferences.setInt(_reviewMinuteKey, settings.weeklyReviewMinute),
      _preferences.setBool(_dailyPlanEnabledKey, settings.dailyPlanEnabled),
      _preferences.setInt(_dailyPlanHourKey, settings.dailyPlanHour),
      _preferences.setInt(_dailyPlanMinuteKey, settings.dailyPlanMinute),
      _preferences.setInt(
        _overdueIntervalKey,
        settings.overdueReminderIntervalMinutes,
      ),
      _preferences.setBool(
        _taskRemindersEnabledKey,
        settings.taskRemindersEnabled,
      ),
      _preferences.setInt(
        _taskReminderIntervalKey,
        settings.taskReminderIntervalMinutes,
      ),
      _preferences.setInt(
        _taskReminderStartKey,
        settings.taskReminderStartMinute,
      ),
      _preferences.setInt(_taskReminderEndKey, settings.taskReminderEndMinute),
      _preferences.setBool(_windowsStartKey, settings.windowsStartWithSystem),
    ]);
  }
}
