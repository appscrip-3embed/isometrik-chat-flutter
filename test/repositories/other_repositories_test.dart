import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatConversationsRepository', () {
    late FakeChatApi api;
    late IsmChatConversationsRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatConversationsRepository(apiWrapper: api.wrapper());
    });

    test('getUserList with and without pageToken', () async {
      api.on(
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
          'pageToken': 'p2',
        }),
      );
      expect((await repo.getUserList())?.users, hasLength(1));
      await repo.getUserList(pageToken: 'p1', count: 10);
      expect(api.requests.last.url.toString(), contains('pageToken=p1'));
      api.on('GET', '/chat/users', const FakeResponse('{}', status: 400));
      expect(await repo.getUserList(), isNull);
      api.throwOn('GET', '/chat/users', Exception('x'));
      expect(await repo.getUserList(), isNull);
    });

    test('getNonBlockUserList with search', () async {
      api.on(
        'GET',
        '/nonblock',
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
      expect(await repo.getNonBlockUserList(), isNotNull);
      await repo.getNonBlockUserList(searchTag: 'al');
      expect(api.requests.last.url.toString(), contains('searchTag=al'));
      api.throwOn('GET', '/nonblock', Exception('x'));
      expect(await repo.getNonBlockUserList(), isNull);
    });

    test('getChatConversations success, search, error', () async {
      api.on(
        'GET',
        '/chat/conversations',
        FakeResponse.json({
          'conversations': [conversationJson(), conversationJson(conversationId: 'c2')],
        }),
      );
      expect(
        await repo.getChatConversations(
          skip: 0,
          limit: 20,
          searchTag: '',
          includeConversationStatusMessagesInUnreadMessagesCount: true,
        ),
        hasLength(2),
      );
      await repo.getChatConversations(
        skip: 0,
        limit: 20,
        searchTag: 'g',
        includeConversationStatusMessagesInUnreadMessagesCount: false,
      );
      expect(api.requests.last.url.toString(), contains('searchTag=g'));
      api.on('GET', '/chat/conversations', const FakeResponse('{}', status: 500));
      expect(
        await repo.getChatConversations(
          skip: 0,
          limit: 20,
          searchTag: '',
          includeConversationStatusMessagesInUnreadMessagesCount: true,
        ),
        isNull,
      );
      api.throwOn('GET', '/chat/conversations', Exception('x'));
      expect(
        await repo.getChatConversations(
          skip: 0,
          limit: 20,
          searchTag: '',
          includeConversationStatusMessagesInUnreadMessagesCount: true,
        ),
        isNull,
      );
    });

    test('unblock, deleteChat, leave, makeAdmin, clear, forward', () async {
      api.on('POST', '/unblock', FakeResponse.json({'ok': true}));
      api.on('DELETE', '/local', FakeResponse.json({'ok': true}));
      api.on('DELETE', '/leave', FakeResponse.json({'ok': true}));
      api.on('PUT', '/admin', FakeResponse.json({'ok': true}));
      api.on('DELETE', '/clear', FakeResponse.json({'ok': true}));
      api.on('POST', '/forward', FakeResponse.json({'ok': true}));
      expect(
        await repo.unblockUser(opponentId: kOpponentId, isLoading: false),
        isNotNull,
      );
      expect(await repo.deleteChat(kDirectConversationId), isNotNull);
      expect(await repo.leaveConversation(kDirectConversationId), isNotNull);
      expect(
        await repo.makeAdmin(
          memberId: kOpponentId,
          conversationId: kDirectConversationId,
          isLoading: false,
        ),
        isNotNull,
      );
      expect(
        await repo.clearAllMessages(conversationId: kDirectConversationId),
        isNotNull,
      );
      expect(
        await repo.sendForwardMessage(
          userIds: [kOpponentId],
          showInConversation: true,
          messageType: 0,
          encrypted: false,
          deviceId: 'd',
          body: 'hi',
          notificationBody: 'hi',
          notificationTitle: 't',
        ),
        isNotNull,
      );
      api.throwOn('POST', '/unblock', Exception('x'));
      expect(
        await repo.unblockUser(opponentId: kOpponentId, isLoading: false),
        isNull,
      );
    });

    test('getUserData / updateUserData / getBlockUser', () async {
      api.on(
        'GET',
        '/user/details',
        FakeResponse.json({
          'userId': kMeId,
          'userName': kMeName,
          'userIdentifier': 'me@test.com',
          'userProfileImageUrl': '',
        }),
      );
      expect((await repo.getUserData())?.userId, kMeId);
      api.on('PATCH', '/chat/user', FakeResponse.json({
        'userId': kMeId,
        'userName': 'New',
        'userIdentifier': 'me@test.com',
        'userProfileImageUrl': '',
      }));
      expect((await repo.updateUserData(userName: 'New'))?.userName, 'New');
      api.on(
        'GET',
        '/block',
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
      expect(
        await repo.getBlockUser(skip: 0, limit: 20, isLoading: false),
        isNotNull,
      );
      api.throwOn('GET', '/user/details', Exception('x'));
      expect(await repo.getUserData(), isNull);
    });
  });

  group('IsmChatCommonRepository', () {
    late FakeChatApi api;
    late IsmChatCommonRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatCommonRepository(apiWrapper: api.wrapper());
    });

    test('sendMessage success, error, exception', () async {
      api.on('POST', '/chat/message', FakeResponse.json({'messageId': 'm1'}));
      final ok = await repo.sendMessage(
        showInConversation: true,
        messageType: 0,
        encrypted: false,
        deviceId: 'd',
        conversationId: kDirectConversationId,
        body: 'hi',
        notificationBody: 'hi',
        notificationTitle: 't',
        customType: 'AttachmentMessage:Text',
      );
      expect(ok?.messageId, 'm1');
      expect(ok?.respone.hasError, isFalse);

      api.on('POST', '/chat/message', const FakeResponse('{}', status: 422));
      final err = await repo.sendMessage(
        showInConversation: true,
        messageType: 0,
        encrypted: false,
        deviceId: 'd',
        conversationId: kDirectConversationId,
        body: 'hi',
        notificationBody: 'hi',
        notificationTitle: 't',
        customType: 'AttachmentMessage:Text',
      );
      expect(err?.messageId, '');
      expect(err?.respone.hasError, isTrue);

      api.throwOn('POST', '/chat/message', Exception('x'));
      expect(
        await repo.sendMessage(
          showInConversation: true,
          messageType: 0,
          encrypted: true,
          deviceId: 'd',
          conversationId: kDirectConversationId,
          body: 'hi',
          notificationBody: 'hi',
          notificationTitle: 't',
          customType: 'AttachmentMessage:Text',
          searchableTags: ['hi'],
        ),
        isNull,
      );
    });

    test('postMediaUrl / updatePresignedUrl / getPresignedUrl / createConversation',
        () async {
      api.on(
        'POST',
        '/presignedurls',
        FakeResponse.json({
          'presignedUrls': [
            {
              'mediaUrl': 'https://cdn.test/m',
              'mediaPresignedUrl': 'https://chat.test/upload',
              'mediaId': 'id',
            }
          ]
        }),
      );
      expect(
        (await repo.postMediaUrl(
          conversationId: kDirectConversationId,
          nameWithExtension: 'a.jpg',
          mediaType: 0,
          mediaId: '1',
          isLoading: false,
        ))
            ?.mediaUrl,
        'https://cdn.test/m',
      );
      api.on('PUT', '/upload', const FakeResponse('{}'));
      expect(
        await repo.updatePresignedUrl(
          presignedUrl: 'https://chat.test/upload',
          bytes: Uint8List.fromList([1]),
        ),
        isNotNull,
      );
      api.on(
        'GET',
        '/presignedurl/create',
        FakeResponse.json({'mediaUrl': 'u', 'presignedUrl': 'p'}),
      );
      expect(
        (await repo.getPresignedUrl(
          isLoading: false,
          userIdentifier: 'me@test.com',
          mediaExtension: 'jpg',
        ))
            ?.mediaUrl,
        'u',
      );
      api.on(
        'POST',
        '/chat/conversation',
        FakeResponse.json({'conversationId': 'c-new'}),
      );
      expect(
        await repo.createConversation(
          typingEvents: true,
          readEvents: true,
          pushNotifications: true,
          members: [kOpponentId],
          isGroup: false,
          conversationType: 0,
        ),
        isNotNull,
      );
      api.on('POST', '/chat/conversation', const FakeResponse('{"error":"no"}', status: 400));
      expect(
        await repo.createConversation(
          typingEvents: true,
          readEvents: true,
          pushNotifications: true,
          members: [kOpponentId],
          isGroup: false,
          conversationType: 0,
        ),
        isNull,
      );
      api.throwOn('POST', '/presignedurls', Exception('x'));
      expect(
        await repo.postMediaUrl(
          conversationId: kDirectConversationId,
          nameWithExtension: 'a.jpg',
          mediaType: 0,
          mediaId: '1',
          isLoading: false,
        ),
        isNull,
      );
    });

    test('getChatMessages mirrors page repository', () async {
      api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [messageJson()],
        }),
      );
      expect(
        await repo.getChatMessages(conversationId: kDirectConversationId),
        hasLength(1),
      );
      api.throwOn('GET', '/chat/messages', Exception('x'));
      expect(
        await repo.getChatMessages(conversationId: kDirectConversationId),
        isNull,
      );
    });
  });

  group('IsmChatBroadcastRepository', () {
    late FakeChatApi api;
    late IsmChatBroadcastRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatBroadcastRepository(apiWrapper: api.wrapper());
    });

    test('get / delete / update broadcast', () async {
      api.on(
        'GET',
        '/groupcasts',
        FakeResponse.json({
          'groupcasts': [
            {
              'groupcastId': 'g1',
              'groupcastTitle': 'B',
              'customType': 'broadcast',
              'sendPushForNewConversationCreated': true,
              'hideNewConversationsForSender': false,
            }
          ]
        }),
      );
      expect(
        await repo.getBroadcast(
          ids: [],
          customType: '',
          searchTag: '',
          sort: 1,
          skip: 0,
          limit: 20,
          sortByCustomType: false,
          executionPending: false,
        ),
        hasLength(1),
      );
      api.on('DELETE', '/groupcast', FakeResponse.json({'ok': true}));
      expect(await repo.deleteBroadcast(groupcastId: 'g1'), isNotNull);
      api.on('PATCH', '/groupcast', FakeResponse.json({'ok': true}));
      expect(
        await repo.updateBroadcast(
          groupcastId: 'g1',
          groupcastTitle: 'N',
          groupcastImageUrl: '',
        ),
        isNotNull,
      );
      api.throwOn('GET', '/groupcasts', Exception('x'));
      expect(
        await repo.getBroadcast(
          ids: [],
          customType: '',
          searchTag: '',
          sort: 1,
          skip: 0,
          limit: 20,
          sortByCustomType: false,
          executionPending: false,
        ),
        isNull,
      );
    });
  });

  group('IsmChatMqttRepository', () {
    late FakeChatApi api;
    late IsmChatMqttRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatMqttRepository(apiWrapper: api.wrapper());
    });

    test('read, counts, conversations, ping', () async {
      api.on('PUT', '/indicator/read', FakeResponse.json({'ok': true}));
      await repo.readSingleMessage(
        conversationId: kDirectConversationId,
        messageId: 'm',
      );
      api.on('GET', '/unread/count', FakeResponse.json({'count': 3}));
      expect(await repo.getChatConversationsUnreadCount(), '3');
      api.on(
        'GET',
        '/conversations/count',
        FakeResponse.json({'conversationsCount': 2}),
      );
      expect(await repo.getChatConversationsCount(), '2');
      api.on('POST', '/indicator/delivered', FakeResponse.json({'ok': true}));
      await repo.pingMessageDelivered(
        conversationId: kDirectConversationId,
        messageId: 'm',
      );
      api.throwOn('PUT', '/indicator/read', Exception('x'));
      await repo.readSingleMessage(
        conversationId: kDirectConversationId,
        messageId: 'm',
      );
    });
  });
}
