import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'work_hours.dart';

String workMoney(int cents) =>
    NumberFormat.currency(locale: 'pl_PL', symbol: 'zł').format(cents / 100);

String workReportText(
  List<WorkEntry> entries,
  String period, {
  bool includeAmounts = true,
}) {
  final summary = WorkSummary(entries);
  final lines = <String>['Dniówka — ewidencja pracy', period, ''];
  for (final item in entries) {
    lines.add(
      '${DateFormat('dd.MM.yyyy').format(item.date)} · ${item.name}${item.place.isEmpty ? '' : ' · ${item.place}'}',
    );
    lines.add(
      '${workTime(item.startMinute)}–${workTime(item.endMinute)}${item.nextDay ? ' (+1 dzień)' : ''} · przerwa ${item.breakMinutes} min · ${workDuration(item.workMinutes)}${includeAmounts ? ' · ${workMoney(item.amountCents)} · ${item.paid ? 'Opłacone' : 'Nieopłacone'}' : ''}',
    );
  }
  lines.addAll([
    '',
    'Razem: ${summary.days} dni · ${workDuration(summary.minutes)}',
  ]);
  if (includeAmounts) {
    lines.addAll([
      'Należność: ${workMoney(summary.totalCents)}',
      'Opłacone: ${workMoney(summary.paidCents)}',
      'Do wypłaty: ${workMoney(summary.outstandingCents)}',
      'Kwoty obliczono jako czas pracy × stawka, bez podatków i dodatków.',
    ]);
  }
  return lines.join('\n');
}

Future<Uint8List> workReportPdf(
  List<WorkEntry> entries,
  String period, {
  bool includeAmounts = true,
}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope.ttf'));
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final summary = WorkSummary(entries);
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 1000,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Text(
        'Dniówka · ${context.pageNumber}/${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      build: (_) => [
        pw.Text(
          'Ewidencja godzin pracy',
          style: const pw.TextStyle(fontSize: 22),
        ),
        pw.SizedBox(height: 8),
        pw.Text(period),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: [
            'Data / praca / miejsce',
            'Od–do / przerwa',
            'Czas',
            if (includeAmounts) 'Kwota / stawka / status',
          ],
          data: [
            for (final item in entries)
              [
                '${DateFormat('dd.MM.yyyy').format(item.date)}\n${item.name}\n${item.place}',
                '${workTime(item.startMinute)}–${workTime(item.endMinute)}${item.nextDay ? ' (+1)' : ''}\n${item.breakMinutes} min',
                workDuration(item.workMinutes),
                if (includeAmounts)
                  '${workMoney(item.amountCents)}\n${workMoney(item.rateCents)}/h\n${item.paid ? 'Opłacone' : 'Nieopłacone'}',
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Razem: ${summary.days} dni · ${workDuration(summary.minutes)}',
        ),
        if (includeAmounts) ...[
          pw.Text('Należność: ${workMoney(summary.totalCents)}'),
          pw.Text('Opłacone: ${workMoney(summary.paidCents)}'),
          pw.Text('Do wypłaty: ${workMoney(summary.outstandingCents)}'),
          pw.SizedBox(height: 8),
          pw.Text(
            'Kwoty: czas pracy × stawka. Bez podatków i dodatków.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ],
    ),
  );
  return document.save();
}
