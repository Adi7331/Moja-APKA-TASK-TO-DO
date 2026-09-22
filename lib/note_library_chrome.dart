import 'package:flutter/material.dart';

import 'note_folder.dart';
import 'note_item.dart';
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

class NotesDesktopSidebar extends StatelessWidget {
  const NotesDesktopSidebar({
    required this.folders,
    required this.notes,
    required this.selection,
    required this.onSelectionChanged,
    super.key,
  });

  final List<NoteFolder> folders;
  final List<NoteItem> notes;
  final NoteLibrarySelection selection;
  final ValueChanged<NoteLibrarySelection> onSelectionChanged;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('notes-desktop-sidebar'),
    width: 224,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
      children: [
        Text(
          'NOTATKI',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _SidebarDestination(
          icon: Icons.grid_view_rounded,
          label: 'Wszystkie',
          count: visibleFolderCount(notes: notes, folderId: null),
          selected:
              selection.scope == NoteLibraryScope.all &&
              selection.folderId == null,
          onTap: () => onSelectionChanged(
            selection.copyWith(scope: NoteLibraryScope.all, folderId: null),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'FOLDERY',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        for (final folder in folders)
          _SidebarDestination(
            icon: Icons.folder_outlined,
            label: folder.name,
            count: visibleFolderCount(notes: notes, folderId: folder.id),
            selected:
                selection.scope == NoteLibraryScope.all &&
                selection.folderId == folder.id,
            onTap: () => onSelectionChanged(
              selection.copyWith(
                scope: NoteLibraryScope.all,
                folderId: folder.id,
              ),
            ),
          ),
        const SizedBox(height: 18),
        _SidebarDestination(
          icon: Icons.push_pin_outlined,
          label: 'Przypięte',
          count: selectNotesForLibrary(
            notes: notes,
            folders: folders,
            selection: const NoteLibrarySelection(
              scope: NoteLibraryScope.pinned,
            ),
          ).length,
          selected: selection.scope == NoteLibraryScope.pinned,
          onTap: () => onSelectionChanged(
            selection.copyWith(scope: NoteLibraryScope.pinned, folderId: null),
          ),
        ),
        _SidebarDestination(
          icon: Icons.archive_outlined,
          label: 'Archiwum',
          count: selectNotesForLibrary(
            notes: notes,
            folders: folders,
            selection: const NoteLibrarySelection(
              scope: NoteLibraryScope.archive,
            ),
          ).length,
          selected: selection.scope == NoteLibraryScope.archive,
          onTap: () => onSelectionChanged(
            selection.copyWith(scope: NoteLibraryScope.archive, folderId: null),
          ),
        ),
        _SidebarDestination(
          icon: Icons.delete_outline_rounded,
          label: 'Kosz',
          count: selectNotesForLibrary(
            notes: notes,
            folders: folders,
            selection: const NoteLibrarySelection(
              scope: NoteLibraryScope.trash,
            ),
          ).length,
          selected: selection.scope == NoteLibraryScope.trash,
          onTap: () => onSelectionChanged(
            selection.copyWith(scope: NoteLibraryScope.trash, folderId: null),
          ),
        ),
      ],
    ),
  );
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('$count', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
    ),
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
