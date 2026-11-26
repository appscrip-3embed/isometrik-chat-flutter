import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

const _localDeviceId = 'device-1';
const _remoteDeviceId = 'device-2';
const _messageId = 'msg-reaction';
const _emoji = 'U+1F44D';

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

  Map<String, dynamic> reactionPayload({
    required String action,
    String? deviceId,
  }) =>
      {
        'action': action,
        'conversationId': kDirectConversationId,
        'messageId': _messageId,
        'reactionType': _emoji,
        'userId': kMeId,
        'userName': kMeName,
        if (deviceId != null) 'deviceId': deviceId,
        'sentAt': 3000,
      };

  Future<IsmChatMessageModel?> storedMessage() async {
    final conversation = await db.getConversation(kDirectConversationId);
    final messages = conversation?.messages;
    if (messages == null) return null;
    for (final entry in messages.entries) {
      if (entry.value.messageId == _messageId) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> seedMessage() async {
    await db.saveConversation(
      conversation: directConversation(
        messages: {
          '1000': message(messageId: _messageId, body: 'react me'),
        },
      ),
    );
  }

  test('same account on another device applies reactionAdd', () async {
    await seedMessage();

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: reactionPayload(
          action: IsmChatActionEvents.reactionAdd.name,
          deviceId: _remoteDeviceId,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final stored = await storedMessage();
    expect(stored, isNotNull);
    final bucket = stored!.reactions?.cast<MessageReactionModel?>().firstWhere(
          (r) => r?.emojiKey == _emoji,
          orElse: () => null,
        );
    expect(bucket, isNotNull);
    expect(bucket!.userIds, contains(kMeId));
  });

  test('reactionAdd from this device skipped when deviceId matches', () async {
    await seedMessage();

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: reactionPayload(
          action: IsmChatActionEvents.reactionAdd.name,
          deviceId: _localDeviceId,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final stored = await storedMessage();
    expect(stored?.reactions, anyOf(isNull, isEmpty));
  });

  test('opponent reactionAdd still applies', () async {
    await seedMessage();

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'status',
        payload: {
          ...reactionPayload(action: IsmChatActionEvents.reactionAdd.name),
          'userId': kOpponentId,
          'userName': kOpponentName,
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final stored = await storedMessage();
    final bucket = stored!.reactions?.firstWhere((r) => r.emojiKey == _emoji);
    expect(bucket?.userIds, contains(kOpponentId));
  });
}