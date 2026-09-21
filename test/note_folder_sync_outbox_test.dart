import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/note_folder.dart';
import 'package:dzien_po_dniu/note_folder_sync_outbox.dart';
import 'package:dzien_po_dniu/note_item.dart';

void main() {
  test('folder outbox keeps only the newest operation per folder', () async {
    SharedPreferences.setMockInitialValues({});
    final store = NoteFolderSyncOutbox(await SharedPreferences.getInstance());
    final folder = NoteFolder(
      id: 'folder-1',
      name: 'Praca',
      colorKey: NoteColorKey.blue,
    );

    await store.enqueueUpsert(folder);
    await store.enqueueDelete(folder);

    final pending = await store.load();
    expect(pending, hasLength(1));
    expect(pending.single.kind, NoteFolderSyncOperationKind.delete);
  });
}
