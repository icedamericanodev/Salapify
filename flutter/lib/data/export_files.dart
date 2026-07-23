// Export the ledger to real files a normal person can open elsewhere: a CSV or
// Excel sheet of transactions, and a one-page PDF report of the month. Each is
// built in memory then handed to the system share sheet (Files, Drive, email),
// the same move as the JSON backup. These files hold financial data, so the
// temp copy is deleted right after the share sheet closes.
//
// The CSV builder is pure and unit tested. The numbers all come from amountOf
// and the golden-locked statements engine, never invented here. No em dashes.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../money/ledger.dart' show amountOf;
import '../money/statements.dart';

const List<String> _headers = [
  'Date',
  'Type',
  'Label',
  'Amount',
  'Account',
  'Note',
];

String _peso(num value) {
  if (!value.isFinite) return 'PHP $value';
  final neg = value < 0;
  final scaled = value.abs() * 100;
  if (!scaled.isFinite) return 'PHP $value';
  final rounded = scaled.round() / 100;
  final whole = rounded.floor();
  final cents = ((rounded - whole) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final centsPart = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}PHP $buf$centsPart';
}

List<Map<String, dynamic>> _txns(Map data) {
  final t = data['transactions'];
  if (t is! List) return const [];
  return t.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

Map<String, String> _accountNames(Map data) {
  final out = <String, String>{};
  final accts = data['accounts'];
  if (accts is List) {
    for (final a in accts) {
      if (a is Map && a['id'] is String) {
        out[a['id'] as String] = (a['name'] ?? '').toString();
      }
    }
  }
  return out;
}

// Header plus one row per transaction, newest first. Shared by CSV and Excel so
// the two exports always carry the same columns and order.
List<List<dynamic>> transactionRows(Map data) {
  final names = _accountNames(data);
  final txns = _txns(data);
  txns.sort(
    (a, b) =>
        (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()),
  );
  final rows = <List<dynamic>>[List<dynamic>.from(_headers)];
  for (final t in txns) {
    rows.add([
      (t['date'] ?? '').toString(),
      (t['type'] ?? '').toString(),
      (t['label'] ?? '').toString(),
      amountOf(t['amount']),
      names[t['accountId']] ?? '',
      (t['note'] ?? '').toString(),
    ]);
  }
  return rows;
}

/// Transactions as CSV text. Pure and testable; the csv package handles quoting
/// of commas, quotes, and newlines in labels or notes.
String transactionsCsv(Map data) =>
    const ListToCsvConverter().convert(transactionRows(data));

/// Transactions as a .xlsx workbook (bytes). Amounts stay real numbers so the
/// sheet sums and filters like a spreadsheet, not text.
List<int> transactionsXlsx(Map data) {
  final book = xl.Excel.createExcel();
  final def = book.getDefaultSheet();
  if (def != null) book.rename(def, 'Transactions');
  final sheet = book['Transactions'];
  final rows = transactionRows(data);
  for (var r = 0; r < rows.length; r++) {
    sheet.appendRow([
      for (final cell in rows[r])
        if (r == 0)
          xl.TextCellValue(cell.toString())
        else if (cell is num)
          xl.DoubleCellValue(cell.toDouble())
        else
          xl.TextCellValue(cell.toString()),
    ]);
  }
  return book.save() ?? const [];
}

/// A one-page PDF report: net worth now, this month's income statement, and the
/// month's transactions. Read-only, from the golden-locked engine.
Future<Uint8List> reportPdf(Map data, DateTime ref) async {
  // Use the app's bundled font so peso signs and Filipino characters (ñ, and
  // Tagalog labels) render, instead of the default Helvetica which cannot. If
  // the asset bundle is unavailable (e.g. a plain unit test), fall back to the
  // built-in font; the PDF still generates.
  pw.ThemeData? theme;
  try {
    final base = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {}
  final doc = pw.Document(theme: theme);
  final typed = data.cast<String, dynamic>();
  final nw = netWorthParts(typed);
  final inc = incomeStatement(typed, ref);
  final monthKey =
      '${ref.year.toString().padLeft(4, '0')}-'
      '${ref.month.toString().padLeft(2, '0')}';
  final monthTxns =
      _txns(data)
          .where((t) => (t['date'] ?? '').toString().startsWith(monthKey))
          .toList()
        ..sort(
          (a, b) => (a['date'] ?? '').toString().compareTo(
            (b['date'] ?? '').toString(),
          ),
        );
  final names = _accountNames(data);

  pw.Widget line(String label, num value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label), pw.Text(_peso(value))],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'Salapify report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          'As of ${ref.year}-${ref.month.toString().padLeft(2, '0')}-'
          '${ref.day.toString().padLeft(2, '0')}',
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Net worth',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        line('What you own', amountOf(nw['assets'])),
        line('What you owe', amountOf(nw['liabilities'])),
        line('Net worth', amountOf(nw['netWorth'])),
        pw.SizedBox(height: 16),
        pw.Text(
          'This month',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        line('Income earned', amountOf(inc['income'])),
        line('Spending', amountOf(inc['expenses'])),
        line('Net income', amountOf(inc['netIncome'])),
        pw.SizedBox(height: 16),
        pw.Text(
          'Transactions this month',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (monthTxns.isEmpty)
          pw.Text('No transactions logged this month.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Type', 'Label', 'Amount', 'Account'],
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            data: [
              for (final t in monthTxns)
                [
                  (t['date'] ?? '').toString(),
                  (t['type'] ?? '').toString(),
                  (t['label'] ?? '').toString(),
                  _peso(amountOf(t['amount'])),
                  names[t['accountId']] ?? '',
                ],
            ],
          ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Made with Salapify. Numbers are from your own logged data.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );
  return doc.save();
}

// Only one export runs at a time. Without this, a second tap (or a tap on
// another export while the PDF is still building) would start a second share
// whose leftover-sweep could delete the first share's temp file out from under
// the receiving app.
bool _exporting = false;

Future<void> _guard(Future<void> Function() task) async {
  if (_exporting) return;
  _exporting = true;
  try {
    await task();
  } finally {
    _exporting = false;
  }
}

// Export temp files carry this prefix so the leftover-sweep only ever touches
// its OWN files. It must NOT match the JSON backup's 'salapify-backup-' files,
// or an in-flight backup share could be deleted mid-save.
const String _exportPrefix = 'salapify-export-';

Future<void> _shareBytes(
  List<int> bytes,
  String filename,
  String mime,
  String subject,
) async {
  final dir = await getTemporaryDirectory();
  // Sweep only leftover EXPORT temp files (never a backup) so a copy of the
  // finances never lingers in the cache after a share the OS killed mid-flow.
  try {
    for (final e in dir.listSync()) {
      final name = e.path.split(Platform.pathSeparator).last;
      if (e is File && name.startsWith(_exportPrefix)) {
        try {
          e.deleteSync();
        } catch (_) {}
      }
    }
  } catch (_) {}
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  try {
    await Share.shareXFiles([
      XFile(file.path, mimeType: mime),
    ], subject: subject);
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}

String _stamp(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

/// Save bytes straight to the device through the system save dialog. The user
/// picks Downloads or any folder; on Android this is the storage access
/// framework, so no storage permission is needed. The plugin writes the bytes
/// itself on mobile; the guarded write covers a desktop dialog that only
/// returns a path. Returns true when saved, false when the user cancelled.
Future<bool> _saveBytesToDevice(List<int> bytes, String filename) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save $filename',
    fileName: filename,
    bytes: Uint8List.fromList(bytes),
  );
  if (path == null) return false;
  if (!kIsWeb && !path.startsWith('content://')) {
    try {
      final f = File(path);
      if (!await f.exists() || await f.length() == 0) {
        await f.writeAsBytes(bytes);
      }
    } catch (_) {}
  }
  return true;
}

// Direct-save filenames are user facing (they land in the user's folder), so
// they carry a clean salapify- name, never the internal temp prefix.

Future<bool> saveTransactionsCsvToDevice(Map data, DateTime now) =>
    _saveBytesToDevice(
      utf8CsvBytes(transactionsCsv(data)),
      'salapify-transactions-${_stamp(now)}.csv',
    );

Future<bool> saveTransactionsXlsxToDevice(Map data, DateTime now) {
  final bytes = transactionsXlsx(data);
  if (bytes.isEmpty) {
    throw const FormatException('The Excel file came back empty.');
  }
  return _saveBytesToDevice(bytes, 'salapify-transactions-${_stamp(now)}.xlsx');
}

Future<bool> saveReportPdfToDevice(Map data, DateTime ref) async {
  final bytes = await reportPdf(data, ref);
  return _saveBytesToDevice(
    bytes,
    'salapify-report-${ref.year.toString().padLeft(4, '0')}-'
    '${ref.month.toString().padLeft(2, '0')}.pdf',
  );
}

Future<void> shareTransactionsCsv(Map data, DateTime now) => _guard(
  () => _shareBytes(
    utf8CsvBytes(transactionsCsv(data)),
    '${_exportPrefix}transactions-${_stamp(now)}.csv',
    'text/csv',
    'Salapify transactions',
  ),
);

Future<void> shareTransactionsXlsx(Map data, DateTime now) => _guard(() {
  final bytes = transactionsXlsx(data);
  if (bytes.isEmpty) {
    throw const FormatException('The Excel file came back empty.');
  }
  return _shareBytes(
    bytes,
    '${_exportPrefix}transactions-${_stamp(now)}.xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'Salapify transactions',
  );
});

Future<void> shareReportPdf(Map data, DateTime ref) => _guard(() async {
  final bytes = await reportPdf(data, ref);
  await _shareBytes(
    bytes,
    '${_exportPrefix}report-${ref.year.toString().padLeft(4, '0')}-'
        '${ref.month.toString().padLeft(2, '0')}.pdf',
    'application/pdf',
    'Salapify report',
  );
});

// UTF-8 bytes with a BOM, so Excel opens a peso or Tagalog label without
// mojibake.
List<int> utf8CsvBytes(String csv) => [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
