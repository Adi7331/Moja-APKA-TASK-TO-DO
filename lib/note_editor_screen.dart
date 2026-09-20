import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'note_attachment_picker.dart';
import 'note_item.dart';
import 'serial_async_queue.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.note,
    required this.onSave,
    required this.onDelete,
    this.embedded = false,
    this.onCreateTask,
    this.onAttach,
    this.onDeleteAttachment,
    this.onOpenAttachment,
    this.initialImagePicker = false,
    this.initialFilePicker = false,
    this.initialChecklist = false,
    this.remastered = false,
  });

  final NoteItem note;
  final Future<void> Function(NoteItem note) onSave;
  final Future<void> Function(NoteItem note) onDelete;
  final bool embedded;
  final Future<void> Function(NoteItem note, String title)? onCreateTask;
  final Future<NoteAttachment> Function(
    NoteItem note,
    NoteAttachmentCandidate candidate,
  )?
  onAttach;
  final Future<void> Function(NoteAttachment attachment)? onDeleteAttachment;
  final Future<String?> Function(NoteAttachment attachment)? onOpenAttachment;
  final bool initialImagePicker;
  final bool initialFilePicker;
  final bool initialChecklist;
  final bool remastered;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late NoteItem _note;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  Timer? _saveTimer;
  final _saveQueue = SerialAsyncQueue();
  String _saveStatus = 'Zapisano';
  bool _advancedOpen = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _titleController = TextEditingController(text: _note.title);
    _bodyController = TextEditingController(text: _firstText(_note));
    _advancedOpen = widget.initialChecklist;
    _titleController.addListener(_scheduleSave);
    _bodyController.addListener(_scheduleSave);
    if (widget.initialImagePicker) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pickAttachment(imageOnly: true),
      );
    }
    if (widget.initialFilePicker) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pickAttachment(imageOnly: false),
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    if (!mounted) return;
    setState(() => _saveStatus = 'Oczekuje na zapis');
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_save()),
    );
  }

  NoteItem _draft() {
    final blocks = [..._note.blocks];
    final textBlock = NoteBlock.text(
      id: blocks.isEmpty ? newNoteId() : blocks.first.id,
      text: _bodyController.text,
    );
    if (blocks.isEmpty) {
      blocks.add(textBlock);
    } else if (blocks.first.type == NoteBlockType.text) {
      blocks[0] = textBlock;
    }
    return _note.copyWith(
      title: _titleController.text,
      blocks: blocks,
      updatedAt: DateTime.now(),
      revision: _note.revision + 1,
    );
  }

  Future<bool> _save() async {
    _saveTimer?.cancel();
    if (mounted) setState(() => _saveStatus = 'Zapisywanie…');
    try {
      await _saveQueue.run(() async {
        final draft = _draft();
        await widget.onSave(draft);
        _note = draft;
      });
      if (mounted) setState(() => _saveStatus = 'Zapisano');
      return true;
    } catch (_) {
      if (mounted) setState(() => _saveStatus = 'Błąd — spróbuj ponownie');
      return false;
    }
  }

  Future<void> _close() async {
    if (!await _save()) return;
    if (!mounted) return;
    if (widget.embedded) return;
    Navigator.of(context).pop(_note);
  }

  Future<void> _moveToTrash() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Przenieść notatkę do kosza?'),
        content: const Text('Notatkę będzie można przywrócić z kosza.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Przenieś'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final deleted = _note.copyWith(
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await widget.onDelete(deleted);
    if (mounted && !widget.embedded) Navigator.of(context).pop(deleted);
  }

  Future<void> _pickAttachment({required bool imageOnly}) async {
    try {
      final candidate = await NoteAttachmentPicker.pick(imageOnly: imageOnly);
      if (candidate == null || !mounted) return;
      setState(() => _saveStatus = 'Przesyłanie pliku…');
      final pending = NoteAttachment(
        id: newNoteId(),
        fileName: candidate.fileName,
        mimeType: candidate.mimeType,
        byteSize: candidate.byteSize,
        localPath: candidate.file.path,
      );
      final saved = widget.onAttach == null
          ? pending
          : await widget.onAttach!(_note, candidate);
      final blocks = [
        ..._note.blocks,
        NoteBlock.attachment(
          id: newNoteId(),
          attachmentId: saved.id,
          position: _note.blocks.length,
        ),
      ];
      setState(
        () => _note = _note.copyWith(
          attachments: [..._note.attachments, saved],
          blocks: blocks,
          updatedAt: DateTime.now(),
        ),
      );
      await _save();
    } on ArgumentError catch (error) {
      if (mounted) {
        _showMessage(error.message?.toString() ?? 'Plik jest za duży.');
      }
    } catch (_) {
      if (mounted) _showMessage('Nie udało się dodać pliku. Spróbuj ponownie.');
    }
  }

  Future<void> _openAttachment(NoteAttachment attachment) async {
    final path = attachment.localPath;
    if (path == null) {
      final remoteUrl = widget.onOpenAttachment == null
          ? null
          : await widget.onOpenAttachment!(attachment);
      if (remoteUrl != null && await launchUrl(Uri.parse(remoteUrl))) return;
      _showMessage('Plik zostanie otwarty po zakończeniu synchronizacji.');
      return;
    }
    final opened = await launchUrl(Uri.file(path));
    if (!opened && mounted) _showMessage('Nie udało się otworzyć pliku.');
  }

  Future<void> _removeAttachment(NoteAttachment attachment) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć załącznik?'),
        content: Text(attachment.fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      if (widget.onDeleteAttachment != null) {
        await widget.onDeleteAttachment!(attachment);
      } else if (attachment.localPath != null) {
        final file = File(attachment.localPath!);
        if (await file.exists()) await file.delete();
      }
      final blocks = _note.blocks
          .where((block) => block.attachmentId != attachment.id)
          .toList();
      setState(
        () => _note = _note.copyWith(
          attachments: _note.attachments
              .where((item) => item.id != attachment.id)
              .toList(),
          blocks: [
            for (var i = 0; i < blocks.length; i++)
              blocks[i].copyWith(position: i),
          ],
          updatedAt: DateTime.now(),
        ),
      );
      await _save();
    } catch (_) {
      if (mounted) _showMessage('Nie udało się usunąć załącznika.');
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addBlock(NoteBlockType type) async {
    final id = newNoteId();
    final block = switch (type) {
      NoteBlockType.heading => NoteBlock.heading(
        id: id,
        position: _note.blocks.length,
      ),
      NoteBlockType.quote => NoteBlock.quote(
        id: id,
        position: _note.blocks.length,
      ),
      NoteBlockType.checklist => NoteBlock.checklist(
        id: id,
        position: _note.blocks.length,
      ),
      NoteBlockType.table => NoteBlock.table(
        id: id,
        table: const NoteTableData(),
        position: _note.blocks.length,
      ),
      NoteBlockType.attachment => NoteBlock.attachment(
        id: id,
        attachmentId: 'attachment-pending',
        position: _note.blocks.length,
      ),
      NoteBlockType.text => NoteBlock.text(
        id: id,
        position: _note.blocks.length,
      ),
    };
    setState(() => _note = _note.copyWith(blocks: [..._note.blocks, block]));
    await _save();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      initialDate: _note.reminderAt ?? now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_note.reminderAt ?? now),
    );
    if (time == null) return;
    setState(
      () => _note = _note.copyWith(
        reminderAt: DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      ),
    );
    await _save();
  }

  Future<void> _editLabels() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EditLabelsDialog(initialValue: _note.labels.join(', ')),
    );
    if (value == null || !mounted) return;
    final labels = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    setState(
      () => _note = _note.copyWith(labels: labels, updatedAt: DateTime.now()),
    );
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final editor = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        widget.remastered ? 24 : 24,
        widget.remastered ? 22 : 8,
        24,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('note-title-field'),
            controller: _titleController,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Tytuł',
              border: InputBorder.none,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          TextField(
            controller: _bodyController,
            minLines: 6,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Zacznij pisać…',
              border: InputBorder.none,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_note.attachments.isNotEmpty)
            _AttachmentsEditor(
              attachments: _note.attachments,
              onOpen: _openAttachment,
              onRemove: _removeAttachment,
            ),
          const SizedBox(height: 16),
          if (widget.remastered)
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .52),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _noteToolbar(),
              ),
            )
          else
            _noteToolbar(),
          if (_note.blocks.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ExpansionTile(
                initiallyExpanded: _advancedOpen,
                onExpansionChanged: (open) =>
                    setState(() => _advancedOpen = open),
                tilePadding: EdgeInsets.zero,
                title: const Text('Dodatkowe bloki'),
                children: _note.blocks.skip(1).map(_buildBlock).toList(),
              ),
            ),
        ],
      ),
    );
    final content = SafeArea(
      child: Column(
        key: widget.remastered ? const ValueKey('remaster-note-editor') : null,
        children: [
          _editorHeader(context),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.remastered && isWide ? 800 : double.infinity,
                ),
                child: widget.remastered && isWide
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Material(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: editor,
                        ),
                      )
                    : editor,
              ),
            ),
          ),
        ],
      ),
    );
    return widget.embedded ? content : Scaffold(body: content);
  }

  Widget _editorHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('note-close-button'),
          tooltip: 'Zamknij notatkę',
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.remastered ? 'Edytujesz notatkę' : 'Notatka',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (widget.remastered)
                Text(
                  _saveStatus,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (!widget.remastered)
          Text(_saveStatus, style: Theme.of(context).textTheme.labelMedium),
        IconButton(
          tooltip: _note.reminderAt == null
              ? 'Ustaw przypomnienie'
              : 'Zmień przypomnienie',
          onPressed: _pickReminder,
          icon: Icon(
            _note.reminderAt == null
                ? Icons.notifications_none_outlined
                : Icons.notifications_active_outlined,
          ),
        ),
        PopupMenuButton<NoteBlockType>(
          tooltip: 'Dodaj blok',
          onSelected: (type) {
            setState(() => _advancedOpen = true);
            _addBlock(type);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: NoteBlockType.heading,
              child: Text('Nagłówek'),
            ),
            PopupMenuItem(value: NoteBlockType.quote, child: Text('Cytat')),
            PopupMenuItem(
              value: NoteBlockType.checklist,
              child: Text('Checklista'),
            ),
            PopupMenuItem(value: NoteBlockType.table, child: Text('Tabela')),
          ],
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
        IconButton(
          tooltip: 'Przenieś do kosza',
          onPressed: _moveToTrash,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
  );

  Widget _noteToolbar() => _NoteToolbar(
    note: _note,
    onChanged: (next) {
      setState(() => _note = next.copyWith(updatedAt: DateTime.now()));
      _scheduleSave();
    },
    onPickImage: () => _pickAttachment(imageOnly: true),
    onPickFile: () => _pickAttachment(imageOnly: false),
    onEditLabels: _editLabels,
  );

  Widget _buildBlock(NoteBlock block) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _blockLabel(block.type),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            IconButton(
              tooltip: 'Przenieś blok w górę',
              onPressed: block.position == 0
                  ? null
                  : () => _moveBlock(block, -1),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Przenieś blok w dół',
              onPressed: block.position >= _note.blocks.length - 1
                  ? null
                  : () => _moveBlock(block, 1),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
        switch (block.type) {
          NoteBlockType.heading => TextField(
            decoration: const InputDecoration(labelText: 'Nagłówek'),
            onChanged: (text) =>
                _updateBlock(block, block.copyWith(text: text)),
          ),
          NoteBlockType.quote => TextField(
            decoration: const InputDecoration(
              labelText: 'Cytat',
              prefixIcon: Icon(Icons.format_quote),
            ),
            onChanged: (text) =>
                _updateBlock(block, block.copyWith(text: text)),
          ),
          NoteBlockType.checklist => _ChecklistBlock(
            block: block,
            onChanged: (items) =>
                _updateBlock(block, block.copyWith(checklistItems: items)),
            onCreateTask: widget.onCreateTask == null
                ? null
                : (title) => widget.onCreateTask!(_note, title),
          ),
          NoteBlockType.table => _TableBlock(
            block: block,
            onChanged: (table) =>
                _updateBlock(block, block.copyWith(table: table)),
            onCreateTask: widget.onCreateTask == null
                ? null
                : (title) => widget.onCreateTask!(_note, title),
          ),
          NoteBlockType.attachment => const SizedBox.shrink(),
          NoteBlockType.text => const SizedBox.shrink(),
        },
      ],
    ),
  );

  void _moveBlock(NoteBlock block, int delta) {
    final blocks = [..._note.blocks]
      ..sort((a, b) => a.position.compareTo(b.position));
    final index = blocks.indexWhere((item) => item.id == block.id);
    final nextIndex = index + delta;
    if (index == -1 || nextIndex < 0 || nextIndex >= blocks.length) return;
    final moved = blocks.removeAt(index);
    blocks.insert(nextIndex, moved);
    setState(
      () => _note = _note.copyWith(
        blocks: [
          for (var i = 0; i < blocks.length; i++)
            blocks[i].copyWith(position: i),
        ],
      ),
    );
    _scheduleSave();
  }

  void _updateBlock(NoteBlock old, NoteBlock updated) {
    final blocks = [..._note.blocks];
    final index = blocks.indexWhere((block) => block.id == old.id);
    if (index == -1) return;
    blocks[index] = updated;
    setState(() => _note = _note.copyWith(blocks: blocks));
    _scheduleSave();
  }
}

