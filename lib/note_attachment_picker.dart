import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'note_item.dart';

/// A platform-neutral result from the gallery/file picker.
class NoteAttachmentCandidate {
  const NoteAttachmentCandidate({
    required this.file,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
  });

  final File file;
  final String fileName;
  final String mimeType;
  final int byteSize;
}

class NoteAttachmentPicker {
  const NoteAttachmentPicker._();

  static Future<NoteAttachmentCandidate?> pick({required bool imageOnly}) async {
    final picked = await FilePicker.pickFile(
      type: imageOnly ? FileType.image : FileType.any,
    );
    final path = picked?.path;
    if (picked == null || path == null) return null;
    final file = File(path);
    final byteSize = await file.length();
    if (byteSize > noteAttachmentMaxBytes) {
      throw ArgumentError('Plik nie może przekraczać 20 MB.');
    }
    return NoteAttachmentCandidate(
      file: file,
      fileName: picked.name,
      mimeType: _mimeType(picked.name),
      byteSize: byteSize,
    );
  }
}

String _mimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}
