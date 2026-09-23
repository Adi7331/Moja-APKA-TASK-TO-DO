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
  });

  final int defaultReminderMinutes;
  final int defaultSnoozeMinutes;
  final int weeklyReviewHour;
  final int weeklyReviewMinute;
  final bool dailyPlanEnabled;
  final int dailyPlanHour;
  final int dailyPlanMinute;
  final int overdueReminderIntervalMinutes;

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
      other.overdueReminderIntervalMinutes == overdueReminderIntervalMinutes;

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
    ]);
  }
}
