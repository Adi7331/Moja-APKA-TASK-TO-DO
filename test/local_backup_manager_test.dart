import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/local_backup_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retains seven complete backups and restores a selected snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final support = await Directory.systemTemp.createTemp('dniowka-backup-data-');
    final destination = await Directory.systemTemp.createTemp('dniowka-backup-target-');
    addTearDown(() async {
      await support.delete(recursive: true);
      await destination.delete(recursive: true);
    });
    final manager = LocalBackupManager(
      preferences: preferences,
      supportDirectory: support,
      storage: DesktopBackupStorage(),
      passwords: MemoryBackupPasswordStore(),
      now: () => DateTime.utc(2026, 10, 13, 12),
    );
    await manager.configure(
      ownerId: 'user-1',
      folder: destination.path,
      enabled: true,
    );
    for (var index = 0; index < 9; index++) {
      await preferences.setString('local_tasks_v1', 'tasks-$index');
      await manager.createNow('user-1');
    }
    final backups = await manager.listBackups();
    expect(backups, hasLength(7));
    expect(manager.settings.lastSuccessfulAt, isNotNull);
    await manager.restore(backups.first, 'user-1');
    expect(preferences.getString('local_tasks_v1'), 'tasks-8');
  });

  test('disabled backup never runs automatically', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final support = await Directory.systemTemp.createTemp('dniowka-backup-data-');
    final destination = await Directory.systemTemp.createTemp('dniowka-backup-target-');
    addTearDown(() async {
      await support.delete(recursive: true);
      await destination.delete(recursive: true);
    });
    final manager = LocalBackupManager(
      preferences: preferences,
      supportDirectory: support,
      storage: DesktopBackupStorage(),
      passwords: MemoryBackupPasswordStore(),
    );
    await manager.configure(ownerId: 'user-1', folder: destination.path, enabled: false);
    await manager.backupIfChanged('user-1');
    expect(await manager.listBackups(), isEmpty);
  });
}
