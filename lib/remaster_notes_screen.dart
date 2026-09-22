import 'package:flutter/material.dart';

import 'note_folder.dart';
import 'note_item.dart';
import 'note_library_cards.dart';
import 'note_library_chrome.dart';
import 'note_library_state.dart';

typedef NewRemasterNote = void Function({String? folderId});
typedef SaveRemasterFolder = Future<void> Function(
  String name,
  NoteColorKey colorKey,
);
typedef RemasterNoteEditorBuilder = Widget Function(
  NoteItem note,
  VoidCallback onClose,
);

/// The Notes library keeps only presentation state. Saving and synchronizing
/// stay with the parent, so switching a filter can never lose an offline edit.
class RemasterNotesScreen extends StatefulWidget {
  const RemasterNotesScreen({
    super.key,
    required this.notes,
    this.greetingName,
    this.folders = const [],
    required this.onNewNote,
    required this.onOpenNote,
    required this.onSave,
    required this.onDelete,
    this.onPermanentlyDelete,
    this.onNewChecklist,
    this.onNewImage,
    this.onNewFile,
    this.onMoveToFolder,
    this.onCreateFolder,
    this.onRenameFolder,
    this.onDeleteFolder,
    this.onSetWidgetNote,
    this.syncStatus,
    this.onRetrySync,
    this.isLoading = false,
    this.editorBuilder,
  });

  final List<NoteItem> notes;
  final String? greetingName;
  final List<NoteFolder> folders;
  final NewRemasterNote onNewNote;
  final ValueChanged<NoteItem> onOpenNote;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;
  final Future<void> Function(NoteItem)? onPermanentlyDelete;
  final NewRemasterNote? onNewChecklist;
  final NewRemasterNote? onNewImage;
  final NewRemasterNote? onNewFile;
  final Future<void> Function(NoteItem note, String? folderId)? onMoveToFolder;
  final SaveRemasterFolder? onCreateFolder;
  final Future<void> Function(NoteFolder folder)? onRenameFolder;
  final Future<void> Function(NoteFolder folder)? onDeleteFolder;
  final Future<void> Function(NoteItem? note)? onSetWidgetNote;
  final String? syncStatus;
  final Future<void> Function()? onRetrySync;
  final bool isLoading;
  final RemasterNoteEditorBuilder? editorBuilder;

  @override
  State<RemasterNotesScreen> createState() => _RemasterNotesScreenState();
}

class _RemasterNotesScreenState extends State<RemasterNotesScreen> {
  final _search = TextEditingController();
  NoteLibrarySelection _selection = const NoteLibrarySelection();
  String? _selectedNoteId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<NoteItem> get _visible => selectNotesForLibrary(
    notes: widget.notes,
    folders: widget.folders,
    selection: _selection,
  );

  bool get _canCreate =>
      _selection.scope == NoteLibraryScope.all ||
      _selection.scope == NoteLibraryScope.pinned ||
      _selection.scope == NoteLibraryScope.reminders;

  void _select(NoteLibrarySelection selection) =>
      setState(() => _selection = selection);

  Future<void> _createFolder() async {
    if (widget.onCreateFolder == null) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nowy folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Np. Praca'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await widget.onCreateFolder!(name.trim(), NoteColorKey.blue);
  }

  NoteItem? get _selectedNote =>
      widget.notes.where((note) => note.id == _selectedNoteId).firstOrNull;

