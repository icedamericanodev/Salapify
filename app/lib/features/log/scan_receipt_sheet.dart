import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/receipt_ocr.dart';
import '../../core/money/receipt_samples.dart';
import '../../data/seed_data.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';
import 'receipt_camera.dart';

/// Scan-to-Log: read a receipt, check what it says, log it.
///
/// Founder spec, 2026-09-20, feature 1, part B.
///
/// ## The camera reads it, on the phone, and keeps nothing
///
/// Founder direction, 2026-09-22: build the camera plugin. Three things make
/// that safe to say out loud on the sheet itself.
///
/// The model is BUNDLED into the APK (`com.google.mlkit:text-recognition`),
/// not fetched from Play Services, so photographing a receipt makes no
/// network request. Salapify makes exactly one, for exchange rates, and the
/// privacy receipt names it; a model downloaded the instant somebody
/// photographs a shop receipt would have made that receipt false.
///
/// NO CAMERA PERMISSION IS DECLARED. `image_picker` fires
/// ACTION_IMAGE_CAPTURE and the phone's own camera app takes the picture.
/// Android's rule runs the opposite way to the obvious guess: declaring
/// `android.permission.CAMERA` without it being granted makes that intent
/// throw, while never declaring it works with no permission and no dialog.
///
/// And the photo is DELETED as soon as the words are out of it, in a
/// `finally` so a failed read cannot leave one behind. See
/// `receipt_camera.dart`.
///
/// Pasting stays exactly as it was, and is still the only path for a receipt
/// that arrived as a GCash or Maya message rather than on paper.
///
/// ## Both paths go through one parser
///
/// A photographed receipt and a pasted one are handed to the same
/// `parseReceiptText`, so they cannot disagree about what a receipt means,
/// and the vectors that lock that parser cover the camera without knowing it
/// exists.
///
/// ## Nothing it reads is trusted without being shown
///
/// Every field the parser filled is editable and visible before anything is
/// saved. That is not politeness, it is the design: the reader is a guess, and
/// the prototype's habit of writing a guess straight into the ledger is how a
/// Jollibee purchase ends up carrying a stranger's TIN.
class ScanReceiptSheet extends StatefulWidget {
  const ScanReceiptSheet({
    super.key,
    required this.palette,
    required this.state,
    this.camera,
  });

  final Palette palette;
  final FinancialState state;

  /// Where a photographed receipt's words come from.
  ///
  /// Injected so a test can drive the whole sheet without a camera, a photo
  /// library or the ML Kit reader, none of which exist in a widget test. The
  /// default is the real device path, so nothing at a call site changes.
  final ReceiptTextSource? camera;

  /// Returns the transaction to log, or null if nothing was confirmed.
  static Future<Transaction?> show(
    BuildContext context,
    Palette palette,
    FinancialState state, {
    ReceiptTextSource? camera,
  }) {
    return SheetScaffold.show<Transaction>(
      context: context,
      palette: palette,
      builder: (BuildContext ctx) =>
          ScanReceiptSheet(palette: palette, state: state, camera: camera),
    );
  }

  @override
  State<ScanReceiptSheet> createState() => _ScanReceiptSheetState();
}

class _ScanReceiptSheetState extends State<ScanReceiptSheet> {
  final TextEditingController _paste = TextEditingController();
  final TextEditingController _merchant = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _ref = TextEditingController();

  ReceiptOcrResult? _read;
  String? _sampleNote;

  late String _category = 'Other Expenses';
  late String _subcategory = 'Miscellaneous Expense';
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _deductible = false;

  /// Built once, and only if this sheet was not handed one.
  ///
  /// Late and lazy because constructing it constructs an ML Kit recogniser,
  /// which is a native object. A sheet somebody opens to paste a GCash
  /// message should not spin one up.
  late final ReceiptTextSource _camera =
      widget.camera ?? (_owned = DeviceReceiptTextSource());
  DeviceReceiptTextSource? _owned;

  /// True while the camera or the reader is working.
  ///
  /// ML Kit takes a noticeable moment on a real receipt, and a screen that
  /// looks identical to a screen that is doing nothing is how somebody taps
  /// the button a second time.
  bool _reading = false;

  /// What to say when a read came back with nothing.
  ReceiptReadFailure? _readFailure;

  @override
  void initState() {
    super.initState();
    _date = widget.state.now;
  }

  @override
  void dispose() {
    _paste.dispose();
    _merchant.dispose();
    _amount.dispose();
    _ref.dispose();
    // Only the one this sheet made. A source passed in belongs to whoever
    // passed it, and closing somebody else's recogniser is how the second
    // opening of a sheet fails.
    _owned?.dispose();
    super.dispose();
  }

