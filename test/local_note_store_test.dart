import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/local_note_store.dart';
import 'package:dzien_po_dniu/note_item.dart';

void main() {
  test('persists notes in an application-data directory', () async {
    final directory = await Directory.systemTemp.createTemp('notes-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = LocalNoteStore(directory: directory);
    final note = NoteItem(id: 'note-1', title: 'Offline');

    await store.save([note]);
    final restored = await store.load();

    expect(restored.single.title, 'Offline');
    expect(File('${directory.path}/notes.json').existsSync(), isTrue);
  });

  test('copies an attachment into the note data directory', () async {
    final directory = await Directory.systemTemp.createTemp('notes-test-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/source.txt')..writeAsStringSync('ok');
    final store = LocalNoteStore(directory: directory);

    final attachment = await store.copyAttachment(
      noteId: 'note-1',
      attachmentId: 'a1',
      source: source,
      fileName: 'source.txt',
    );

    expect(File(attachment.localPath!).readAsStringSync(), 'ok');
    expect(attachment.fileName, 'source.txt');
  });
}
