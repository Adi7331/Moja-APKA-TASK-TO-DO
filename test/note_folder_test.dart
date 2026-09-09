import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('folder survives local serialization with its color', () {
    final folder = NoteFolder(
      id: 'folder-1',
      name: 'Praca',
      colorKey: NoteColorKey.lavender,
    );

    final restored = NoteFolder.fromStorage(folder.toStorage());

    expect(restored.id, 'folder-1');
    expect(restored.name, 'Praca');
    expect(restored.colorKey, NoteColorKey.lavender);
  });
}
