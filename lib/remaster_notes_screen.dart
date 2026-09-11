import 'package:flutter/material.dart';

import 'note_item.dart';
import 'note_folder.dart';
import 'remaster_theme.dart';

typedef NewRemasterNote = void Function({String? folderId});
typedef SaveRemasterFolder = Future<void> Function(
  String name,
  NoteColorKey colorKey,
);

/// Keep-first note grid for the remaster. The screen keeps selection and its
/// current search locally, which means switching Start / Tasks / Notes does
/// not discard a user's place in the notebook.
class RemasterNotesScreen extends StatefulWidget {
  const RemasterNotesScreen({
    super.key,
    required this.notes,
    this.folders = const [],
    required this.onNewNote,
    required this.onOpenNote,
    required this.onSave,
    required this.onDelete,
    this.onNewChecklist,
    this.onNewImage,
    this.onNewFile,
    this.onMoveToFolder,
    this.onCreateFolder,
    this.onRenameFolder,
    this.onDeleteFolder,
  });

  final List<NoteItem> notes;
  final List<NoteFolder> folders;
  final NewRemasterNote onNewNote;
  final ValueChanged<NoteItem> onOpenNote;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;
  final NewRemasterNote? onNewChecklist;
  final NewRemasterNote? onNewImage;
  final NewRemasterNote? onNewFile;
  final Future<void> Function(NoteItem note, String? folderId)? onMoveToFolder;
  final SaveRemasterFolder? onCreateFolder;
  final Future<void> Function(NoteFolder folder)? onRenameFolder;
  final Future<void> Function(NoteFolder folder)? onDeleteFolder;

  @override
  State<RemasterNotesScreen> createState() => _RemasterNotesScreenState();
}

class _RemasterNotesScreenState extends State<RemasterNotesScreen> {
  final _search = TextEditingController();
  String _query = '';
  _NoteSection _section = _NoteSection.notes;
  String? _selectedNoteId;
  String? _folderId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<NoteItem> get _notes {
    final query = _query.trim().toLowerCase();
    final result =
        widget.notes.where((note) {
          final section = switch (_section) {
            _NoteSection.notes => !note.isArchived && !note.isDeleted,
            _NoteSection.reminders =>
              note.reminderAt != null && !note.isArchived && !note.isDeleted,
            _NoteSection.archive => note.isArchived && !note.isDeleted,
            _NoteSection.trash => note.isDeleted,
          };
          final text =
              '${note.title} ${note.previewText} ${note.labels.join(' ')}'
                  .toLowerCase();
          return section &&
              (_folderId == null || note.folderId == _folderId) &&
              (query.isEmpty || text.contains(query));
        }).toList()..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
    return result;
  }

  NoteItem? get _selected =>
      _notes.where((note) => note.id == _selectedNoteId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final content = _NotesGrid(
          search: _search,
          query: _query,
          section: _section,
          notes: _notes,
          folders: widget.folders,
          selectedFolderId: _folderId,
          selectedId: _selectedNoteId,
          onQueryChanged: (value) => setState(() => _query = value),
          onSectionChanged: (value) => setState(() => _section = value),
          onFolderChanged: (value) => setState(() => _folderId = value),
          onNewNote: widget.onNewNote,
          onNewChecklist: widget.onNewChecklist,
          onNewImage: widget.onNewImage,
          onNewFile: widget.onNewFile,
          onSelect: (note) => setState(() => _selectedNoteId = note.id),
          onOpen: widget.onOpenNote,
          onSave: widget.onSave,
          onDelete: widget.onDelete,
          onMoveToFolder: widget.onMoveToFolder,
          onCreateFolder: widget.onCreateFolder,
          onRenameFolder: widget.onRenameFolder,
          onDeleteFolder: widget.onDeleteFolder,
        );
        if (!wide) return content;
        return Row(
          children: [
            Expanded(child: content),
            Container(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            SizedBox(
              width: 348,
              child: _NotePreview(note: _selected, onOpen: widget.onOpenNote),
            ),
          ],
        );
      },
    );
  }
}

