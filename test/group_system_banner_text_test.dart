import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import 'helpers/fixtures.dart';
import 'helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);

  test('leave banner uses You left for current user', () {
    final message = IsmChatMessageModel(
      body: '',
      customType: IsmChatCustomMessageType.memberLeave,
      sentAt: 1,
      sentByMe: true,
      userId: kMeId,
      userName: kMeName,
    );
    expect(message.groupMemberLeaveBannerText(), IsmChatStrings.youLeftTheGroup);
  });

  test('leave banner names other member', () {
    final message = IsmChatMessageModel(
      body: '',
      customType: IsmChatCustomMessageType.memberLeave,
      sentAt: 1,
      sentByMe: false,
      userId: kOpponentId,
      userName: kOpponentName,
    );
    expect(
      message.groupMemberLeaveBannerText(),
      IsmChatStrings.memberLeftTheGroup(kOpponentName),
    );
  });

  test('add member banner for added user', () {
    final message = IsmChatMessageModel(
      body: '',
      customType: IsmChatCustomMessageType.addMember,
      sentAt: 1,
      sentByMe: false,
      initiatorId: kOpponentId,
      initiatorName: kOpponentName,
      memberId: kMeId,
      memberName: kMeName,
    );
    expect(
      message.groupAddRemoveMemberBannerText(isAdded: true),
      IsmChatStrings.youWereAddedToGroupBy(kOpponentName),
    );
  });

  test('isCurrentUserRemovedFromGroup is false after voluntary leave preview',
      () {
    final conv = groupConversation().copyWith(
      lastMessageDetails: LastMessageDetails(
        showInConversation: true,
        sentAt: 1,
        senderName: kMeName,
        senderId: kMeId,
        messageType: 0,
        messageId: '',
        conversationId: kGroupConversationId,
        body: '',
        sentByMe: true,
        customType: IsmChatCustomMessageType.memberLeave,
        userId: kMeId,
      ),
    );
    expect(conv.isCurrentUserRemovedFromGroup, isFalse);
    expect(conv.isLastMessageCurrentUserRemovedFromGroup, isTrue);
  });

  test('isCurrentUserRemovedFromGroup is true when admin removed user', () {
    final conv = groupConversation().copyWith(
      lastMessageDetails: LastMessageDetails(
        showInConversation: true,
        sentAt: 1,
        senderName: kOpponentName,
        senderId: kOpponentId,
        messageType: 0,
        messageId: '',
        conversationId: kGroupConversationId,
        body: '',
        sentByMe: false,
        customType: IsmChatCustomMessageType.removeMember,
        userId: kMeId,
      ),
    );
    expect(conv.isCurrentUserRemovedFromGroup, isTrue);
  });

  test('add member banner for observer', () {
    final message = IsmChatMessageModel(
      body: '',
      customType: IsmChatCustomMessageType.addMember,
      sentAt: 1,
      sentByMe: true,
      initiatorId: kMeId,
      initiatorName: kMeName,
      memberId: kOpponentId,
      memberName: kOpponentName,
    );
    expect(
      message.groupAddRemoveMemberBannerText(isAdded: true),
      IsmChatStrings.addedMembersToGroup(
        initiator: 'You',
        members: kOpponentName,
      ),
    );
  });
}