class _EditLabelsDialog extends StatefulWidget {
  const _EditLabelsDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_EditLabelsDialog> createState() => _EditLabelsDialogState();
}

class _EditLabelsDialogState extends State<_EditLabelsDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save([String? value]) {
    Navigator.of(context).pop((value ?? _controller.text).trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Etykiety'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'np. praca, dom'),
      onSubmitted: _save,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Anuluj'),
      ),
      FilledButton(onPressed: _save, child: const Text('Zapisz')),
    ],
  );
}

class _AttachmentsEditor extends StatelessWidget {
  const _AttachmentsEditor({
    required this.attachments,
    required this.onOpen,
    required this.onRemove,
  });
  final List<NoteAttachment> attachments;
  final ValueChanged<NoteAttachment> onOpen;
  final ValueChanged<NoteAttachment> onRemove;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: attachments.map((attachment) {
        final isImage = attachment.mimeType.startsWith('image/');
        final path = attachment.localPath;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onOpen(attachment),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (isImage && path != null && File(path).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Icon(
                      isImage
                          ? Icons.image_outlined
                          : Icons.insert_drive_file_outlined,
                      size: 32,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${attachment.mimeType} · ${_formatBytes(attachment.byteSize)}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 20),
                  IconButton(
                    tooltip: 'Usuń załącznik',
                    onPressed: () => onRemove(attachment),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _NoteToolbar extends StatelessWidget {
  const _NoteToolbar({
    required this.note,
    required this.onChanged,
    required this.onPickImage,
    required this.onPickFile,
    required this.onEditLabels,
  });
  final NoteItem note;
  final ValueChanged<NoteItem> onChanged;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onEditLabels;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _ColorButton(
        label: 'Neutralny',
        color: NoteColorKey.neutral,
        note: note,
        onChanged: onChanged,
      ),
      _ColorButton(
        label: 'Błękit',
        color: NoteColorKey.blue,
        note: note,
        onChanged: onChanged,
      ),
      _ColorButton(
        label: 'Lawenda',
        color: NoteColorKey.lavender,
        note: note,
        onChanged: onChanged,
      ),
      _ColorButton(
        label: 'Mięta',
        color: NoteColorKey.mint,
        note: note,
        onChanged: onChanged,
      ),
      _ColorButton(
        label: 'Brzoskwinia',
        color: NoteColorKey.peach,
        note: note,
        onChanged: onChanged,
      ),
      _ColorButton(
        label: 'Piasek',
        color: NoteColorKey.sand,
        note: note,
        onChanged: onChanged,
      ),
      IconButton(
        tooltip: note.pinned ? 'Odepnij' : 'Przypnij',
        onPressed: () => onChanged(note.copyWith(pinned: !note.pinned)),
        icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
      ),
      IconButton(
        tooltip: 'Dodaj zdjęcie',
        onPressed: onPickImage,
        icon: const Icon(Icons.image_outlined),
      ),
      IconButton(
        tooltip: 'Dodaj plik',
        onPressed: onPickFile,
        icon: const Icon(Icons.attach_file_rounded),
      ),
      IconButton(
        tooltip: 'Edytuj etykiety',
        onPressed: onEditLabels,
        icon: const Icon(Icons.label_outline_rounded),
      ),
      IconButton(
        tooltip: note.isArchived ? 'Przywróć z archiwum' : 'Archiwizuj',
        onPressed: () => onChanged(
          note.copyWith(archivedAt: note.isArchived ? null : DateTime.now()),
        ),
        icon: Icon(
          note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
        ),
      ),
    ],
  );
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.label,
    required this.color,
    required this.note,
    required this.onChanged,
  });
  final String label;
  final NoteColorKey color;
  final NoteItem note;
  final ValueChanged<NoteItem> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Kolor: $label',
    selected: note.colorKey == color,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(note.copyWith(colorKey: color)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 9,
          backgroundColor: _noteTint(color, Theme.of(context).colorScheme),
          child: note.colorKey == color
              ? const Icon(Icons.check, size: 12)
              : null,
        ),
      ),
    ),
  );
}

