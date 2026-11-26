import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

/// `messagesDeleteForAll` must reach every device for the same account.
///
/// Reuses [kProjectConfig.deviceId] (`device-1`) as the local device under test.
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

  Map<String, dynamic> deleteForAllPayload({
    required String messageId,
    required String userId,
    String? deviceId,
    List<String>? messageIds,
  }) =>
      {
        'action': IsmChatActionEvents.messagesDeleteForAll.name,
        'conversationId': kDirectConversationId,
        if (messageIds != null) 'messageIds': messageIds,
        if (messageIds == null) 'messageId': messageId,
        'userId': userId,
        'userName': userId == kMeId ? kMeName : kOpponentName,
        if (deviceId != null) 'deviceId': deviceId,
        'sentAt': 3000,
      };

  IsmChatMessageModel? messageById(
    IsmChatConversationModel? conversation,
    String messageId,
  ) {
    final messages = conversation?.messages;
    if (messages == null) return null;
    for (final entry in messages.entries) {
      if (entry.value.messageId == messageId) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> seedConversation({required String messageId}) async {
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(
            messageId: messageId,
            body: 'delete me',
            sentByMe: true,
          ),
        },
      ),
    );
  }

  test(
      'same account on another device applies delete-for-everyone over MQTT',
      () async {
    const messageId = 'msg-multi-delete';
    await seedConversation(messageId: messageId);

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: deleteForAllPayload(
          messageId: messageId,
          userId: kMeId,
          deviceId: _remoteDeviceId,
          messageIds: [messageId],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    final stored = messageById(conversation, messageId);
    expect(stored, isNotNull);
    expect(
      stored!.customType,
      IsmChatCustomMessageType.deletedForEveryone,
    );
  });

  test('delete-for-everyone from this device is skipped when deviceId matches',
      () async {
    const messageId = 'msg-local-echo';
    await seedConversation(messageId: messageId);

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: deleteForAllPayload(
          messageId: messageId,
          userId: kMeId,
          deviceId: _localDeviceId,
          messageIds: [messageId],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    final stored = messageById(conversation, messageId);
    expect(stored!.customType, IsmChatCustomMessageType.text);
  });

  test('opponent delete-for-everyone still applies', () async {
    const messageId = 'msg-opponent-delete';
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(
            messageId: messageId,
            body: 'opponent msg',
            sentByMe: false,
          ),
        },
      ),
    );

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: deleteForAllPayload(
          messageId: messageId,
          userId: kOpponentId,
          messageIds: [messageId],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    final stored = messageById(conversation, messageId);
    expect(
      stored!.customType,
      IsmChatCustomMessageType.deletedForEveryone,
    );
  });

  test('single messageId without messageIds array still applies', () async {
    const messageId = 'msg-single-id';
    await seedConversation(messageId: messageId);

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: deleteForAllPayload(
          messageId: messageId,
          userId: kMeId,
          deviceId: _remoteDeviceId,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final conversation = await db.getConversation(kDirectConversationId);
    final stored = messageById(conversation, messageId);
    expect(
      stored!.customType,
      IsmChatCustomMessageType.deletedForEveryone,
    );
  });
}