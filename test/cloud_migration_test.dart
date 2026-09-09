import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/cloud_migration.dart';

void main() {
  test('offers migration only when local tasks exist and cloud is empty', () {
    final decision = decideLocalTaskMigration(
      localTaskCount: 3,
      cloudTaskCount: 0,
      migrationCompleted: false,
    );

    expect(decision.shouldImport, isTrue);
  });

  test('does not offer migration when cloud already contains tasks', () {
    final decision = decideLocalTaskMigration(
      localTaskCount: 3,
      cloudTaskCount: 1,
      migrationCompleted: false,
    );

    expect(decision.shouldImport, isFalse);
    expect(decision.reason, contains('nie nadpisujemy'));
  });

  test('does not offer migration twice', () {
    final decision = decideLocalTaskMigration(
      localTaskCount: 3,
      cloudTaskCount: 0,
      migrationCompleted: true,
    );

    expect(decision.shouldImport, isFalse);
  });
}
