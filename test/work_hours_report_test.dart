import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/work_hours.dart';
import 'package:dzien_po_dniu/work_hours_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final item = WorkEntry(
    id: 'a',
    date: DateTime(2026, 9, 10),
    name: 'Łańcuch',
    place: 'Kraków',
    startMinute: 480,
    endMinute: 1020,
    rateCents: 4000,
    updatedAt: DateTime.utc(2026, 9, 10),
  );
  test('text report has exact hours, cents totals and optional amounts', () {
    final text = workReportText([item], 'Wrzesień 2026');
    expect(text, contains('Łańcuch'));
    expect(text, contains('9 h'));
    expect(text.replaceAll('\u00a0', ' '), contains('360,00 zł'));
    final without = workReportText(
      [item],
      'Wrzesień 2026',
      includeAmounts: false,
    );
    expect(without, isNot(contains('zł')));
    expect(without, isNot(contains('Nieopłacone')));
  });
  test(
    'PDF uses bundled Polish font and paginates many rows offline',
    () async {
      final bytes = await workReportPdf(
        List.filled(100, item),
        'Wrzesień 2026',
      );
      final source = latin1.decode(bytes);
      expect(source, startsWith('%PDF-'));
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(source).length,
        greaterThan(1),
      );
      expect(source, contains('/FontFile2'));
    },
  );
}
