import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// Thread composer drafts: unsent text and the nested-reply target survive
/// closing and re-opening a thread, per thread, backed by real Hive.
void main() {
  late FakeChatApi api;
  late IsmChatThreadController controller;

  setUp(() async {
    configureChatSdk(useDatabase: true);
    await openTestDatabase();
    IsmChatConfig.threadsEnabled = true;
    api = FakeChatApi()
      ..on('GET', '/chat/messages', FakeResponse.json({'messages': []}))
      ..on('POST', '/chat/message', FakeResponse.json({'messageId': 'srv'}));
    controller = Get.put(
      IsmChatThreadController(
        IsmChatThreadViewModel(
          IsmChatThreadRepository(apiWrapper: api.wrapper()),
        ),
      ),
    );
  });

  tearDown(() async {
    IsmChatConfig.threadsEnabled = false;
    await resetChatSdk();
  });

  Future<void> open(String rootId) =>
      controller.openThread(root: threadRoot(messageId: rootId));

  test('text and nested reply come back after close + reopen', () async {
    final nested = message(body: 'nested', messageId: 'nested-1');
    await open('root-1');
    controller
      ..replyTo = nested
      ..replyController.text = 'half typed';
    controller.closeThread();
    expect(controller.replyController.text, isEmpty);

    await open('root-1');
    expect(controller.replyController.text, 'half typed');
    expect(controller.replyTo?.messageId, 'nested-1');
  });

  test('drafts are kept per thread', () async {
    await open('root-1');
    controller.replyController.text = 'for one';
    await open('root-2');
    expect(controller.replyController.text, isEmpty);
    controller.replyController.text = 'for two';

    await open('root-1');
    expect(controller.replyController.text, 'for one');
    await open('root-2');
    expect(controller.replyController.text, 'for two');
  });

  test('sending clears the draft', () async {
    await open('root-1');
    controller.replyController.text = 'send me';
    await controller.sendReply();
    controller.closeThread();

    await open('root-1');
    expect(controller.replyController.text, isEmpty);
  });

  test('the edited body is not saved as a draft', () async {
    await open('root-1');
    controller.replyController.text = 'draft';
    await controller.flushComposerDraft();
    controller.isEditing = true;
    controller.replyController.text = 'edited body';
    controller.closeThread();
    controller.isEditing = false;

    await open('root-1');
    expect(controller.replyController.text, 'draft');
  });
}
