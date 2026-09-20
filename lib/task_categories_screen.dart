import 'dart:math';

import 'package:flutter/material.dart';

import 'task_category.dart';

class TaskCategoriesScreen extends StatelessWidget {
  const TaskCategoriesScreen({
    super.key,
    required this.categories,
    required this.onSave,
    required this.onDelete,
    required this.userId,
  });

  final List<TaskCategory> categories;
  final Future<void> Function(TaskCategory category) onSave;
  final Future<void> Function(TaskCategory category) onDelete;
  final String userId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Kategorie zadań'),
          actions: [
            IconButton(
              tooltip: 'Dodaj kategorię',
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Text(
              'Kategorie pomagają uporządkować zadania. Jedno zadanie może mieć jedną kategorię.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Card(
              child: const ListTile(
                leading: Icon(Icons.inbox_outlined),
                title: Text('Bez kategorii'),
                subtitle: Text('Dawne zadania i zadania bez wyboru kategorii'),
              ),
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Nie masz jeszcze własnych kategorii.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final category in categories)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _color(category.color),
                    child: Text(category.emoji ?? category.name.characters.first),
                  ),
                  title: Text(
                    [if (category.emoji?.isNotEmpty ?? false) category.emoji!, category.name].join(' '),
                  ),
                  subtitle: const Text('Dotknij, aby zmienić'),
                  trailing: IconButton(
                    tooltip: 'Usuń kategorię',
                    onPressed: () => _confirmDelete(context, category),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  onTap: () => _edit(context, category),
                ),
              ),
          ],
        ),
      );

  Future<void> _edit(BuildContext context, [TaskCategory? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final emoji = TextEditingController(text: existing?.emoji ?? '');
    const colors = ['#2F6FED', '#A78BFA', '#50B89C', '#E2B76D', '#E68B80'];
    var color = existing?.color ?? colors.first;
    final category = await showDialog<TaskCategory>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nowa kategoria' : 'Edytuj kategorię'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nazwa'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emoji,
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: 'Emoji (opcjonalnie)',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Kolor', style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in colors)
                      ChoiceChip(
                        label: const SizedBox(width: 18, height: 18),
                        avatar: CircleAvatar(backgroundColor: _color(option)),
                        selected: option == color,
                        onSelected: (_) => setDialogState(() => color = option),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                final value = name.text.trim();
                if (value.isEmpty) return;
                final now = DateTime.now().toUtc();
                Navigator.pop(
                  dialogContext,
                  TaskCategory(
                    id: existing?.id ?? _newUuid(),
                    userId: existing?.userId ?? userId,
                    name: value,
                    color: color,
                    emoji: emoji.text.trim().isEmpty ? null : emoji.text.trim(),
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    emoji.dispose();
    if (category != null) await onSave(category);
  }

  Future<void> _confirmDelete(BuildContext context, TaskCategory category) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usunąć kategorię?'),
        content: Text('Zadania z „${category.name}” przejdą do „Bez kategorii”.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Anuluj')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (accepted == true) await onDelete(category);
  }
}

Color _color(String hex) => Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

String _newUuid() {
  final random = Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  String bytes(int from, int until) => values
      .sublist(from, until)
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${bytes(0, 4)}-${bytes(4, 6)}-${bytes(6, 8)}-${bytes(8, 10)}-${bytes(10, 16)}';
}
