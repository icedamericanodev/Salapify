// Import transactions from a bank, GCash, or spreadsheet CSV. The user picks a
// file, says which column is the date, the amount, and the description (plus the
// date format and the sign rule), sees a preview with how many rows will import
// and how many will be skipped, and only then confirms. Nothing touches the
// ledger until Import is tapped. The parsing lives in the tested
// data/csv_import.dart engine; this screen is only the mapping and preview.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/csv_import.dart';
import '../data/store.dart';
import '../theme.dart';

class CsvImportScreen extends StatefulWidget {
  final SalapifyStore store;
  const CsvImportScreen({super.key, required this.store});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  List<List<String>>? _rows;
  String? _fileName;
  bool _firstRowHeader = true;
  int? _dateCol;
  int? _amountCol;
  int? _descCol;
  int? _typeCol;
  DateFormatChoice _dateFmt = DateFormatChoice.iso;
  bool _negIsExpense = true;
  bool _busy = false;

  List<String> get _headerLabels {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return const [];
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (_firstRowHeader) {
      final h = rows.first;
      return [
        for (var i = 0; i < cols; i++)
          (i < h.length && h[i].isNotEmpty) ? h[i] : 'Column ${i + 1}'
      ];
    }
    return [for (var i = 0; i < cols; i++) 'Column ${i + 1}'];
  }

