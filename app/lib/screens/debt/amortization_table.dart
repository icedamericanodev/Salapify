import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/money/amortization_export.dart';
import '../../core/money/format.dart';
import '../../core/money/loan.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The month by month statement, from src/components/BankAmortizationTable.tsx.
///
/// Every loan calculator produced a schedule from the day the engine was
/// ported, and none of them ever SHOWED one. That gap is exactly what the
/// founder found on 2026-09-19, and it is the reason tool/surface_audit.py
/// now exists: a 691 line component rendered inside a screen that had been
/// ticked off as done.
///
/// Two views, because they answer different questions. The monthly schedule
/// answers "what do I owe in month 40 and how much of it is interest". The
/// annual summary answers "how much of this will I actually have paid off by
/// year three", which is the one people ask out loud and which no single month
/// can tell them.
class AmortizationTable extends StatefulWidget {
  const AmortizationTable({
    super.key,
    required this.palette,
    required this.schedule,
    required this.meta,
    required this.footnote,
  });

  final Palette palette;
  final List<AmortizationRow> schedule;
  final LoanStatementMeta meta;

  /// The one line about how this lender computes, under the table. Kept on
  /// the screen rather than behind a dot because somebody comparing this with
  /// a bank's own printout needs to know which standard it follows.
  final String footnote;

  @override
  State<AmortizationTable> createState() => _AmortizationTableState();
}

class _AmortizationTableState extends State<AmortizationTable> {
  static const int _pageSize = 24;

  AmortizationView _view = AmortizationView.monthly;
  int _page = 0;
  bool _busy = false;

  @override
  void didUpdateWidget(AmortizationTable old) {
    super.didUpdateWidget(old);
    // Typing a new loan amount rebuilds the schedule under us. Staying on
    // page 8 of a schedule that is now four pages long shows an empty table
    // and reads as a broken screen.
    if (old.schedule.length != widget.schedule.length) _page = 0;
  }

  List<YearSummary> get _years => summariseByYear(widget.schedule);

  int get _rowCount => _view == AmortizationView.monthly
      ? widget.schedule.length
      : _years.length;

