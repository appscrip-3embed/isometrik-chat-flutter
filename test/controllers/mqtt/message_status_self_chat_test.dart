import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

/// MQTT deliver/read when [userId] is the logged-in user.
///
/// Self-chat acks must update ticks; normal 1:1 must still ignore those events.
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
    // Match production: [isSenderMe] reads [IsmChatMqttController.userConfig].
    mqtt.userConfig = IsmChatConfig.communicationConfig?.userConfig;
    mqtt.projectConfig = IsmChatConfig.communicationConfig?.projectConfig;
  });

  tearDown(() async {
    await resetChatSdk();
  });

  Map<String, dynamic> statusPayload({
    required String conversationId,
    required String messageId,
    required String action,
    String userId = kMeId,
    int sentAt = 2000,
  }) =>
      {
        'action': action,
        'conversationId': conversationId,
        'messageId': messageId,
        'userId': userId,
        'userName': kMeName,
        'sentAt': sentAt,
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

  test('self chat applies messageDelivered and messageRead from current user',
      () async {
    const messageId = 'msg-self-status';
    await db.saveConversation(
      conversation: selfChatConversation(
        messages: {
          '1000': message(
            conversationId: kSelfChatConversationId,
            messageId: messageId,
            sentByMe: true,
          ),
        },
      ),
    );

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: statusPayload(
          conversationId: kSelfChatConversationId,
          messageId: messageId,
          action: IsmChatActionEvents.messageDelivered.name,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));

    var conversation = await db.getConversation(kSelfChatConversationId);
    var stored = messageById(conversation, messageId);
    expect(stored, isNotNull);
    expect(stored!.deliveredToAll, isTrue);

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: statusPayload(
          conversationId: kSelfChatConversationId,
          messageId: messageId,
          action: IsmChatActionEvents.messageRead.name,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));

    conversation = await db.getConversation(kSelfChatConversationId);
    stored = messageById(conversation, messageId);
    expect(stored!.readByAll, isTrue);
    expect(stored.deliveredToAll, isTrue);
  });

  test('direct 1:1 still ignores deliver/read MQTT from current user', () async {
    const messageId = 'msg-direct-status';
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(messageId: messageId, sentByMe: true),
        },
      ),
    );

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: statusPayload(
          conversationId: kDirectConversationId,
          messageId: messageId,
          action: IsmChatActionEvents.messageDelivered.name,
        ),
      ),
    );
    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: statusPayload(
          conversationId: kDirectConversationId,
          messageId: messageId,
          action: IsmChatActionEvents.messageRead.name,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final conversation = await db.getConversation(kDirectConversationId);
    final stored = messageById(conversation, messageId);
    expect(stored, isNotNull);
    expect(stored!.deliveredTo, isEmpty);
    expect(stored.readBy, isEmpty);
    expect(stored.deliveredToAll, isNot(true));
    expect(stored.readByAll, isNot(true));
  });
}