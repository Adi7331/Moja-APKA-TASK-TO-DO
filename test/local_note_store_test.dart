import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/local_note_store.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:dzien_po_dniu/note_folder.dart';

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

  test('persists note folders separately from note content', () async {
    final directory = await Directory.systemTemp.createTemp('folders-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = LocalNoteStore(directory: directory);

    await store.saveFolders([NoteFolder(id: 'work', name: 'Praca')]);

    expect((await store.loadFolders()).single.name, 'Praca');
    expect(File('${directory.path}/note_folders.json').existsSync(), isTrue);
  });
}
