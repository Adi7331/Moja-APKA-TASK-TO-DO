import 'package:flutter/material.dart';

import 'note_folder.dart';
import 'note_item.dart';
import 'remaster_theme.dart';

const _noFolderSelection = Object();

/// A compact, list-first presentation of one note.
///
/// The row deliberately keeps actions in a menu so the title and preview have
/// room to breathe while every action remains reachable with a keyboard or
/// screen reader.
class NoteListRow extends StatelessWidget {
  const NoteListRow({
    super.key,
    required this.note,
    this.folder,
    this.folders = const [],
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onSave,
    required this.onDelete,
    this.onPermanentlyDelete,
    this.onMoveToFolder,
    this.onSetWidgetNote,
  });

  final NoteItem note;
  final NoteFolder? folder;
  final List<NoteFolder> folders;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;
  final Future<void> Function(NoteItem)? onPermanentlyDelete;
  final Future<void> Function(NoteItem, String?)? onMoveToFolder;
  final Future<void> Function(NoteItem)? onSetWidgetNote;

  String get _title =>
      note.title.trim().isEmpty ? 'Bez tytułu' : note.title.trim();

  String get _preview {
    final value = note.previewText.trim();
    if (value.isEmpty || value == note.title.trim()) return '';
    return value.startsWith(note.title.trim())
        ? value.substring(note.title.trim().length).trim()
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = note.colorKey == NoteColorKey.neutral
        ? scheme.outlineVariant
        : remasterNoteColor(context, note.colorKey.index - 1);
    final surface = selected
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: .10),
            scheme.surfaceContainerLow,
          )
        : scheme.surfaceContainerLow;
    final status = _statusLabel(context);

    return Semantics(
      button: true,
      container: true,
      explicitChildNodes: true,
      label:
          'Notatka $_title${folder == null ? '' : ', folder ${folder!.name}'}',
      hint: 'Otwórz notatkę',
      child: Material(
        key: ValueKey('note-row-${note.id}'),
        color: surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Focus(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 68,
                    margin: const EdgeInsets.only(top: 2, right: 14),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (note.pinned)
                              Tooltip(
                                message: 'Przypięta notatka',
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                              ),
                          ],
                        ),
                        if (_preview.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        if (note.attachments.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _AttachmentSummary(
                            attachment: note.attachments.first,
                          ),
                        ],
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (folder != null)
                              _MetaItem(
                                icon: Icons.folder_outlined,
                                label: folder!.name,
                              ),
                            if (note.labels.isNotEmpty)
                              _MetaItem(
                                icon: Icons.sell_outlined,
                                label: note.labels.take(2).join(' · '),
                              ),
                            if (note.checklistTotal > 0)
                              _MetaItem(
                                icon: Icons.checklist_rounded,
                                label:
                                    '${note.checklistDone} z ${note.checklistTotal} ukończone',
                              ),
                            if (note.attachments.isNotEmpty)
                              Tooltip(
                                message:
                                    'Załączniki: ${note.attachments.length}',
                                child: _MetaItem(
                                  icon: Icons.attach_file_rounded,
                                  label: '${note.attachments.length}',
                                ),
                              ),
                            if (status != null)
                              _MetaItem(
                                icon: status.$1,
                                label: 'Przypomnienie · ${status.$2}',
                              ),
                            if (status == null)
                              _MetaItem(
                                icon: Icons.update_rounded,
                                label: MaterialLocalizations.of(
                                  context,
                                ).formatCompactDate(note.updatedAt.toLocal()),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _QuickActions(note: note, onSave: onSave, onDelete: onDelete),
                  _ActionsMenu(
                    note: note,
                    folders: folders,
                    onOpen: onOpen,
                    onSave: onSave,
                    onDelete: onDelete,
                    onPermanentlyDelete: onPermanentlyDelete,
                    onMoveToFolder: onMoveToFolder,
                    onSetWidgetNote: onSetWidgetNote,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (IconData, String)? _statusLabel(BuildContext context) {
    final reminder = note.reminderAt;
    if (reminder == null) return null;
    final local = reminder.toLocal();
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return (Icons.schedule_rounded, time);
  }
}

/// Pastel note surface used by the visual-reference card grid.
class NoteGridCard extends StatelessWidget {
  const NoteGridCard({
    super.key,
    required this.note,
    required this.folders,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onSave,
    required this.onDelete,
    this.onPermanentlyDelete,
    this.onMoveToFolder,
    this.onSetWidgetNote,
  });

  final NoteItem note;
  final List<NoteFolder> folders;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;
  final Future<void> Function(NoteItem)? onPermanentlyDelete;
  final Future<void> Function(NoteItem, String?)? onMoveToFolder;
  final Future<void> Function(NoteItem?)? onSetWidgetNote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tinted = note.colorKey != NoteColorKey.neutral;
    final background = tinted
        ? remasterNoteCardColor(note.colorKey.index - 1)
        : scheme.surfaceContainerLow;
    final foreground = tinted ? const Color(0xff172033) : scheme.onSurface;
    final muted = tinted ? const Color(0xff465166) : scheme.onSurfaceVariant;
    final date = MaterialLocalizations.of(context)
        .formatCompactDate(note.updatedAt.toLocal());
    final preview = note.previewText.replaceFirst(note.title.trim(), '').trim();

    return Semantics(
      button: true,
      container: true,
      label: 'Notatka ${note.title.isEmpty ? 'Bez tytułu' : note.title}',
      hint: 'Otwórz notatkę',
      child: Material(
        key: ValueKey('note-card-${note.id}'),
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: remasterMotion(context, 140),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : tinted
                    ? foreground.withValues(alpha: .08)
                    : scheme.outlineVariant.withValues(alpha: .65),
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.trim().isEmpty ? 'Bez tytułu' : note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (note.pinned)
                      Icon(
                        Icons.push_pin_rounded,
                        size: 17,
                        color: tinted ? foreground : scheme.primary,
                      ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: PopupMenuButton<_NoteAction>(
                        tooltip: 'Opcje notatki',
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: Icon(Icons.more_horiz_rounded, color: muted),
                        onSelected: (action) => _handleGridAction(
                          context,
                          action,
                          note: note,
                          folders: folders,
                          onOpen: onOpen,
                          onSave: onSave,
                          onDelete: onDelete,
                          onPermanentlyDelete: onPermanentlyDelete,
                          onMoveToFolder: onMoveToFolder,
                          onSetWidgetNote: onSetWidgetNote,
                        ),
                        itemBuilder: (context) => _gridMenuItems(
                          note,
                          onMoveToFolder,
                          onSetWidgetNote,
                          onPermanentlyDelete,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    preview.isEmpty ? 'Otwórz, aby dodać treść.' : preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: preview.isEmpty ? muted : foreground,
                      height: 1.35,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: muted),
                      ),
                    ),
                    if (note.checklistTotal > 0) ...[
                      Icon(Icons.check_box_outlined, size: 15, color: muted),
                      const SizedBox(width: 3),
                      Text(
                        '${note.checklistDone}/${note.checklistTotal}',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: muted),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (note.attachments.isNotEmpty)
                      Tooltip(
                        message: 'Załączniki: ${note.attachments.length}',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 15,
                              color: muted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${note.attachments.length}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: muted),
                            ),
                          ],
                        ),
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

List<PopupMenuEntry<_NoteAction>> _gridMenuItems(
  NoteItem note,
  Future<void> Function(NoteItem, String?)? onMoveToFolder,
  Future<void> Function(NoteItem?)? onSetWidgetNote,
  Future<void> Function(NoteItem)? onPermanentlyDelete,
) => [
  PopupMenuItem(
    value: _NoteAction.open,
    child: Text(note.isDeleted ? 'Podgląd notatki' : 'Edytuj notatkę'),
  ),
  if (!note.isDeleted)
    PopupMenuItem(
      value: _NoteAction.pin,
      child: Text(note.pinned ? 'Odepnij notatkę' : 'Przypnij notatkę'),
    ),
  if (!note.isDeleted && onMoveToFolder != null)
    const PopupMenuItem(
      value: _NoteAction.move,
      child: Text('Przenieś do folderu'),
    ),
  if (!note.isDeleted)
    PopupMenuItem(
      value: _NoteAction.archive,
      child: Text(note.isArchived ? 'Przywróć z archiwum' : 'Archiwizuj'),
    ),
  if (onSetWidgetNote != null && !note.isDeleted)
    const PopupMenuItem(
      value: _NoteAction.widget,
      child: Text('Ustaw w widżecie'),
    ),
  if (note.isDeleted && onPermanentlyDelete != null)
    const PopupMenuItem(
      value: _NoteAction.permanentDelete,
      child: Text('Usuń trwale'),
    ),
  if (!note.isDeleted)
    const PopupMenuItem(
      value: _NoteAction.trash,
      child: Text('Przenieś do Kosza'),
    ),
];

Future<void> _handleGridAction(
  BuildContext context,
  _NoteAction action, {
  required NoteItem note,
  required List<NoteFolder> folders,
  required VoidCallback onOpen,
  required Future<void> Function(NoteItem) onSave,
  required Future<void> Function(NoteItem) onDelete,
  Future<void> Function(NoteItem)? onPermanentlyDelete,
  Future<void> Function(NoteItem, String?)? onMoveToFolder,
  Future<void> Function(NoteItem?)? onSetWidgetNote,
}) async {
  switch (action) {
    case _NoteAction.open:
      onOpen();
    case _NoteAction.pin:
      await onSave(
        note.copyWith(pinned: !note.pinned, updatedAt: DateTime.now()),
      );
    case _NoteAction.move:
      final selection = await showModalBottomSheet<Object?>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Przenieś notatkę')),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Bez folderu'),
                onTap: () => Navigator.pop(context, _noFolderSelection),
              ),
              ...folders.map(
                (folder) => ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder.name),
                  onTap: () => Navigator.pop(context, folder.id),
                ),
              ),
            ],
          ),
        ),
      );
      if (selection == null) return;
      await onMoveToFolder?.call(
        note,
        selection == _noFolderSelection ? null : selection as String,
      );
    case _NoteAction.archive:
      await onSave(
        note.copyWith(
          archivedAt: note.isArchived ? null : DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    case _NoteAction.widget:
      await onSetWidgetNote?.call(note);
    case _NoteAction.trash:
      await onDelete(note);
    case _NoteAction.permanentDelete:
      await onPermanentlyDelete?.call(note);
  }
}

