import 'package:flutter/material.dart';

import 'note_folder.dart';
import 'note_library_state.dart';

class NotesLibraryHeader extends StatelessWidget {
  const NotesLibraryHeader({
    required this.greetingName,
    required this.noteCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onNewNote,
    required this.onMore,
    super.key,
  });

  final String? greetingName;
  final int noteCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNewNote;
  final Widget onMore;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final name = greetingName?.trim();
      final greeting = name == null || name.isEmpty
          ? 'Dzień dobry!'
          : 'Dzień dobry, $name!';
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final compactActions = constraints.maxWidth < 520 || textScale >= 1.5;
      final search = TextField(
        key: const ValueKey('notes-search'),
        controller: searchController,
        onChanged: onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Szukaj w notatkach…',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      );
      final create = FilledButton.icon(
        key: const ValueKey('notes-new-note'),
        onPressed: onNewNote,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nowa notatka'),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Twoje miejsce na rzeczy, do których chcesz wrócić.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                child: Text(
                  name == null || name.isEmpty ? 'D' : name[0].toUpperCase(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (compactActions) ...[
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: create),
                onMore,
              ],
            ),
          ] else
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 10),
                create,
                onMore,
              ],
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$noteCount ${_noteCountLabel(noteCount)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class NotesFilterStrip extends StatelessWidget {
  const NotesFilterStrip({
    required this.selection,
    required this.folders,
    required this.onSelectionChanged,
    super.key,
  });

  final NoteLibrarySelection selection;
  final List<NoteFolder> folders;
  final ValueChanged<NoteLibrarySelection> onSelectionChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('notes-filter-strip'),
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _FilterChip(
          label: 'Wszystkie',
          selected:
              selection.scope == NoteLibraryScope.all &&
              selection.folderId == null,
          onPressed: () => onSelectionChanged(
            selection.copyWith(scope: NoteLibraryScope.all, folderId: null),
          ),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Przypięte',
          icon: Icons.push_pin_outlined,
          selected: selection.scope == NoteLibraryScope.pinned,
          onPressed: () => onSelectionChanged(
            selection.copyWith(scope: NoteLibraryScope.pinned, folderId: null),
          ),
        ),
        for (final folder in folders) ...[
          const SizedBox(width: 8),
          _FilterChip(
            label: folder.name,
            icon: Icons.folder_outlined,
            selected:
                selection.scope == NoteLibraryScope.all &&
                selection.folderId == folder.id,
            onPressed: () => onSelectionChanged(
              selection.copyWith(
                scope: NoteLibraryScope.all,
                folderId: folder.id,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class NotesOverflowMenu extends StatelessWidget {
  const NotesOverflowMenu({
    required this.onScopeSelected,
    this.onCreateFolder,
    super.key,
  });

  final ValueChanged<NoteLibraryScope> onScopeSelected;
  final VoidCallback? onCreateFolder;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_NotesMenuAction>(
    tooltip: 'Więcej widoków notatek',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (action) {
      switch (action) {
        case _NotesMenuAction.reminders:
          onScopeSelected(NoteLibraryScope.reminders);
        case _NotesMenuAction.archive:
          onScopeSelected(NoteLibraryScope.archive);
        case _NotesMenuAction.trash:
          onScopeSelected(NoteLibraryScope.trash);
        case _NotesMenuAction.createFolder:
          onCreateFolder?.call();
      }
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: _NotesMenuAction.reminders,
        child: ListTile(
          leading: Icon(Icons.notifications_outlined),
          title: Text('Przypomnienia'),
        ),
      ),
      PopupMenuItem(
        value: _NotesMenuAction.archive,
        child: ListTile(
          leading: Icon(Icons.archive_outlined),
          title: Text('Archiwum'),
        ),
      ),
      PopupMenuItem(
        value: _NotesMenuAction.trash,
        child: ListTile(
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Kosz'),
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem(
        value: _NotesMenuAction.createFolder,
        child: ListTile(
          leading: Icon(Icons.create_new_folder_outlined),
          title: Text('Nowy folder'),
        ),
      ),
    ],
  );
}

enum _NotesMenuAction { reminders, archive, trash, createFolder }

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(99),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 17,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _noteCountLabel(int count) {
  if (count == 1) return 'notatka';
  if (count % 10 >= 2 &&
      count % 10 <= 4 &&
      (count % 100 < 12 || count % 100 > 14)) {
    return 'notatki';
  }
  return 'notatek';
}