enum _NoteSection { notes, reminders, archive, trash }

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.search,
    required this.query,
    required this.section,
    required this.notes,
    required this.folders,
    required this.selectedFolderId,
    required this.selectedId,
    required this.onQueryChanged,
    required this.onSectionChanged,
    required this.onFolderChanged,
    required this.onNewNote,
    required this.onNewChecklist,
    required this.onNewImage,
    required this.onNewFile,
    required this.onSelect,
    required this.onOpen,
    required this.onSave,
    required this.onDelete,
    this.onMoveToFolder,
    this.onCreateFolder,
    this.onRenameFolder,
    this.onDeleteFolder,
  });
  final TextEditingController search;
  final String query;
  final _NoteSection section;
  final List<NoteItem> notes;
  final List<NoteFolder> folders;
  final String? selectedFolderId;
  final String? selectedId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_NoteSection> onSectionChanged;
  final ValueChanged<String?> onFolderChanged;
  final NewRemasterNote onNewNote;
  final NewRemasterNote? onNewChecklist;
  final NewRemasterNote? onNewImage;
  final NewRemasterNote? onNewFile;
  final ValueChanged<NoteItem> onSelect;
  final ValueChanged<NoteItem> onOpen;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;
  final Future<void> Function(NoteItem note, String? folderId)? onMoveToFolder;
  final SaveRemasterFolder? onCreateFolder;
  final Future<void> Function(NoteFolder folder)? onRenameFolder;
  final Future<void> Function(NoteFolder folder)? onDeleteFolder;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('remaster-notes-scroll'),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notatki',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: search,
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'Szukaj w notatkach',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _Composer(
                selectedFolderId: selectedFolderId,
                onNewNote: onNewNote,
                onNewChecklist: onNewChecklist,
                onNewImage: onNewImage,
                onNewFile: onNewFile,
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _NoteSection.values
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_sectionLabel(item)),
                            selected: section == item,
                            onSelected: (_) => onSectionChanged(item),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _FolderStrip(
                folders: folders,
                selectedFolderId: selectedFolderId,
                onSelected: onFolderChanged,
                onCreate: onCreateFolder,
                onRename: onRenameFolder,
                onDelete: onDeleteFolder,
              ),
            ],
          ),
        ),
      ),
      if (notes.isEmpty)
        SliverToBoxAdapter(
          child: _EmptyNotes(
            onNewNote: () => onNewNote(folderId: selectedFolderId),
          ),
        )
      else ...[
        if (notes.any((note) => note.pinned))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'PRZYPIĘTE',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(letterSpacing: 1.1),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: notes
                      .map(
                        (note) => SizedBox(
                          width: width,
                          child: _NoteCard(
                            note: note,
                            selected: note.id == selectedId,
                            onSelect: () => onSelect(note),
                            onOpen: () => onOpen(note),
                            onSave: onSave,
                            onDelete: onDelete,
                            folders: folders,
                            onMoveToFolder: onMoveToFolder,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ),
      ],
    ],
  );
}

class _FolderStrip extends StatelessWidget {
  const _FolderStrip({
    required this.folders,
    required this.selectedFolderId,
    required this.onSelected,
    this.onCreate,
    this.onRename,
    this.onDelete,
  });
  final List<NoteFolder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelected;
  final SaveRemasterFolder? onCreate;
  final Future<void> Function(NoteFolder folder)? onRename;
  final Future<void> Function(NoteFolder folder)? onDelete;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ChoiceChip(
        label: const Text('Wszystkie foldery'),
        selected: selectedFolderId == null,
        onSelected: (_) => onSelected(null),
      ),
      ...folders.map(
        (folder) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputChip(
              label: Text(folder.name),
              selected: selectedFolderId == folder.id,
              backgroundColor: _folderTint(context, folder.colorKey),
              onPressed: () => onSelected(folder.id),
            ),
            if (onRename != null || onDelete != null)
              PopupMenuButton<_FolderMenuAction>(
                tooltip: 'Opcje folderu',
                onSelected: (action) async {
                  switch (action) {
                    case _FolderMenuAction.rename:
                      await _rename(context, folder);
                    case _FolderMenuAction.delete:
                      await _confirmDelete(context, folder);
                  }
                },
                itemBuilder: (context) => [
                  if (onRename != null)
                    const PopupMenuItem(
                      value: _FolderMenuAction.rename,
                      child: Text('Zmień nazwę folderu'),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: _FolderMenuAction.delete,
                      child: Text('Usuń folder'),
                    ),
                ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ),
      ),
      if (onCreate != null)
        ActionChip(
          avatar: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('Folder'),
          onPressed: () => _create(context),
        ),
    ],
  );

  Future<void> _create(BuildContext context) async {
    final draft = await showDialog<_FolderDraft>(
      context: context,
      builder: (_) => const _CreateFolderDialog(),
    );
    if (draft == null || draft.name.isEmpty || onCreate == null) return;
    await onCreate!(draft.name, draft.colorKey);
  }

  Future<void> _rename(BuildContext context, NoteFolder folder) async {
    if (onRename == null) return;
    final draft = await showDialog<_FolderDraft>(
      context: context,
      builder: (_) => _RenameFolderDialog(folder: folder),
    );
    if (draft == null ||
        draft.name.isEmpty ||
        (draft.name == folder.name && draft.colorKey == folder.colorKey)) {
      return;
    }
    await onRename!(
      folder.copyWith(name: draft.name, colorKey: draft.colorKey),
    );
  }

  Future<void> _confirmDelete(BuildContext context, NoteFolder folder) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Usunąć folder „${folder.name}”?'),
        content: const Text(
          'Notatki zostaną zachowane w sekcji „Bez folderu”.',
        ),
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
    if (accepted == true && onDelete != null) await onDelete!(folder);
  }
}

