import 'dart:async';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Debounced saving of one composer's draft (channel or thread).
///
/// A composer is shared by every chat or thread it shows, so the tracker is
/// bound to one storage [key] at a time with [attach]. While no key is
/// attached, changes are ignored: clearing the field to show another chat
/// never wipes the previous chat's draft. Call [detach] before re-targeting.
class IsmChatDraftTracker {
  IsmChatDraftTracker({
    required this.save,
    this.delay = const Duration(milliseconds: 400),
  });

  /// Persists [draft] under [key]; an empty draft means delete.
  final Future<void> Function(String key, IsmChatDraftModel draft) save;

  final Duration delay;

  String? _key;
  Timer? _timer;
  IsmChatDraftModel? _pending;
  IsmChatDraftModel? _lastSaved;
  Future<void> _lastWrite = Future<void>.value();

  /// Completes when the latest storage write has landed. Await it before
  /// reading a draft back, since [detach] does not wait for its write.
  Future<void> get idle => _lastWrite;

  /// Storage key currently tracked, or null while detached.
  String? get key => _key;

  /// Starts tracking [key]. [saved] is what the composer was filled with.
  void attach(String key, IsmChatDraftModel? saved) {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _lastSaved = saved;
    _key = key.isEmpty ? null : key;
  }

  /// Records the composer's current state; saved after [delay].
  void onChanged(IsmChatDraftModel draft) {
    final key = _key;
    if (key == null) return;
    final previous = _pending ?? _lastSaved;
    // Selection/cursor moves also notify text controllers.
    if (draft.sameContentAs(previous)) return;
    if (draft.isEmpty && (previous == null || previous.isEmpty)) return;
    _pending = draft;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_write(key)));
  }

  /// Saves an unsaved change right away.
  ///
  /// Everything up to the storage write runs synchronously, so a [detach]
  /// right after this still saves under the old key.
  Future<void> flush() async {
    final key = _key;
    if (key == null) return;
    await _write(key);
  }

  Future<void> _write(String key) async {
    _timer?.cancel();
    _timer = null;
    final draft = _pending;
    if (draft == null) return;
    _pending = null;
    _lastSaved = draft;
    final write = _lastWrite = save(key, draft);
    await write;
  }

  /// Saves any pending change and stops tracking.
  void detach() {
    unawaited(flush());
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _lastSaved = null;
    _key = null;
  }
}
