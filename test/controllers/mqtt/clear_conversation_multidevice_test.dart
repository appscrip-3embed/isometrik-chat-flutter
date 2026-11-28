import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

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

  Map<String, dynamic> clearConversationPayload({String? deviceId}) => {
        'action': IsmChatActionEvents.clearConversation.name,
        'conversationId': kDirectConversationId,
        'userId': kMeId,
        if (deviceId != null) 'deviceId': deviceId,
        'sentAt': 3000,
      };

  Future<void> seedConversationWithMessages() async {
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(body: 'one'),
          '2000': message(messageId: 'm2', sentAt: 2000, body: 'two'),
        },
      ).copyWith(
        lastMessageDetails: LastMessageDetails(
          showInConversation: true,
          sentAt: 2000,
          senderName: kMeName,
          messageType: 0,
          messageId: 'm2',
          conversationId: kDirectConversationId,
          body: 'two',
          sentByMe: true,
        ),
        lastMessageSentAt: 2000,
      ),
    );
  }

  test('clearConversation on another device empties local messages', () async {
    await seedConversationWithMessages();

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: clearConversationPayload(deviceId: _remoteDeviceId),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    expect(conversation?.messages, isEmpty);
    expect(conversation?.lastMessageDetails?.body, isEmpty);
    expect(conversation?.lastMessageDetails?.sentAt, 2000);
    expect(conversation?.lastMessageSentAt, 2000);
  });

  test('clearConversation skipped on same device when deviceId matches',
      () async {
    await seedConversationWithMessages();

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: clearConversationPayload(deviceId: _localDeviceId),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    expect(conversation?.messages, isNotEmpty);
  });

  test('clearConversation from another user is ignored', () async {
    await seedConversationWithMessages();

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: {
          ...clearConversationPayload(deviceId: _remoteDeviceId),
          'userId': kOpponentId,
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    expect(conversation?.messages, isNotEmpty);
  });
}