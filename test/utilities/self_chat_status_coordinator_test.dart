import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatSelfChatStatusCoordinator.passesStaticGuards', () {
    test('rejects empty conversationId or messageId', () {
      expect(
        IsmChatSelfChatStatusCoordinator.passesStaticGuards(
          conversationId: '',
          messageId: 'm1',
        ),
        isFalse,
      );
      expect(
        IsmChatSelfChatStatusCoordinator.passesStaticGuards(
          conversationId: 'c1',
          messageId: '',
        ),
        isFalse,
      );
    });

    test('rejects when self chat feature is off', () {
      expect(
        IsmChatSelfChatStatusCoordinator.passesStaticGuards(
          conversationId: 'c1',
          messageId: 'm1',
          enableSelfChat: false,
        ),
        isFalse,
      );
    });

    test('rejects non-self conversation when model is provided', () {
      expect(
        IsmChatSelfChatStatusCoordinator.passesStaticGuards(
          conversationId: kDirectConversationId,
          messageId: 'm1',
          conversation: IsmChatConversationModel.fromMap(conversationJson()),
          enableSelfChat: true,
        ),
        isFalse,
      );
    });

    test('passes for self chat with ids and feature on', () {
      expect(
        IsmChatSelfChatStatusCoordinator.passesStaticGuards(
          conversationId: 'self-1',
          messageId: 'm1',
          conversation: IsmChatConversationModel.fromMap({
            'conversationId': 'self-1',
            'isGroup': false,
            'selfChat': true,
          }),
          enableSelfChat: true,
        ),
        isTrue,
      );
    });
  });

  test('acknowledgeAfterSend no-ops without MQTT controller', () async {
    IsmChatProperties.conversationProperties = IsmChatConversationProperties(
      enableSelfChat: true,
    );
    await IsmChatSelfChatStatusCoordinator.acknowledgeAfterSend(
      conversationId: 'self-1',
      messageId: 'm1',
      conversation: IsmChatConversationModel.selfChatPlaceholder()
          .copyWith(conversationId: 'self-1'),
    );
  });
}