class _ChecklistBlock extends StatelessWidget {
  const _ChecklistBlock({
    required this.block,
    required this.onChanged,
    this.onCreateTask,
  });
  final NoteBlock block;
  final ValueChanged<List<NoteChecklistItem>> onChanged;
  final Future<void> Function(String title)? onCreateTask;
  @override
  Widget build(BuildContext context) {
    final open = block.visibleChecklistItems
        .where((item) => !item.isDone)
        .toList();
    final completed = block.completedChecklistItems;
    Widget itemRow(NoteChecklistItem item, {required bool done}) => Row(
      children: [
        Checkbox(
          value: done,
          onChanged: (_) => onChanged(
            block.checklistItems
                .map(
                  (current) => current.id == item.id
                      ? current.copyWith(
                          isDone: !done,
                          completedAt: !done ? DateTime.now() : null,
                        )
                      : current,
                )
                .toList(),
          ),
        ),
        Expanded(
          child: TextFormField(
            initialValue: item.text,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Element listy',
            ),
            onChanged: (text) => onChanged(
              block.checklistItems
                  .map(
                    (current) => current.id == item.id
                        ? current.copyWith(text: text)
                        : current,
                  )
                  .toList(),
            ),
            style: done
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        ),
        if (onCreateTask != null)
          IconButton(
            tooltip: 'Utwórz zadanie z elementu',
            onPressed: () => onCreateTask!(item.text),
            icon: const Icon(Icons.add_task_outlined),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Checklista',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        ...open.map((item) => itemRow(item, done: false)),
        if (completed.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Ukończone (${completed.length})'),
            children: completed
                .map((item) => itemRow(item, done: true))
                .toList(),
          ),
        TextButton.icon(
          onPressed: () => onChanged([
            ...block.checklistItems,
            NoteChecklistItem(
              id: newNoteId(),
              text: '',
              position: block.checklistItems.length,
            ),
          ]),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Dodaj element'),
        ),
      ],
    );
  }
}

class _TableBlock extends StatelessWidget {
  const _TableBlock({
    required this.block,
    required this.onChanged,
    this.onCreateTask,
  });
  final NoteBlock block;
  final ValueChanged<NoteTableData> onChanged;
  final Future<void> Function(String title)? onCreateTask;

