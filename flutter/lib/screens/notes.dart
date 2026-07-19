// Notes with the calculator: the founder's favorite tool from the RN app.
// The list shows every note newest first with its computed total when the
// note does math; the editor recomputes the CALCULATIONS panel on every
// keystroke through the golden-verified engine (lunch 120, jeep 24 + 24,
// and 7-11 run 250 all count correctly; dates and phone numbers never turn
// into subtraction). Saves are debounced through the guarded store write
// and flushed on close; a note closed with no text is discarded quietly so
// backing out never piles up empty cards.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/notecalc.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

class NotesScreen extends StatelessWidget {
  final SalapifyStore store;
  const NotesScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final notes = [
          for (final n in (store.data['notes'] as List? ?? const []))
            if (n is Map) n.cast<String, dynamic>(),
        ];
        final indexed = List.generate(notes.length, (i) => (notes[i], i));
        indexed.sort((a, b) {
          final c = (b.$1['updatedAt'] ?? '')
              .toString()
              .compareTo((a.$1['updatedAt'] ?? '').toString());
          return c != 0 ? c : a.$2.compareTo(b.$2);
        });
        final sorted = [for (final e in indexed) e.$1];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Barako.background,
            foregroundColor: Barako.text,
            title: Text('Notes',
                style: TextStyle(
                    color: Barako.text, fontWeight: FontWeight.w800)),
          ),
          floatingActionButton: store.canWrite
              ? FloatingActionButton.extended(
                  onPressed: () => _openNew(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New note',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                )
              : null,
          body: SafeArea(
            child: sorted.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No notes yet',
                              style: TextStyle(
                                  color: Barako.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              'Jot anything. Lines with amounts add themselves '
                              'up, like a receipt: lunch 120, jeep 24 + 24.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Barako.muted,
                                  fontSize: 13,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                    itemCount: sorted.length,
                    itemBuilder: (context, i) =>
                        _noteCard(context, sorted[i]),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openNew(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await store.addNote();
      navigator.push(MaterialPageRoute(
          builder: (_) => NoteEditor(store: store, noteId: id)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not create a note, nothing was changed. $e')));
    }
  }

  Widget _noteCard(BuildContext context, Map<String, dynamic> n) {
    final text = (n['text'] ?? '').toString();
    final lines = text.split('\n');
    final title = lines.first.trim().isEmpty
        ? 'Untitled note'
        : lines.first.trim();
    // RN scans past blank lines for the first real preview line.
    final preview = lines
        .skip(1)
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    final calc = computeCalc(text);
    final hasMath = calc['hasMath'] as bool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NoteEditor(
                  store: store, noteId: (n['id'] ?? '').toString()))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Barako.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (hasMath)
                  Text(formatMoney(calc['total'] as double),
                      style: TextStyle(
                          color: Barako.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  final SalapifyStore store;
  final String noteId;
  const NoteEditor({super.key, required this.store, required this.noteId});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController controller;
  Timer? _debounce;
  String _lastSaved = '';
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final note = _find();
    final text = (note?['text'] ?? '').toString();
    controller = TextEditingController(text: text);
    _lastSaved = text;
  }

  Map<String, dynamic>? _find() {
    for (final n in (widget.store.data['notes'] as List? ?? const [])) {
      if (n is Map && n['id'] == widget.noteId) {
        return n.cast<String, dynamic>();
      }
    }
    return null;
  }

  void _onChanged(String text) {
    setState(() {}); // recompute the panel every keystroke
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  Future<void> _flush() async {
    final text = controller.text;
    if (text == _lastSaved) return;
    try {
      await widget.store.updateNote(widget.noteId, text);
      _lastSaved = text;
    } catch (_) {
      // The store rolled back; the close-flush or the next keystroke
      // retries, and the close path surfaces a persistent failure.
    }
  }

  Future<void> _close() async {
    // A second back tap while the first save is still writing must not pop
    // twice; that would pop the Notes list too and dump the user on the
    // Overview.
    if (_closing) return;
    _closing = true;
    _debounce?.cancel();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = controller.text;
    try {
      if (text.trim().isEmpty) {
        // A note with no text is discarded quietly, matching RN.
        await widget.store.deleteNote(widget.noteId);
      } else if (text != _lastSaved) {
        await widget.store.updateNote(widget.noteId, text);
      }
      navigator.pop();
    } catch (e) {
      _closing = false;
      // Saving keeps failing (disk full, storage broken). The editor must
      // never become a trap, so offer a way out that skips the save.
      messenger.showSnackBar(SnackBar(
          content: Text('Could not save the note, it is still open. $e'),
          action: SnackBarAction(
              label: 'Leave anyway',
              onPressed: () {
                if (_closing) return;
                _closing = true;
                navigator.pop();
              })));
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete this note?',
            style: TextStyle(color: Barako.text)),
        content: Text('This cannot be undone.',
            style: TextStyle(color: Barako.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: TextStyle(color: Barako.muted))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child:
                  Text('Delete', style: TextStyle(color: Barako.warning))),
        ],
      ),
    );
    if (ok != true || _closing) return;
    _closing = true;
    _debounce?.cancel();
    try {
      await widget.store.deleteNote(widget.noteId);
      navigator.pop();
    } catch (e) {
      _closing = false;
      messenger.showSnackBar(SnackBar(
          content: Text('Could not delete, nothing was changed. $e')));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calc = computeCalc(controller.text);
    final rows = (calc['rows'] as List).cast<Map<String, dynamic>>();
    final hasMath = calc['hasMath'] as bool;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Barako.background,
          foregroundColor: Barako.text,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back), onPressed: _close),
          title: Text('Note',
              style: TextStyle(
                  color: Barako.text, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
                icon: Icon(Icons.delete_outline, color: Barako.muted),
                onPressed: _delete),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: TextField(
                    controller: controller,
                    onChanged: _onChanged,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                        color: Barako.text, fontSize: 16, height: 1.5),
                    decoration: InputDecoration(
                      hintText:
                          'Jot anything. Amounts add themselves up:\nlunch 120\njeep 24 + 24\ngrab 250',
                      hintStyle:
                          TextStyle(color: Barako.faint, height: 1.5),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              if (hasMath)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Barako.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Barako.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CALCULATIONS',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(row['label'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Barako.textSecondary,
                                        fontSize: 12)),
                              ),
                              Text(
                                  formatMoney(row['value'] as double),
                                  style: TextStyle(
                                      color: Barako.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ])),
                            ],
                          ),
                        ),
                      Divider(color: Barako.border, height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Total',
                                style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text(formatMoney(calc['total'] as double),
                              style: TextStyle(
                                  color: Barako.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
