import 'package:flutter/material.dart';

import 'note_folder.dart';
import 'note_item.dart';
import 'note_library_cards.dart';
import 'note_library_chrome.dart';
import 'note_library_state.dart';

typedef NewRemasterNote = void Function({String? folderId});
typedef SaveRemasterFolder = Future<void> Function(NoteFolderDraft draft);
typedef RemasterNoteEditorBuilder = Widget Function(
  NoteItem note,
  VoidCallback onClose,
);

enum _FolderAction { rename, delete }

Future<NoteFolderDraft?> showRemasterFolderDialog({
  required BuildContext context,
  required List<NoteFolder> folders,
}) => showDialog<NoteFolderDraft>(
  context: context,
  builder: (context) => _FolderDialog(
    title: 'Nowy folder',
    folders: folders,
    confirmLabel: 'Utwórz',
  ),
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
    final draft = await showDialog<NoteFolderDraft>(
      context: context,
      builder: (context) => _FolderDialog(
        title: 'Nowy folder',
        folders: widget.folders,
        confirmLabel: 'Utwórz',
      ),
    );
    if (draft == null || !mounted) return;
    await widget.onCreateFolder!(draft);
  }

  Future<void> _manageFolders() async {
    var folderItems = List<NoteFolder>.of(widget.folders);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Zarządzaj folderami')),
              if (folderItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Nie masz jeszcze folderów.'),
                ),
              for (final folder in folderItems)
                ListTile(
                  leading: _FolderAvatar(folder: folder),
                  title: Text(folder.displayName),
                  trailing: PopupMenuButton<_FolderAction>(
                    tooltip: 'Opcje folderu: ${folder.name}',
                    onSelected: (action) async {
                      if (action == _FolderAction.rename) {
                        final updated = await _editFolder(folder);
                        if (updated == null) return;
                        setSheetState(() {
                          final index = folderItems.indexWhere(
                            (item) => item.id == updated.id,
                          );
                          if (index != -1) folderItems[index] = updated;
                        });
                      } else {
                        final deleted = await _deleteFolder(folder);
                        if (deleted) {
                          setSheetState(
                            () => folderItems.removeWhere(
                              (item) => item.id == folder.id,
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _FolderAction.rename,
                        child: Text('Edytuj'),
                      ),
                      PopupMenuItem(
                        value: _FolderAction.delete,
                        child: Text('Usuń folder'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<NoteFolder?> _editFolder(NoteFolder folder) async {
    if (widget.onRenameFolder == null || !mounted) return null;
    final draft = await showDialog<NoteFolderDraft>(
      context: context,
      builder: (context) => _FolderDialog(
        title: 'Edytuj folder',
        folder: folder,
        folders: widget.folders,
        confirmLabel: 'Zapisz',
      ),
    );
    if (draft == null || !mounted) return null;
    final updated = folder.copyWith(
      name: draft.name,
      colorKey: draft.colorKey,
      emoji: draft.emoji,
      updatedAt: DateTime.now(),
    );
    await widget.onRenameFolder!(updated);
    return updated;
  }

  Future<bool> _deleteFolder(NoteFolder folder) async {
    if (widget.onDeleteFolder == null || !mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć folder?'),
        content: const Text('Notatki pozostaną zapisane w sekcji Bez folderu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń folder'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return false;
    await widget.onDeleteFolder!(folder);
    return true;
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
                    onManageFolders: _manageFolders,
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

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({
    required this.title,
    required this.folders,
    required this.confirmLabel,
    this.folder,
  });
  final String title;
  final List<NoteFolder> folders;
  final NoteFolder? folder;
  final String confirmLabel;

  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  late NoteColorKey _colorKey;
  String? _emojiError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _emojiController = TextEditingController(text: widget.folder?.emoji ?? '');
    _colorKey = widget.folder?.colorKey ?? NoteColorKey.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    final length = name.characters.length;
    if (length < 1 || length > 80) return 'Nazwa musi mieć 1–80 znaków.';
    final duplicate = widget.folders.any(
      (folder) => folder.id != widget.folder?.id && folder.name.trim() == name,
    );
    if (duplicate) return 'Folder o tej nazwie już istnieje.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    String? emoji;
    try {
      emoji = normalizeFolderEmoji(_emojiController.text);
    } on FormatException catch (error) {
      setState(() => _emojiError = error.message);
      return;
    }
    Navigator.pop(
      context,
      NoteFolderDraft(
        name: _nameController.text.trim(),
        colorKey: _colorKey,
        emoji: emoji,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const ValueKey('folder-name-field'),
              controller: _nameController,
              autofocus: true,
              maxLength: 80,
              validator: _validateName,
              decoration: const InputDecoration(
                labelText: 'Nazwa folderu',
                hintText: 'Np. Praca',
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text('Kolor', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final color in NoteColorKey.values)
                  ChoiceChip(
                    key: ValueKey('folder-color-${color.name}'),
                    label: Text(_folderColorLabel(color)),
                    selected: _colorKey == color,
                    onSelected: (_) => setState(() => _colorKey = color),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('folder-emoji-field'),
              controller: _emojiController,
              maxLength: 16,
              decoration: InputDecoration(
                labelText: 'Emoji (opcjonalnie)',
                errorText: _emojiError,
                helperText: 'Jedna emoji, np. 🚗',
              ),
              onChanged: (_) {
                if (_emojiError != null) setState(() => _emojiError = null);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Anuluj'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
    ],
  );
}

String _folderColorLabel(NoteColorKey color) => switch (color) {
  NoteColorKey.neutral => 'Neutralny',
  NoteColorKey.blue => 'Błękit',
  NoteColorKey.lavender => 'Lawenda',
  NoteColorKey.mint => 'Mięta',
  NoteColorKey.peach => 'Koral',
  NoteColorKey.sand => 'Piasek',
};

class _FolderAvatar extends StatelessWidget {
  const _FolderAvatar({required this.folder});
  final NoteFolder folder;

  @override
  Widget build(BuildContext context) => folder.emoji == null
      ? const Icon(Icons.folder_outlined)
      : Semantics(
          label: folder.displayName,
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: Text(folder.emoji!, style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
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
