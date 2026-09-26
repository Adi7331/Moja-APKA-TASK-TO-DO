import 'package:dzien_po_dniu/organizer_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'organizer settings preserve reminder defaults and Monday review time',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = OrganizerSettingsStore(
        await SharedPreferences.getInstance(),
      );
      const expected = OrganizerSettings(
        defaultReminderMinutes: 30,
        defaultSnoozeMinutes: 60,
        weeklyReviewHour: 0,
        weeklyReviewMinute: 0,
        dailyPlanEnabled: true,
        dailyPlanHour: 8,
        dailyPlanMinute: 15,
        overdueReminderIntervalMinutes: 60,
      );

      await store.save(expected);

      expect(await store.load(), expected);
    },
  );

  test('keeps new reminder features disabled by default', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OrganizerSettingsStore(await SharedPreferences.getInstance());

    final settings = await store.load();

    expect(settings.dailyPlanEnabled, isFalse);
    expect(settings.overdueReminderIntervalMinutes, 0);
    expect(settings.taskRemindersEnabled, isFalse);
    expect(settings.taskReminderIntervalMinutes, 60);
    expect(settings.taskReminderStartMinute, 9 * 60);
    expect(settings.taskReminderEndMinute, 21 * 60);
    expect(settings.windowsStartWithSystem, isFalse);
  });

  test('persists device-local task digest schedule', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OrganizerSettingsStore(await SharedPreferences.getInstance());
    const expected = OrganizerSettings(
      taskRemindersEnabled: true,
      taskReminderIntervalMinutes: 45,
      taskReminderStartMinute: 8 * 60 + 30,
      taskReminderEndMinute: 23 * 60,
      windowsStartWithSystem: true,
    );

    await store.save(expected);

    expect(await store.load(), expected);
  });
}