  /// Photograph or choose a receipt, read it, and fill the form in.
  ///
  /// The text goes through `parseReceiptText`, the SAME function the paste
  /// box and the samples use. A photographed receipt and a pasted one cannot
  /// disagree about what a receipt means, and the golden vectors that lock
  /// that parser cover this path without knowing it exists.
  Future<void> _scan(ReceiptImageSource from) async {
    setState(() {
      _reading = true;
      _readFailure = null;
    });

    final ReceiptRead? read = await _camera.read(from);

    // The sheet can be closed while the camera is open, which on a phone is
    // the ordinary case rather than a rare one.
    if (!mounted) return;

    setState(() => _reading = false);

    // Backed out. Says nothing, because nothing happened.
    if (read == null) return;

    if (!read.ok) {
      setState(() => _readFailure = read.failure);
      return;
    }

    // The words go in the paste box as well as through the parser, so what
    // the reader saw is visible and correctable. A scan that silently fills
    // four fields from text nobody can see is a scan nobody can check.
    _paste.text = read.text;
    _apply(parseReceiptText(read.text));
  }

  List<CategoryInfo> get _expenseCategories => SeedData.categories
      .where((CategoryInfo c) => c.kind == CategoryKind.expense)
      .toList();

  List<String> get _subsFor {
    final CategoryInfo? c = _expenseCategories
        .where((CategoryInfo c) => c.name == _category)
        .firstOrNull;
    return c?.subcategories ?? const <String>[];
  }

  void _apply(ReceiptOcrResult r, {String? note}) {
    setState(() {
      _read = r;
      _sampleNote = note;
      _merchant.text = r.merchant;
      _amount.text = r.amount > 0 ? r.amount.toStringAsFixed(2) : '';
      _ref.text = r.taxTinOrRef ?? '';
      _deductible = r.isTaxDeductible;

      // THE CATEGORY IS ONLY TAKEN WHEN THE PARSER REALLY KNEW ONE.
      //
      // Its fallback is 'Other Expenses', and writing that over a category
      // somebody had already chosen is the founder's own "Electricity"
      // report: a confident wrong answer replacing a correct one.
      if (r.categoryMatched) {
        _category = r.category;
        _subcategory = r.subcategory;
      }

      // Only when the paper NAMED a wallet, and only if the person has one
      // of that kind. An unmatched receipt leaves the picker empty rather
      // than landing on whichever account happens to be first.
      if (r.accountKind != null) {
        _accountId = widget.state.accounts
            .where((Account a) => a.kind == r.accountKind)
            .map((Account a) => a.id)
            .firstOrNull;
      }

      if (r.dateFound) _date = r.date;
    });
  }

  double? get _amountValue =>
      double.tryParse(_amount.text.replaceAll(',', '').trim());

  bool get _canSave =>
      (_amountValue ?? 0) > 0 &&
      _accountId != null &&
      _merchant.text.trim().isNotEmpty;

  void _save() {
    final double? amount = _amountValue;
    if (amount == null || !_canSave) return;

    Navigator.of(context).pop(
      Transaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.expense,
        amount: amount,
        category: _category,
        subcategory: _subcategory.isEmpty ? null : _subcategory,
        accountId: _accountId!,
        date: _iso(_date),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        merchant: _merchant.text.trim(),
        profile: widget.state.activeProfile ?? ProfileEntity.personal,
        isTaxDeductible: _deductible,
        taxTinOrRef: _ref.text.trim().isEmpty ? null : _ref.text.trim(),
      ),
    );
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final DateTime today = widget.state.now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(today.year - 5, today.month, today.day),
      // No future, the same bound the Log sheet uses and for the same
      // reason: logging moves the balance now, so a future date would take
      // the money out today and file it under a day that has not happened.
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'When was this receipt',
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final ReceiptOcrResult? r = _read;