  int get _pageCount => _rowCount == 0 ? 1 : ((_rowCount - 1) ~/ _pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    if (widget.schedule.isEmpty) return const SizedBox.shrink();

    final int from = _page * _pageSize;
    final int to = (from + _pageSize).clamp(0, _rowCount);

    return Container(
      margin: const EdgeInsets.only(top: Spacing.lg),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.meta.title, style: AppType.rowTitle(p)),
          const SizedBox(height: 2),
          Text(widget.meta.institution, style: AppType.caption(p)),
          const SizedBox(height: Spacing.md),
          _Totals(palette: p, meta: widget.meta),
          if (widget.meta.interestSaved > 0) ...<Widget>[
            const SizedBox(height: Spacing.md),
            _SavingsNote(palette: p, meta: widget.meta),
          ],
          const SizedBox(height: Spacing.md),
          _ViewToggle(
            palette: p,
            view: _view,
            months: widget.schedule.length,
            years: _years.length,
            onSelect: (AmortizationView v) => setState(() {
              _view = v;
              _page = 0;
            }),
          ),
          const SizedBox(height: Spacing.md),
          _ExportRow(palette: p, busy: _busy, onExport: _export, onCopy: _copy),
          const SizedBox(height: Spacing.md),
          if (_view == AmortizationView.monthly)
            _MonthlyRows(
              palette: p,
              rows: widget.schedule.sublist(from, to),
            )
          else
            _AnnualRows(palette: p, rows: _years.sublist(from, to)),
          const SizedBox(height: Spacing.sm),
          _Pager(
            palette: p,
            from: from + 1,
            to: to,
            total: _rowCount,
            page: _page + 1,
            pages: _pageCount,
            onPrev: _page == 0 ? null : () => setState(() => _page--),
            onNext: _page + 1 >= _pageCount
                ? null
                : () => setState(() => _page++),
          ),
          const SizedBox(height: Spacing.md),
          Text(widget.footnote, style: AppType.caption(p)),
        ],
      ),
    );
  }

  String _csv() => amortizationCsv(
    schedule: widget.schedule,
    meta: widget.meta,
    view: _view,
  );

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _csv()));
    _say('Copied. Paste it into a spreadsheet.');
  }

  /// Writes the statement and hands it to the phone's own share sheet.
  ///
  /// Share rather than "saved to Downloads": Salapify has no business asking
  /// for storage permission to write somewhere it will never look again, and
  /// the share sheet is how a file actually reaches Gmail, Drive or Files on
  /// a real phone.
  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Directory dir = await getTemporaryDirectory();
      final File file = File(
        '${dir.path}/${amortizationFileName(widget.meta.title, _view)}',
      );
      // The BOM is what makes Excel on Windows read the peso sign instead of
      // showing mojibake. Written here rather than in the CSV builder, so the
      // string the tests read is the string a spreadsheet reads.
      await file.writeAsString('﻿${_csv()}', flush: true);
      // share_plus 10's API, checked against the installed package rather
      // than remembered: version 11 renamed this to SharePlus.instance.share.
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'text/csv')],
        subject: widget.meta.title,
      );
    } on MissingPluginException {
      // The app is running a build made before share_plus or path_provider
      // were added, so the native side of them is not in the APK. A hot
      // restart cannot fix that and neither can the person holding the phone.
      //
      // The statement itself is not lost, though, so it goes to the clipboard
      // instead of nowhere. Failing outright here would have thrown away a
      // 205 row export over a plugin registration.
      await Clipboard.setData(ClipboardData(text: _csv()));
      _say(
        'This build cannot open the share sheet yet, so the statement is on '
        'your clipboard instead. A full rebuild fixes it.',
      );
    } on Object catch (e) {
      await Clipboard.setData(ClipboardData(text: _csv()));
      _say('Could not share the file, so it is on your clipboard instead. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    final Palette p = widget.palette;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: p.onAccent)),
          backgroundColor: p.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.palette, required this.meta});

  final Palette palette;
  final LoanStatementMeta meta;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, bool)> cells = <(String, String, bool)>[
      ('PRINCIPAL LOAN', formatPeso(meta.principal), false),
      ('MONTHLY DUE', formatPeso(meta.monthlyPayment), true),
      ('TOTAL INTEREST', formatPeso(meta.totalInterest), false),
      ('TOTAL PAYABLE', formatPeso(meta.totalPayment), false),
    ];

    return Column(
      children: <Widget>[
        for (int i = 0; i < cells.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : Spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Cell(palette: palette, cell: cells[i]),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: _Cell(palette: palette, cell: cells[i + 1]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.palette, required this.cell});

  final Palette palette;
  final (String, String, bool) cell;

  @override
  Widget build(BuildContext context) {
    final (String label, String value, bool accent) = cell;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppType.kicker(palette)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppType.rowTitle(palette).copyWith(
                fontWeight: FontWeight.w800,
                color: accent ? palette.accent : palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsNote extends StatelessWidget {
  const _SavingsNote({required this.palette, required this.meta});

  final Palette palette;
  final LoanStatementMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.positive.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: palette.positive.withValues(alpha: 0.35)),
      ),
      child: Text.rich(
        TextSpan(
          style: AppType.body(palette),
          children: <InlineSpan>[
            TextSpan(
              text: meta.extraMonthly > 0
                  ? 'Prepaying ${formatPeso(meta.extraMonthly)} a month '
                  : 'Prepaying ',
            ),
            TextSpan(
              text: 'saves ${formatPeso(meta.interestSaved)} in interest',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: ' and shaves off ${meta.monthsSaved} months.'),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.palette,
    required this.view,
    required this.months,
    required this.years,
    required this.onSelect,
  });

  final Palette palette;
  final AmortizationView view;
  final int months;
  final int years;
  final ValueChanged<AmortizationView> onSelect;

  @override
  Widget build(BuildContext context) {
    // A Wrap rather than a Row of Expandeds: a Container with an alignment
    // and no width fills whatever it is offered, which has stacked pills into
    // full width bars three times in this repository already.
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (final (AmortizationView v, String label) in <(
          AmortizationView,
          String,
        )>[
          (AmortizationView.monthly, 'Monthly schedule ($months mos)'),
          (AmortizationView.annual, 'Annual summary ($years yrs)'),
        ])
          Semantics(
            button: true,
            selected: view == v,
            child: InkWell(
              onTap: () => onSelect(v),
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: view == v ? palette.accent : palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color: view == v ? palette.accent : palette.border,
                  ),
                ),
                child: Text(
                  label,
                  style: AppType.button(
                    palette,
                    color: view == v ? palette.onAccent : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.palette,
    required this.busy,
    required this.onExport,
    required this.onCopy,
  });

  final Palette palette;
  final bool busy;
  final VoidCallback onExport;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        Semantics(
          button: true,
          child: InkWell(
            onTap: busy ? null : onExport,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.file_download_outlined,
                    size: 16,
                    color: palette.onAccent,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    busy ? 'Exporting…' : 'Export CSV',
                    style: AppType.button(palette, color: palette.onAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          child: InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.copy_outlined, size: 16, color: palette.accent),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    'Copy',
                    style: AppType.button(palette, color: palette.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The schedule rows.
///
/// Three columns rather than the prototype's ten, because ten columns on a
/// phone is a horizontal scroll nobody discovers. The other seven are all in
/// the CSV, which is what the export is FOR.
class _MonthlyRows extends StatelessWidget {
  const _MonthlyRows({required this.palette, required this.rows});

  final Palette palette;
  final List<AmortizationRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _HeadRow(
          palette: palette,
          labels: const <String>['Period', 'Payment', 'Principal'],
        ),
        for (final AmortizationRow r in rows)
          _DataRow(
            palette: palette,
            cells: <String>[
              'Month ${r.period}',
              formatPeso(r.scheduledPayment + r.extraPayment),
              formatPeso(r.principalComponent),
            ],
            // Principal in the positive colour: it is the only part of the
            // payment that is actually yours, and seeing it grow month by
            // month is the single most encouraging thing on this screen.
            tint: palette.positive,
          ),
      ],
    );
  }
}

class _AnnualRows extends StatelessWidget {
  const _AnnualRows({required this.palette, required this.rows});

  final Palette palette;
  final List<YearSummary> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _HeadRow(
          palette: palette,
          labels: const <String>['Year', 'Paid', 'Balance left'],
        ),
        for (final YearSummary y in rows)
          _DataRow(
            palette: palette,
            cells: <String>[
              y.monthCount == 12 ? 'Year ${y.year}' : 'Year ${y.year} (${y.monthCount} mos)',
              formatPeso(y.totalPayment),
              formatPeso(y.endingBalance),
            ],
            tint: palette.textPrimary,
          ),
      ],
    );
  }
}

class _HeadRow extends StatelessWidget {
  const _HeadRow({required this.palette, required this.labels});

  final Palette palette;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(flex: 3, child: Text(labels[0], style: AppType.kicker(palette))),
          Expanded(
            flex: 4,
            child: Text(
              labels[1],
              textAlign: TextAlign.right,
              style: AppType.kicker(palette),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              labels[2],
              textAlign: TextAlign.right,
              style: AppType.kicker(palette),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.palette,
    required this.cells,
    required this.tint,
  });

  final Palette palette;
  final List<String> cells;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(cells[0], style: AppType.body(palette)),
          ),
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(cells[1], style: AppType.body(palette)),
            ),
          ),
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                cells[2],
                style: AppType.body(palette).copyWith(
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.palette,
    required this.from,
    required this.to,
    required this.total,
    required this.page,
    required this.pages,
    required this.onPrev,
    required this.onNext,
  });

  final Palette palette;
  final int from;
  final int to;
  final int total;
  final int page;
  final int pages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Showing $from to $to of $total',
            style: AppType.caption(palette),
          ),
        ),
        _Arrow(palette: palette, icon: Icons.chevron_left, onTap: onPrev),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Text('$page / $pages', style: AppType.caption(palette)),
        ),
        _Arrow(palette: palette, icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.palette,
    required this.icon,
    required this.onTap,
  });

  final Palette palette;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 20,
            color: on ? palette.accent : palette.textMuted,
          ),
        ),
      ),
    );
  }
}
