import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

void main() {
  chatTestWidgets('incoming chatMessageSent is queued onto the open chat',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    ctx.page.conversation = directConversation();
    ctx.page.currentUser = me();

    final mqtt = Get.put(
      IsmChatMqttController(
        IsmChatMqttViewModel(IsmChatMqttRepository(apiWrapper: ctx.api.wrapper())),
      ),
    );

    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'msg',
        payload: {
          ...messageJson(
            messageId: 'live-1',
            body: 'from mqtt',
            senderId: kOpponentId,
          ),
          'action': 'chatMessageSent',
        },
      ),
    );
    await pumpUntil(
      tester,
      () => ctx.page.messages.any((m) => m.messageId == 'live-1'),
    );
    expect(ctx.page.messages.any((m) => m.body == 'from mqtt'), isTrue);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('typing and read actions are accepted without throwing',
      (tester, ctx) async {
    ctx.page.conversation = directConversation();
    final mqtt = Get.put(
      IsmChatMqttController(
        IsmChatMqttViewModel(IsmChatMqttRepository(apiWrapper: ctx.api.wrapper())),
      ),
    );
    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'act',
        payload: {
          'action': IsmChatActionEvents.typingEvent.name,
          'conversationId': kDirectConversationId,
          'userId': kOpponentId,
          'userName': kOpponentName,
          'sentAt': 1,
        },
      ),
    );
    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'act',
        payload: {
          'action': IsmChatActionEvents.messageRead.name,
          'conversationId': kDirectConversationId,
          'messageId': 'm1',
          'userId': kOpponentId,
          'sentAt': 2,
        },
      ),
    );
    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'act',
        payload: {
          'action': 'membersAdd',
          'conversationId': kGroupConversationId,
          'memberId': 'user-new',
          'memberName': 'New',
          'sentAt': 3,
        },
      ),
    );
    mqtt.onMqttEvent(
      event: EventModel(
        topic: 'act',
        payload: {
          'action': IsmChatActionEvents.meetingCreated.name,
          'conversationId': kDirectConversationId,
          'meetingId': 'meet-1',
          'sentAt': 4,
        },
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(mqtt, isNotNull);
  }, setUpApi: (api) => api.registerSendDefaults());

  test('EventModel round-trip', () {
    final event = EventModel(topic: 't', payload: {'a': 1});
    expect(EventModel.fromJson(event.toJson()).topic, 't');
    expect(event.copyWith(topic: 'x').topic, 'x');
    expect(event == event, isTrue);
  });
}
