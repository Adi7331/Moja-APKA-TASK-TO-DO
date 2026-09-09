import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/note_item.dart';

void main() {
  test('serializes a note with structured blocks and restores it', () {
    final note = NoteItem(
      id: 'note-1',
      title: 'Plan tygodnia',
      colorKey: NoteColorKey.blue,
      pinned: true,
      labels: const ['praca'],
      blocks: [
        NoteBlock.text(id: 'b1', text: 'Najważniejsze rzeczy'),
        NoteBlock.checklist(
          id: 'b2',
          items: [
            NoteChecklistItem(id: 'c1', text: 'Telefon', isDone: false),
            NoteChecklistItem(id: 'c2', text: 'Raport', isDone: true),
          ],
        ),
      ],
    );

    final restored = NoteItem.fromStorage(note.toStorage());

    expect(restored.id, note.id);
    expect(restored.title, note.title);
    expect(restored.pinned, isTrue);
    expect(restored.labels, ['praca']);
    expect(restored.blocks[1].checklistItems.first.text, 'Telefon');
    expect(restored.blocks[1].checklistItems.last.isDone, isTrue);
  });

  test('keeps open checklist items and completed items in separate order', () {
    final block = NoteBlock.checklist(
      id: 'b1',
      items: [
        NoteChecklistItem(id: 'done', text: 'Gotowe', isDone: true, position: 0),
        NoteChecklistItem(id: 'open', text: 'Do zrobienia', isDone: false, position: 1),
      ],
    );

    expect(block.visibleChecklistItems.map((item) => item.id), ['open', 'done']);
    expect(block.completedChecklistItems.map((item) => item.id), ['done']);
  });

  test('moves completed table rows below open rows', () {
    final block = NoteBlock.table(
      id: 'table',
      table: NoteTableData(
        mode: NoteTableMode.checklist,
        columns: const ['Zadanie'],
        rows: [
          NoteTableRow(id: 'r2', cells: const {'Zadanie': 'Gotowe'}, isDone: true),
          NoteTableRow(id: 'r1', cells: const {'Zadanie': 'Otwarte'}),
        ],
      ),
    );

    expect(block.visibleTableRows.map((row) => row.id), ['r1', 'r2']);
  });

  test('rejects attachments larger than 20 MB', () {
    expect(
      () => NoteAttachment(
        id: 'a1',
        fileName: 'duzy.zip',
        mimeType: 'application/zip',
        byteSize: 20 * 1024 * 1024 + 1,
      ),
      throwsArgumentError,
    );
  });
}
