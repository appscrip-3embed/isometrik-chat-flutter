import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

Future<void> _seedDirect(ChatTestContext ctx) async {
  ctx.page
    ..conversation = directConversation()
    ..currentUser = me();
  ctx.conversations.userDetails = me();
}

void main() {
  chatTestWidgets('sends a 1-to-1 text message', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seedDirect(ctx);
    ctx.page.chatInputController.text = 'hello world';
    ctx.page.sendTextMessage(
      conversationId: kDirectConversationId,
      userId: kOpponentId,
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    expect(ctx.page.messages.any((m) => m.body == 'hello world'), isTrue);
    final req = ctx.api.requestsTo('/chat/message', method: 'POST').last;
    expect(req.json['body'], 'hello world');
    expect(req.json['conversationId'], kDirectConversationId);
    expect(req.json['customType'], IsmChatCustomMessageType.text.value);
    expect(req.json['encrypted'], isFalse);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('creates the conversation on first send when it is not in DB',
      (tester, ctx) async {
    await _seedDirect(ctx);
    ctx.page.conversation = directConversation(conversationId: '');
    ctx.page.chatInputController.text = 'first';
    ctx.page.sendTextMessage(conversationId: '', userId: kOpponentId);
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/conversation', method: 'POST').isNotEmpty,
    );
    expect(
      ctx.api.requestsTo('/chat/conversation', method: 'POST').single.json['isGroup'],
      isFalse,
    );
  }, setUpApi: (api) => api.registerSendDefaults(conversationId: 'conv-created'));

  chatTestWidgets('sends a reply with parentMessageId', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seedDirect(ctx);
    final parent = message(body: 'original', sentByMe: false);
    ctx.page
      ..isreplying = true
      ..replayMessage = parent
      ..chatInputController.text = 'replying';
    ctx.page.sendTextMessage(
      conversationId: kDirectConversationId,
      userId: kOpponentId,
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    final req = ctx.api.requestsTo('/chat/message', method: 'POST').last;
    expect(req.json['customType'], IsmChatCustomMessageType.reply.value);
    expect(req.json['parentMessageId'], parent.messageId);
    expect(ctx.page.isreplying, isFalse);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('keepLocalOnly never hits the send API', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seedDirect(ctx);
    ctx.page.chatInputController.text = 'blocked locally';
    ctx.page.sendTextMessage(
      conversationId: kDirectConversationId,
      userId: kOpponentId,
      keepLocalOnly: true,
      localBlockReason: 'phishing',
    );
    await settle(tester, rounds: 4);
    expect(ctx.api.requestsTo('/chat/message', method: 'POST'), isEmpty);
    expect(ctx.page.messages.single.isInvalidMessage, isTrue);
    expect(ctx.page.messages.single.body, 'blocked locally');
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('trySendTextFromComposer rejects empty and blocked chats',
      (tester, ctx) async {
    await _seedDirect(ctx);
    ctx.page.conversation = directConversation(messagingDisabled: true);
    expect(await ctx.page.trySendTextFromComposer(text: 'nope'), isFalse);

    ctx.page.conversation = directConversation();
    ctx.page.chatInputController.text = '   ';
    expect(await ctx.page.trySendTextFromComposer(), isFalse);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('trySendTextFromComposer sends a normal text message',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seedDirect(ctx);
    expect(
      await ctx.page.trySendTextFromComposer(text: 'from composer'),
      isTrue,
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    expect(
      ctx.api.requestsTo('/chat/message', method: 'POST').last.json['body'],
      'from composer',
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('masks sensitive content when enabled', (tester, ctx) async {
    IsmChatConfig.maskSensitiveContent = true;
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seedDirect(ctx);
    ctx.page.chatInputController.text = 'mail me@test.com please';
    ctx.page.sendTextMessage(
      conversationId: kDirectConversationId,
      userId: kOpponentId,
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    expect(ctx.page.messages.last.body, isNot(contains('me@test.com')));
    expect(
      ctx.api.requestsTo('/chat/message', method: 'POST').last.json['body'],
      contains('me@test.com'),
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('updateMessage PATCHes metadata', (tester, ctx) async {
    final ok = await drive(
      tester,
      () => ctx.page.viewModel.updateMessage(
        metaData: {'edited': true},
        messageId: 'm1',
        conversationId: kDirectConversationId,
        isLoading: false,
      ),
    );
    expect(ok, isTrue);
    expect(
      ctx.api.requestsTo('/chat/message', method: 'PATCH').single.json['metaData'],
      {'edited': true},
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('read / typing / block hit the right endpoints',
      (tester, ctx) async {
    await drive(
      tester,
      () => ctx.page.viewModel.readMessage(
        conversationId: kDirectConversationId,
        messageId: 'm1',
      ),
    );
    await drive(
      tester,
      () => ctx.page.viewModel.notifyTyping(
        conversationId: kDirectConversationId,
      ),
    );
    expect(
      await drive(
        tester,
        () => ctx.page.viewModel.blockUser(
          opponentId: kOpponentId,
          conversationId: kDirectConversationId,
        ),
      ),
      isTrue,
    );
    expect(ctx.api.requestsTo('/indicator/read', method: 'PUT'), isNotEmpty);
    expect(ctx.api.requestsTo('/indicator/typing', method: 'POST'), isNotEmpty);
    expect(ctx.api.requestsTo('/block', method: 'POST'), isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());
}
