import 'dart:io';

import 'package:flutter/material.dart';

import 'note_attachment_picker.dart';
import 'note_editor_screen.dart';
import 'note_item.dart';

/// Keep-style notes home. The list and editor deliberately share one route
/// state so closing a note never resets search, filters, or scroll position.
class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.notes,
    required this.onOpenTasks,
    required this.onSave,
    required this.onDelete,
    this.syncStatus = 'Lokalnie',
    this.onCreateTask,
    this.onPermanentlyDelete,
    this.onAttach,
    this.onDeleteAttachment,
    this.onOpenAttachment,
  });

  final List<NoteItem> notes;
  final VoidCallback onOpenTasks;
  final Future<void> Function(NoteItem note) onSave;
  final Future<void> Function(NoteItem note) onDelete;
  final String syncStatus;
  final Future<void> Function(NoteItem note, String title)? onCreateTask;
  final Future<void> Function(NoteItem note)? onPermanentlyDelete;
  final Future<NoteAttachment> Function(NoteItem note, NoteAttachmentCandidate candidate)? onAttach;
  final Future<void> Function(NoteAttachment attachment)? onDeleteAttachment;
  final Future<String?> Function(NoteAttachment attachment)? onOpenAttachment;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late List<NoteItem> _notes;
  final _searchController = TextEditingController();
  String _query = '';
  String _section = 'notes';

  @override
  void initState() {
    super.initState();
    _notes = [...widget.notes];
  }

  @override
  void didUpdateWidget(covariant NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The app state refreshes its shared list in place after Realtime updates.
    // Always copy the incoming snapshot so a remote note cannot be hidden by
    // the screen's previous local list.
    _notes = [...widget.notes];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NoteItem> get _visibleNotes {
    final query = _query.trim().toLowerCase();
    final filtered = _notes.where((note) {
      final matchesQuery = query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.previewText.toLowerCase().contains(query) ||
          note.labels.any((label) => label.toLowerCase().contains(query));
      final matchesSection = switch (_section) {
        'reminders' => note.reminderAt != null && !note.isDeleted && !note.isArchived,
        'labels' => note.labels.isNotEmpty && !note.isDeleted && !note.isArchived,
        'archive' => note.isArchived && !note.isDeleted,
        'trash' => note.isDeleted,
        _ => !note.isArchived && !note.isDeleted,
      };
      return matchesQuery && matchesSection;
    }).toList();
    filtered.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filtered;
  }

  void _replace(NoteItem note) {
    if (!mounted) return;
    setState(() {
      final index = _notes.indexWhere((item) => item.id == note.id);
      if (index == -1) {
        _notes.insert(0, note);
      } else {
        _notes[index] = note;
      }
    });
  }

  Future<void> _openNote(NoteItem note, {bool initialImagePicker = false, bool initialFilePicker = false, bool initialChecklist = false}) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 1100) {
      final saved = await Navigator.of(context).push<NoteItem>(
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            note: note,
            onSave: widget.onSave,
            onDelete: widget.onDelete,
            onCreateTask: widget.onCreateTask,
            onAttach: widget.onAttach,
            onDeleteAttachment: widget.onDeleteAttachment,
            onOpenAttachment: widget.onOpenAttachment,
            initialImagePicker: initialImagePicker,
            initialFilePicker: initialFilePicker,
            initialChecklist: initialChecklist,
          ),
        ),
      );
      if (saved != null) _replace(saved);
      return;
    }

    final saved = await showDialog<NoteItem>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: NoteEditorScreen(
            note: note,
            onSave: widget.onSave,
            onDelete: widget.onDelete,
            onCreateTask: widget.onCreateTask,
            onAttach: widget.onAttach,
            onDeleteAttachment: widget.onDeleteAttachment,
            onOpenAttachment: widget.onOpenAttachment,
            initialImagePicker: initialImagePicker,
            initialFilePicker: initialFilePicker,
            initialChecklist: initialChecklist,
          ),
        ),
      ),
    );
    if (saved != null) _replace(saved);
  }

  Future<void> _createNote({bool imagePicker = false, bool filePicker = false, bool checklist = false}) async {
    final blocks = <NoteBlock>[NoteBlock.text(id: newNoteId())];
    if (checklist) blocks.add(NoteBlock.checklist(id: newNoteId(), position: 1));
    final note = NoteItem(
      id: newNoteId(),
      title: 'Nowa notatka',
      blocks: blocks,
    );
    _replace(note);
    await _openNote(note, initialImagePicker: imagePicker, initialFilePicker: filePicker, initialChecklist: checklist);
  }

  Future<void> _deleteNote(NoteItem note) async {
    if (note.isDeleted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Usunąć notatkę trwale?'),
          content: const Text('Tej operacji nie można cofnąć.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Usuń trwale')),
          ],
        ),
      );
      if (accepted != true) return;
      await (widget.onPermanentlyDelete ?? widget.onDelete)(note);
      if (mounted) setState(() => _notes.removeWhere((item) => item.id == note.id));
      return;
    }
    await widget.onDelete(note);
    if (!mounted) return;
    setState(() {
      final index = _notes.indexWhere((item) => item.id == note.id);
      if (index != -1) _notes[index] = note.copyWith(deletedAt: DateTime.now());
    });
  }

  Future<void> _saveFromPanel(NoteItem note) async {
    _replace(note);
    await widget.onSave(note);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final content = _NotesContent(
          notes: _visibleNotes,
          queryController: _searchController,
          section: _section,
          syncStatus: widget.syncStatus,
          onQueryChanged: (value) => setState(() => _query = value),
          onSectionChanged: (value) => setState(() => _section = value),
          onOpenTasks: widget.onOpenTasks,
          onNewNote: () => _createNote(),
          onNewChecklist: () => _createNote(checklist: true),
          onNewImage: () => _createNote(imagePicker: true),
          onNewFile: () => _createNote(filePicker: true),
          onOpenNote: _openNote,
          onPin: (note) => _saveFromPanel(note.copyWith(pinned: !note.pinned, updatedAt: DateTime.now())),
          onArchive: (note) => _saveFromPanel(
            note.isDeleted
                ? note.copyWith(deletedAt: null, updatedAt: DateTime.now())
                : note.copyWith(
                    archivedAt: note.isArchived ? null : DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
          ),
          onDelete: _deleteNote,
        );
        if (!wide) {
          return Scaffold(
            body: SafeArea(child: content),
            floatingActionButton: FloatingActionButton(
              key: const ValueKey('mobile-new-note'),
              tooltip: 'Nowa notatka',
              onPressed: () => _createNote(),
              child: const Icon(Icons.add),
            ),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                _NotesSidebar(section: _section, onSectionChanged: (value) => setState(() => _section = value), onOpenTasks: widget.onOpenTasks),
                VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                Expanded(child: content),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotesSidebar extends StatelessWidget {
  const _NotesSidebar({required this.section, required this.onSectionChanged, required this.onOpenTasks});
  final String section;
  final ValueChanged<String> onSectionChanged;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 26),
            child: Row(children: [
              Icon(Icons.lightbulb_outline_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text('Notatki', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          _NavItem(icon: Icons.sticky_note_2_outlined, label: 'Notatki', value: 'notes', selected: section == 'notes', onTap: onSectionChanged),
          _NavItem(icon: Icons.notifications_none_rounded, label: 'Przypomnienia', value: 'reminders', selected: section == 'reminders', onTap: onSectionChanged),
          _NavItem(icon: Icons.label_outline_rounded, label: 'Etykiety', value: 'labels', selected: section == 'labels', onTap: onSectionChanged),
          const SizedBox(height: 12),
          _NavItem(icon: Icons.archive_outlined, label: 'Archiwum', value: 'archive', selected: section == 'archive', onTap: onSectionChanged),
          _NavItem(icon: Icons.delete_outline_rounded, label: 'Kosz', value: 'trash', selected: section == 'trash', onTap: onSectionChanged),
          const Spacer(),
          TextButton.icon(onPressed: onOpenTasks, icon: const Icon(Icons.checklist_outlined), label: const Text('Przejdź do zadań'), style: TextButton.styleFrom(alignment: Alignment.centerLeft)),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.value, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .62) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [Icon(icon, size: 21), const SizedBox(width: 12), Expanded(child: Text(label))]),
          ),
        ),
      ),
    ),
  );
}

