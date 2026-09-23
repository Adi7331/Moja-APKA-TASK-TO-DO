import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'note_folder.dart';
import 'note_item.dart';
import 'remaster_theme.dart';

typedef NoteLibraryMoreCallback = void Function(NoteItem note, Offset anchor);

Color noteLibraryCardColor(NoteItem note, ColorScheme scheme) =>
    noteLibrarySurfaceForColor(note.colorKey, scheme);

String formatNoteUpdatedAt(DateTime updatedAt) =>
    DateFormat('dd.MM.yyyy · HH:mm', 'pl_PL').format(updatedAt.toLocal());

class NoteLibraryCard extends StatelessWidget {
  const NoteLibraryCard({
    required this.note,
    required this.onOpen,
    required this.onMore,
    this.folder,
    super.key,
  });

  final NoteItem note;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final NoteFolder? folder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNeutral = note.colorKey == NoteColorKey.neutral;
    final ink = isNeutral ? scheme.onSurface : noteLibraryCardInk;
    final mutedInk = isNeutral
        ? scheme.onSurfaceVariant
        : noteLibraryCardMutedInk;
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
          color: noteLibraryCardColor(note, scheme),
          borderRadius: BorderRadius.circular(18),
          border: isNeutral ? Border.all(color: scheme.outlineVariant) : null,
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
                                color: ink,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                        ),
                      ),
                      if (note.pinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 18,
                            color: ink,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Opcje notatki',
                        onPressed: onMore,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.more_horiz_rounded, color: ink),
                      ),
                    ],
                  ),
                  if (folder != null) ...[
                    const SizedBox(height: 6),
                    _FolderBadge(
                      name: folder!.displayName,
                      foreground: ink,
                      background: isNeutral
                          ? scheme.surfaceContainer
                          : Colors.white.withValues(alpha: .42),
                    ),
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
                              color: mutedInk,
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
                                      color: ink,
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
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: mutedInk, height: 1.42),
                    ),
                  ],
                  if (attachment != null) ...[
                    const SizedBox(height: 12),
                    _AttachmentSummary(attachment: attachment),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          formatNoteUpdatedAt(note.updatedAt),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: mutedInk,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (note.reminderAt != null)
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 17,
                          color: mutedInk,
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
        final rowCount = (notes.length / columns).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < rowCount; row++)
              Padding(
                padding: EdgeInsets.only(bottom: row == rowCount - 1 ? 0 : 12),
                child: Row(
                  key: ValueKey('note-library-row-$row'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < columns; column++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: column == columns - 1 ? 0 : 12,
                          ),
                          child: _cardAt(row * columns + column, foldersById),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cardAt(int index, Map<String, NoteFolder> foldersById) {
    if (index >= notes.length) return const SizedBox.shrink();
    final note = notes[index];
    return NoteLibraryCard(
      note: note,
      folder: foldersById[note.folderId],
      onOpen: () => onOpen(note),
      onMore: () => onMore(note, Offset.zero),
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

class _FolderBadge extends StatelessWidget {
  const _FolderBadge({
    required this.name,
    required this.foreground,
    required this.background,
  });
  final String name;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
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
