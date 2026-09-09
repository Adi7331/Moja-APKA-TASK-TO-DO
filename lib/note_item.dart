import 'dart:math' as math;

const noteAttachmentMaxBytes = 20 * 1024 * 1024;

String newNoteId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum NoteColorKey { neutral, blue, lavender, mint, peach, sand }

enum NoteBlockType { text, heading, quote, checklist, table, attachment }

enum NoteTableMode { plain, checklist }

enum NoteTrashRetention { never, sevenDays, thirtyDays }

class NoteSettings {
  const NoteSettings({this.trashRetention = NoteTrashRetention.never});

  factory NoteSettings.fromJson(Map<String, dynamic> json) => NoteSettings(
    trashRetention: switch (json['trashRetentionDays']) {
      7 => NoteTrashRetention.sevenDays,
      30 => NoteTrashRetention.thirtyDays,
      _ => NoteTrashRetention.never,
    },
  );

  final NoteTrashRetention trashRetention;

  int? get trashRetentionDays => switch (trashRetention) {
    NoteTrashRetention.never => null,
    NoteTrashRetention.sevenDays => 7,
    NoteTrashRetention.thirtyDays => 30,
  };

  Map<String, dynamic> toJson() => {'trashRetentionDays': trashRetentionDays};
  Map<String, dynamic> toSupabasePayload(String userId) => {
    'user_id': userId,
    'trash_retention_days': trashRetentionDays,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class NoteChecklistItem {
  const NoteChecklistItem({
    required this.id,
    required this.text,
    this.isDone = false,
    this.position = 0,
    this.completedAt,
  });

  factory NoteChecklistItem.fromJson(Map<String, dynamic> json) =>
      NoteChecklistItem(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
        position: (json['position'] as num?)?.toInt() ?? 0,
        completedAt: _date(json['completedAt']),
      );

  final String id;
  final String text;
  final bool isDone;
  final int position;
  final DateTime? completedAt;

  NoteChecklistItem copyWith({
    String? id,
    String? text,
    bool? isDone,
    int? position,
    Object? completedAt = _unset,
  }) => NoteChecklistItem(
    id: id ?? this.id,
    text: text ?? this.text,
    isDone: isDone ?? this.isDone,
    position: position ?? this.position,
    completedAt: identical(completedAt, _unset)
        ? this.completedAt
        : completedAt as DateTime?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isDone': isDone,
    'position': position,
    'completedAt': completedAt?.toIso8601String(),
  };
}

class NoteTableRow {
  const NoteTableRow({
    required this.id,
    this.cells = const {},
    this.isDone = false,
    this.position = 0,
  });

  factory NoteTableRow.fromJson(Map<String, dynamic> json) => NoteTableRow(
    id: json['id'] as String,
    cells: Map<String, dynamic>.from(json['cells'] as Map? ?? const {})
        .map((key, value) => MapEntry(key, value?.toString() ?? '')),
    isDone: json['isDone'] as bool? ?? false,
    position: (json['position'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final Map<String, String> cells;
  final bool isDone;
  final int position;

  NoteTableRow copyWith({
    String? id,
    Map<String, String>? cells,
    bool? isDone,
    int? position,
  }) => NoteTableRow(
    id: id ?? this.id,
    cells: cells ?? this.cells,
    isDone: isDone ?? this.isDone,
    position: position ?? this.position,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'cells': cells,
    'isDone': isDone,
    'position': position,
  };
}

class NoteTableData {
  const NoteTableData({
    this.mode = NoteTableMode.plain,
    this.columns = const ['Kolumna 1'],
    this.rows = const [],
  });

  factory NoteTableData.fromJson(Map<String, dynamic> json) => NoteTableData(
    mode: NoteTableMode.values.firstWhere(
      (value) => value.name == json['mode'],
      orElse: () => NoteTableMode.plain,
    ),
    columns: (json['columns'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    rows: (json['rows'] as List<dynamic>? ?? const [])
        .map((item) => NoteTableRow.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  final NoteTableMode mode;
  final List<String> columns;
  final List<NoteTableRow> rows;

  NoteTableData copyWith({
    NoteTableMode? mode,
    List<String>? columns,
    List<NoteTableRow>? rows,
  }) => NoteTableData(
    mode: mode ?? this.mode,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'columns': columns,
    'rows': rows.map((row) => row.toJson()).toList(),
  };
}

class NoteAttachment {
  NoteAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    this.localPath,
    this.storagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (byteSize > noteAttachmentMaxBytes) {
      throw ArgumentError.value(
        byteSize,
        'byteSize',
        'Załącznik nie może przekraczać 20 MB.',
      );
    }
    if (byteSize < 0) throw ArgumentError.value(byteSize, 'byteSize');
  }

  factory NoteAttachment.fromJson(Map<String, dynamic> json) => NoteAttachment(
    id: json['id'] as String,
    fileName: json['fileName'] as String? ?? 'plik',
    mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
    localPath: json['localPath'] as String?,
    storagePath: json['storagePath'] as String?,
    createdAt: _date(json['createdAt']),
  );

  final String id;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String? localPath;
  final String? storagePath;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'mimeType': mimeType,
    'byteSize': byteSize,
    'localPath': localPath,
    'storagePath': storagePath,
    'createdAt': createdAt.toIso8601String(),
  };
}

class NoteBlock {
  const NoteBlock._({
    required this.id,
    required this.type,
    this.text = '',
    this.checklistItems = const [],
    this.table,
    this.attachmentId,
    this.position = 0,
  });

  const NoteBlock.text({required String id, String text = '', int position = 0})
    : this._(id: id, type: NoteBlockType.text, text: text, position: position);

  const NoteBlock.heading({required String id, String text = '', int position = 0})
    : this._(id: id, type: NoteBlockType.heading, text: text, position: position);

  const NoteBlock.quote({required String id, String text = '', int position = 0})
    : this._(id: id, type: NoteBlockType.quote, text: text, position: position);

  const NoteBlock.checklist({
    required String id,
    List<NoteChecklistItem> items = const [],
    int position = 0,
  }) : this._(
    id: id,
    type: NoteBlockType.checklist,
    checklistItems: items,
    position: position,
  );

  const NoteBlock.table({
    required String id,
    required NoteTableData table,
    int position = 0,
  }) : this._(id: id, type: NoteBlockType.table, table: table, position: position);

  const NoteBlock.attachment({
    required String id,
    required String attachmentId,
    int position = 0,
  }) : this._(
    id: id,
    type: NoteBlockType.attachment,
    attachmentId: attachmentId,
    position: position,
  );

  factory NoteBlock.fromJson(Map<String, dynamic> json) => NoteBlock._(
    id: json['id'] as String,
    type: NoteBlockType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => NoteBlockType.text,
    ),
    text: json['text'] as String? ?? '',
    checklistItems: (json['checklistItems'] as List<dynamic>? ?? const [])
        .map((item) => NoteChecklistItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    table: json['table'] is Map
        ? NoteTableData.fromJson(Map<String, dynamic>.from(json['table'] as Map))
        : null,
    attachmentId: json['attachmentId'] as String?,
    position: (json['position'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final NoteBlockType type;
  final String text;
  final List<NoteChecklistItem> checklistItems;
  final NoteTableData? table;
  final String? attachmentId;
  final int position;

  List<NoteChecklistItem> get visibleChecklistItems => _openFirst(checklistItems);
  List<NoteChecklistItem> get completedChecklistItems =>
      checklistItems.where((item) => item.isDone).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
  List<NoteTableRow> get visibleTableRows => _openFirst(table?.rows ?? const []);

  NoteBlock copyWith({
    String? id,
    NoteBlockType? type,
    String? text,
    List<NoteChecklistItem>? checklistItems,
    Object? table = _unset,
    Object? attachmentId = _unset,
    int? position,
  }) => NoteBlock._(
    id: id ?? this.id,
    type: type ?? this.type,
    text: text ?? this.text,
    checklistItems: checklistItems ?? this.checklistItems,
    table: identical(table, _unset) ? this.table : table as NoteTableData?,
    attachmentId: identical(attachmentId, _unset)
        ? this.attachmentId
        : attachmentId as String?,
    position: position ?? this.position,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'text': text,
    'checklistItems': checklistItems.map((item) => item.toJson()).toList(),
    'table': table?.toJson(),
    'attachmentId': attachmentId,
    'position': position,
  };
}

class NoteItem {
  NoteItem({
    required this.id,
    this.userId,
    this.title = '',
    this.blocks = const [],
    this.colorKey = NoteColorKey.neutral,
    this.pinned = false,
    this.archivedAt,
    this.deletedAt,
    this.reminderAt,
    this.revision = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.labels = const [],
    this.attachments = const [],
    this.conflictOf,
    this.folderId,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory NoteItem.fromStorage(Map<String, dynamic> json) => NoteItem(
    id: json['id'] as String,
    userId: json['userId'] as String?,
    title: json['title'] as String? ?? '',
    blocks: (json['blocks'] as List<dynamic>? ?? const [])
        .map((item) => NoteBlock.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    colorKey: _enumValue(NoteColorKey.values, json['colorKey'], NoteColorKey.neutral),
    pinned: json['pinned'] as bool? ?? false,
    archivedAt: _date(json['archivedAt']),
    deletedAt: _date(json['deletedAt']),
    reminderAt: _date(json['reminderAt']),
    revision: (json['revision'] as num?)?.toInt() ?? 1,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    labels: (json['labels'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    attachments: (json['attachments'] as List<dynamic>? ?? const [])
        .map((item) => NoteAttachment.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    conflictOf: json['conflictOf'] as String?,
    folderId: json['folderId'] as String?,
  );

  final String id;
  final String? userId;
  final String title;
  final List<NoteBlock> blocks;
  final NoteColorKey colorKey;
  final bool pinned;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime? reminderAt;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> labels;
  final List<NoteAttachment> attachments;
  final String? conflictOf;
  /// A note belongs to at most one folder. A missing value intentionally means
  /// "Bez folderu" so older local files remain readable.
  final String? folderId;

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  String get previewText {
    final parts = <String>[];
    if (title.trim().isNotEmpty) parts.add(title.trim());
    for (final block in blocks) {
      if (block.text.trim().isNotEmpty) parts.add(block.text.trim());
      if (block.type == NoteBlockType.checklist) {
        parts.addAll(block.checklistItems.map((item) => item.text));
      }
      if (block.type == NoteBlockType.table) {
        parts.addAll(block.table?.rows.expand((row) => row.cells.values) ?? const []);
      }
    }
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int get checklistTotal => blocks.fold(0, (sum, block) => sum + block.checklistItems.length);
  int get checklistDone => blocks.fold(
    0,
    (sum, block) => sum + block.checklistItems.where((item) => item.isDone).length,
  );

  NoteItem copyWith({
    String? id,
    Object? userId = _unset,
    String? title,
    List<NoteBlock>? blocks,
    NoteColorKey? colorKey,
    bool? pinned,
    Object? archivedAt = _unset,
    Object? deletedAt = _unset,
    Object? reminderAt = _unset,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? labels,
    List<NoteAttachment>? attachments,
    Object? conflictOf = _unset,
    Object? folderId = _unset,
  }) => NoteItem(
    id: id ?? this.id,
    userId: identical(userId, _unset) ? this.userId : userId as String?,
    title: title ?? this.title,
    blocks: blocks ?? this.blocks,
    colorKey: colorKey ?? this.colorKey,
    pinned: pinned ?? this.pinned,
    archivedAt: identical(archivedAt, _unset)
        ? this.archivedAt
        : archivedAt as DateTime?,
    deletedAt: identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?,
    reminderAt: identical(reminderAt, _unset)
        ? this.reminderAt
        : reminderAt as DateTime?,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    labels: labels ?? this.labels,
    attachments: attachments ?? this.attachments,
    conflictOf: identical(conflictOf, _unset)
        ? this.conflictOf
        : conflictOf as String?,
    folderId: identical(folderId, _unset) ? this.folderId : folderId as String?,
  );

  Map<String, dynamic> toStorage() => {
    'id': id,
    'userId': userId,
    'title': title,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'colorKey': colorKey.name,
    'pinned': pinned,
    'archivedAt': archivedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'reminderAt': reminderAt?.toIso8601String(),
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'labels': labels,
    'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
    'conflictOf': conflictOf,
    'folderId': folderId,
  };

  Map<String, dynamic> toSupabasePayload({required String userId}) => {
    'id': id,
    'user_id': userId,
    'title': title.trim().substring(0, math.min(title.trim().length, 160)),
    'preview_text': previewText.substring(0, math.min(previewText.length, 400)),
    'color_key': colorKey.name,
    'pinned': pinned,
    'archived_at': archivedAt?.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
    'reminder_at': reminderAt?.toUtc().toIso8601String(),
    'revision': revision,
    'conflict_of': conflictOf,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

const _unset = Object();

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.firstWhere((value) => value.name == raw, orElse: () => fallback);

List<T> _openFirst<T>(Iterable<T> source) {
  final values = source.toList();
  values.sort((a, b) {
    final aDone = a is NoteChecklistItem ? a.isDone : (a as NoteTableRow).isDone;
    final bDone = b is NoteChecklistItem ? b.isDone : (b as NoteTableRow).isDone;
    if (aDone != bDone) return aDone ? 1 : -1;
    final aPos = a is NoteChecklistItem ? a.position : (a as NoteTableRow).position;
    final bPos = b is NoteChecklistItem ? b.position : (b as NoteTableRow).position;
    return aPos.compareTo(bPos);
  });
  return values;
}