    return SheetScaffold(
      palette: p,
      icon: Icons.document_scanner_outlined,
      title: 'Scan a receipt',
      subtitle: 'Photograph it, or paste the text.',
      footer: PrimaryButton(
        palette: p,
        label: 'Confirm and log',
        icon: Icons.check,
        onTap: _canSave ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The camera first, because it is what somebody holding a receipt
          // reaches for. Pasting stays underneath, unchanged, and is still
          // the only path for a receipt that arrived as a message.
          Row(
            children: <Widget>[
              Expanded(
                child: _ScanButton(
                  palette: p,
                  icon: Icons.photo_camera_outlined,
                  label: 'Take a photo',
                  busy: _reading,
                  onTap: () => _scan(ReceiptImageSource.camera),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _ScanButton(
                  palette: p,
                  icon: Icons.image_outlined,
                  label: 'Choose an image',
                  busy: _reading,
                  onTap: () => _scan(ReceiptImageSource.library),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            // THE CLAIM THIS APP HAS TO KEEP, said where the photo is taken
            // rather than only in the privacy receipt. Reading happens on the
            // phone, with a model that shipped inside the app, and the
            // picture is deleted the moment the words are out of it.
            'Read on your phone. The photo is not saved or sent anywhere.',
            style: AppType.caption(p),
          ),
          if (_readFailure != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            _ReadFailed(palette: p, failure: _readFailure!),
          ],
          const SizedBox(height: Spacing.lg),
          Text('SAMPLES', style: AppType.kicker(p)),
          const SizedBox(height: Spacing.xs),
          Text(
            // SAID ON THE SCREEN, not just in a comment. The prototype falls
            // back to its Jollibee sample whenever a file name matches
            // nothing, so a photo of any other receipt silently becomes a
            // Jollibee purchase. Nothing here is reachable except by tapping
            // it, and a person can only trust that if they are told.
            'These are made-up receipts for trying it out. Nothing is read '
            'from them unless you tap one.',
            style: AppType.caption(p),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: <Widget>[
              for (final ReceiptSample s in receiptSamples)
                _Chip(
                  palette: p,
                  label: s.label,
                  onTap: () {
                    _paste.text = s.text;
                    _apply(parseReceiptText(s.text), note: s.note);
                  },
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          SheetField(
            palette: p,
            label: 'Or paste the receipt text',
            controller: _paste,
            hint: 'Paste what the receipt or the screenshot says',
            keyboardType: TextInputType.multiline,
            onChanged: (String v) {
              if (v.trim().length < 12) return;
              _apply(parseReceiptText(v));
            },
          ),
          if (r != null) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            _ReadNote(palette: p, result: r, sampleNote: _sampleNote),
            const SizedBox(height: Spacing.lg),
            SheetField(
              palette: p,
              label: 'Where it was',
              controller: _merchant,
              hint: 'Shop or merchant',
              keyboardType: TextInputType.text,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.lg),
            SheetField(
              palette: p,
              label: 'How much',
              controller: _amount,
              hint: '0.00',
              prefix: '₱ ',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.lg),
            _Label(palette: p, text: 'What kind of spending'),
            _Dropdown<String>(
              palette: p,
              value: _category,
              items: <(String, String)>[
                for (final CategoryInfo c in _expenseCategories)
                  (c.name, c.name),
              ],
              onChanged: (String v) => setState(() {
                _category = v;
                _subcategory = _subsFor.isEmpty ? '' : _subsFor.first;
              }),
            ),
            if (_subsFor.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.md),
              _Label(palette: p, text: 'More exactly'),
              _Dropdown<String>(
                palette: p,
                value: _subsFor.contains(_subcategory)
                    ? _subcategory
                    : _subsFor.first,
                items: <(String, String)>[
                  for (final String s in _subsFor) (s, s),
                ],
                onChanged: (String v) => setState(() => _subcategory = v),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            _Label(palette: p, text: 'Paid from'),
            _Dropdown<String?>(
              palette: p,
              value: _accountId,
              items: <(String?, String)>[
                (null, 'Choose an account'),
                for (final Account a in widget.state.accounts.where(
                  (Account a) => a.isLiquid || a.kind == AccountKind.credit,
                ))
                  (a.id, a.name),
              ],
              onChanged: (String? v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: Spacing.lg),
            _Label(palette: p, text: 'When'),
            _DateRow(
              palette: p,
              date: _date,
              // A date the parser did not find is TODAY, and saying so is the
              // difference between a reading and a default. Somebody
              // backdating a receipt from last week needs to know the app
              // guessed.
              guessed: r.dateFound == false,
              onTap: _pickDate,
            ),
            const SizedBox(height: Spacing.lg),
            _DeductibleRow(
              palette: p,
              on: _deductible,
              onChanged: (bool v) => setState(() => _deductible = v),
            ),
            const SizedBox(height: Spacing.md),
            SheetField(
              palette: p,
              label: 'Receipt or TIN reference',
              controller: _ref,
              hint: 'OR number, SI number, or the supplier TIN',
              keyboardType: TextInputType.text,
            ),
            if (r.lineItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.lg),
              _Label(palette: p, text: 'What was on it'),
              for (final ReceiptLineItem i in r.lineItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          i.qty > 1 ? '${i.qty} x ${i.desc}' : i.desc,
                          style: AppType.caption(p),
                        ),
                      ),
                      Text(formatPeso(i.price), style: AppType.caption(p)),
                    ],
                  ),
                ),
              const SizedBox(height: Spacing.xs),
              Text(
                // The items are SHOWN and not saved, and that is worth
                // stating: a ledger row is one amount, and quietly dropping
                // detail somebody can see on screen is how an app loses
                // trust over something small.
                'Shown so you can check the total. Salapify logs one entry, '
                'not each line.',
                style: AppType.caption(p),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// What the reader made of it, and how sure it is.
class _ReadNote extends StatelessWidget {
  const _ReadNote({
    required this.palette,
    required this.result,
    required this.sampleNote,
  });

  final Palette palette;
  final ReceiptOcrResult result;
  final String? sampleNote;

  String get _sure {
    // WORDS, not a percentage. The parser's confidence is a count of signals
    // found, which is genuinely useful as "most of this" or "very little of
    // this" and is false precision as "63%". The prototype's health check
    // shipping "89% Accuracy" is the shape being avoided.
    if (result.confidence >= 0.75) return 'Read most of this receipt.';
    if (result.confidence >= 0.5) return 'Read the main figures.';
    return 'Could not read much. Check every field below.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_sure, style: AppType.rowTitle(palette)),
          const SizedBox(height: 2),
          Text(
            'Everything below is a guess from the text. Change anything that '
            'is wrong before you log it.',
            style: AppType.caption(palette),
          ),
          if (sampleNote != null) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              'Sample: $sampleNote',
              style: AppType.caption(palette).copyWith(color: palette.accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeductibleRow extends StatelessWidget {
  const _DeductibleRow({
    required this.palette,
    required this.on,
    required this.onChanged,
  });

  final Palette palette;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Claimable business expense',
                style: AppType.rowTitle(palette),
              ),
              Text(
                'Tick this and it appears in the claimable list on Reports. '
                'It changes no total and files nothing.',
                style: AppType.caption(palette),
              ),
            ],
          ),
        ),
        Switch(value: on, onChanged: onChanged),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.palette,
    required this.date,
    required this.guessed,
    required this.onTap,
  });

  final Palette palette;
  final DateTime date;
  final bool guessed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.control),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: palette.textMuted,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                guessed
                    ? '${_label(date)} (no date on the receipt)'
                    : _label(date),
                style: AppType.body(palette),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(DateTime d) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// Take a photo, or choose an image.
///
/// Both go grey together while a read is running: the camera and the library
/// share one reader, and a second tap on the other button while the first is
/// working is the ordinary way somebody ends up with two pickers open.
class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final Palette palette;
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: label,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            // Comfortably past the 44 floor, and equal to the fields below.
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    ),
                  )
                else
                  Icon(icon, size: 18, color: palette.accent),
                const SizedBox(width: Spacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.rowTitle(
                      palette,
                    ).copyWith(fontSize: 14, color: palette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A read that came back with nothing, and what to do about it.
///
/// Two failures, two different sentences, because they need two different
/// things from the person. A blurry photo is theirs to retake; a reader that
/// would not start is not, and telling them to try again in better light
/// would send them round a loop that cannot end.
class _ReadFailed extends StatelessWidget {
  const _ReadFailed({required this.palette, required this.failure});

  final Palette palette;
  final ReceiptReadFailure failure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.warning),
      ),
      child: Text(switch (failure) {
        ReceiptReadFailure.noText =>
          'No words could be read from that picture. A flatter angle and '
              'more light usually fixes it, or type the amount in below.',
        ReceiptReadFailure.unavailable =>
          // NAMES THE BUTTON SITTING RIGHT ABOVE IT. Founder screenshot,
          // 2026-09-22, from an emulator: this sentence sent them to the
          // paste box and never mentioned Choose an image, which needs no
          // camera and reads through the very same reader. On an emulator
          // that is the ordinary case rather than a rare one, so the message
          // was steering people away from the one thing that would work.
          'The camera could not be opened on this phone. Choose an image '
              'instead, or paste the receipt text below. Both read exactly '
              'the same way.',
      }, style: AppType.body(palette)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: AppType.caption(
                palette,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.palette, required this.text});

  final Palette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Text(text.toUpperCase(), style: AppType.kicker(palette)),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.palette,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final Palette palette;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: palette.surface,
          style: AppType.body(palette),
          icon: Icon(Icons.expand_more, color: palette.textMuted),
          items: <DropdownMenuItem<T>>[
            for (final (T, String) i in items)
              DropdownMenuItem<T>(value: i.$1, child: Text(i.$2)),
          ],
          onChanged: (T? v) {
            if (v != null || null is T) onChanged(v as T);
          },
        ),
      ),
    );
  }
}