  @override
  Widget build(BuildContext context) {
    final table = block.table ?? const NoteTableData();
    final rows = table.rows.isEmpty
        ? [
            NoteTableRow(id: newNoteId(), cells: const {'Kolumna 1': ''}),
          ]
        : table.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tabela',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        for (final row in rows)
          Row(
            children: [
              if (table.mode == NoteTableMode.checklist)
                Checkbox(
                  value: row.isDone,
                  onChanged: (done) => onChanged(
                    table.copyWith(
                      rows: rows
                          .map(
                            (current) => current.id == row.id
                                ? current.copyWith(isDone: done)
                                : current,
                          )
                          .toList(),
                    ),
                  ),
                ),
              for (final column in table.columns)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: TextFormField(
                      initialValue: row.cells[column] ?? '',
                      decoration: InputDecoration(labelText: column),
                      onChanged: (value) => onChanged(
                        table.copyWith(
                          rows: rows
                              .map(
                                (current) => current.id == row.id
                                    ? current.copyWith(
                                        cells: {...row.cells, column: value},
                                      )
                                    : current,
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              if (table.mode == NoteTableMode.checklist && onCreateTask != null)
                IconButton(
                  tooltip: 'Utwórz zadanie z wiersza',
                  onPressed: () => onCreateTask!(row.cells.values.join(' · ')),
                  icon: const Icon(Icons.add_task_outlined),
                ),
            ],
          ),
        TextButton.icon(
          onPressed: () => onChanged(
            table.copyWith(
              rows: [
                ...rows,
                NoteTableRow(
                  id: newNoteId(),
                  cells: {for (final column in table.columns) column: ''},
                  position: rows.length,
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Dodaj wiersz'),
        ),
      ],
    );
  }
}

String _firstText(NoteItem note) => note.blocks
    .firstWhere(
      (block) => block.type == NoteBlockType.text,
      orElse: () => const NoteBlock.text(id: 'empty'),
    )
    .text;
String _blockLabel(NoteBlockType type) => switch (type) {
  NoteBlockType.text => 'Tekst',
  NoteBlockType.heading => 'Nagłówek',
  NoteBlockType.quote => 'Cytat',
  NoteBlockType.checklist => 'Checklista',
  NoteBlockType.table => 'Tabela',
  NoteBlockType.attachment => 'Załącznik',
};
String _formatBytes(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

Color _noteTint(NoteColorKey key, ColorScheme scheme) => switch (key) {
  NoteColorKey.neutral => scheme.surfaceContainerLow,
  NoteColorKey.blue => Color.alphaBlend(
    scheme.primary.withValues(alpha: .10),
    scheme.surfaceContainerLow,
  ),
  NoteColorKey.lavender => Color.alphaBlend(
    const Color(0xff8d7cf7).withValues(alpha: .10),
    scheme.surfaceContainerLow,
  ),
  NoteColorKey.mint => Color.alphaBlend(
    const Color(0xff52b788).withValues(alpha: .10),
    scheme.surfaceContainerLow,
  ),
  NoteColorKey.peach => Color.alphaBlend(
    const Color(0xffee9b6b).withValues(alpha: .10),
    scheme.surfaceContainerLow,
  ),
  NoteColorKey.sand => Color.alphaBlend(
    const Color(0xffd2b48c).withValues(alpha: .10),
    scheme.surfaceContainerLow,
  ),
};
