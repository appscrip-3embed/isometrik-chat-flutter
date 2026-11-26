import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import 'helpers/fixtures.dart';
import 'helpers/test_bootstrap.dart';

void main() {
  tearDown(resetChatSdk);

  test('keepHistory persists leave row and removes current user from members',
      () async {
    configureChatSdk();
    final db = await openTestDatabase();
  final conv = groupConversation();
    await db.saveConversation(conversation: conv);

    await IsmChatLeaveGroupCoordinator.applyPostLeaveLocalState(
      conversationId: kGroupConversationId,
      mode: IsmChatLeaveGroupMode.keepHistory,
    );

    final saved = await db.getConversation(kGroupConversationId);
    expect(saved, isNotNull);
    expect(
      saved!.members?.any((m) => m.userId == kMeId),
      isFalse,
    );
    expect(
      saved.messages?.values.any(
        (m) => m.customType == IsmChatCustomMessageType.memberLeave,
      ),
      isTrue,
    );
    expect(
      saved.lastMessageDetails?.customType,
      IsmChatCustomMessageType.memberLeave,
    );
  });

  test('deleteForMe removes conversation from local database', () async {
    configureChatSdk();
    final db = await openTestDatabase();
    await db.saveConversation(conversation: groupConversation());

    await IsmChatLeaveGroupCoordinator.applyPostLeaveLocalState(
      conversationId: kGroupConversationId,
      mode: IsmChatLeaveGroupMode.deleteForMe,
    );

    final saved = await db.getConversation(kGroupConversationId);
    expect(saved, isNull);
  });
}