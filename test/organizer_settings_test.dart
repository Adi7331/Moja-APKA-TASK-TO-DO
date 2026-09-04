import 'package:dzien_po_dniu/organizer_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('organizer settings preserve reminder defaults and Monday review time', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OrganizerSettingsStore(await SharedPreferences.getInstance());
    const expected = OrganizerSettings(
      defaultReminderMinutes: 30,
      defaultSnoozeMinutes: 60,
      weeklyReviewHour: 0,
      weeklyReviewMinute: 0,
    );

    await store.save(expected);

    expect(await store.load(), expected);
  });
}
