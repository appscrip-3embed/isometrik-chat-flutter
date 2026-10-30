import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  late FakeChatApi api;
  late IsmChatPageRepository repo;

  setUp(() {
    configureChatSdk();
    api = FakeChatApi();
    repo = IsmChatPageRepository(apiWrapper: api.wrapper());
  });
  tearDown(resetChatSdk);

  const conv = kDirectConversationId;

  group('getChatMessages', () {
    test('parses messages and builds timestamp / search urls', () async {
      api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [messageJson(), messageJson(messageId: 'm2', sentAt: 6)],
        }),
      );
      final list = await repo.getChatMessages(conversationId: conv, limit: 10);
      expect(list, hasLength(2));
      expect(api.requests.single.url.toString(), contains('conversationId=$conv'));
      expect(api.requests.single.url.toString(), isNot(contains('lastMessageTimestamp')));

      await repo.getChatMessages(
        conversationId: conv,
        lastMessageTimestamp: 9,
        searchText: 'hello',
        skip: 5,
      );
      expect(api.requests.last.url.toString(), contains('searchTag=hello'));
      expect(api.requests.last.url.toString(), contains('skip=5'));
    });

    test('returns null on error and on exception', () async {
      api.on('GET', '/chat/messages', const FakeResponse('{}', status: 500));
      expect(await repo.getChatMessages(conversationId: conv), isNull);
      api.throwOn('GET', '/chat/messages', Exception('net'));
      expect(await repo.getChatMessages(conversationId: conv), isNull);
    });
  });

  group('getBroadcastMessages', () {
    test('parses messages with and without search', () async {
      api.on(
        'GET',
        '/groupcast/messages',
        FakeResponse.json({
          'messages': [messageJson()],
        }),
      );
      expect(
        await repo.getBroadcastMessages(
          groupcastId: 'g1',
          hideNewConversationsForSender: false,
          sendPushForNewConversationCreated: true,
          notifyOnCompletion: true,
          executionFinished: false,
        ),
        hasLength(1),
      );
      await repo.getBroadcastMessages(
        groupcastId: 'g1',
        hideNewConversationsForSender: false,
        sendPushForNewConversationCreated: true,
        notifyOnCompletion: true,
        executionFinished: false,
        searchText: 'q',
        lastMessageTimestamp: 3,
      );
      expect(api.requests.last.url.toString(), contains('searchTag=q'));
    });

    test('error and exception return null', () async {
      api.on('GET', '/groupcast/messages', const FakeResponse('{}', status: 400));
      expect(
        await repo.getBroadcastMessages(
          groupcastId: 'g',
          hideNewConversationsForSender: false,
          sendPushForNewConversationCreated: true,
          notifyOnCompletion: true,
          executionFinished: false,
        ),
        isNull,
      );
      api.throwOn('GET', '/groupcast/messages', const SocketException('x'));
      expect(
        await repo.getBroadcastMessages(
          groupcastId: 'g',
          hideNewConversationsForSender: false,
          sendPushForNewConversationCreated: true,
          notifyOnCompletion: true,
          executionFinished: false,
        ),
        isNull,
      );
    });
  });

  test('changeGroupTitle / changeGroupProfile success, error, exception',
      () async {
    api.on('PATCH', '/title', FakeResponse.json({'ok': true}));
    api.on('PATCH', '/image', FakeResponse.json({'ok': true}));
    expect(
      await repo.changeGroupTitle(
          conversationTitle: 'N', conversationId: conv, isLoading: false),
      isNotNull,
    );
    expect(api.requestsTo('/title').single.json['conversationTitle'], 'N');
    expect(
      await repo.changeGroupProfile(
          conversationImageUrl: 'u', conversationId: conv, isLoading: false),
      isNotNull,
    );

    api.on('PATCH', '/title', const FakeResponse('{}', status: 400));
    expect(
      await repo.changeGroupTitle(
          conversationTitle: 'N', conversationId: conv, isLoading: false),
      isNull,
    );
    api.throwOn('PATCH', '/title', Exception('x'));
    expect(
      await repo.changeGroupTitle(
          conversationTitle: 'N', conversationId: conv, isLoading: false),
      isNull,
    );
    api.throwOn('PATCH', '/image', Exception('x'));
    expect(
      await repo.changeGroupProfile(
          conversationImageUrl: 'u', conversationId: conv, isLoading: false),
      isNull,
    );
  });

  test('readMessage and notifyTyping hit indicator endpoints', () async {
    api.on('PUT', '/indicator/read', FakeResponse.json({'ok': true}));
    api.on('POST', '/indicator/typing', FakeResponse.json({'ok': true}));
    await repo.readMessage(conversationId: conv, messageId: 'm1');
    await repo.notifyTyping(conversationId: conv);
    expect(api.requestsTo('/indicator/read'), hasLength(1));
    expect(api.requestsTo('/indicator/typing').single.json['conversationId'],
        conv);
    api.throwOn('PUT', '/indicator/read', Exception('x'));
    await repo.readMessage(conversationId: conv, messageId: 'm1');
    api.throwOn('POST', '/indicator/typing', Exception('x'));
    await repo.notifyTyping(conversationId: conv);
  });

  test('add / remove members, leave, make / remove admin', () async {
    api.on('PUT', '/members', FakeResponse.json({'ok': true}));
    api.on('DELETE', '/members', FakeResponse.json({'ok': true}));
    api.on('DELETE', '/leave', FakeResponse.json({'ok': true}));
    api.on('PUT', '/admin', FakeResponse.json({'ok': true}));
    api.on('DELETE', '/admin', FakeResponse.json({'ok': true}));

    expect(
      await repo.addMembers(memberList: ['u'], conversationId: conv),
      isNotNull,
    );
    expect(await repo.removeMembers(conv, 'u', false), isNotNull);
    expect(await repo.leaveConversation(conv, false), isNotNull);
    expect(await repo.makeAdmin('u', conv, false), isNotNull);
    expect(await repo.removeAdmin(conv, 'u', false), isNotNull);

    api.on('PUT', '/members', const FakeResponse('{}', status: 400));
    expect(
      await repo.addMembers(memberList: ['u'], conversationId: conv),
      isNull,
    );
    api.throwOn('PUT', '/members', Exception('x'));
    expect(
      await repo.addMembers(memberList: ['u'], conversationId: conv),
      isNull,
    );
    api.throwOn('DELETE', '/members', Exception('x'));
    expect(await repo.removeMembers(conv, 'u', false), isNull);
    api.throwOn('DELETE', '/leave', Exception('x'));
    expect(await repo.leaveConversation(conv, false), isNull);
    api.throwOn('PUT', '/admin', Exception('x'));
    expect(await repo.makeAdmin('u', conv, false), isNull);
    api.throwOn('DELETE', '/admin', Exception('x'));
    expect(await repo.removeAdmin(conv, 'u', false), isNull);
  });

  test('getEligibleMembers with and without search', () async {
    api.on(
      'GET',
      '/eligible/members',
      FakeResponse.json({
        'conversationEligibleMembers': [
          {
            'userId': 'u',
            'userName': 'U',
            'userIdentifier': 'u@t',
            'userProfileImageUrl': '',
          }
        ]
      }),
    );
    expect(
      await repo.getEligibleMembers(conversationId: conv),
      hasLength(1),
    );
    await repo.getEligibleMembers(conversationId: conv, searchTag: 'al');
    expect(api.requests.last.url.toString(), contains('searchTag=al'));
    api.on('GET', '/eligible/members', const FakeResponse('{}', status: 400));
    expect(await repo.getEligibleMembers(conversationId: conv), isNull);
    api.throwOn('GET', '/eligible/members', Exception('x'));
    expect(await repo.getEligibleMembers(conversationId: conv), isNull);
  });

  test('getConverstaionDetails success, error, exception', () async {
    api.on(
      'GET',
      '/details/',
      FakeResponse.json({
        'conversationDetails': conversationJson(),
      }),
    );
    var wrap = await repo.getConverstaionDetails(
      conversationId: conv,
      includeMembers: true,
    );
    expect(wrap.data, isA<IsmChatConversationModel>());
    expect(wrap.statusCode, 200);
    wrap = await repo.getConverstaionDetails(conversationId: conv);
    expect(api.requests.last.url.toString(), isNot(contains('includeMembers')));

    api.on('GET', '/details/', const FakeResponse('{}', status: 404));
    wrap = await repo.getConverstaionDetails(conversationId: conv);
    expect(wrap.data, isNull);
    expect(wrap.statusCode, 404);

    api.throwOn('GET', '/details/', Exception('x'));
    wrap = await repo.getConverstaionDetails(conversationId: conv);
    expect(wrap.statusCode, 1000);
  });

  test('blockUser, delete, clear, readAll', () async {
    api.on('POST', '/block', FakeResponse.json({'ok': true}));
    api.on('DELETE', '/self', FakeResponse.json({'ok': true}));
    api.on('DELETE', '/everyone', FakeResponse.json({'ok': true}));
    api.on('DELETE', '/clear', FakeResponse.json({'ok': true}));
    api.on('PUT', '/messages/read', FakeResponse.json({'ok': true}));

    expect(await repo.blockUser(opponentId: kOpponentId), isNotNull);
    expect(
      await repo.deleteMessageForMe(conversationId: conv, messageIds: 'm1'),
      isNotNull,
    );
    expect(
      await repo.deleteMessageForEveryone(conversationId: conv, messages: 'm1'),
      isNotNull,
    );
    expect(await repo.clearAllMessages(conversationId: conv), isNotNull);
    await repo.readAllMessages(conversationId: conv, timestamp: 1);

    api.on('POST', '/block', const FakeResponse('{}', status: 400));
    expect(await repo.blockUser(opponentId: kOpponentId), isNull);
    api.throwOn('POST', '/block', Exception('x'));
    expect(await repo.blockUser(opponentId: kOpponentId), isNull);
    api.throwOn('DELETE', '/self', Exception('x'));
    expect(
      await repo.deleteMessageForMe(conversationId: conv, messageIds: 'm1'),
      isNull,
    );
    api.throwOn('DELETE', '/everyone', Exception('x'));
    expect(
      await repo.deleteMessageForEveryone(conversationId: conv, messages: 'm1'),
      isNull,
    );
    api.throwOn('DELETE', '/clear', Exception('x'));
    expect(await repo.clearAllMessages(conversationId: conv), isNull);
    api.throwOn('PUT', '/messages/read', Exception('x'));
    await repo.readAllMessages(conversationId: conv, timestamp: 1);
  });

  test('deliver / read time, reactions, updateMessage, status', () async {
    final users = {
      'users': [
        {
          'userId': kOpponentId,
          'userName': kOpponentName,
          'userIdentifier': 'x',
          'userProfileImageUrl': '',
        }
      ]
    };
    api.on('GET', '/delivery', FakeResponse.json(users));
    api.on('GET', '/status/read', FakeResponse.json(users));
    api.on('GET', '/status/read', FakeResponse.json({'users': null}));
    expect(
      await repo.getMessageDeliverTime(conversationId: conv, messageId: 'm'),
      hasLength(1),
    );
    api.on('GET', '/status/read', FakeResponse.json(users));
    expect(
      await repo.getMessageReadTime(conversationId: conv, messageId: 'm'),
      hasLength(1),
    );
    api.on('GET', '/delivery', FakeResponse.json({'users': null}));
    expect(
      await repo.getMessageDeliverTime(conversationId: conv, messageId: 'm'),
      isNull,
    );

    final reaction = Reaction(
      reactionType: IsmChatEmoji.yes,
      messageId: 'm',
      conversationId: conv,
    );
    api.on('POST', '/reaction', FakeResponse.json({'ok': true}));
    api.on('DELETE', '/reaction', FakeResponse.json({'ok': true}));
    api.on(
      'GET',
      '/reaction',
      FakeResponse.json({
        'reactions': [
          {
            'userId': kOpponentId,
            'userName': kOpponentName,
            'userIdentifier': 'x',
            'userProfileImageUrl': '',
          }
        ]
      }),
    );
    expect(await repo.addReacton(reaction: reaction), isNotNull);
    expect(await repo.deleteReacton(reaction: reaction), isNotNull);
    expect(await repo.getReacton(reaction: reaction), hasLength(1));

    api.on('PATCH', '/message', FakeResponse.json({'ok': true}));
    expect(
      await repo.updateMessage(
        metaData: {'k': 'v'},
        messageId: 'm',
        conversationId: conv,
        isLoading: false,
      ),
      isTrue,
    );
    api.on(
      'GET',
      '/messages/status',
      FakeResponse.json({
        'messages': [
          {'messageId': 'm', 'deliveredToAll': true, 'readByAll': false}
        ]
      }),
    );
    expect(
      await repo.getMessageForStatus(
        conversationId: conv,
        messageIds: ['m'],
        isLoading: false,
      ),
      hasLength(1),
    );

    api.throwOn('GET', '/delivery', Exception('x'));
    expect(
      await repo.getMessageDeliverTime(conversationId: conv, messageId: 'm'),
      isNull,
    );
    api.throwOn('GET', '/status/read', Exception('x'));
    expect(
      await repo.getMessageReadTime(conversationId: conv, messageId: 'm'),
      isNull,
    );
    api.throwOn('POST', '/reaction', Exception('x'));
    expect(await repo.addReacton(reaction: reaction), isNull);
    api.throwOn('DELETE', '/reaction', Exception('x'));
    expect(await repo.deleteReacton(reaction: reaction), isNull);
    api.throwOn('GET', '/reaction', Exception('x'));
    expect(await repo.getReacton(reaction: reaction), isNull);
    api.throwOn('PATCH', '/message', Exception('x'));
    expect(
      await repo.updateMessage(
        metaData: {},
        messageId: 'm',
        conversationId: conv,
        isLoading: false,
      ),
      isFalse,
    );
    api.throwOn('GET', '/messages/status', Exception('x'));
    expect(
      await repo.getMessageForStatus(
        conversationId: conv,
        messageIds: ['m'],
        isLoading: false,
      ),
      isNull,
    );
  });

  test('getLocation success, error, exception', () async {
    api.on(
      'GET',
      'maps.googleapis.com',
      FakeResponse.json({
        'results': [
          {
            'name': 'Office',
            'placeId': 'p1',
            'geometry': {
              'location': {'lat': 12.0, 'lng': 77.0},
            },
            'vicinity': 'BLR',
          }
        ]
      }),
    );
    expect(
      await repo.getLocation(latitude: '12.0', longitude: '77.0', query: ''),
      hasLength(1),
    );
    await repo.getLocation(latitude: '12.0', longitude: '77.0', query: 'cafe');
    expect(api.requests.last.url.toString(), contains('name=cafe'));
    api.on('GET', 'maps.googleapis.com', const FakeResponse('{}', status: 400));
    expect(
      await repo.getLocation(latitude: '12', longitude: '77', query: ''),
      isNull,
    );
    api.throwOn('GET', 'maps.googleapis.com', Exception('x'));
    expect(
      await repo.getLocation(latitude: '12', longitude: '77', query: ''),
      isNull,
    );
  });

  test('sendBroadcastMessage and createBroadcastConversation', () async {
    api.on('POST', '/groupcast/message', FakeResponse.json({'ok': true}));
    api.on('POST', '/chat/groupcast', FakeResponse.json({'groupcastId': 'g1'}));
    expect(
      await repo.sendBroadcastMessage(
        showInConversation: true,
        sendPushForNewConversationCreated: true,
        notifyOnCompletion: true,
        hideNewConversationsForSender: false,
        groupcastId: 'g1',
        messageType: 0,
        encrypted: false,
        deviceId: 'd',
        body: 'hi',
        notificationBody: 'hi',
        notificationTitle: 't',
        mentionedUsers: [
          {'userId': kOpponentId}
        ],
      ),
      isNotNull,
    );
    expect(api.requestsTo('/groupcast/message').single.json['mentionedUsers'],
        isNotEmpty);
    expect(
      await repo.createBroadcastConversation(
        groupcastTitle: 't',
        groupcastImageUrl: 'u',
        membersId: [kOpponentId],
      ),
      'g1',
    );

    api.on('POST', '/groupcast/message', const FakeResponse('{}', status: 400));
    expect(
      await repo.sendBroadcastMessage(
        showInConversation: true,
        sendPushForNewConversationCreated: true,
        notifyOnCompletion: true,
        hideNewConversationsForSender: false,
        groupcastId: 'g1',
        messageType: 0,
        encrypted: true,
        deviceId: 'd',
        body: 'hi',
        notificationBody: 'hi',
        notificationTitle: 't',
      ),
      isNull,
    );
    api.throwOn('POST', '/groupcast/message', Exception('x'));
    expect(
      await repo.sendBroadcastMessage(
        showInConversation: true,
        sendPushForNewConversationCreated: true,
        notifyOnCompletion: true,
        hideNewConversationsForSender: false,
        groupcastId: 'g1',
        messageType: 0,
        encrypted: false,
        deviceId: 'd',
        body: 'hi',
        notificationBody: 'hi',
        notificationTitle: 't',
      ),
      isNull,
    );
    api.throwOn('POST', '/chat/groupcast', Exception('x'));
    expect(
      await repo.createBroadcastConversation(
        groupcastTitle: 't',
        groupcastImageUrl: 'u',
        membersId: [],
      ),
      isNull,
    );
  });
}
