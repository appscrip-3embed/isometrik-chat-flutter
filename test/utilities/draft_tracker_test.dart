import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  late List<(String, String)> saved;
  late IsmChatDraftTracker tracker;

  setUp(() {
    saved = [];
    tracker = IsmChatDraftTracker(
      delay: const Duration(milliseconds: 10),
      save: (key, draft) async => saved.add((key, draft.text)),
    );
  });

  Future<void> waitPastDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  test('ignores changes while detached', () async {
    tracker.onChanged(const IsmChatDraftModel(text: 'hi'));
    await waitPastDelay();
    expect(saved, isEmpty);
  });

  test('debounces to the latest change', () async {
    tracker
      ..attach('a', null)
      ..onChanged(const IsmChatDraftModel(text: 'h'))
      ..onChanged(const IsmChatDraftModel(text: 'hi'));
    await waitPastDelay();
    expect(saved, [('a', 'hi')]);
  });

  test('detach saves the pending change under the old key', () async {
    tracker
      ..attach('a', null)
      ..onChanged(const IsmChatDraftModel(text: 'hi'))
      ..detach()
      // Clearing the composer for the next chat must not reach storage.
      ..onChanged(const IsmChatDraftModel(text: ''));
    await waitPastDelay();
    expect(saved, [('a', 'hi')]);
    expect(tracker.key, isNull);
  });

  test('skips unchanged and empty-over-empty states', () async {
    tracker
      ..attach('a', const IsmChatDraftModel(text: 'hi'))
      ..onChanged(const IsmChatDraftModel(text: 'hi'));
    await waitPastDelay();
    expect(saved, isEmpty);

    tracker
      ..attach('b', null)
      ..onChanged(const IsmChatDraftModel(text: ''));
    await waitPastDelay();
    expect(saved, isEmpty);
  });

  test('clearing a saved draft saves the empty state (delete)', () async {
    tracker
      ..attach('a', const IsmChatDraftModel(text: 'hi'))
      ..onChanged(const IsmChatDraftModel(text: ''));
    await tracker.flush();
    expect(saved, [('a', '')]);
  });
}