class _AttachmentSummary extends StatelessWidget {
  const _AttachmentSummary({required this.attachment});

  final NoteAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final image = attachment.mimeType.startsWith('image/');
    final size = attachment.byteSize < 1024 * 1024
        ? '${(attachment.byteSize / 1024).ceil()} KB'
        : '${(attachment.byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return Semantics(
      container: true,
      explicitChildNodes: true,
      image: image,
      label: image
          ? 'Podgląd zdjęcia: ${attachment.fileName}'
          : 'Załączony dokument: ${attachment.fileName}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            image ? Icons.image_outlined : Icons.insert_drive_file_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (!image) ...[
                  const SizedBox(width: 4),
                  Text(
                    attachment.mimeType == 'application/pdf'
                        ? 'PDF · $size'
                        : '· $size',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.note,
    required this.onSave,
    required this.onDelete,
  });

  final NoteItem note;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: note.isDeleted
            ? 'Przywróć notatkę z kosza'
            : note.isArchived
            ? 'Przywróć z archiwum'
            : 'Archiwizuj notatkę',
        onPressed: () {
          if (note.isDeleted) {
            onSave(note.copyWith(deletedAt: null, updatedAt: DateTime.now()));
            return;
          }
          onSave(
            note.copyWith(
              archivedAt: note.isArchived ? null : DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        },
        icon: Icon(
          note.isDeleted
              ? Icons.restore_from_trash_outlined
              : note.isArchived
              ? Icons.unarchive_outlined
              : Icons.archive_outlined,
        ),
      ),
      IconButton(
        tooltip: note.isDeleted
            ? 'Kosz czyści notatki po 30 dniach'
            : 'Przenieś notatkę do kosza',
        onPressed: () {
          if (note.isDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notatki w Koszu są czyszczone automatycznie po 30 dniach.',
                ),
              ),
            );
            return;
          }
          onDelete(note);
        },
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    ],
  );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.note,
    required this.folders,
    required this.onOpen,
    required this.onSave,
    required this.onDelete,
    this.onPermanentlyDelete,
    this.onMoveToFolder,
    this.onSetWidgetNote,
  });

  final NoteItem note;
  final List<NoteFolder> folders;
  final VoidCallback onOpen;
  final Future<void> Function(NoteItem) onSave;
  final Future<void> Function(NoteItem) onDelete;
  final Future<void> Function(NoteItem)? onPermanentlyDelete;
  final Future<void> Function(NoteItem, String?)? onMoveToFolder;
  final Future<void> Function(NoteItem)? onSetWidgetNote;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_NoteAction>(
    tooltip: 'Opcje notatki',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (action) => _handle(context, action),
    itemBuilder: (context) => [
      PopupMenuItem(
        value: _NoteAction.open,
        child: Text(note.isDeleted ? 'Podgląd notatki' : 'Edytuj notatkę'),
      ),
      if (!note.isDeleted)
        PopupMenuItem(
          value: _NoteAction.pin,
          child: Text(note.pinned ? 'Odepnij notatkę' : 'Przypnij notatkę'),
        ),
      if (!note.isDeleted && onMoveToFolder != null)
        const PopupMenuItem(
          value: _NoteAction.move,
          child: Text('Przenieś do folderu'),
        ),
      if (!note.isDeleted)
        PopupMenuItem(
          value: _NoteAction.archive,
          child: Text(note.isArchived ? 'Przywróć z archiwum' : 'Archiwizuj'),
        ),
      if (onSetWidgetNote != null && !note.isDeleted)
        const PopupMenuItem(
          value: _NoteAction.widget,
          child: Text('Ustaw w widżecie'),
        ),
      if (note.isDeleted && onPermanentlyDelete != null)
        const PopupMenuItem(
          value: _NoteAction.permanentDelete,
          child: Text('Usuń trwale'),
        ),
      if (!note.isDeleted)
        const PopupMenuItem(
          value: _NoteAction.trash,
          child: Text('Przenieś do Kosza'),
        ),
    ],
  );

  Future<void> _handle(BuildContext context, _NoteAction action) async {
    switch (action) {
      case _NoteAction.open:
        onOpen();
      case _NoteAction.pin:
        await onSave(
          note.copyWith(pinned: !note.pinned, updatedAt: DateTime.now()),
        );
      case _NoteAction.move:
        final selection = await showModalBottomSheet<Object?>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Przenieś notatkę')),
                ListTile(
                  leading: const Icon(Icons.folder_off_outlined),
                  title: const Text('Bez folderu'),
                  onTap: () => Navigator.pop(context, _noFolderSelection),
                ),
                ...folders.map(
                  (folder) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.name),
                    onTap: () => Navigator.pop(context, folder.id),
                  ),
                ),
              ],
            ),
          ),
        );
        if (selection == null) return;
        await onMoveToFolder?.call(
          note,
          selection == _noFolderSelection ? null : selection as String,
        );
      case _NoteAction.archive:
        await onSave(
          note.copyWith(
            archivedAt: note.isArchived ? null : DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      case _NoteAction.widget:
        await onSetWidgetNote?.call(note);
      case _NoteAction.trash:
        await onDelete(note);
      case _NoteAction.permanentDelete:
        await onPermanentlyDelete?.call(note);
    }
  }
}

enum _NoteAction { open, pin, move, archive, widget, trash, permanentDelete }
