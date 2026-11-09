import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// Send rejection paths for [IsmChatCommonViewModel] (profanity, quota, etc.).
void main() {
  setUp(() => configureChatSdk(useDatabase: true));
  tearDown(resetChatSdk);

  test('sendMessage HTTP 403 profanity keeps failed state and completes send',
      () async {
    final db = await openTestDatabase();
    await db.saveConversation(conversation: directConversation());
    final pending = message(sentAt: 99, body: 'bad word')..messageId = '';
    await db.saveMessage(pending, IsmChatDbBox.pending);

    final api = FakeChatApi()..registerSendDefaults();
    api.on(
      'POST',
      '/chat/message',
      FakeResponse.json(
        const {
          'error': 'Dropping message due to- Profanity words ',
          'errorCode': 3,
        },
        status: 403,
      ),
    );
    final vm = IsmChatCommonViewModel(
      IsmChatCommonRepository(apiWrapper: api.wrapper()),
    );

    final sent = await vm.sendMessage(
      showInConversation: true,
      messageType: 0,
      encrypted: false,
      deviceId: 'device-1',
      conversationId: kDirectConversationId,
      body: pending.body,
      createdAt: 99,
      notificationBody: pending.body,
      notificationTitle: kMeName,
      customType: IsmChatCustomMessageType.text.value,
    );

    expect(sent, isTrue);
    final stored = await db.getConversation(kDirectConversationId);
    final failed = stored?.messages?['99'];
    expect(failed?.isInvalidMessage, isTrue);
    expect(failed?.messageId, isEmpty);
  });
}
