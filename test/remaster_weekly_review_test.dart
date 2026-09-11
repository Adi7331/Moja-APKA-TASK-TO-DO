import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/remaster_weekly_review.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/weekly_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'remastered weekly review gives the completed week a clear date range',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRemasterTheme(Brightness.dark),
          home: RemasterWeeklyReviewScreen(
            review: WeeklyReview(
              weekStart: DateTime(2026, 8, 31),
              completedCount: 4,
              overdue: const [
                TaskItem(id: 'late', title: 'Faktura', status: 'todo'),
              ],
              nextDue: const [
                TaskItem(id: 'next', title: 'Telefon', status: 'todo'),
              ],
            ),
            onOpenDailyPlan: () {},
          ),
        ),
      );

      expect(find.text('31 sierpnia – 6 września'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Faktura'), findsOneWidget);
    },
  );
}
