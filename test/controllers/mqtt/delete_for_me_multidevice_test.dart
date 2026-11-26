import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

/// `messagesDeleteLocal` (delete for me) on the Status topic.
const _localDeviceId = 'device-1';
const _remoteDeviceId = 'device-2';

void main() {
  late IsmChatDBWrapper db;
  late IsmChatMqttController mqtt;

  setUp(() async {
    configureChatSdk(useDatabase: false);
    db = await openTestDatabase();
    final api = FakeChatApi();
    mqtt = Get.put(
      IsmChatMqttController(
        IsmChatMqttViewModel(
          IsmChatMqttRepository(apiWrapper: api.wrapper()),
        ),
      ),
    );
    mqtt.userConfig = IsmChatConfig.communicationConfig?.userConfig;
    mqtt.projectConfig = IsmChatConfig.communicationConfig?.projectConfig;
  });

  tearDown(() async {
    await resetChatSdk();
  });

  Map<String, dynamic> deleteLocalPayload({
    required String messageId,
    List<String>? messageIds,
    String? deviceId,
  }) =>
      {
        'action': IsmChatActionEvents.messagesDeleteLocal.name,
        'conversationId': kDirectConversationId,
        if (messageIds != null) 'messageIds': messageIds,
        if (messageIds == null) 'messageId': messageId,
        'userId': kMeId,
        'userName': kMeName,
        if (deviceId != null) 'deviceId': deviceId,
        'sentAt': 3000,
        'privateOneToOne': true,
      };

  test('same account on another device removes message after delete for me',
      () async {
    const messageId = '6b07f0602552cb00019b771a';
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(messageId: messageId, body: 'gone'),
          '2000': message(
            messageId: 'msg-keep',
            body: 'stay',
            sentAt: 2000,
          ),
        },
      ),
    );

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: deleteLocalPayload(
          messageId: messageId,
          messageIds: [messageId],
          deviceId: _remoteDeviceId,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    final messages = conversation?.messages;
    expect(messages, isNotNull);
  expect(messages!.values.any((m) => m.messageId == messageId), isFalse);
    expect(messages.values.any((m) => m.messageId == 'msg-keep'), isTrue);
  });

  test('delete for me from this device is skipped when deviceId matches',
      () async {
    const messageId = 'msg-local-delete-me';
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(messageId: messageId),
        },
      ),
    );

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: deleteLocalPayload(
          messageId: messageId,
          messageIds: [messageId],
          deviceId: _localDeviceId,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    expect(
      conversation?.messages?.values.any((m) => m.messageId == messageId),
      isTrue,
    );
  });

  test('delete for me from another user is ignored', () async {
    const messageId = 'msg-other-user';
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(messageId: messageId, sentByMe: false),
        },
      ),
    );

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: {
          ...deleteLocalPayload(
            messageId: messageId,
            messageIds: [messageId],
            deviceId: _remoteDeviceId,
          ),
          'userId': kOpponentId,
          'userName': kOpponentName,
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    expect(
      conversation?.messages?.values.any((m) => m.messageId == messageId),
      isTrue,
    );
  });
}