  List<List<String>> get _dataRows {
    final rows = _rows;
    if (rows == null) return const [];
    return _firstRowHeader && rows.isNotEmpty ? rows.sublist(1) : rows;
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      const maxBytes = 25 * 1024 * 1024;
      if (f.size > maxBytes) {
        _snack('That file is too large to import.');
        return;
      }
      String text;
      if (f.bytes != null) {
        text = utf8.decode(f.bytes!, allowMalformed: true);
      } else if (!kIsWeb && f.path != null) {
        text = await File(f.path!).readAsString();
      } else {
        _snack('Could not read that file.');
        return;
      }
      final parsed = parseCsv(text);
      if (parsed.rows.isEmpty) {
        _snack('That file has no rows to import.');
        return;
      }
      setState(() {
        _rows = parsed.rows;
        _fileName = f.name;
        _guessColumns(reset: true);
      });
    } catch (e) {
      _snack('Could not read that file. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Best-effort auto-map from the header names, so the user usually just checks
  // and confirms rather than picking every column. Only fills columns the user
  // has not set, so re-running it (on a header toggle) never wipes a manual
  // choice. Pass reset: true when a fresh file is loaded to guess from scratch.
  void _guessColumns({bool reset = false}) {
    if (reset) {
      _dateCol = null;
      _amountCol = null;
      _descCol = null;
      _typeCol = null;
    }
    final labels = _headerLabels;
    int? find(List<String> keys) {
      for (var i = 0; i < labels.length; i++) {
        final l = labels[i].toLowerCase();
        if (keys.any((k) => l.contains(k))) return i;
      }
      return null;
    }

    _dateCol ??= find(['date', 'petsa']);
    _amountCol ??= find(['amount', 'amt', 'halaga', 'debit', 'value']);
    _descCol ??= find(['desc', 'detail', 'narration', 'particular', 'remarks', 'label', 'memo']);
    _typeCol ??= find(['type', 'category']);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // buildImport walks the whole file, and build() reads the preview on every
  // setState (each dropdown or switch touch). Memoize it, keyed on the file and
  // the mapping, so a big import is parsed once per real change, not per frame.
  String? _previewKey;
  ImportResult? _previewCache;

  ImportResult? get _preview {
    if (_dateCol == null || _amountCol == null) return null;
    final key = '$_fileName|${_rows?.length}|$_firstRowHeader|$_dateCol|'
        '$_amountCol|$_descCol|$_typeCol|$_dateFmt|$_negIsExpense';
    if (key == _previewKey && _previewCache != null) return _previewCache;
    final result = buildImport(
      _dataRows,
      ColumnMap(
        date: _dateCol!,
        amount: _amountCol!,
        description: _descCol,
        type: _typeCol,
        dateFormat: _dateFmt,
        negativeIsExpense: _negIsExpense,
      ),
    );
    _previewKey = key;
    _previewCache = result;
    return result;
  }

  Future<void> _import() async {
    if (_busy) return;
    final result = _preview;
    if (result == null || result.imported == 0) return;
    setState(() => _busy = true);
    try {
      final added = await widget.store.importTransactions(result.transactions);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('Imported $added ${added == 1 ? 'entry' : 'entries'}.');
    } catch (e) {
      _snack('Could not import, nothing was changed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = _headerLabels;
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Import CSV',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
                'Bring in entries from a bank, GCash, or spreadsheet CSV. Choose the '
                'file, tell me which column is which, check the preview, then import. '
                'Your existing entries are never touched.',
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 14, height: 1.4)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary),
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file),
              label: Text(_fileName == null ? 'Choose CSV file' : 'Choose a different file'),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text(_fileName!,
                  style: TextStyle(color: Barako.muted, fontSize: 12)),
            ],
            if (_rows != null) ...[
              const SizedBox(height: 20),
              _switchRow('First row is a header', _firstRowHeader,
                  (v) => setState(() {
                        _firstRowHeader = v;
                        _guessColumns();
                      })),
              const Divider(height: 24),
              _colPicker('Date column', _dateCol, labels,
                  (v) => setState(() => _dateCol = v)),
              const SizedBox(height: 10),
              _dateFmtPicker(),
              const SizedBox(height: 14),
              _colPicker('Amount column', _amountCol, labels,
                  (v) => setState(() => _amountCol = v)),
              const SizedBox(height: 10),
              _switchRow('Negative amount means an expense', _negIsExpense,
                  (v) => setState(() => _negIsExpense = v)),
              const SizedBox(height: 14),
              _colPicker('Description column (optional)', _descCol, labels,
                  (v) => setState(() => _descCol = v),
                  optional: true),
              const SizedBox(height: 10),
              _colPicker('Type column (optional)', _typeCol, labels,
                  (v) => setState(() => _typeCol = v),
                  optional: true),
              const SizedBox(height: 20),
              if (preview != null) _previewCard(preview),
            ],
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: Barako.text, fontSize: 14))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Barako.onPrimary,
            activeTrackColor: Barako.primary,
            inactiveThumbColor: Barako.faint,
            inactiveTrackColor: Barako.border,
          ),
        ],
      );

  Widget _colPicker(String label, int? value, List<String> labels,
      ValueChanged<int?> onChanged,
      {bool optional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Barako.kickerStyle),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          initialValue: value,
          isExpanded: true,
          decoration: _dropDecoration(),
          dropdownColor: Barako.card,
          items: [
            if (optional)
              DropdownMenuItem<int?>(
                  value: null,
                  child: Text('None',
                      style: TextStyle(color: Barako.muted))),
            for (var i = 0; i < labels.length; i++)
              DropdownMenuItem<int?>(
                  value: i,
                  child: Text(labels[i],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Barako.text))),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dateFmtPicker() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date format', style: Barako.kickerStyle),
          const SizedBox(height: 4),
          DropdownButtonFormField<DateFormatChoice>(
            initialValue: _dateFmt,
            isExpanded: true,
            decoration: _dropDecoration(),
            dropdownColor: Barako.card,
            items: const [
              DropdownMenuItem(
                  value: DateFormatChoice.iso, child: Text('2026-07-15 (year first)')),
              DropdownMenuItem(
                  value: DateFormatChoice.mdy, child: Text('07/15/2026 (month first)')),
              DropdownMenuItem(
                  value: DateFormatChoice.dmy, child: Text('15/07/2026 (day first)')),
            ],
            onChanged: (v) => setState(() => _dateFmt = v ?? DateFormatChoice.iso),
          ),
        ],
      );

  InputDecoration _dropDecoration() => InputDecoration(
        filled: true,
        fillColor: Barako.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Barako.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Barako.border),
        ),
      );

  Widget _previewCard(ImportResult r) {
    final sample = r.transactions.take(6).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PREVIEW', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            Text(
                r.imported == 0
                    ? 'No rows could be read with this mapping. Check the date column and format.'
                    : 'Will import ${r.imported} '
                        '${r.imported == 1 ? 'entry' : 'entries'}'
                        '${r.skipped > 0 ? ', skip ${r.skipped} the app could not read' : ''}.',
                style: TextStyle(
                    color: r.imported == 0 ? Barako.warningStrong : Barako.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            if (sample.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final t in sample)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${t['date']}  ${t['label']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Barako.textSecondary, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          '${t['type'] == 'expense' ? '-' : '+'}'
                          '${(t['amount'] as num).toStringAsFixed(2)}',
                          style: TextStyle(
                              color: t['type'] == 'expense'
                                  ? Barako.warningStrong
                                  : Barako.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Text(
                'Imported entries are added, not merged. Importing the same file '
                'twice will add it twice.',
                style: TextStyle(color: Barako.faint, fontSize: 11, height: 1.35)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary),
                onPressed: (_busy || r.imported == 0) ? null : _import,
                child: Text(_busy ? 'Importing...' : 'Import ${r.imported}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
