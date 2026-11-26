import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// How the local client should behave after a successful group-leave API call.
///
/// Reused by [IsmChatPageOtherOperationsMixin.leaveGroup] and
/// [IsmChatConversationOperationsMixin.leaveGroup] so both entry points stay in sync.
enum IsmChatLeaveGroupMode {
  /// Stay in the chat list with history; composer read-only; leave banner in timeline.
  keepHistory,

  /// Remove the conversation from this device after leaving on the server.
  deleteForMe,
}

/// Local side-effects after `DELETE .../leave` succeeds.
///
/// Builds the centered leave row via [IsmChatGroupSystemMessageCoordinator]
/// (same MQTT shape as [IsmChatMqttEventGroupOperationsMixin.handleMemberJoinAndLeave])
/// so the leaver sees the event without waiting on the broker.
class IsmChatLeaveGroupCoordinator {
  IsmChatLeaveGroupCoordinator._();

  static String get _currentUserId =>
      IsmChatConfig.communicationConfig.userConfig.userId.trim();

  static String get _currentUserName =>
      (IsmChatConfig.communicationConfig.userConfig.userName ?? '').trim();

  static IsmChatConversationModel _removeCurrentUser(
    IsmChatConversationModel conversation,
  ) {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty) return conversation;

    final members = List<UserDetails>.from(conversation.members ?? [])
      ..removeWhere((member) => member.userId.trim() == currentUserId);

    return conversation.copyWith(
      members: members,
      membersCount: members.length,
    );
  }

  static IsmChatMqttActionModel _buildLeaveAction(String conversationId) {
    return IsmChatMqttActionModel(
      conversationId: conversationId.trim(),
      sentAt: DateTime.now().millisecondsSinceEpoch,
      action: IsmChatActionEvents.memberLeave,
      userDetails: IsmChatMqttUserModel(
        userId: _currentUserId,
        userName: _currentUserName,
      ),
    );
  }

  /// Inserts a `memberLeave` system row and drops the signed-in user from
  /// [members]. Uses local [sentAt] so a later MQTT row with server time does
  /// not collide on the same map key when both arrive.
  static Future<void> persistLocalMemberLeave(String conversationId) async {
    final trimmedId = conversationId.trim();
    if (trimmedId.isEmpty || _currentUserId.isEmpty) return;

    final actionModel = _buildLeaveAction(trimmedId);
    final chatOpenOnConversation = IsmChatUtility.chatPageControllerRegistered &&
        IsmChatUtility.chatPageController.conversation?.conversationId ==
            trimmedId;

    if (chatOpenOnConversation) {
      await IsmChatGroupSystemMessageCoordinator.persistAndRefreshOpenChat(
        actionModel: actionModel,
        sentByMe: true,
        transformBeforeSave: _removeCurrentUser,
        syncInMemoryConversation: _removeCurrentUser,
      );
      IsmChatUtility.chatPageController.isActionAllowed = true;
      final fromDb =
          await IsmChatConfig.dbWrapper?.getConversation(trimmedId);
      if (fromDb != null) {
        IsmChatUtility.chatPageController.conversation = fromDb;
      }
      return;
    }

    await IsmChatGroupSystemMessageCoordinator.persistSystemMessage(
      actionModel: actionModel,
      sentByMe: true,
      transformBeforeSave: _removeCurrentUser,
    );
  }

  /// Applies [mode] after the leave API returned success.
  static Future<void> applyPostLeaveLocalState({
    required String conversationId,
    required IsmChatLeaveGroupMode mode,
  }) async {
    final trimmedId = conversationId.trim();
    if (trimmedId.isEmpty) return;

    if (mode == IsmChatLeaveGroupMode.keepHistory) {
      await persistLocalMemberLeave(trimmedId);

      if (IsmChatUtility.conversationControllerRegistered) {
        await Future.wait([
          IsmChatUtility.conversationController.getConversationsFromDB(),
          IsmChatUtility.conversationController.getChatConversations(),
        ]);
      }
      return;
    }

    if (IsmChatUtility.conversationControllerRegistered) {
      await IsmChatUtility.conversationController.deleteChat(
        trimmedId,
        deleteFromServer: true,
        shouldUpdateLocal: true,
        // Leave API already ran; server `/local` delete may fail for ex-members.
        removeLocalEvenIfServerFails: true,
      );
      return;
    }
    await IsmChatConfig.dbWrapper?.removeConversation(trimmedId);
  }
}