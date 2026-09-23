import 'package:dzien_po_dniu/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly rule selects the next chosen weekday after completion', () {
    const rule = RepeatRule(
      unit: RepeatUnit.week,
      interval: 1,
      weekdays: {1, 4},
    );

    expect(
      rule.nextDueDate(DateTime(2026, 9, 1, 9)),
      DateTime(2026, 9, 3, 9),
    );
  });

  test('a rule serializes to the database shape', () {
    const rule = RepeatRule(unit: RepeatUnit.day, interval: 3);

    expect(rule.toJson(), {
      'unit': 'day',
      'interval': 3,
      'weekdays': <int>[],
    });
  });
}
