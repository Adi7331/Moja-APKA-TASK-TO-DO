import 'task_item.dart';

class OrganizerSuggestion {
  const OrganizerSuggestion({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class SuggestionEngine {
  const SuggestionEngine();

  List<OrganizerSuggestion> build(List<TaskItem> tasks, DateTime now) {
    final suggestions = <OrganizerSuggestion>[];
    final open = tasks.where((task) => !task.isDone).toList();
    final withoutDeadline = open.where((task) => task.dueAt == null).length;
    if (withoutDeadline >= 6) {
      suggestions.add(
        const OrganizerSuggestion(
          id: 'tasks-without-deadline',
          title: 'Zaplanuj 2 zadania na ten tydzień',
          description: 'Masz co najmniej 6 zadań bez terminu.',
        ),
      );
    }
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final today = open.where((task) {
      final dueAt = task.dueAt;
      return dueAt != null &&
          !dueAt.isBefore(dayStart) &&
          dueAt.isBefore(dayEnd);
    }).length;
    if (today >= 6) {
      suggestions.add(
        const OrganizerSuggestion(
          id: 'crowded-day',
          title: 'Dzisiaj masz napięty plan',
          description: 'Wybierz maksymalnie 3 najważniejsze zadania.',
        ),
      );
    }
    final inProgress = open
        .where((task) => task.status == 'in_progress')
        .length;
    if (inProgress >= 4) {
      suggestions.add(
        const OrganizerSuggestion(
          id: 'too-many-in-progress',
          title: 'Masz dużo zadań w toku',
          description: 'Domknij jedno zadanie, zanim rozpoczniesz kolejne.',
        ),
      );
    }
    return suggestions;
  }
}