enum _FolderMenuAction { rename, delete }

typedef _FolderDraft = ({String name, NoteColorKey colorKey});

Color? _folderTint(BuildContext context, NoteColorKey colorKey) =>
    colorKey == NoteColorKey.neutral
    ? null
    : remasterNoteColor(context, colorKey.index - 1);

String _folderColorLabel(NoteColorKey colorKey) => switch (colorKey) {
  NoteColorKey.neutral => 'Neutralny',
  NoteColorKey.blue => 'Błękit',
  NoteColorKey.lavender => 'Lawenda',
  NoteColorKey.mint => 'Mięta',
  NoteColorKey.peach => 'Koral',
  NoteColorKey.sand => 'Piasek',
};

/// Owns its controller for the full lifetime of the modal route.
///
/// The route can remain mounted during its closing animation, so disposing a
/// controller in the caller immediately after [showDialog] returns makes the
/// still-visible [TextField] subscribe to an already disposed controller.
class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  late final TextEditingController _controller;
  var _colorKey = NoteColorKey.neutral;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    Navigator.of(context)
        .pop((name: (value ?? _controller.text).trim(), colorKey: _colorKey));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nowy folder'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          decoration: const InputDecoration(labelText: 'Nazwa folderu'),
        ),
        const SizedBox(height: 8),
        Text('Kolor', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        _FolderColorPicker(
          value: _colorKey,
          onChanged: (value) => setState(() => _colorKey = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Anuluj'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Utwórz')),
    ],
  );
}

class _RenameFolderDialog extends StatefulWidget {
  const _RenameFolderDialog({required this.folder});

  final NoteFolder folder;

  @override
  State<_RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<_RenameFolderDialog> {
  late final TextEditingController _controller;
  late NoteColorKey _colorKey;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.folder.name);
    _colorKey = widget.folder.colorKey;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    Navigator.of(context)
        .pop((name: (value ?? _controller.text).trim(), colorKey: _colorKey));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Zmień nazwę folderu'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          decoration: const InputDecoration(labelText: 'Nazwa folderu'),
        ),
        const SizedBox(height: 8),
        Text('Kolor', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        _FolderColorPicker(
          value: _colorKey,
          onChanged: (value) => setState(() => _colorKey = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Anuluj'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Zapisz')),
    ],
  );
}

class _FolderColorPicker extends StatelessWidget {
  const _FolderColorPicker({required this.value, required this.onChanged});

