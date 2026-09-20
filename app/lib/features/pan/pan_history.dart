/// The last few exchanges with Pan, kept between app openings.
///
/// Founder direction, 2026-09-20, asking for chat history to survive an app
/// restart so a financial audit is not lost, with a control to clear it.
///
/// ## It is a SEPARATE FILE from the ledger, and that is the whole design
///
/// The founder's spec said to keep it "in the local encrypted ledger store".
/// Two things about that sentence needed correcting rather than following.
///
/// There is no encrypted store. Salapify's data is plain readable JSON on the
/// phone, `truthful_claims_test.dart` fails the build on any source file that
/// says otherwise, and a person who believes a backup is protected will email
/// it to themselves.
///
/// And it must not go IN the ledger. One malformed row inside
/// salapify_data.json makes the whole file unreadable, which stops every save
/// in the app; that exact failure was found in QA on the notifications row
/// during this same batch. Chat is the least important thing Salapify holds
/// and the ledger is the most, so a chat entry must never be able to take the
/// money data down with it. Its own file means the worst case is a lost
/// conversation.
///
/// ## Two properties it has to keep
///
/// It is CAPPED, because a chat log that grows forever is a file that grows
/// forever on somebody's phone, and the twentieth question back is of no use
/// to anybody.
///
/// It is DELETED BY THE WIPE. "Delete everything on this phone" is a promise
/// the privacy policy makes, and a file Salapify wrote that survives it makes
/// that sentence false. `store.dart` names this file in
/// `filesToDeleteInOrder`, and `wipe_durability_test.dart` holds it there.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One line of the conversation as it is stored.
///
/// Deliberately not a serialised PanAnswer. Storing the figures and the
/// action buttons would mean a stale peso amount reappearing days later
/// beside a live one, which is the worst kind of wrong number: it looks
/// exactly like a current one. A restored message is text and a label, and
/// anything computed is computed again when it is asked again.
class PanStoredMessage {
  const PanStoredMessage({
    required this.fromPan,
    required this.text,
    this.badge,
  });

  final bool fromPan;
  final String text;
  final String? badge;

  Map<String, Object?> toJson() => <String, Object?>{
    'fromPan': fromPan,
    'text': text,
    if (badge != null) 'badge': badge,
  };

  static PanStoredMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? text = raw['text'];
    if (text is! String || text.isEmpty) return null;
    return PanStoredMessage(
      fromPan: raw['fromPan'] == true,
      text: text,
      badge: raw['badge'] is String ? raw['badge'] as String : null,
    );
  }
}

abstract class PanHistoryStore {
  Future<List<PanStoredMessage>> load();
  Future<void> save(List<PanStoredMessage> messages);
  Future<void> clear();
}

/// The cap, in messages. A question and its answer are two, so this is the
/// last dozen exchanges.
const int panHistoryLimit = 24;

/// The file name, named here so `store.dart` can delete it by the same
/// constant rather than by a string typed twice.
const String panHistoryFileName = 'salapify_pan_chat.json';

class FilePanHistoryStore implements PanHistoryStore {
  FilePanHistoryStore({Directory? directory}) : _dir = directory;

  final Directory? _dir;

  Future<File> _file() async {
    final Directory dir = _dir ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$panHistoryFileName');
  }

  @override
  Future<List<PanStoredMessage>> load() async {
    try {
      final File f = await _file();
      if (!await f.exists()) return const <PanStoredMessage>[];
      final Object? raw = jsonDecode(await f.readAsString());
      if (raw is! List) return const <PanStoredMessage>[];
      return <PanStoredMessage>[
        for (final Object? e in raw)
          if (PanStoredMessage.fromJson(e) case final PanStoredMessage m) m,
      ];
    } on Object {
      // A corrupt chat file is an empty chat, never an error in front of
      // somebody. There is nothing here worth interrupting a person over.
      return const <PanStoredMessage>[];
    }
  }

  @override
  Future<void> save(List<PanStoredMessage> messages) async {
    try {
      final List<PanStoredMessage> kept = messages.length > panHistoryLimit
          ? messages.sublist(messages.length - panHistoryLimit)
          : messages;
      final File f = await _file();
      await f.writeAsString(
        jsonEncode(<Object?>[
          for (final PanStoredMessage m in kept) m.toJson(),
        ]),
      );
    } on Object {
      // Failing to keep a chat is not worth a word on screen. The ledger has
      // a whole reporting path for a failed save because losing money data
      // matters; losing a conversation does not.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final File f = await _file();
      if (await f.exists()) await f.delete();
    } on Object {
      // Same reasoning. The in-memory list is cleared by the caller either
      // way, so the person sees the thing they asked for.
    }
  }
}

/// For tests, and for any screen that wants Pan without touching a disk.
class MemoryPanHistoryStore implements PanHistoryStore {
  List<PanStoredMessage> _messages = <PanStoredMessage>[];

  @override
  Future<List<PanStoredMessage>> load() async => _messages;

  @override
  Future<void> save(List<PanStoredMessage> messages) async {
    _messages = messages.length > panHistoryLimit
        ? messages.sublist(messages.length - panHistoryLimit)
        : List<PanStoredMessage>.of(messages);
  }

  @override
  Future<void> clear() async => _messages = <PanStoredMessage>[];
}
