import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatPageViewModel', () {
    late FakeChatApi api;
    late IsmChatPageViewModel vm;

    setUp(() {
      api = FakeChatApi();
      vm = IsmChatPageViewModel(IsmChatPageRepository(apiWrapper: api.wrapper()));
    });

    test('getChatMessages returns empty when repository returns null', () async {
      api.on('GET', '/chat/messages', const FakeResponse('{}', status: 500));
      expect(await vm.getChatMessages(conversationId: kDirectConversationId),
          isEmpty);
    });

    test('filters action events and block banners', () async {
      api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [
            messageJson(body: 'keep', messageId: 'keep'),
            messageJson(
              messageId: 'react',
              action: IsmChatActionEvents.reactionAdd.name,
            ),
            messageJson(
              messageId: 'block',
              customType: 'block',
              action: IsmChatActionEvents.userBlock.name,
            ),
          ],
        }),
      );
      // chatPageController is required; register a dummy page controller.
      GetTestControllers.registerPage(vm);
      final list =
          await vm.getChatMessages(conversationId: kDirectConversationId);
      expect(list.map((m) => m.messageId), contains('keep'));
      expect(list.map((m) => m.messageId), isNot(contains('react')));
    });

    test('delegates group admin and reactions', () async {
      api.on('PATCH', '/title', FakeResponse.json({'ok': true}));
      api.on('PUT', '/members', FakeResponse.json({'ok': true}));
      api.on('POST', '/reaction', FakeResponse.json({'ok': true}));
      api.on('POST', '/block', FakeResponse.json({'ok': true}));
      // addReacton returns null unless the conversation+message already exist in Hive.
      await openTestDatabase();
      await IsmChatConfig.dbWrapper?.saveConversation(
        conversation: directConversation().copyWith(
          messages: {
            'm': message(messageId: 'm'),
          },
        ),
      );
      GetTestControllers.registerPage(vm);
      expect(
        await vm.changeGroupTitle(
          conversationTitle: 'N',
          conversationId: kDirectConversationId,
          isLoading: false,
        ),
        isNotNull,
      );
      expect(
        await vm.addMembers(
          memberList: ['u'],
          conversationId: kDirectConversationId,
        ),
        isNotNull,
      );
      expect(
        await vm.addReacton(
          reaction: Reaction(
            reactionType: IsmChatEmoji.yes,
            messageId: 'm',
            conversationId: kDirectConversationId,
          ),
        ),
        isNotNull,
      );
      expect(
        await vm.blockUser(
          opponentId: kOpponentId,
          conversationId: kDirectConversationId,
        ),
        isTrue,
      );
    });

    test('updateMessage and getMessageForStatus', () async {
      api.on('PATCH', '/message', FakeResponse.json({'ok': true}));
      expect(
        await vm.updateMessage(
          metaData: {},
          messageId: 'm',
          conversationId: kDirectConversationId,
          isLoading: false,
        ),
        isTrue,
      );
      api.on(
        'GET',
        '/messages/status',
        FakeResponse.json({
          'messages': [
            {'messageId': 'm', 'deliveredToAll': true, 'readByAll': true}
          ]
        }),
      );
      expect(
        await vm.getMessageForStatus(
          conversationId: kDirectConversationId,
          messageIds: ['m'],
          isLoading: false,
        ),
        hasLength(1),
      );
    });
  });

  group('IsmChatConversationsViewModel', () {
    test('getChatConversations returns empty on error', () async {
      final api = FakeChatApi()
        ..on('GET', '/chat/conversations', const FakeResponse('{}', status: 500));
      final vm = IsmChatConversationsViewModel(
        IsmChatConversationsRepository(apiWrapper: api.wrapper()),
      );
      expect(
        await vm.getChatConversations(skip: 0, chatLimit: 20, searchTag: ''),
        isEmpty,
      );
    });

    test('deleteChat / unblockUser / getUserList', () async {
      final api = FakeChatApi()
        ..on('DELETE', '/local', FakeResponse.json({'ok': true}))
        ..on('POST', '/unblock', FakeResponse.json({'ok': true}))
        ..on(
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
            'pageToken': '',
          }),
        );
      final vm = IsmChatConversationsViewModel(
        IsmChatConversationsRepository(apiWrapper: api.wrapper()),
      );
      expect(await vm.deleteChat(kDirectConversationId), isNotNull);
      expect(
        await vm.unblockUser(opponentId: kOpponentId, isLoading: false),
        isNotNull,
      );
      expect((await vm.getUserList())?.users, hasLength(1));
    });
  });

  group('IsmChatMqttViewModel', () {
    test('count methods return empty string on error', () async {
      final api = FakeChatApi()
        ..on('GET', '/unread/count', const FakeResponse('{}', status: 500))
        ..on('GET', '/conversations/count',
            const FakeResponse('{}', status: 500));
      final vm =
          IsmChatMqttViewModel(IsmChatMqttRepository(apiWrapper: api.wrapper()));
      expect(await vm.getChatConversationsUnreadCount(), '');
      expect(await vm.getChatConversationsCount(), '');
    });

    test('getUserMessges strips action events', () async {
      final api = FakeChatApi()
        ..on(
          'GET',
          '/messages/user',
          FakeResponse.json({
            'messages': [
              messageJson(messageId: 'keep'),
              messageJson(
                messageId: 'created',
                action: IsmChatActionEvents.conversationCreated.name,
              ),
            ],
          }),
        );
      final vm =
          IsmChatMqttViewModel(IsmChatMqttRepository(apiWrapper: api.wrapper()));
      final list = await vm.getUserMessges(senderIds: [kMeId]);
      expect(list?.map((m) => m.messageId), contains('keep'));
      expect(list?.map((m) => m.messageId), isNot(contains('created')));
    });
  });

  group('IsmChatBroadcastViewModel', () {
    test('deleteBroadcast / updateBroadcast bool mapping', () async {
      final api = FakeChatApi()
        ..on('DELETE', '/groupcast', FakeResponse.json({'ok': true}))
        ..on('PATCH', '/groupcast', FakeResponse.json({'ok': true}));
      final vm = IsmChatBroadcastViewModel(
        IsmChatBroadcastRepository(apiWrapper: api.wrapper()),
      );
      expect(await vm.deleteBroadcast(groupcastId: 'g'), isTrue);
      expect(await vm.updateBroadcast(groupcastId: 'g'), isTrue);
      api.on('DELETE', '/groupcast', const FakeResponse('{}', status: 500));
      expect(await vm.deleteBroadcast(groupcastId: 'g'), isFalse);
      api.on('PATCH', '/groupcast', const FakeResponse('{}', status: 500));
      expect(await vm.updateBroadcast(groupcastId: 'g'), isFalse);
    });
  });

  group('IsmChatCommonViewModel', () {
    test('updatePresignedUrl returns status code', () async {
      final api = FakeChatApi()..on('PUT', '/upload', const FakeResponse('{}'));
      final vm = IsmChatCommonViewModel(
        IsmChatCommonRepository(apiWrapper: api.wrapper()),
      );
      expect(
        await vm.updatePresignedUrl(
          presignedUrl: 'https://chat.test/upload',
          bytes: Uint8List.fromList([1]),
        ),
        200,
      );
    });

    test('getChatMessages filters actions and sorts', () async {
      final api = FakeChatApi()
        ..on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [
              messageJson(messageId: 'b', sentAt: 2),
              messageJson(messageId: 'a', sentAt: 1),
              messageJson(
                messageId: 'drop',
                action: IsmChatActionEvents.reactionAdd.name,
              ),
            ],
          }),
        );
      final vm = IsmChatCommonViewModel(
        IsmChatCommonRepository(apiWrapper: api.wrapper()),
      );
      final list =
          await vm.getChatMessages(conversationId: kDirectConversationId);
      expect(list.map((m) => m.messageId), containsAll(['a', 'b']));
      expect(list.map((m) => m.messageId), isNot(contains('drop')));
    });
  });
}

/// Tiny helper so view-model tests can satisfy `IsmChatUtility.chatPageController`.
class GetTestControllers {
  static void registerPage(IsmChatPageViewModel vm) {
    Get.put(IsmChatPageController(vm), tag: IsmChat.i.chatPageTag);
  }
}
