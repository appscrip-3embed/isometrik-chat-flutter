import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import 'fake_api.dart';
import 'fixtures.dart';
import 'test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  test('database opens in a temp directory and stores a conversation',
      () async {
    final db = await openTestDatabase();
    await db.saveConversation(conversation: directConversation());
    final stored = await db.getConversation(kDirectConversationId);
    expect(stored?.conversationId, kDirectConversationId);
  });

  chatTestWidgets('controllers register against the fake API',
      (tester, ctx) async {
    expect(ctx.page.viewModel, isNotNull);
    expect(IsmChatUtility.chatPageControllerRegistered, isTrue);
    expect(ctx.conversations.intilizedContrller, isTrue);
    expect(ctx.api.requests, isNotEmpty);
  });
}
