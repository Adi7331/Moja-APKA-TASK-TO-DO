/// Small, platform-neutral payload used to keep Android widgets in sync.
///
/// The native side only receives the minimum data needed to render the two
/// widgets. Keeping this model independent from Flutter widgets also makes it
/// safe to test and to use on Windows (where the bridge is a no-op).
class WidgetTaskData {
  const WidgetTaskData({
    required this.id,
    required this.title,
    required this.isDone,
  });

  final String id;
  final String title;
  final bool isDone;
}

class WidgetNoteData {
  const WidgetNoteData({
    required this.id,
    required this.title,
    required this.preview,
  });

  final String id;
  final String title;
  final String preview;
}

class AndroidWidgetSnapshot {
  const AndroidWidgetSnapshot({
    required this.todayTasks,
    required this.remainingTaskCount,
    required this.selectedNote,
  });

  factory AndroidWidgetSnapshot.fromData({
    required List<WidgetTaskData> tasks,
    required WidgetNoteData? selectedNote,
  }) {
    final pendingTasks = tasks.where((task) => !task.isDone).toList();
    return AndroidWidgetSnapshot(
      todayTasks: pendingTasks.take(3).toList(growable: false),
      remainingTaskCount: pendingTasks.length,
      selectedNote: selectedNote,
    );
  }

  final List<WidgetTaskData> todayTasks;
  final int remainingTaskCount;
  final WidgetNoteData? selectedNote;

  Map<String, dynamic> toChannelPayload() {
    return <String, dynamic>{
      'remainingTaskCount': remainingTaskCount,
      'tasks': todayTasks
          .map(
            (task) => <String, dynamic>{
              'id': task.id,
              'title': task.title,
            },
          )
          .toList(growable: false),
      'selectedNote': selectedNote == null
          ? null
          : <String, dynamic>{
              'id': selectedNote!.id,
              'title': selectedNote!.title,
              'preview': selectedNote!.preview,
            },
    };
  }
}