class _NotesContent extends StatelessWidget {
  const _NotesContent({required this.notes, required this.queryController, required this.section, required this.syncStatus, required this.onQueryChanged, required this.onSectionChanged, required this.onOpenTasks, required this.onNewNote, required this.onNewChecklist, required this.onNewImage, required this.onNewFile, required this.onOpenNote, required this.onPin, required this.onArchive, required this.onDelete});
  final List<NoteItem> notes;
  final TextEditingController queryController;
  final String section;
  final String syncStatus;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSectionChanged;
  final VoidCallback onOpenTasks;
  final VoidCallback onNewNote;
  final VoidCallback onNewChecklist;
  final VoidCallback onNewImage;
  final VoidCallback onNewFile;
  final Future<void> Function(NoteItem note, {bool initialImagePicker, bool initialFilePicker, bool initialChecklist}) onOpenNote;
  final Future<void> Function(NoteItem note) onPin;
  final Future<void> Function(NoteItem note) onArchive;
  final Future<void> Function(NoteItem note) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), child: Row(children: [
          if (MediaQuery.sizeOf(context).width < 1024) IconButton(tooltip: 'Wróć do zadań', onPressed: onOpenTasks, icon: const Icon(Icons.arrow_back_rounded)),
          if (MediaQuery.sizeOf(context).width < 1024) const SizedBox(width: 4),
          Expanded(child: Text(_sectionTitle(section), key: const ValueKey('notes-section-title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700))),
          Semantics(label: 'Status synchronizacji: $syncStatus', child: Icon(syncStatus == 'Lokalnie' ? Icons.phone_android_outlined : Icons.cloud_done_outlined, color: scheme.onSurfaceVariant)),
        ]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: TextField(controller: queryController, onChanged: onQueryChanged, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Szukaj notatek')))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 18, 24, 8), child: _QuickComposer(onNewNote: onNewNote, onNewChecklist: onNewChecklist, onNewImage: onNewImage, onNewFile: onNewFile))),
        if (MediaQuery.sizeOf(context).width < 1024)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 4), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _SectionChip(label: 'Notatki', value: 'notes', selected: section, onChanged: onSectionChanged),
            _SectionChip(label: 'Przypomnienia', value: 'reminders', selected: section, onChanged: onSectionChanged),
            _SectionChip(label: 'Etykiety', value: 'labels', selected: section, onChanged: onSectionChanged),
            _SectionChip(label: 'Archiwum', value: 'archive', selected: section, onChanged: onSectionChanged),
            _SectionChip(label: 'Kosz', value: 'trash', selected: section, onChanged: onSectionChanged),
          ])))),
        if (notes.isEmpty) SliverFillRemaining(hasScrollBody: false, child: _NotesEmptyState(section: section, onNewNote: onNewNote))
        else SliverPadding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 96), sliver: SliverToBoxAdapter(child: _MasonryNotes(notes: notes, onOpenNote: onOpenNote, onPin: onPin, onArchive: onArchive, onDelete: onDelete))),
      ],
    );
  }
}

