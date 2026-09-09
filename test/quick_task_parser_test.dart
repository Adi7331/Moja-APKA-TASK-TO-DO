import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/quick_task_parser.dart';

void main() {
  final now = DateTime(2026, 9, 6, 16, 20);

  test('keeps a plain quick task unchanged', () {
    final result = parseQuickTask('Kupić mleko', now);

    expect(result.title, 'Kupić mleko');
    expect(result.dueAt, isNull);
  });

  test('recognizes today with a 09:00 default', () {
    final result = parseQuickTask('Wysłać fakturę dziś', now);

    expect(result.title, 'Wysłać fakturę');
    expect(result.dueAt, DateTime(2026, 9, 6, 9));
  });

  test('recognizes tomorrow with a supplied time', () {
    final result = parseQuickTask('Zadzwonić do Marka jutro 18:30', now);

    expect(result.title, 'Zadzwonić do Marka');
    expect(result.dueAt, DateTime(2026, 9, 7, 18, 30));
  });

  test('recognizes next Monday with a 09:00 default', () {
    final result = parseQuickTask('Plan tygodnia w poniedziałek', now);

    expect(result.title, 'Plan tygodnia');
    expect(result.dueAt, DateTime(2026, 9, 7, 9));
  });
}
