class CloudMigrationDecision {
  const CloudMigrationDecision({
    required this.shouldImport,
    required this.reason,
  });

  final bool shouldImport;
  final String reason;
}

CloudMigrationDecision decideLocalTaskMigration({
  required int localTaskCount,
  required int cloudTaskCount,
  required bool migrationCompleted,
}) {
  if (migrationCompleted) {
    return const CloudMigrationDecision(
      shouldImport: false,
      reason: 'Migracja została już wykonana.',
    );
  }
  if (localTaskCount == 0) {
    return const CloudMigrationDecision(
      shouldImport: false,
      reason: 'Brak lokalnych zadań do przeniesienia.',
    );
  }
  if (cloudTaskCount > 0) {
    return const CloudMigrationDecision(
      shouldImport: false,
      reason: 'Chmura zawiera już zadania — nie nadpisujemy ich.',
    );
  }
  return const CloudMigrationDecision(
    shouldImport: true,
    reason:
        'Chmura jest pusta, więc można bezpiecznie przenieść zadania lokalne.',
  );
}
