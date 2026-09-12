import 'package:dzien_po_dniu/suggestion_engine.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suggests planning two tasks when six tasks have no deadline', () {
    final tasks = List.generate(
      6,
      (index) =>
          TaskItem(id: '$index', title: 'Zadanie $index', status: 'todo'),
    );

    final suggestions = SuggestionEngine().build(tasks, DateTime(2026, 9, 11));

    expect(suggestions.single.id, 'tasks-without-deadline');
    expect(suggestions.single.title, 'Zaplanuj 2 zadania na ten tydzień');
  });
}
