import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dzien_po_dniu/local_backup_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('captures and restores user data and local attachment paths', () async {
    final source = await Directory.systemTemp.createTemp('dniowka-backup-source-');
    final target = await Directory.systemTemp.createTemp('dniowka-backup-target-');
    addTearDown(() async {
      await source.delete(recursive: true);
      await target.delete(recursive: true);
    });
    final attachment = File(
      '${source.path}${Platform.pathSeparator}attachments${Platform.pathSeparator}note-1${Platform.pathSeparator}photo.jpg',
    );
    await attachment.parent.create(recursive: true);
    await attachment.writeAsBytes([1, 2, 3]);
    await File('${source.path}/notes.json').writeAsString(jsonEncode([
      {'id': 'note-1', 'attachments': [{'localPath': attachment.path}]},
    ]));
    SharedPreferences.setMockInitialValues({
      'local_tasks_v1': '[{"id":"task-1"}]',
      'task_sync_outbox_v1_owner-1': '[{"id":"task-1"}]',
      'note_sync_outbox_v1_owner-1': jsonEncode([
        {
          'id': 'note-1',
          'note': {'attachments': [{'localPath': attachment.path}]},
        },
      ]),
      'work_hours_v1_owner-1': '{"entries":[],"pending":[]}',
      'cost_entries_v1_other-owner': '[{"private":"other"}]',
      'supabase.auth.token': 'never include',
    });
    final sourcePrefs = await SharedPreferences.getInstance();
    final captured = await LocalBackupData(sourcePrefs, source).capture('owner-1');

    expect(captured['ownerId'], 'owner-1');
    final values = captured['preferences'] as Map;
    expect(values['task_sync_outbox_v1_owner-1'], isNotNull);
    final capturedOutbox = jsonDecode(
      values['note_sync_outbox_v1_owner-1'] as String,
    ) as List;
    expect(
      capturedOutbox.single['note']['attachments'][0]['localPath'],
      'backup://attachments/note-1/photo.jpg',
    );
    expect(values['work_hours_v1_owner-1'], isNotNull);
    expect(values.containsKey('cost_entries_v1_other-owner'), isFalse);
    expect(values.containsKey('supabase.auth.token'), isFalse);

    SharedPreferences.setMockInitialValues({});
    final targetPrefs = await SharedPreferences.getInstance();
    await LocalBackupData(targetPrefs, target).restore(captured, 'owner-1');
    expect(targetPrefs.getString('local_tasks_v1'), contains('task-1'));
    expect(
      await File('${target.path}/attachments/note-1/photo.jpg').readAsBytes(),
      [1, 2, 3],
    );
    final restoredNotes = jsonDecode(
      await File('${target.path}/notes.json').readAsString(),
    ) as List;
    expect(restoredNotes.first['attachments'][0]['localPath'],
        '${target.path}${Platform.pathSeparator}attachments${Platform.pathSeparator}note-1${Platform.pathSeparator}photo.jpg');
    final restoredOutbox = jsonDecode(
      targetPrefs.getString('note_sync_outbox_v1_owner-1')!,
    ) as List;
    expect(
      restoredOutbox.single['note']['attachments'][0]['localPath'],
      '${target.path}${Platform.pathSeparator}attachments${Platform.pathSeparator}note-1${Platform.pathSeparator}photo.jpg',
    );
  });

  test('refuses to restore another account or escaping file paths', () async {
    final target = await Directory.systemTemp.createTemp('dniowka-backup-guard-');
    addTearDown(() => target.delete(recursive: true));
    SharedPreferences.setMockInitialValues({});
    final data = LocalBackupData(await SharedPreferences.getInstance(), target);
    expect(
      () => data.restore({'ownerId': 'other', 'preferences': {}, 'files': {}}, 'mine'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => data.restore({
        'ownerId': 'mine',
        'preferences': {},
        'files': {'../escape.txt': 'YQ=='},
      }, 'mine'),
      throwsA(isA<FormatException>()),
    );
  });
}
