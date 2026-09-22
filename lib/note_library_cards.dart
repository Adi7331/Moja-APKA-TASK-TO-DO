import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'note_folder.dart';
import 'note_item.dart';
import 'remaster_theme.dart';

typedef NoteLibraryMoreCallback = void Function(NoteItem note, Offset anchor);

Color noteLibraryCardColor(NoteItem note, int visualIndex) {
  final paletteIndex = note.colorKey == NoteColorKey.neutral
      ? visualIndex
      : note.colorKey.index - 1;
  return noteLibraryPastelPalette[paletteIndex %
      noteLibraryPastelPalette.length];
}

class NoteLibraryCard extends StatelessWidget {
  const NoteLibraryCard({
    required this.note,
    required this.visualIndex,
    required this.onOpen,
    required this.onMore,
    this.folder,
    super.key,
  });

  final NoteItem note;
  final int visualIndex;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final NoteFolder? folder;

  @override
  Widget build(BuildContext context) {
    final checklistItems = note.blocks
        .where((block) => block.type == NoteBlockType.checklist)
        .expand((block) => block.checklistItems)
        .take(4)
        .toList();
    final plainPreview = note.blocks
        .where((block) => block.type != NoteBlockType.checklist)
        .map((block) => block.text.trim())
        .where((text) => text.isNotEmpty)
        .join(' ');
    final preview = plainPreview.isNotEmpty ? plainPreview : note.previewText;
    final displayPreview = preview == note.title.trim() ? '' : preview;
    final attachment = note.attachments.isEmpty ? null : note.attachments.first;

    return Semantics(
      button: true,
      label: 'Otwórz notatkę ${note.title.isEmpty ? 'bez tytułu' : note.title}',
      child: DecoratedBox(
        key: ValueKey('note-library-card-surface-${note.id}'),
        decoration: BoxDecoration(
          color: noteLibraryCardColor(note, visualIndex),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: ValueKey('note-library-card-${note.id}'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title.trim().isEmpty
                              ? 'Bez tytułu'
                              : note.title.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: noteLibraryCardInk,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                        ),
                      ),
                      if (note.pinned)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 18,
                            color: noteLibraryCardInk,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Opcje notatki',
                        onPressed: onMore,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: noteLibraryCardInk,
                        ),
                      ),
                    ],
                  ),
                  if (folder != null) ...[
                    const SizedBox(height: 6),
                    _FolderBadge(name: folder!.name),
                  ],
                  if (checklistItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...checklistItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Icon(
                              item.isDone
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              color: noteLibraryCardMutedInk,
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                item.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: noteLibraryCardInk,
                                      decoration: item.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (displayPreview.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      displayPreview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: noteLibraryCardMutedInk,
                        height: 1.42,
                      ),
                    ),
                  ],
                  if (attachment != null) ...[
                    const SizedBox(height: 12),
                    _AttachmentSummary(attachment: attachment),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        _formatDate(note.updatedAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: noteLibraryCardMutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (note.reminderAt != null)
                        const Icon(
                          Icons.notifications_none_rounded,
                          size: 17,
                          color: noteLibraryCardMutedInk,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NoteMasonryGrid extends StatelessWidget {
  const NoteMasonryGrid({
    required this.notes,
    required this.folders,
    required this.onOpen,
    required this.onMore,
    this.minCardWidth = 210,
    super.key,
  });

  final List<NoteItem> notes;
  final List<NoteFolder> folders;
  final ValueChanged<NoteItem> onOpen;
  final NoteLibraryMoreCallback onMore;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    final foldersById = {for (final folder in folders) folder.id: folder};
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = _columnCount(constraints.maxWidth, textScale);
        final buckets = List.generate(columns, (_) => <_IndexedNote>[]);
        final heights = List<double>.filled(columns, 0);
        for (var index = 0; index < notes.length; index++) {
          final shortest = heights.indexOf(heights.reduce(math.min));
          final note = notes[index];
          buckets[shortest].add(_IndexedNote(note, index));
          heights[shortest] += estimatedNoteHeight(note);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            columns,
            (column) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: column == columns - 1 ? 0 : 12),
                child: Column(
                  key: ValueKey('note-library-column-$column'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final indexed in buckets[column]) ...[
                      NoteLibraryCard(
                        note: indexed.note,
                        visualIndex: indexed.index,
                        folder: foldersById[indexed.note.folderId],
                        onOpen: () => onOpen(indexed.note),
                        onMore: () => onMore(indexed.note, Offset.zero),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _columnCount(double width, double textScale) {
    if (width < 600) return textScale >= 1.6 ? 1 : 2;
    if (width < 1100) return 2;
    return math.max(3, math.min(4, (width / minCardWidth).floor()));
  }
}

double estimatedNoteHeight(NoteItem note) {
  final checklistRows = math.min(4, note.checklistTotal);
  final attachmentRows = note.attachments.isEmpty ? 0 : 1;
  return 108 +
      (checklistRows * 27) +
      (attachmentRows * 38) +
      (note.previewText.isNotEmpty && checklistRows == 0 ? 56 : 0);
}

class _IndexedNote {
  const _IndexedNote(this.note, this.index);
  final NoteItem note;
  final int index;
}

class _FolderBadge extends StatelessWidget {
  const _FolderBadge({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: noteLibraryCardInk, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _AttachmentSummary extends StatelessWidget {
  const _AttachmentSummary({required this.attachment});
  final NoteAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.mimeType.startsWith('image/');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .44),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            Icon(
              isImage ? Icons.image_outlined : Icons.attach_file_rounded,
              color: noteLibraryCardInk,
              size: 19,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: noteLibraryCardInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
