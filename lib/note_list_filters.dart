import 'package:flutter/material.dart';

typedef NoteListCreate = void Function({String? folderId});

/// Shared controls above the list. The parent owns the selected values so the
/// controls survive module switches and route changes.
class NoteListFilters extends StatelessWidget {
  const NoteListFilters({
    super.key,
    required this.search,
    required this.query,
    required this.selectedSection,
    required this.onQueryChanged,
    required this.onSectionChanged,
    required this.selectedFolderId,
    required this.onNewNote,
    this.onNewChecklist,
    this.onNewImage,
    this.onNewFile,
    this.folderContent,
    this.labelContent,
    this.syncStatus,
    this.onRetrySync,
    this.isLoading = false,
  });

  final TextEditingController search;
  final String query;
  final String selectedSection;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSectionChanged;
  final String? selectedFolderId;
  final NoteListCreate onNewNote;
  final NoteListCreate? onNewChecklist;
  final NoteListCreate? onNewImage;
  final NoteListCreate? onNewFile;
  final Widget? folderContent;
  final Widget? labelContent;
  final String? syncStatus;
  final Future<void> Function()? onRetrySync;
  final bool isLoading;

  static const sections = <String, String>{
    'notes': 'Notatki',
    'reminders': 'Przypomnienia',
    'archive': 'Archiwum',
    'trash': 'Kosz',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        key: const ValueKey('notes-search'),
        controller: search,
        onChanged: onQueryChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Szukaj w notatkach',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      if (isLoading ||
          (syncStatus != null && syncStatus!.trim().isNotEmpty)) ...[
        const SizedBox(height: 8),
        _SyncStatus(
          status: isLoading ? 'Ładowanie notatek…' : syncStatus!,
          onRetry: onRetrySync,
          isLoading: isLoading,
        ),
      ],
      const SizedBox(height: 12),
      _Composer(
        selectedFolderId: selectedFolderId,
        onNewNote: onNewNote,
        onNewChecklist: onNewChecklist,
        onNewImage: onNewImage,
        onNewFile: onNewFile,
      ),
      const SizedBox(height: 16),
      Wrap(
        key: const ValueKey('notes-section-filter'),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in sections.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: selectedSection == entry.key,
              onSelected: (_) => onSectionChanged(entry.key),
            ),
        ],
      ),
      if (folderContent != null) ...[
        const SizedBox(height: 12),
        folderContent!,
      ],
      if (labelContent != null) ...[const SizedBox(height: 12), labelContent!],
    ],
  );
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({
    required this.status,
    this.onRetry,
    this.isLoading = false,
  });

  final String status;
  final Future<void> Function()? onRetry;
  final bool isLoading;

  bool get _needsRetry =>
      !isLoading && status.contains('Błąd') ||
      status.contains('czeka') ||
      status.contains('Czeka') ||
      status.contains('offline') ||
      status.contains('Offline');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed =
        !isLoading &&
        (status.contains('Błąd') ||
            status.contains('offline') ||
            status.contains('Offline'));
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Stan synchronizacji notatek: $status',
      child: DecoratedBox(
        key: ValueKey(isLoading ? 'notes-loading-state' : 'notes-sync-status'),
        decoration: BoxDecoration(
          color: (failed ? scheme.errorContainer : scheme.secondaryContainer)
              .withValues(alpha: .55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                isLoading
                    ? Icons.hourglass_top_rounded
                    : failed
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_queue_rounded,
                size: 18,
                color: failed
                    ? scheme.onErrorContainer
                    : scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_needsRetry && onRetry != null)
                Tooltip(
                  message: 'Ponów synchronizację notatek',
                  child: TextButton.icon(
                    onPressed: () => onRetry!(),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Ponów'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
  final NoteListCreate onNewNote;
  final NoteListCreate? onNewChecklist;
  final NoteListCreate? onNewImage;
  final NoteListCreate? onNewFile;

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
