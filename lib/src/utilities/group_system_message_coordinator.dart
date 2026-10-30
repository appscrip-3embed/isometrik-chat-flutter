import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Builds and persists centered group system rows (add/remove member, admin,
/// join/leave) from MQTT action payloads.
///
/// Reused by MQTT group operation handlers so actor and observers
/// see the same banner row in local DB before [IsmChatPageController.getMessagesFromDB].
///
/// See also: [IsmChatBlockUnblockCoordinator] for block/unblock banners.
class IsmChatGroupSystemMessageCoordinator {
  IsmChatGroupSystemMessageCoordinator._();

  static ({String id, String name, String profileUrl, String identifier})
      resolveInitiator(IsmChatMqttActionModel actionModel) {
    final id = (actionModel.initiatorId ??
            actionModel.initiatorDetails?.userId ??
            actionModel.userDetails?.userId ??
            '')
        .trim();
    final name = (actionModel.initiatorName ??
            actionModel.initiatorDetails?.userName ??
            actionModel.userDetails?.userName ??
            '')
        .trim();
    final profileUrl = actionModel.initiatorDetails?.profileImageUrl ??
        actionModel.userDetails?.profileImageUrl ??
        '';
    final identifier = actionModel.initiatorDetails?.userIdentifier ??
        actionModel.userDetails?.userIdentifier ??
        '';
    return (id: id, name: name, profileUrl: profileUrl, identifier: identifier);
  }

  static IsmChatCustomMessageType resolveCustomType(
    IsmChatMqttActionModel actionModel,
  ) =>
      IsmChatCustomMessageType.fromAction(actionModel.action.name) ??
      IsmChatCustomMessageType.fromString(actionModel.action.name);

  /// Maps MQTT action → list row shown by [IsmChatAddRemoveMember],
  /// [IsmChatAddRevokeAdmin], [IsmChatMemberLeaveAndJoin], etc.
  static IsmChatMessageModel buildFromMqttAction(
    IsmChatMqttActionModel actionModel, {
    required bool sentByMe,
  }) {
    final initiator = resolveInitiator(actionModel);
    final customType = resolveCustomType(actionModel);
    final isJoinOrLeave = actionModel.action == IsmChatActionEvents.memberJoin ||
        actionModel.action == IsmChatActionEvents.memberLeave;

    final subjectUserId = isJoinOrLeave
        ? (actionModel.userDetails?.userId ?? actionModel.memberId ?? '').trim()
        : initiator.id;
    final subjectUserName = isJoinOrLeave
        ? (actionModel.userDetails?.userName ?? actionModel.memberName ?? '')
            .trim()
        : initiator.name;

    final firstMember = actionModel.members?.isNotEmpty == true
        ? actionModel.members!.first
        : null;
    final memberId = (actionModel.memberId ?? firstMember?.memberId ?? '')
        .trim();
    final memberName =
        (actionModel.memberName ?? firstMember?.memberName ?? '').trim();

    final senderInfo = UserDetails(
      userProfileImageUrl: isJoinOrLeave
          ? (actionModel.userDetails?.profileImageUrl ?? '')
          : initiator.profileUrl,
      userName: isJoinOrLeave ? subjectUserName : initiator.name,
      userIdentifier: isJoinOrLeave
          ? (actionModel.userDetails?.userIdentifier ?? '')
          : initiator.identifier,
      userId: isJoinOrLeave ? subjectUserId : initiator.id,
      online: true,
      lastSeen: 0,
    );

    return IsmChatMessageModel(
      members: actionModel.members,
      initiatorId: initiator.id,
      initiatorName: initiator.name,
      userId: subjectUserId,
      userName: subjectUserName,
      customType: customType,
      body: '',
      sentAt: actionModel.sentAt,
      sentByMe: sentByMe,
      isGroup: true,
      conversationId: actionModel.conversationId,
      memberId: memberId.isEmpty ? null : memberId,
      memberName: memberName.isEmpty ? null : memberName,
      showInConversation: true,
      senderInfo: senderInfo,
    );
  }

  static LastMessageDetails buildLastMessageDetails(
    IsmChatMqttActionModel actionModel, {
    required bool sentByMe,
  }) {
    final initiator = resolveInitiator(actionModel);
    final customType = resolveCustomType(actionModel);
    final isJoinOrLeave = actionModel.action == IsmChatActionEvents.memberJoin ||
        actionModel.action == IsmChatActionEvents.memberLeave;
    final firstMember = actionModel.members?.isNotEmpty == true
        ? actionModel.members!.first
        : null;

    return LastMessageDetails(
      sentByMe: sentByMe,
      showInConversation: true,
      sentAt: actionModel.sentAt,
      senderName: isJoinOrLeave
          ? (actionModel.userDetails?.userName ?? actionModel.memberName ?? '')
          : initiator.name,
      messageType: 0,
      messageId: '',
      conversationId: actionModel.conversationId ?? '',
      body: '',
      customType: customType,
      senderId: initiator.id,
      userId: isJoinOrLeave
          ? (actionModel.userDetails?.userId ?? actionModel.memberId)
          : (actionModel.memberId ?? firstMember?.memberId),
      memberId: actionModel.memberId ?? firstMember?.memberId,
      memberName: actionModel.memberName ?? firstMember?.memberName,
      members: actionModel.members?.map((e) => e.memberName ?? '').toList(),
      reactionType: '',
    );
  }

  /// Inserts [buildFromMqttAction] into local DB and updates last message.
  /// Call [refreshOpenChatPage] after this (or use [persistAndRefreshOpenChat]).
  static Future<IsmChatConversationModel?> persistSystemMessage({
    required IsmChatMqttActionModel actionModel,
    required bool sentByMe,
    IsmChatConversationModel Function(IsmChatConversationModel)? transformBeforeSave,
    int? unreadMessagesCount,
  }) async {
    final conversationId = actionModel.conversationId ?? '';
    if (conversationId.isEmpty) return null;

    var conversation =
        await IsmChatConfig.dbWrapper?.getConversation(conversationId);
    if (conversation == null) return null;

    if (transformBeforeSave != null) {
      conversation = transformBeforeSave(conversation);
    }

    final row = buildFromMqttAction(actionModel, sentByMe: sentByMe);
    final messages = Map<String, IsmChatMessageModel>.from(
      conversation.messages ?? {},
    );
    messages['${actionModel.sentAt}'] = row;

    conversation = conversation.copyWith(
      messages: messages,
      lastMessageDetails: buildLastMessageDetails(
        actionModel,
        sentByMe: sentByMe,
      ),
      unreadMessagesCount:
          unreadMessagesCount ?? conversation.unreadMessagesCount,
    );

    await IsmChatConfig.dbWrapper?.saveConversation(conversation: conversation);
    return conversation;
  }

  /// Reloads the open chat list from DB after a system row was persisted.
  static Future<void> refreshOpenChatPage(
    IsmChatMqttActionModel actionModel, {
    LastMessageDetails? lastMessageDetails,
    IsmChatConversationModel Function(IsmChatConversationModel)?
        syncInMemoryConversation,
  }) async {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    final controller = IsmChatUtility.chatPageController;
    if (controller.conversation?.conversationId != actionModel.conversationId) {
      return;
    }

    if (lastMessageDetails != null || syncInMemoryConversation != null) {
      var conv = controller.conversation;
      if (lastMessageDetails != null && conv != null) {
        conv = conv.copyWith(lastMessageDetails: lastMessageDetails);
      }
      if (syncInMemoryConversation != null && conv != null) {
        conv = syncInMemoryConversation(conv);
      }
      controller.conversation = conv;
    }

    await controller.getMessagesFromDB(actionModel.conversationId ?? '');
  }

  static Future<void> persistAndRefreshOpenChat({
    required IsmChatMqttActionModel actionModel,
    required bool sentByMe,
    IsmChatConversationModel Function(IsmChatConversationModel)? transformBeforeSave,
    int? unreadMessagesCount,
    IsmChatConversationModel Function(IsmChatConversationModel)?
        syncInMemoryConversation,
  }) async {
    final saved = await persistSystemMessage(
      actionModel: actionModel,
      sentByMe: sentByMe,
      transformBeforeSave: transformBeforeSave,
      unreadMessagesCount: unreadMessagesCount,
    );
    if (saved == null) return;
    await refreshOpenChatPage(
      actionModel,
      lastMessageDetails: saved.lastMessageDetails,
      syncInMemoryConversation: syncInMemoryConversation,
    );
  }
}
