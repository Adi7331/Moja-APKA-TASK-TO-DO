import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/note_attachment_preview.dart';
import 'package:dzien_po_dniu/note_item.dart';

NoteAttachment attachment(String name, String mimeType) => NoteAttachment(
  id: 'a1',
  fileName: name,
  mimeType: mimeType,
  byteSize: 1,
);

void main() {
  test('selects internal preview for image, PDF and text attachments', () {
    expect(
      noteAttachmentPreviewKind(attachment('photo.jpg', 'image/jpeg')),
      NoteAttachmentPreviewKind.image,
    );
    expect(
      noteAttachmentPreviewKind(attachment('file.pdf', 'application/pdf')),
      NoteAttachmentPreviewKind.pdf,
    );
    expect(
      noteAttachmentPreviewKind(attachment('notes.md', 'application/octet-stream')),
      NoteAttachmentPreviewKind.text,
    );
  });

  test('keeps office documents in-app until user chooses external app', () {
    expect(
      noteAttachmentPreviewKind(
        attachment(
          'document.docx',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
      ),
      NoteAttachmentPreviewKind.external,
    );
  });
}
