import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dzien_po_dniu/work_hours.dart';
import 'package:dzien_po_dniu/work_hours_store.dart';

WorkEntry entry(
  String id, {
  int end = 17 * 60,
  int pause = 0,
  bool paid = false,
  bool overnight = false,
  int start = 8 * 60,
  int rate = 4000,
}) => WorkEntry(
  id: id,
  date: DateTime(2026, 9, 10),
  name: 'Ferroli',
  place: 'Kraków',
  startMinute: start,
  endMinute: end,
  breakMinutes: pause,
  nextDay: overnight,
  rateCents: rate,
  paid: paid,
  updatedAt: DateTime.utc(2026, 9, 10),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'acknowledging an older upload cannot erase a newer queued edit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = WorkHoursStore(
        await SharedPreferences.getInstance(),
        'owner',
      );
      await store.put(entry('a'));
      final old = store.pending.single;
      await store.put(entry('a', paid: true));
      await store.acknowledge(old);
      expect(store.pending.length, 1);
      expect(store.entries.single.paid, true);
    },
  );
  test(
    'remote deletion removes cached entry and undo is a fresh mutation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = WorkHoursStore(
        await SharedPreferences.getInstance(),
        'owner',
      );
      final original = entry('a');
      await store.put(original);
      expect(store.pending.single['payload']['restore_requested'], false);
      await store.acknowledge(store.pending.single);
      final tombstone = original.toJson()
        ..['deleted_at'] = DateTime.now().toUtc().toIso8601String();
      await store.mergeRemote([tombstone], null);
      expect(store.entries, isEmpty);
      await store.restore(original);
      expect(store.entries.single.updatedAt.isAfter(original.updatedAt), true);
      expect(store.pending.single['payload']['deleted_at'], isNull);
      expect(store.pending.single['payload']['restore_requested'], true);
    },
  );
  test('calculates minutes and integer cents including unpaid break', () {
    final item = entry('a', pause: 30);
    expect(item.workMinutes, 510);
    expect(item.amountCents, 34000);
  });
  test('overnight requires explicit next day and rejects invalid breaks', () {
    expect(entry('a', start: 22 * 60, end: 6 * 60).validationError, isNotNull);
    expect(
      entry('a', start: 22 * 60, end: 6 * 60, overnight: true).workMinutes,
      480,
    );
    expect(entry('a', pause: 600).validationError, isNotNull);
  });
  test(
    'summary counts distinct dates and sums paid and outstanding amounts',
    () {
      final summary = WorkSummary([
        entry('a', paid: true),
        entry('b', end: 16 * 60),
      ]);
      expect(summary.days, 1);
      expect(summary.minutes, 1020);
      expect(summary.totalCents, 68000);
      expect(summary.paidCents, 36000);
      expect(summary.outstandingCents, 32000);
    },
  );
  test('per entry rounding and rate snapshot survive serialization', () {
    final item = entry('a', start: 0, end: 1, rate: 100);
    expect(item.amountCents, 2);
    final restored = WorkEntry.fromJson(item.toJson());
    expect(restored.rateCents, 100);
    expect(restored.amountCents, 2);
  });
  test(
    'local entry and delete outbox survive restart and isolate owners',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = WorkHoursStore(prefs, 'owner-a');
      await store.put(entry('a'));
      await store.remove('a');
      final restarted = WorkHoursStore(prefs, 'owner-a');
      expect(restarted.entries, isEmpty);
      expect(restarted.pending.single['deleted'], true);
      expect(WorkHoursStore(prefs, 'owner-b').pending, isEmpty);
      await restarted.mergeRemote([entry('a').toJson()], null);
      expect(restarted.entries, isEmpty);
    },
  );
}