  final NoteColorKey value;
  final ValueChanged<NoteColorKey> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final colorKey in NoteColorKey.values)
        ChoiceChip(
          label: Text(_folderColorLabel(colorKey)),
          selected: value == colorKey,
          onSelected: (_) => onChanged(colorKey),
        ),
    ],
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.selectedFolderId,
    required this.onNewNote,
    required this.onNewChecklist,
    required this.onNewImage,
    required this.onNewFile,
  });
  final String? selectedFolderId;
  final NewRemasterNote onNewNote;
  final NewRemasterNote? onNewChecklist;
  final NewRemasterNote? onNewImage;
  final NewRemasterNote? onNewFile;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => onNewNote(folderId: selectedFolderId),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
          child: Row(
            children: [
              const Expanded(child: Text('Utwórz notatkę…')),
              IconButton(
                tooltip: 'Utwórz checklistę',
                onPressed: onNewChecklist == null
                    ? null
                    : () => onNewChecklist!(folderId: selectedFolderId),
                icon: const Icon(Icons.check_box_outlined),
              ),
              IconButton(
                tooltip: 'Dodaj zdjęcie do notatki',
                onPressed: onNewImage == null
                    ? null
                    : () => onNewImage!(folderId: selectedFolderId),
                icon: const Icon(Icons.image_outlined),
              ),
              IconButton(
                tooltip: 'Dodaj plik do notatki',
                onPressed: onNewFile == null
                    ? null
                    : () => onNewFile!(folderId: selectedFolderId),
                icon: const Icon(Icons.attach_file_rounded),
              ),
              IconButton(
                tooltip: 'Utwórz notatkę',
                onPressed: () => onNewNote(folderId: selectedFolderId),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onSave,
    required this.onDelete,
    required this.folders,
    this.onMoveToFolder,
  });
  final NoteItem note;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;
  final List<NoteFolder> folders;
  final Future<void> Function(NoteItem note, String? folderId)? onMoveToFolder;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = note.colorKey == NoteColorKey.neutral
        ? scheme.surfaceContainerLow
        : remasterNoteColor(context, note.colorKey.index - 1);
    final preview = note.previewText.replaceFirst(note.title, '').trim();
    final folder = folders
        .where((item) => item.id == note.folderId)
        .firstOrNull;
    return Semantics(
      button: true,
      label: 'Notatka ${note.title.isEmpty ? 'bez tytułu' : note.title}',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onSelect,
          onDoubleTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'Bez tytułu' : note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: note.pinned
                          ? 'Odepnij notatkę'
                          : 'Przypnij notatkę',
                      onPressed: () => onSave(
                        note.copyWith(
                          pinned: !note.pinned,
                          updatedAt: DateTime.now(),
                        ),
                      ),
                      icon: Icon(
                        note.pinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      ),
                    ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (note.checklistTotal > 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${note.checklistDone} z ${note.checklistTotal} ukończone',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: note.checklistDone / note.checklistTotal,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ],
                if (note.labels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: note.labels
                        .take(3)
                        .map(
                          (label) => Chip(
                            label: Text(label),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (folder != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    container: true,
                    label: 'Folder: ${folder.name}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.folder_outlined,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          folder.name,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Edytuj notatkę',
                      onPressed: onOpen,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (onMoveToFolder != null)
                      PopupMenuButton<String?>(
                        tooltip: 'Przenieś do folderu',
                        onSelected: (folderId) =>
                            onMoveToFolder!(note, folderId),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: null,
                            child: Text('Bez folderu'),
                          ),
                          ...folders.map(
                            (folder) => PopupMenuItem(
                              value: folder.id,
                              child: Text(folder.name),
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.folder_outlined),
                      ),
                    IconButton(
                      tooltip: 'Usuń notatkę',
                      onPressed: () => onDelete(note),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.note, required this.onOpen});
  final NoteItem? note;
  final ValueChanged<NoteItem> onOpen;
  @override
  Widget build(BuildContext context) {
    final current = note;
    if (current == null) {
      return Center(
        child: Text(
          'Wybierz notatkę',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PODGLĄD',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            current.title.isEmpty ? 'Bez tytułu' : current.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            current.previewText,
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => onOpen(current),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Otwórz edytor'),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.onNewNote});
  final VoidCallback onNewNote;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Nie masz jeszcze notatek',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Zapisz myśl, listę albo plan. Wrócisz do niej na każdym urządzeniu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onNewNote,
            icon: const Icon(Icons.add),
            label: const Text('Utwórz notatkę'),
          ),
        ],
      ),
    ),
  );
}

String _sectionLabel(_NoteSection section) => switch (section) {
  _NoteSection.notes => 'Notatki',
  _NoteSection.reminders => 'Przypomnienia',
  _NoteSection.archive => 'Archiwum',
  _NoteSection.trash => 'Kosz',
};