class _QuickComposer extends StatelessWidget {
  const _QuickComposer({required this.onNewNote, required this.onNewChecklist, required this.onNewImage, required this.onNewFile});
  final VoidCallback onNewNote;
  final VoidCallback onNewChecklist;
  final VoidCallback onNewImage;
  final VoidCallback onNewFile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), child: InkWell(
      key: const ValueKey('quick-note-composer'),
      onTap: onNewNote,
      borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.fromLTRB(18, 8, 8, 8), child: Row(children: [
        Expanded(child: Text('Utwórz notatkę…', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant))),
        _ComposerButton(key: const ValueKey('quick-checklist'), tooltip: 'Nowa checklista', icon: Icons.check_box_outlined, onPressed: onNewChecklist),
        _ComposerButton(key: const ValueKey('quick-image'), tooltip: 'Dodaj zdjęcie', icon: Icons.image_outlined, onPressed: onNewImage),
        _ComposerButton(key: const ValueKey('quick-file'), tooltip: 'Dodaj plik', icon: Icons.attach_file_rounded, onPressed: onNewFile),
      ])),
    ));
  }
}

class _ComposerButton extends StatelessWidget {
  const _ComposerButton({super.key, required this.tooltip, required this.icon, required this.onPressed});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon));
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.label, required this.value, required this.selected, required this.onChanged});
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: value == selected, onSelected: (_) => onChanged(value)));
}

