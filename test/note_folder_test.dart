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

  test('folder emoji survives storage and Supabase row mapping', () {
    final old = NoteFolder.fromStorage({'id': 'old', 'name': 'Praca'});
    expect(old.emoji, isNull);
    expect(
      NoteFolder.fromSupabaseRow({'id': 'old', 'name': 'Praca'}).emoji,
      isNull,
    );

    final folder = NoteFolder(id: 'car', name: 'Samochód', emoji: '🚗');
    expect(NoteFolder.fromStorage(folder.toStorage()).emoji, '🚗');
    expect(folder.toStorage()['emoji'], '🚗');
    expect(folder.toSupabasePayload('owner')['emoji'], '🚗');
    expect(
      NoteFolder.fromSupabaseRow({
        ...folder.toSupabasePayload('owner'),
        'user_id': 'owner',
      }).emoji,
      '🚗',
    );
    expect(folder.copyWith(emoji: null).emoji, isNull);
  });

  test('blank stored and cloud emoji normalize to null', () {
    expect(
      NoteFolder.fromStorage({
        'id': 'blank-local',
        'name': 'Praca',
        'emoji': '',
      }).emoji,
      isNull,
    );
    expect(
      NoteFolder.fromStorage({
        'id': 'spaces-local',
        'name': 'Praca',
        'emoji': '  ',
      }).emoji,
      isNull,
    );
    expect(
      NoteFolder.fromSupabaseRow({
        'id': 'blank-cloud',
        'name': 'Praca',
        'emoji': '  ',
      }).emoji,
      isNull,
    );
  });
}
