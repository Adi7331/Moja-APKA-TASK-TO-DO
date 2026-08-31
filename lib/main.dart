import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_task_store.dart';
import 'task_sync_service.dart';
import 'notification_service.dart';
import 'task_item.dart';
import 'app_theme.dart';
import 'task_editor.dart';
import 'today_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool localMode = false;
  bool cloudMode = false;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String? _successNotice;
  final _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _noticeTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _taskSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _subtaskSubscription;
  var _nextLocalTaskId = 4;
  LocalTaskStore? _localStore;
  final tasks = <TaskItem>[
    const TaskItem(id: 'local-1', title: 'Wykosić trawnik', status: 'todo', category: 'Dom'),
    const TaskItem(id: 'local-2', title: 'Poprawić grafikę', status: 'todo', category: 'Praca'),
    const TaskItem(id: 'local-3', title: 'Kreacje do reklamy', status: 'todo', category: 'Praca'),
  ];
  late final TaskSyncService _sync = TaskSyncService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _restoreLocalTasks();
  }

  Future<void> _restoreLocalTasks() async {
    final store = LocalTaskStore(await SharedPreferences.getInstance());
    final storedTasks = await store.load();
    if (!mounted) return;
    setState(() {
      _localStore = store;
      if (storedTasks.isNotEmpty) {
        tasks
          ..clear()
          ..addAll(storedTasks);
        _nextLocalTaskId = tasks.length + 1;
      }
    });
  }

  Future<void> _saveLocalTasks() async {
    if (!cloudMode) await _localStore?.save(tasks);
  }

  Future<void> _loadCloudTasks() async {
    final rows = await _sync.loadTasks();
    final cloudTasks = await Future.wait(rows.map((row) async {
      final subtasks = await _sync.loadSubtasks(row['id'] as String);
      return TaskItem.fromRow({...row, 'subtasks': subtasks});
    }));
    if (!mounted) return;
    setState(() {
      tasks
        ..clear()
        ..addAll(cloudTasks);
    });
  }

  Future<void> _enterCloudMode() async {
    setState(() { localMode = true; cloudMode = true; });
    await _loadCloudTasks();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await _taskSubscription?.cancel();
    _taskSubscription = Supabase.instance.client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((_) => _loadCloudTasks());
    await _subtaskSubscription?.cancel();
    _subtaskSubscription = Supabase.instance.client
        .from('subtasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((_) => _loadCloudTasks());
  }

  Future<void> _showTaskForm(BuildContext context, {TaskItem? task}) async {
    final modalContext = _navigatorKey.currentContext;
    if (modalContext == null) return;
    var saved = false;
    await showTaskEditor(
      modalContext,
      task: task,
      onSave: (draft) async {
        late final String taskId;
        if (task != null) {
          taskId = task.id;
          if (cloudMode) {
            await _sync.updateTask(
              taskId,
              title: draft.title,
              note: draft.note,
              category: draft.category,
              priority: draft.priority,
              dueAt: draft.dueAt,
            );
            final originalSteps = {for (final item in task.subtasks) item.id: item};
            final editedSteps = {for (final item in draft.subtasks) item.id: item};
            for (final removed in originalSteps.keys.where((id) => !editedSteps.containsKey(id))) {
              await _sync.deleteSubtask(removed);
            }
            for (final step in draft.subtasks) {
              final original = originalSteps[step.id];
              if (original == null) {
                await _sync.addSubtask(taskId, step.title, step.position);
              } else if (original.isDone != step.isDone) {
                await _sync.setSubtaskDone(step.id, step.isDone);
              }
            }
            await _loadCloudTasks();
          } else {
            setState(() {
              final index = tasks.indexOf(task);
              tasks[index] = task.copyWith(
                title: draft.title,
                note: draft.note,
                category: draft.category,
                priority: draft.priority,
                dueAt: draft.dueAt,
                subtasks: draft.subtasks,
              );
            });
            await _saveLocalTasks();
          }
        } else if (cloudMode) {
          final row = await _sync.addTask(
            draft.title,
            note: draft.note,
            category: draft.category,
            priority: draft.priority,
            dueAt: draft.dueAt,
          );
          taskId = row['id'] as String;
          for (final step in draft.subtasks) {
            await _sync.addSubtask(taskId, step.title, step.position);
          }
          await _loadCloudTasks();
        } else {
          taskId = 'local-${_nextLocalTaskId++}';
          setState(() => tasks.add(TaskItem(
                id: taskId,
                title: draft.title,
                status: 'todo',
                note: draft.note,
                category: draft.category,
                priority: draft.priority,
                dueAt: draft.dueAt,
                subtasks: draft.subtasks,
              )));
          await _saveLocalTasks();
        }
        await NotificationService.instance.cancel(taskId);
        if (draft.dueAt != null) {
          await NotificationService.instance.schedule(
            taskId: taskId,
            title: draft.title,
            when: draft.dueAt!,
          );
        }
        saved = true;
      },
    );
    if (saved) _showSuccessNotice();
  }

  void _showSuccessNotice() {
    _noticeTimer?.cancel();
    setState(() => _successNotice = 'Zapisano zadanie');
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _successNotice = null);
    });
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    _subtaskSubscription?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  Future<void> _changeTaskStatus(TaskItem task, String status) async {
    if (cloudMode) {
      await _sync.setStatus(task.id, status);
      await _loadCloudTasks();
      return;
    }
    setState(() {
      final index = tasks.indexOf(task);
      tasks[index] = task.copyWith(status: status);
    });
    await _saveLocalTasks();
  }

  Future<void> _confirmDeleteTask(BuildContext context, TaskItem task) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć zadanie?'),
        content: Text('„${task.title}” zniknie z Twojej listy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Usuń')),
        ],
      ),
    );
    if (accepted != true) return;
    if (cloudMode) {
      await _sync.deleteTask(task.id);
      await _loadCloudTasks();
    } else {
      setState(() => tasks.remove(task));
      await _saveLocalTasks();
    }
    await NotificationService.instance.cancel(task.id);
  }

  List<TaskItem> get _visibleTasks {
    final query = _searchQuery.trim().toLowerCase();
    return tasks
        .where((task) => _statusFilter == 'all' || task.status == _statusFilter)
        .where((task) => query.isEmpty ||
            task.title.toLowerCase().contains(query) ||
            task.note.toLowerCase().contains(query))
        .toList();
  }

  List<TaskItem> get _laterTasks {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    return _visibleTasks
        .where((task) => task.dueAt != null && task.dueAt!.isAfter(endOfToday))
        .toList();
  }

  List<TaskItem> get _todayTasks {
    final laterIds = _laterTasks.map((task) => task.id).toSet();
    return _visibleTasks.where((task) => !laterIds.contains(task.id)).toList();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: _navigatorKey,
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    home: localMode
        ? TodayScreen(
            visibleTasks: _todayTasks,
            laterTasks: _laterTasks,
            successNotice: _successNotice,
            searchQuery: _searchQuery,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            selectedFilter: _statusFilter,
            onFilterChanged: (value) => setState(() => _statusFilter = value),
            onOpenTask: (task) => _showTaskForm(context, task: task),
            onCompleteTask: (task) => _changeTaskStatus(task, 'done'),
            onStatusSelected: (task, status) => _changeTaskStatus(task, status),
            onDeleteTask: (task) => _confirmDeleteTask(context, task),
            onQuickAdd: () => _showTaskForm(context),
          )
        : _LoginPage(onLocalMode: () => setState(() => localMode = true), onSignedIn: _enterCloudMode),
  );
}

class _LoginPage extends StatelessWidget {
  const _LoginPage({required this.onLocalMode, required this.onSignedIn});
  final VoidCallback onLocalMode;
  final Future<void> Function() onSignedIn;
  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final password = TextEditingController();
    return Scaffold(
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.check_circle_outline, size: 56), const SizedBox(height: 18),
        Text('Zaloguj się', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8), const Text('Synchronizuj zadania między telefonem i komputerem.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Adres e-mail', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Hasło', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton(onPressed: () async { await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text); if (Supabase.instance.client.auth.currentSession != null) await onSignedIn(); }, child: const Text('Zaloguj e-mail')),
        TextButton(onPressed: () async { await Supabase.instance.client.auth.signUp(email: email.text.trim(), password: password.text); }, child: const Text('Załóż konto')),
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.g_mobiledata), label: const Text('Kontynuuj z Google')),
        TextButton(onPressed: onLocalMode, child: const Text('Tryb lokalny')),
      ])),
    )),
    );
  }
}
