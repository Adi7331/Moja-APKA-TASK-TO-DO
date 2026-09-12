import 'package:dzien_po_dniu/calendar_event.dart';
import 'package:dzien_po_dniu/calendar_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'calendar store keeps selection and cached events for offline planning',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CalendarStore(await SharedPreferences.getInstance());
      final event = CalendarEvent(
        id: 'event-1',
        calendarId: 'primary',
        title: 'Dentysta',
        startsAt: DateTime(2026, 9, 11, 14),
        endsAt: DateTime(2026, 9, 11, 15),
        isAllDay: false,
      );

      await store.saveSelection(['primary', 'work']);
      await store.saveCache([event], DateTime.utc(2026, 9, 11, 12));

      expect(await store.loadSelection(), ['primary', 'work']);
      final cache = await store.loadCache();
      expect(cache.lastSyncedAt, DateTime.utc(2026, 9, 11, 12));
      expect(cache.events.single.title, 'Dentysta');
    },
  );
}
