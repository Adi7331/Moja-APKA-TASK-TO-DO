import 'package:shared_preferences/shared_preferences.dart';

class OrganizerSettings {
  const OrganizerSettings({
    this.defaultReminderMinutes = 0,
    this.defaultSnoozeMinutes = 15,
    this.weeklyReviewHour = 0,
    this.weeklyReviewMinute = 0,
  });

  final int defaultReminderMinutes;
  final int defaultSnoozeMinutes;
  final int weeklyReviewHour;
  final int weeklyReviewMinute;

  @override
  bool operator ==(Object other) =>
      other is OrganizerSettings &&
      other.defaultReminderMinutes == defaultReminderMinutes &&
      other.defaultSnoozeMinutes == defaultSnoozeMinutes &&
      other.weeklyReviewHour == weeklyReviewHour &&
      other.weeklyReviewMinute == weeklyReviewMinute;

  @override
  int get hashCode => Object.hash(
        defaultReminderMinutes,
        defaultSnoozeMinutes,
        weeklyReviewHour,
        weeklyReviewMinute,
      );
}

class OrganizerSettingsStore {
  OrganizerSettingsStore(this._preferences);
  final SharedPreferences _preferences;

  static const _reminderKey = 'organizer_default_reminder_minutes';
  static const _snoozeKey = 'organizer_default_snooze_minutes';
  static const _reviewHourKey = 'organizer_weekly_review_hour';
  static const _reviewMinuteKey = 'organizer_weekly_review_minute';

  Future<OrganizerSettings> load() async => OrganizerSettings(
        defaultReminderMinutes: _preferences.getInt(_reminderKey) ?? 0,
        defaultSnoozeMinutes: _preferences.getInt(_snoozeKey) ?? 15,
        weeklyReviewHour: _preferences.getInt(_reviewHourKey) ?? 0,
        weeklyReviewMinute: _preferences.getInt(_reviewMinuteKey) ?? 0,
      );

  Future<void> save(OrganizerSettings settings) async {
    await Future.wait([
      _preferences.setInt(_reminderKey, settings.defaultReminderMinutes),
      _preferences.setInt(_snoozeKey, settings.defaultSnoozeMinutes),
      _preferences.setInt(_reviewHourKey, settings.weeklyReviewHour),
      _preferences.setInt(_reviewMinuteKey, settings.weeklyReviewMinute),
    ]);
  }
}
