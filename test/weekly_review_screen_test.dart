import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/weekly_review.dart';
import 'package:dzien_po_dniu/weekly_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('weekly review presents its summary and daily-plan shortcut', (tester) async {
    await tester.pumpWidget(MaterialApp(home: WeeklyReviewScreen(
      review: WeeklyReview(
        weekStart: DateTime(2026, 8, 31), completedCount: 4,
        overdue: const [TaskItem(id: 'late', title: 'Faktura', status: 'todo')],
        nextDue: const [TaskItem(id: 'next', title: 'Telefon', status: 'todo')],
      ),
      onOpenDailyPlan: () {},
    )));
    expect(find.text('Ukończone w poprzednim tygodniu'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Faktura'), findsOneWidget);
    expect(find.text('Przejdź do planu dnia'), findsOneWidget);
  });
}
