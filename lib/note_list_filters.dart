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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 660;
      final searchField = TextField(
        key: const ValueKey('notes-search'),
        controller: search,
        onChanged: onQueryChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Szukaj w notatkach',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Wyczyść wyszukiwanie',
                  onPressed: () {
                    search.clear();
                    onQueryChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      );
      final createButton = FilledButton.icon(
        key: const ValueKey('notes-create-primary'),
        onPressed: () => onNewNote(folderId: selectedFolderId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nowa notatka'),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            searchField
          else
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                createButton,
                const SizedBox(width: 4),
                _MoreCreateActions(
                  selectedFolderId: selectedFolderId,
                  onNewChecklist: onNewChecklist,
                  onNewImage: onNewImage,
                  onNewFile: onNewFile,
                ),
              ],
            ),
          if (isLoading ||
              (syncStatus != null && syncStatus!.trim().isNotEmpty)) ...[
            const SizedBox(height: 12),
            _SyncStatus(
              status: isLoading ? 'Ładowanie notatek…' : syncStatus!,
              onRetry: onRetrySync,
              isLoading: isLoading,
            ),
          ],
          const SizedBox(height: 16),
          SingleChildScrollView(
            key: const ValueKey('notes-section-filter'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in sections.entries) ...[
                  _SectionTab(
                    label: entry.value,
                    selected: selectedSection == entry.key,
                    onTap: () => onSectionChanged(entry.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (folderContent != null || labelContent != null) ...[
            const SizedBox(height: 12),
            if (folderContent != null) ...[
              _FilterHeading(
                icon: Icons.folder_open_outlined,
                label: 'FOLDERY',
              ),
              const SizedBox(height: 6),
              folderContent!,
            ],
            if (labelContent != null) ...[
              const SizedBox(height: 10),
              _FilterHeading(icon: Icons.sell_outlined, label: 'ETYKIETY'),
              const SizedBox(height: 6),
              labelContent!,
            ],
          ],
        ],
      );
    },
  );
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_rounded, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
}

class _FilterHeading extends StatelessWidget {
  const _FilterHeading({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 7),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _MoreCreateActions extends StatelessWidget {
  const _MoreCreateActions({
    required this.selectedFolderId,
    this.onNewChecklist,
    this.onNewImage,
    this.onNewFile,
  });

  final String? selectedFolderId;
  final NoteListCreate? onNewChecklist;
  final NoteListCreate? onNewImage;
  final NoteListCreate? onNewFile;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Więcej sposobów tworzenia',
    icon: const Icon(Icons.more_horiz_rounded),
    onSelected: (value) {
      switch (value) {
        case 'checklist':
          onNewChecklist?.call(folderId: selectedFolderId);
          break;
        case 'image':
          onNewImage?.call(folderId: selectedFolderId);
          break;
        case 'file':
          onNewFile?.call(folderId: selectedFolderId);
          break;
      }
    },
    itemBuilder: (context) => [
      if (onNewChecklist != null)
        const PopupMenuItem(
          value: 'checklist',
          child: ListTile(
            leading: Icon(Icons.checklist_rounded),
            title: Text('Nowa checklista'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onNewImage != null)
        const PopupMenuItem(
          value: 'image',
          child: ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Dodaj zdjęcie'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onNewFile != null)
        const PopupMenuItem(
          value: 'file',
          child: ListTile(
            leading: Icon(Icons.attach_file_rounded),
            title: Text('Dodaj plik'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
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
