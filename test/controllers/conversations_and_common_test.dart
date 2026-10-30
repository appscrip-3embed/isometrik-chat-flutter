import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  chatTestWidgets('conversations list, search and user list', (tester, ctx) async {
    ctx.api.on(
      'GET',
      '/chat/conversations',
      FakeResponse.json({
        'conversations': [
          conversationJson(),
          conversationJson(conversationId: 'c2', isGroup: true, title: 'G'),
        ],
      }),
    );
    final list = await drive(
      tester,
      () => ctx.conversations.viewModel.getChatConversations(),
    );
    expect(list, isNotEmpty);

    ctx.api.on(
      'GET',
      '/chat/users',
      FakeResponse.json({
        'users': [
          {
            'userId': kOpponentId,
            'userName': kOpponentName,
            'userIdentifier': 'x',
            'userProfileImageUrl': '',
          }
        ],
        'pageToken': 'next',
      }),
    );
    expect(
      (await drive(tester, () => ctx.conversations.viewModel.getUserList()))
          ?.pageToken,
      'next',
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('forward message posts to /message/forward', (tester, ctx) async {
    ctx.api.on('POST', '/forward', FakeResponse.json({'ok': true}));
    expect(
      await drive(
        tester,
        () => ctx.conversations.viewModel.sendForwardMessage(
          userIds: [kOpponentId],
          showInConversation: true,
          messageType: 0,
          encrypted: false,
          deviceId: 'd',
          body: 'fwd',
          notificationBody: 'fwd',
          notificationTitle: kMeName,
        ),
      ),
      isNotNull,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('common controller sendMessage and postMediaUrl',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await tester.runAsync(
      () => ctx.db!.saveMessage(
        message(sentAt: 99)..messageId = '',
        IsmChatDbBox.pending,
      ),
    );
    final sent = await drive(
      tester,
      () => ctx.common.sendMessage(
        showInConversation: true,
        messageType: 0,
        encrypted: false,
        deviceId: 'device-1',
        conversationId: kDirectConversationId,
        body: 'hi',
        createdAt: 99,
        notificationBody: 'hi',
        notificationTitle: kMeName,
        customType: IsmChatCustomMessageType.text.value,
      ),
    );
    expect(sent, isTrue);

    final url = await drive(
      tester,
      () => ctx.common.postMediaUrl(
        conversationId: kDirectConversationId,
        nameWithExtension: 'a.jpg',
        mediaType: IsmChatMediaType.image.value,
        mediaId: '1',
        bytes: Uint8List.fromList(const [1, 2, 3]),
        isLoading: false,
      ),
    );
    expect(url?.mediaUrl, isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('common handleSorSelectedMembers tags A-Z', (tester, ctx) async {
    final list = [
      SelectedMembers(
        isUserSelected: false,
        userDetails: user(id: 'a', name: 'Alice'),
        isBlocked: false,
      ),
      SelectedMembers(
        isUserSelected: false,
        userDetails: user(id: '1', name: '1numeric'),
        isBlocked: false,
        localContacts: true,
      ),
    ];
    ctx.common.handleSorSelectedMembers(list);
    expect(list.first.tagIndex, 'A');
    ctx.common.handleSorSelectedMembers([]);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('createConversation returns a model with the new id',
      (tester, ctx) async {
    final created = await drive(
      tester,
      () => ctx.common.createConversation(
        conversation: directConversation(conversationId: ''),
        userId: [kOpponentId],
        isGroup: false,
      ),
    );
    expect(created?.conversationId, isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults(conversationId: 'conv-created'));
}
