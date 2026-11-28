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

  static String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static ({String id, String name, String profileUrl, String identifier})
      resolveInitiator(IsmChatMqttActionModel actionModel) {
    // MQTT often sends createdBy:"" — empty [initiatorId] must not block
    // [userDetails] (Status topic actor lives in userId/userName).
    final id = _firstNonEmpty([
      actionModel.initiatorId,
      actionModel.initiatorDetails?.userId,
      actionModel.userDetails?.userId,
      actionModel.senderId,
    ]);
    final name = _firstNonEmpty([
      actionModel.initiatorName,
      actionModel.initiatorDetails?.userName,
      actionModel.userDetails?.userName,
      actionModel.senderName,
    ]);
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

    return IsmChatMessageModel.normalizeGroupSystemActor(
      IsmChatMessageModel(
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
      ),
    );
  }

  /// Subject user id for join/leave centered rows (who joined or left).
  static String leaveOrJoinSubjectId(IsmChatMessageModel message) =>
      (message.userId ?? message.memberId ?? message.senderInfo?.userId ?? '')
          .trim();

  /// Drops older `memberLeave` rows for the same subject before inserting another.
  static void replaceMemberLeaveRowsForSubject(
    Map<String, IsmChatMessageModel> messages,
    IsmChatMessageModel row,
  ) {
    if (row.customType != IsmChatCustomMessageType.memberLeave) {
      return;
    }
    final subjectId = leaveOrJoinSubjectId(row);
    if (subjectId.isEmpty) {
      return;
    }
    final removeKeys = <String>[];
    for (final entry in messages.entries) {
      final existing = entry.value;
      if (existing.customType != IsmChatCustomMessageType.memberLeave) {
        continue;
      }
      if (leaveOrJoinSubjectId(existing) == subjectId) {
        removeKeys.add(entry.key);
      }
    }
    for (final key in removeKeys) {
      messages.remove(key);
    }
  }

  /// Timeline safety net when local optimistic leave and MQTT share different [sentAt].
  static void dedupeMemberLeaveTimelineRows(List<IsmChatMessageModel> messages) {
    final newestBySubject = <String, IsmChatMessageModel>{};
    for (final message in messages) {
      if (message.customType != IsmChatCustomMessageType.memberLeave) {
        continue;
      }
      final subjectId = leaveOrJoinSubjectId(message);
      if (subjectId.isEmpty) {
        continue;
      }
      final existing = newestBySubject[subjectId];
      if (existing == null || message.sentAt >= existing.sentAt) {
        newestBySubject[subjectId] = message;
      }
    }
    if (newestBySubject.isEmpty) {
      return;
    }
    messages.removeWhere((message) {
      if (message.customType != IsmChatCustomMessageType.memberLeave) {
        return false;
      }
      final subjectId = leaveOrJoinSubjectId(message);
      if (subjectId.isEmpty) {
        return false;
      }
      final keep = newestBySubject[subjectId];
      return keep != null && keep != message;
    });
  }

  /// True when the logged-in user appears in an `addMember` MQTT payload.
  ///
  /// Reused when there is no local conversation row yet (newly added member):
  /// list refresh must use [IsmChatConversationsController.getChatConversations]
  /// like [conversationCreated], not [getConversationsFromDB] alone.
  static bool isCurrentUserAmongAddedMembers(
    IsmChatMqttActionModel actionModel,
  ) {
    final selfId =
        IsmChatConfig.communicationConfig.userConfig.userId.trim();
    if (selfId.isEmpty) return false;
    for (final member in actionModel.members ?? const <UserDetails>[]) {
      if (member.matchesConversationMember(selfId)) {
        return true;
      }
    }
    final memberId = (actionModel.memberId ?? '').trim();
    return memberId.isNotEmpty && memberId == selfId;
  }

  /// Local DB first; then in-memory chat list when user never opened the group.
  static Future<IsmChatConversationModel?> resolveConversation(
    String conversationId,
  ) async {
    final trimmedId = conversationId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }

    var conversation =
        await IsmChatConfig.dbWrapper?.getConversation(trimmedId);
    if (conversation != null) {
      return conversation;
    }

    if (IsmChatUtility.conversationControllerRegistered) {
      conversation =
          IsmChatUtility.conversationController.getConversation(trimmedId);
      if (conversation != null) {
        await IsmChatConfig.dbWrapper?.saveConversation(
          conversation: conversation,
        );
        return conversation;
      }
    }
    return null;
  }

  /// Minimal local row when MQTT delivers a chat message before Hive has that
  /// conversation (e.g. newly added to an existing group). Server metadata is
  /// back-filled by [IsmChatConversationsController.getChatConversations].
  static IsmChatConversationModel? bootstrapConversationFromIncomingMessage(
    IsmChatMessageModel message, {
    required bool sentByMe,
  }) {
    final conversationId = (message.conversationId ?? '').trim();
    if (conversationId.isEmpty) {
      return null;
    }

    final details = message.conversationDetails;
    final detailsIsGroup = details?['isGroup'];
    final isGroup =
        message.isGroup == true || detailsIsGroup == true;

    final title = _firstNonEmpty([
      message.conversationTitle,
      details?['conversationTitle'] as String?,
    ]);
    final imageUrl = _firstNonEmpty([
      message.conversationImageUrl,
      details?['conversationImageUrl'] as String?,
    ]);

    var membersCount = message.membersCount ?? 0;
    final fromDetails = details?['membersCount'];
    if (membersCount == 0 && fromDetails is int) {
      membersCount = fromDetails;
    }

    final lastMessageDetails = LastMessageDetails(
      showInConversation: true,
      sentAt: message.sentAt,
      senderName: message.senderInfo?.userName ?? message.chatName,
      senderId: message.senderInfo?.userId ?? '',
      messageType: message.messageType?.value ?? 0,
      messageId: message.messageId ?? '',
      conversationId: conversationId,
      body: IsmChatUtility.lastMessageBodyForConversationSync(message),
      sentByMe: sentByMe,
      customType: message.customType,
      action: message.action ?? '',
      meetingId: message.meetingId,
      meetingType: message.meetingType,
      callDurations: message.callDurations,
      deliverCount: 0,
      deliveredTo: const <MessageStatus>[],
      readCount: 0,
      readBy: const <MessageStatus>[],
      reactionType: '',
      metaData: message.metaData,
      audioOnly: message.audioOnly,
      isInvalidMessage: message.isInvalidMessage,
    );

    return IsmChatConversationModel(
      conversationId: conversationId,
      conversationTitle: title,
      conversationImageUrl: imageUrl,
      isGroup: isGroup,
      privateOneToOne: message.privateOneToOne,
      membersCount: membersCount,
      lastMessageSentAt: message.sentAt,
      lastMessageDetails: lastMessageDetails,
      unreadMessagesCount: sentByMe ? 0 : 1,
      messages: <String, IsmChatMessageModel>{},
      opponentDetails:
          isGroup ? null : message.senderInfo,
      conversationType: IsmChatConversationType.fromValue(
        message.conversationType ?? 0,
      ),
      config: ConversationConfigModel(
        typingEvents: true,
        readEvents: true,
        pushNotifications: true,
      ),
    );
  }

  /// Keeps [IsmChatConversationsController.conversations] in sync after MQTT rows.
  static void syncConversationListCache(IsmChatConversationModel conversation) {
    if (!IsmChatUtility.conversationControllerRegistered) {
      return;
    }
    final controller = IsmChatUtility.conversationController;
    final conversationId = conversation.conversationId ?? '';
    if (conversationId.isEmpty) {
      return;
    }

    final list =
        List<IsmChatConversationModel>.from(controller.conversations);
    final index =
        list.indexWhere((entry) => entry.conversationId == conversationId);
    if (index != -1) {
      list[index] = conversation;
    } else {
      list.add(conversation);
      int sortKey(IsmChatConversationModel c) =>
          c.lastMessageDetails?.sentAt ?? c.lastMessageSentAt ?? 0;
      list.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
    }
    controller.conversations = list;

    if (controller.currentConversationId == conversationId) {
      controller.currentConversation = conversation;
    }

    if (IsmChatUtility.chatPageControllerRegistered &&
        IsmChatUtility.chatPageController.conversation?.conversationId ==
            conversationId) {
      final page = IsmChatUtility.chatPageController;
      page.conversation = page.conversation?.copyWith(
            members: conversation.members,
            membersCount: conversation.membersCount,
            lastMessageDetails: conversation.lastMessageDetails,
            lastMessageSentAt: conversation.lastMessageSentAt,
          ) ??
          conversation;
      if (conversation.members != null) {
        page.groupMembers = List<UserDetails>.from(conversation.members!);
      }
    }
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
      initiatorId: initiator.id,
      userId: isJoinOrLeave
          ? (actionModel.userDetails?.userId ?? actionModel.memberId)
          : (actionModel.memberId ?? firstMember?.memberId),
      memberId: actionModel.memberId ?? firstMember?.memberId,
      memberName: actionModel.memberName ?? firstMember?.memberName,
      members: actionModel.members
          ?.map((e) => (e.memberName ?? e.userName).trim())
          .where((name) => name.isNotEmpty)
          .toList(),
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

    var conversation = await resolveConversation(conversationId);
    if (conversation == null) return null;

    if (transformBeforeSave != null) {
      conversation = transformBeforeSave(conversation);
    }

    final row = buildFromMqttAction(actionModel, sentByMe: sentByMe);
    final messages = Map<String, IsmChatMessageModel>.from(
      conversation.messages ?? {},
    );
    replaceMemberLeaveRowsForSubject(messages, row);
    messages['${actionModel.sentAt}'] = row;

    conversation = conversation.copyWith(
      messages: messages,
      lastMessageDetails: buildLastMessageDetails(
        actionModel,
        sentByMe: sentByMe,
      ),
      lastMessageSentAt: actionModel.sentAt,
      unreadMessagesCount:
          unreadMessagesCount ?? conversation.unreadMessagesCount,
    );

    await IsmChatConfig.dbWrapper?.saveConversation(conversation: conversation);
    syncConversationListCache(conversation);
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
