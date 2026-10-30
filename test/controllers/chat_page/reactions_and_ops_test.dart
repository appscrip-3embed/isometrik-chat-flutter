import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

void main() {
  chatTestWidgets('addReacton posts and skip empty messageId',
      (tester, ctx) async {
    await drive(
      tester,
      () => ctx.page.addReacton(
        reaction: Reaction(
          reactionType: IsmChatEmoji.heart,
          messageId: '',
          conversationId: kDirectConversationId,
        ),
      ),
    );
    expect(ctx.api.requestsTo('/reaction', method: 'POST'), isEmpty);

    await drive(
      tester,
      () => ctx.page.addReacton(
        reaction: Reaction(
          reactionType: IsmChatEmoji.heart,
          messageId: 'm1',
          conversationId: kDirectConversationId,
        ),
      ),
    );
    expect(ctx.api.requestsTo('/reaction', method: 'POST'), isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('onReplyTap and onMessageSelect', (tester, ctx) async {
    ctx.page.conversation = directConversation();
    final msg = message();
    ctx.page.onReplyTap(msg);
    expect(ctx.page.isreplying, isTrue);
    expect(ctx.page.replayMessage?.messageId, msg.messageId);

    ctx.page.isMessageSeleted = true;
    ctx.page.onMessageSelect(msg);
    expect(ctx.page.selectedMessage, contains(msg));
    ctx.page.onMessageSelect(msg);
    expect(ctx.page.selectedMessage, isEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('getMessageBody covers location, contact, text',
      (tester, ctx) async {
    expect(
      ctx.page.getMessageBody(
        message(customType: IsmChatCustomMessageType.location),
      ),
      isNotEmpty,
    );
    expect(
      ctx.page.getMessageBody(
        message(
          customType: IsmChatCustomMessageType.contact,
          metaData: IsmChatMetaData(
            contacts: [
              IsmChatContactMetaDatModel(contactName: 'Alice'),
            ],
          ),
        ),
      ),
      isNotEmpty,
    );
    expect(ctx.page.getMessageBody(message(body: 'plain')), 'plain');
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('delete for me / everyone and clearAll', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(
        conversation: directConversation(
          messages: {'1': message(sentAt: 1, messageId: 'm1')},
        ),
      ),
    );
    ctx.page.conversation = directConversation();
    await drive(
      tester,
      () => ctx.page.viewModel.deleteMessageForMe({
        '1': message(sentAt: 1, messageId: 'm1'),
      }),
    );
    expect(ctx.api.requestsTo('/self', method: 'DELETE'), isNotEmpty);

    await drive(
      tester,
      () => ctx.page.viewModel.deleteMessageForEveryone({
        '1': message(sentAt: 1, messageId: 'm1'),
      }),
    );
    expect(ctx.api.requestsTo('/everyone', method: 'DELETE'), isNotEmpty);

    expect(
      await drive(
        tester,
        () => ctx.page.viewModel.clearAllMessages(
          conversationId: kDirectConversationId,
        ),
      ),
      isTrue,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('broadcast send and create', (tester, ctx) async {
    ctx.page
      ..isBroadcast = true
      ..conversation = directConversation().copyWith(
        customType: IsmChatStrings.broadcast,
        conversationId: 'gcast-1',
      )
      ..currentUser = me();
    await drive(
      tester,
      () => ctx.page.sendBroadcastMessage(
        createdAt: 1,
        groupcastId: 'gcast-1',
        messageType: 0,
        deviceId: 'device-1',
        body: 'hello all',
        notificationBody: 'hello all',
        notificationTitle: kMeName,
        customType: IsmChatCustomMessageType.text.value,
      ),
    );
    expect(ctx.api.requestsTo('/groupcast/message', method: 'POST'), isNotEmpty);

    final id = await drive(
      tester,
      () => ctx.page.viewModel.createBroadcastConversation(
        groupcastTitle: 'B',
        groupcastImageUrl: 'u',
        membersId: [kOpponentId],
      ),
    );
    expect(id, 'gcast-1');
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('pagination getChatMessages search vs timestamp',
      (tester, ctx) async {
    ctx.api.on(
      'GET',
      '/chat/messages',
      FakeResponse.json({
        'messages': [
          messageJson(messageId: 'm-keep', body: 'keep'),
          messageJson(
            messageId: 'm-drop',
            action: IsmChatActionEvents.reactionAdd.name,
          ),
        ],
      }),
    );
    ctx.page.conversation = directConversation();
    final list = await drive(
      tester,
      () => ctx.page.viewModel.getChatMessages(
        conversationId: kDirectConversationId,
        searchText: 'keep',
      ),
    );
    expect(list.map((m) => m.messageId), contains('m-keep'));
    expect(list.map((m) => m.messageId), isNot(contains('m-drop')));
  }, setUpApi: (api) => api.registerSendDefaults());
}
