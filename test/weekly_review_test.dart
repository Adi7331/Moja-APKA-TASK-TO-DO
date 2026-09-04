import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/weekly_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previous-week review excludes a completion after Monday midnight', () {
    final review = buildWeeklyReview([
      TaskItem(
        id: 'last-week',
        title: 'Raport',
        status: 'done',
        completedAt: DateTime(2026, 9, 6, 22),
      ),
      TaskItem(
        id: 'this-week',
        title: 'Plan',
        status: 'done',
        completedAt: DateTime(2026, 9, 7, 0, 1),
      ),
      TaskItem(
        id: 'late',
        title: 'Faktura',
        status: 'todo',
        dueAt: DateTime(2026, 9, 5, 12),
      ),
      TaskItem(
        id: 'soon',
        title: 'Telefon',
        status: 'todo',
        dueAt: DateTime(2026, 9, 8, 9),
      ),
    ], DateTime(2026, 9, 7, 10));

    expect(review.weekStart, DateTime(2026, 8, 31));
    expect(review.completedCount, 1);
    expect(review.overdue.single.title, 'Faktura');
    expect(review.nextDue.single.title, 'Telefon');
  });
}
