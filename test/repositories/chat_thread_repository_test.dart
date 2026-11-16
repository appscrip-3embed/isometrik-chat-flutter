import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// Pins the wire contract from `THREADING_API_HANDOFF.md`:
/// thread fetch = `feedType=thread` + `threadRootId`, count =
/// `/chat/messages/count?threadRootId=`, send = `POST /chat/message` with
/// `messageType: 2`, `parentMessageId` and `showInConversation`.
void main() {
  setUp(() {
    configureChatSdk();
    IsmChatConfig.threadsEnabled = true;
  });
  tearDown(() async {
    IsmChatConfig.threadsEnabled = false;
    await resetChatSdk();
  });

  test('defaults to the production API wrapper', () {
    // No network call — just proves the test-only injection point is optional.
    expect(IsmChatThreadRepository(), isA<IsmChatThreadRepository>());
  });

  group('IsmChatThreadRepository.getThreadMessages', () {
    late FakeChatApi api;
    late IsmChatThreadRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatThreadRepository(apiWrapper: api.wrapper());
    });

    test('asks for the whole thread, oldest-first, with user auth', () async {
      api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [
            threadReplyJson(messageId: 'r1', sentAt: 2000),
            threadReplyJson(messageId: 'r2', sentAt: 3000),
          ],
        }),
      );

      final replies = await repo.getThreadMessages(
        conversationId: kDirectConversationId,
        threadRootId: 'root-1',
        limit: 50,
      );

      expect(replies, hasLength(2));
      expect(replies!.first.threadRootId, 'root-1');
      expect(replies.first.messageType, IsmChatMessageType.reply);

      final request = api.requestsTo('/chat/messages').last;
      final query = request.url.queryParameters;
      expect(query['feedType'], 'thread');
      expect(query['threadRootId'], 'root-1');
      expect(query['conversationId'], kDirectConversationId);
      expect(query['sort'], '1');
      expect(query['limit'], '50');
      expect(query['skip'], '0');
      expect(request.headers['userToken'], isNotNull);
      expect(request.headers['licenseKey'], isNotNull);
    });

    test('pages with skip', () async {
      api.on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      await repo.getThreadMessages(
        conversationId: kDirectConversationId,
        threadRootId: 'root-1',
        skip: 20,
      );
      expect(
        api.requestsTo('/chat/messages').last.url.queryParameters['skip'],
        '20',
      );
    });

    test('returns null on a server error and [] on an empty thread', () async {
      api.on('GET', '/chat/messages', const FakeResponse('{}', status: 500));
      expect(
        await repo.getThreadMessages(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        isNull,
      );

      api.on('GET', '/chat/messages', FakeResponse.json(const {}));
      expect(
        await repo.getThreadMessages(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        isEmpty,
      );
    });

    test('returns null when the transport throws', () async {
      api.throwOn('GET', '/chat/messages', Exception('offline'));
      expect(
        await repo.getThreadMessages(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        isNull,
      );
    });

    test('never calls the API without a conversation and a root', () async {
      expect(
        await repo.getThreadMessages(conversationId: '', threadRootId: 'r'),
        isNull,
      );
      expect(
        await repo.getThreadMessages(
          conversationId: kDirectConversationId,
          threadRootId: '  ',
        ),
        isNull,
      );
      expect(api.requests, isEmpty);
    });
  });

  group('IsmChatThreadRepository.getThreadReplyCount', () {
    late FakeChatApi api;
    late IsmChatThreadRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatThreadRepository(apiWrapper: api.wrapper());
    });

    test('counts the full thread via threadRootId', () async {
      api.on(
        'GET',
        '/chat/messages/count',
        FakeResponse.json(const {'messagesCount': 7}),
      );
      expect(
        await repo.getThreadReplyCount(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        7,
      );
      final query =
          api.requestsTo('/chat/messages/count').last.url.queryParameters;
      expect(query['threadRootId'], 'root-1');
      expect(query['conversationId'], kDirectConversationId);
      // Badge counts the whole thread, so parentMessageId must not be sent.
      expect(query.containsKey('parentMessageId'), isFalse);
    });

    test('accepts the alternative count keys servers use', () async {
      api.on(
        'GET',
        '/chat/messages/count',
        FakeResponse.json(const {'count': '3'}),
      );
      expect(
        await repo.getThreadReplyCount(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        3,
      );
    });

    test('returns null when the count transport throws', () async {
      api.throwOn('GET', '/chat/messages/count', Exception('offline'));
      expect(
        await repo.getThreadReplyCount(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        isNull,
      );
    });

    test('never calls the API without a conversation and a root', () async {
      expect(
        await repo.getThreadReplyCount(conversationId: '', threadRootId: 'r'),
        isNull,
      );
      expect(
        await repo.getThreadReplyCount(
          conversationId: kDirectConversationId,
          threadRootId: '  ',
        ),
        isNull,
      );
      expect(api.requests, isEmpty);
    });

    test('returns null when the call fails or the body has no count', () async {
      api.on(
        'GET',
        '/chat/messages/count',
        const FakeResponse('{}', status: 500),
      );
      expect(
        await repo.getThreadReplyCount(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        isNull,
      );

      api.on('GET', '/chat/messages/count', FakeResponse.json(const {}));
      expect(
        await repo.getThreadReplyCount(
          conversationId: kDirectConversationId,
          threadRootId: 'root-1',
        ),
        isNull,
      );
    });
  });

  group('IsmChatThreadRepository.sendThreadReply', () {
    late FakeChatApi api;
    late IsmChatThreadRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatThreadRepository(apiWrapper: api.wrapper());
    });

    Future<({String messageId, IsmChatResponseModel response})?> send({
      required bool showInConversation,
      String parentMessageId = 'root-1',
    }) =>
        repo.sendThreadReply(
          conversationId: kDirectConversationId,
          parentMessageId: parentMessageId,
          body: 'in the thread',
          showInConversation: showInConversation,
          deviceId: 'device-1',
          customType: IsmChatCustomMessageType.text.name,
          notificationBody: 'in the thread',
          notificationTitle: kMeName,
        );

    test('posts messageType 2 with the immediate parent, thread-only',
        () async {
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(const {'messageId': 'server-reply'}),
      );

      final result = await send(showInConversation: false);
      expect(result?.messageId, 'server-reply');
      expect(result?.response.hasError, isFalse);

      final body = api.requestsForPath('/chat/message', method: 'POST').last.json
          as Map<String, dynamic>;
      expect(body['messageType'], IsmChatMessageType.reply.value);
      expect(body['messageType'], 2);
      expect(body['parentMessageId'], 'root-1');
      expect(body['showInConversation'], isFalse);
      expect(body['conversationId'], kDirectConversationId);
      expect(body['body'], 'in the thread');
      // The server derives threadRootId — clients must not send it.
      expect(body.containsKey('threadRootId'), isFalse);
      final events = body['events'] as Map<String, dynamic>;
      expect(events['updateUnreadCount'], isTrue);
      expect(events['sendPushNotification'], isTrue);
    });

    test('"also send to channel" sends showInConversation: true', () async {
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(const {'messageId': 'server-reply'}),
      );
      await send(showInConversation: true);
      final body = api.requestsForPath('/chat/message', method: 'POST').last.json
          as Map<String, dynamic>;
      expect(body['showInConversation'], isTrue);
    });

    test('a nested reply keeps the parent it was written against', () async {
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(const {'messageId': 'server-reply'}),
      );
      await send(showInConversation: false, parentMessageId: 'reply-7');
      final body = api.requestsForPath('/chat/message', method: 'POST').last.json
          as Map<String, dynamic>;
      expect(body['parentMessageId'], 'reply-7');
    });

    test('surfaces a rejected parent (404 errorCode 1) to the caller',
        () async {
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(
          const {'errorCode': 1, 'error': 'Parent message not found.'},
          status: 404,
        ),
      );
      final result = await send(showInConversation: false);
      expect(result, isNotNull);
      expect(result!.messageId, isEmpty);
      expect(result.response.hasError, isTrue);
      expect(result.response.applicationErrorCode, 1);
      expect(
        result.response.apiErrorMessage(),
        'Parent message not found.',
      );
    });

    test('returns null when the transport throws', () async {
      api.throwOn('POST', '/chat/message', Exception('offline'));
      expect(await send(showInConversation: false), isNull);
    });

    test('an encrypted reply never sends ciphertext as the push body',
        () async {
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(const {'messageId': 'server-reply'}),
      );
      await repo.sendThreadReply(
        conversationId: kDirectConversationId,
        parentMessageId: 'root-1',
        body: 'cipher-text',
        showInConversation: false,
        deviceId: 'device-1',
        customType: IsmChatCustomMessageType.text.name,
        notificationBody: 'cipher-text',
        notificationTitle: kMeName,
        encrypted: true,
        metaData: IsmChatMetaData(messageSentAt: 1234),
        searchableTags: const ['plain words'],
      );

      final body = api.requestsForPath('/chat/message', method: 'POST').last.json
          as Map<String, dynamic>;
      expect(body['encrypted'], isTrue);
      expect(body['notificationBody'], isNot('cipher-text'));
      expect(body['searchableTags'], ['plain words']);
      expect((body['metaData'] as Map)['messageSentAt'], 1234);
    });
  });

  group('IsmChatPageRepository.getChatMessages (threading params)', () {
    late FakeChatApi api;
    late IsmChatPageRepository repo;

    setUp(() {
      api = FakeChatApi()
        ..on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      repo = IsmChatPageRepository(apiWrapper: api.wrapper());
    });

    test('sends no threading params when none are passed (legacy URL)',
        () async {
      await repo.getChatMessages(conversationId: kDirectConversationId);
      final query = api.requestsTo('/chat/messages').last.url.queryParameters;
      expect(query.containsKey('feedType'), isFalse);
      expect(query.containsKey('threadRootId'), isFalse);
      expect(query['conversationId'], kDirectConversationId);
    });

    test('feedType=main keeps thread-only replies out of the timeline',
        () async {
      await repo.getChatMessages(
        conversationId: kDirectConversationId,
        feedType: IsmChatFeedType.main,
        lastMessageTimestamp: 1234,
      );
      final query = api.requestsTo('/chat/messages').last.url.queryParameters;
      expect(query['feedType'], 'main');
      expect(query['lastMessageTimestamp'], '1234');
    });

    test('threading params also apply to the search URL', () async {
      await repo.getChatMessages(
        conversationId: kDirectConversationId,
        searchText: 'hello',
        feedType: IsmChatFeedType.main,
      );
      final query = api.requestsTo('/chat/messages').last.url.queryParameters;
      expect(query['searchTag'], 'hello');
      expect(query['feedType'], 'main');
    });

    test('threadRootId can be combined with feedType=thread', () async {
      await repo.getChatMessages(
        conversationId: kDirectConversationId,
        feedType: IsmChatFeedType.thread,
        threadRootId: ' root-1 ',
      );
      final query = api.requestsTo('/chat/messages').last.url.queryParameters;
      expect(query['feedType'], 'thread');
      expect(query['threadRootId'], 'root-1');
    });
  });
}