  Future<void> _showCardActions(NoteItem note, {required bool desktop}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _NoteActionsSheet(
        note: note,
        folders: widget.folders,
        isTrash: _selection.scope == NoteLibraryScope.trash,
        onOpen: () {
          Navigator.pop(context);
          if (desktop) {
            setState(() => _selectedNoteId = note.id);
          } else {
            widget.onOpenNote(note);
          }
        },
        onSave: (changed) async {
          Navigator.pop(context);
          await widget.onSave(changed);
        },
        onDelete: () async {
          Navigator.pop(context);
          await widget.onDelete(note);
        },
        onPermanentlyDelete: widget.onPermanentlyDelete == null
            ? null
            : () async {
                Navigator.pop(context);
                await widget.onPermanentlyDelete!(note);
              },
        onMoveToFolder: widget.onMoveToFolder == null
            ? null
            : (folderId) async {
                Navigator.pop(context);
                await widget.onMoveToFolder!(note, folderId);
              },
        onSetWidgetNote: widget.onSetWidgetNote == null
            ? null
            : () async {
                Navigator.pop(context);
                await widget.onSetWidgetNote!(note);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1100;
        final library = _library(context, desktop: desktop);
        if (!desktop) return library;
        final selected = _selectedNote;
        return Row(
          children: [
            NotesDesktopSidebar(
              folders: widget.folders,
              notes: widget.notes,
              selection: _selection,
              onSelectionChanged: _select,
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: library),
            if (selected != null && widget.editorBuilder != null) ...[
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              SizedBox(
                key: const ValueKey('notes-detail-panel'),
                width: 420,
                child: widget.editorBuilder!(
                  selected,
                  () => setState(() => _selectedNoteId = null),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _library(BuildContext context, {required bool desktop}) {
    final visible = _visible;
    return CustomScrollView(
      key: const PageStorageKey('remaster-notes-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NotesLibraryHeader(
                  greetingName: widget.greetingName,
                  noteCount: visible.length,
                  searchController: _search,
                  onSearchChanged: (query) =>
                      _select(_selection.copyWith(query: query)),
                  onNewNote: _canCreate
                      ? () => widget.onNewNote(folderId: _selection.folderId)
                      : () => _select(const NoteLibrarySelection()),
                  onMore: NotesOverflowMenu(
                    onScopeSelected: (scope) => _select(
                      _selection.copyWith(scope: scope, folderId: null),
                    ),
                    onCreateFolder: _createFolder,
                  ),
                ),
                const SizedBox(height: 12),
                NotesFilterStrip(
                  selection: _selection,
                  folders: widget.folders,
                  onSelectionChanged: _select,
                ),
                if (widget.syncStatus != null) ...[
                  const SizedBox(height: 12),
                  _SyncStatus(
                    status: widget.syncStatus!,
                    onRetry: widget.onRetrySync,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.isLoading)
          const SliverFillRemaining(child: _LoadingNotes())
        else if (visible.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            sliver: SliverToBoxAdapter(
              child: _EmptyNotes(
                scope: _selection.scope,
                canCreate: _canCreate,
                onNewNote: () =>
                    widget.onNewNote(folderId: _selection.folderId),
                onReset: () => _select(const NoteLibrarySelection()),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 104),
            sliver: SliverToBoxAdapter(
              child: NoteMasonryGrid(
                notes: visible,
                folders: widget.folders,
                onOpen: (note) {
                  if (desktop) {
                    setState(() => _selectedNoteId = note.id);
                  } else {
                    widget.onOpenNote(note);
                  }
                },
                onMore: (note, _) => _showCardActions(note, desktop: desktop),
              ),
            ),
          ),
      ],
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.status, this.onRetry});
  final String status;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = status.toLowerCase().contains('błąd');
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('notes-sync-status'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasError ? scheme.errorContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            color: hasError ? scheme.onErrorContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasError
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: 'Ponów synchronizację notatek',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

class _LoadingNotes extends StatelessWidget {
  const _LoadingNotes();

  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('notes-loading-state'),
    child: CircularProgressIndicator(),
  );
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({
    required this.scope,
    required this.canCreate,
    required this.onNewNote,
    required this.onReset,
  });
  final NoteLibraryScope scope;
  final bool canCreate;
  final VoidCallback onNewNote;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final title = switch (scope) {
      NoteLibraryScope.all ||
      NoteLibraryScope.pinned => 'Zacznij od pierwszej notatki',
      NoteLibraryScope.reminders => 'Nie masz notatek z przypomnieniem',
      NoteLibraryScope.archive => 'Archiwum jest puste',
      NoteLibraryScope.trash => 'Kosz jest pusty',
    };
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 30,
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            canCreate
                ? 'Zapisz myśl, listę albo plan. Twoje notatki zostaną pod ręką.'
                : 'Wróć do wszystkich notatek albo zmień widok w menu.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          if (canCreate)
            FilledButton.icon(
              onPressed: onNewNote,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nowa notatka'),
            )
          else
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Pokaż wszystkie notatki'),
            ),
        ],
      ),
    );
  }
}

class _NoteActionsSheet extends StatelessWidget {
  const _NoteActionsSheet({
    required this.note,
    required this.folders,
    required this.isTrash,
    required this.onOpen,
    required this.onSave,
    required this.onDelete,
    this.onPermanentlyDelete,
    this.onMoveToFolder,
    this.onSetWidgetNote,
  });
  final NoteItem note;
  final List<NoteFolder> folders;
  final bool isTrash;
  final VoidCallback onOpen;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onPermanentlyDelete;
  final Future<void> Function(String? folderId)? onMoveToFolder;
  final Future<void> Function()? onSetWidgetNote;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded),
            title: const Text('Otwórz notatkę'),
            onTap: onOpen,
          ),
          if (isTrash) ...[
            ListTile(
              leading: const Icon(Icons.restore_from_trash_outlined),
              title: const Text('Przywróć notatkę'),
              onTap: () => onSave(note.copyWith(deletedAt: null)),
            ),
            if (onPermanentlyDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Usuń trwale'),
                onTap: onPermanentlyDelete,
              ),
          ] else ...[
            ListTile(
              leading: Icon(
                note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(note.pinned ? 'Odepnij' : 'Przypnij'),
              onTap: () => onSave(note.copyWith(pinned: !note.pinned)),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(
                note.isArchived ? 'Przywróć z archiwum' : 'Archiwizuj',
              ),
              onTap: () => onSave(
                note.copyWith(
                  archivedAt: note.isArchived ? null : DateTime.now(),
                ),
              ),
            ),
            if (onMoveToFolder != null)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Przenieś do folderu'),
                onTap: () => _chooseFolder(context),
              ),
            if (onSetWidgetNote != null)
              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Ustaw jako widżet'),
                onTap: onSetWidgetNote,
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Przenieś do Kosza'),
              onTap: onDelete,
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _chooseFolder(BuildContext context) async {
    final folderId = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Przenieś do folderu')),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Bez folderu'),
              onTap: () => Navigator.pop(context),
            ),
            for (final folder in folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                onTap: () => Navigator.pop(context, folder.id),
              ),
          ],
        ),
      ),
    );
    if (context.mounted) await onMoveToFolder?.call(folderId);
  }
}