class _MasonryNotes extends StatelessWidget {
  const _MasonryNotes({required this.notes, required this.onOpenNote, required this.onPin, required this.onArchive, required this.onDelete});
  final List<NoteItem> notes;
  final Future<void> Function(NoteItem note, {bool initialImagePicker, bool initialFilePicker, bool initialChecklist}) onOpenNote;
  final Future<void> Function(NoteItem note) onPin;
  final Future<void> Function(NoteItem note) onArchive;
  final Future<void> Function(NoteItem note) onDelete;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1380 ? 3 : width >= 760 ? 2 : 1;
    final groups = List.generate(columns, (_) => <NoteItem>[]);
    for (var i = 0; i < notes.length; i++) {
      groups[i % columns].add(notes[i]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var column = 0; column < columns; column++) ...[
        if (column > 0) const SizedBox(width: 14),
        Expanded(child: Column(children: [
          for (final note in groups[column]) Padding(padding: const EdgeInsets.only(bottom: 14), child: _NoteCard(note: note, onOpen: () => onOpenNote(note), onPin: () => onPin(note), onArchive: () => onArchive(note), onDelete: () => onDelete(note))),
        ])),
      ],
    ]);
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onOpen, required this.onPin, required this.onArchive, required this.onDelete});
  final NoteItem note;
  final VoidCallback onOpen;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    NoteAttachment? imagePreview;
    for (final attachment in note.attachments) {
      if (attachment.mimeType.startsWith('image/') && attachment.localPath != null) {
        imagePreview = attachment;
        break;
      }
    }
    final imagePreviewPath = imagePreview?.localPath;
    return Semantics(button: true, label: 'Notatka ${note.title.isEmpty ? 'bez tytułu' : note.title}', child: Card(color: _noteTint(note.colorKey, scheme), clipBehavior: Clip.antiAlias, child: InkWell(onTap: onOpen, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(note.title.isEmpty ? 'Bez tytułu' : note.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          IconButton(tooltip: note.pinned ? 'Odepnij notatkę' : 'Przypnij notatkę', onPressed: onPin, icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 19)),
           IconButton(tooltip: note.isDeleted ? 'Usuń trwale' : 'Przenieś do kosza', onPressed: onDelete, icon: Icon(note.isDeleted ? Icons.delete_forever_outlined : Icons.delete_outline, size: 19)),
         ]),
        if (imagePreviewPath != null && File(imagePreviewPath).existsSync())
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(imagePreviewPath), height: 132, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
        if (note.previewText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note.previewText, maxLines: 8, overflow: TextOverflow.ellipsis)),
        if (note.attachments.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 6, runSpacing: 6, children: note.attachments.take(3).map((attachment) => _AttachmentBadge(attachment: attachment)).toList())),
        Padding(padding: const EdgeInsets.only(top: 12), child: Row(children: [
          if (note.checklistTotal > 0) ...[Icon(Icons.checklist_outlined, size: 17, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Text('${note.checklistDone}/${note.checklistTotal}', style: Theme.of(context).textTheme.labelMedium)],
          if (note.reminderAt != null) ...[const SizedBox(width: 10), Icon(Icons.notifications_none_rounded, size: 17, color: scheme.onSurfaceVariant)],
          if (note.labels.isNotEmpty) ...[const SizedBox(width: 10), Flexible(child: Text(note.labels.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)))],
          const Spacer(),
          IconButton(tooltip: note.isDeleted ? 'Przywróć z kosza' : note.isArchived ? 'Przywróć z archiwum' : 'Archiwizuj', onPressed: onArchive, icon: Icon(note.isDeleted || note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18)),
        ])),
      ]),
    ))));
  }
}

class _AttachmentBadge extends StatelessWidget {
  const _AttachmentBadge({required this.attachment});
  final NoteAttachment attachment;
  @override
  Widget build(BuildContext context) => Chip(avatar: Icon(attachment.mimeType.startsWith('image/') ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 16), label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Text(attachment.fileName, overflow: TextOverflow.ellipsis)));
}

Color _noteTint(NoteColorKey key, ColorScheme scheme) => switch (key) {
  NoteColorKey.neutral => scheme.surfaceContainerLow,
  NoteColorKey.blue => Color.alphaBlend(scheme.primary.withValues(alpha: .10), scheme.surfaceContainerLow),
  NoteColorKey.lavender => Color.alphaBlend(const Color(0xff8d7cf7).withValues(alpha: .10), scheme.surfaceContainerLow),
  NoteColorKey.mint => Color.alphaBlend(const Color(0xff52b788).withValues(alpha: .10), scheme.surfaceContainerLow),
  NoteColorKey.peach => Color.alphaBlend(const Color(0xffee9b6b).withValues(alpha: .10), scheme.surfaceContainerLow),
  NoteColorKey.sand => Color.alphaBlend(const Color(0xffd2b48c).withValues(alpha: .10), scheme.surfaceContainerLow),
};

class _NotesEmptyState extends StatelessWidget {
  const _NotesEmptyState({required this.section, required this.onNewNote});
  final String section;
  final VoidCallback onNewNote;
  @override
  Widget build(BuildContext context) {
    final isFiltered = section != 'notes';
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(isFiltered ? Icons.search_off_rounded : Icons.sticky_note_2_outlined, size: 46),
      const SizedBox(height: 14),
      Text(isFiltered ? 'Brak notatek w tym widoku' : 'Utwórz pierwszą notatkę', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      Text(isFiltered ? 'Spróbuj innej sekcji lub wyszukiwania.' : 'Zapisz pomysł, listę albo plan — wszystko w jednym miejscu.', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      FilledButton.icon(key: const ValueKey('new-note'), onPressed: onNewNote, icon: const Icon(Icons.add), label: const Text('Nowa notatka')),
    ])));
  }
}

String _sectionTitle(String section) => switch (section) {
  'reminders' => 'Przypomnienia',
  'labels' => 'Etykiety',
  'archive' => 'Archiwum',
  'trash' => 'Kosz',
  _ => 'Notatki',
};
