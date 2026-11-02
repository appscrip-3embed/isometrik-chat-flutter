import 'dart:async';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mixins/mqtt_event/utilities.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mixins/mqtt_event/variables.dart';

/// Group operations mixin for IsmChatMqttEventMixin.
///
/// This mixin contains methods for handling group-related events like member add/remove,
/// admin changes, and member join/leave.
mixin IsmChatMqttEventGroupOperationsMixin {
  /// Applies member add/remove delta from MQTT event to conversation members.
  IsmChatConversationModel _applyMemberDelta(
    IsmChatConversationModel conversation,
    IsmChatMqttActionModel actionModel,
  ) {
    final existingMembers = List<UserDetails>.from(conversation.members ?? []);
    final eventMembers = actionModel.members ?? const <UserDetails>[];

    if (actionModel.action == IsmChatActionEvents.addMember) {
      for (final member in eventMembers) {
        final id = member.conversationMemberIdForApi;
        if (id.isEmpty) continue;
        final existingIndex = existingMembers.indexWhere(
          (e) => e.matchesConversationMember(id),
        );
        // Re-add after remove must replace stale rows (e.g. old isAdmin flag).
        if (existingIndex >= 0) {
          existingMembers[existingIndex] = member;
        } else {
          existingMembers.add(member);
        }
      }
    } else if (actionModel.action == IsmChatActionEvents.membersRemove) {
      final removedIds = eventMembers
          .map((e) => e.conversationMemberIdForApi)
          .where((id) => id.isNotEmpty)
          .toSet();
      if (removedIds.isNotEmpty) {
        existingMembers.removeWhere(
          (e) => removedIds.any(e.matchesConversationMember),
        );
      }
    }

    return conversation.copyWith(
      members: existingMembers,
      membersCount: existingMembers.length,
    );
  }

  /// Handles a group remove and add user event.
  ///
  /// * `actionModel`: The group remove and add user event model to handle
  void handleGroupRemoveAndAddUser(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin &&
        self is IsmChatMqttEventVariablesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      final vars = self as IsmChatMqttEventVariablesMixin;
      // Process self-initiated add/remove so the actor sees the center banner.
      if (vars.messageId == actionModel.sentAt.toString()) return;
      vars.messageId = actionModel.sentAt.toString();

      if (!IsmChatUtility.conversationControllerRegistered) {
        return;
      }
      final conversationController = IsmChatUtility.conversationController;

      final initiator =
          IsmChatGroupSystemMessageCoordinator.resolveInitiator(actionModel);
      final sentByMe = utils.isSenderMe(initiator.id);

      await IsmChatGroupSystemMessageCoordinator.persistAndRefreshOpenChat(
        actionModel: actionModel,
        sentByMe: sentByMe,
        transformBeforeSave: (conv) => _applyMemberDelta(conv, actionModel),
        unreadMessagesCount:
            actionModel.action == IsmChatActionEvents.membersRemove ? 0 : null,
        syncInMemoryConversation: (conv) => _applyMemberDelta(conv, actionModel),
      );

      await conversationController.getConversationsFromDB();

      if (IsmChatUtility.chatPageControllerRegistered) {
        final chatPageController = IsmChatUtility.chatPageController;
        if (actionModel.conversationId ==
            chatPageController.conversation?.conversationId) {
          await chatPageController.getConverstaionDetails(isLoading: false);
        }
      }
    }
  }

  /// Handles a member join and leave event.
  ///
  /// * `actionModel`: The member join and leave event model to handle
  void handleMemberJoinAndLeave(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin &&
        self is IsmChatMqttEventVariablesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      final vars = self as IsmChatMqttEventVariablesMixin;
      if (vars.messageId == actionModel.sentAt.toString()) return;
      vars.messageId = actionModel.sentAt.toString();

      if (!IsmChatUtility.conversationControllerRegistered) {
        return;
      }
      final conversationController = IsmChatUtility.conversationController;

      final subjectId = (actionModel.userDetails?.userId ??
              actionModel.memberId ??
              '')
          .trim();
      final sentByMe = utils.isSenderMe(subjectId);

      await IsmChatGroupSystemMessageCoordinator.persistAndRefreshOpenChat(
        actionModel: actionModel,
        sentByMe: sentByMe,
      );

      await conversationController.getConversationsFromDB();

      if (IsmChatUtility.chatPageControllerRegistered) {
        final controller = IsmChatUtility.chatPageController;
        if (controller.conversation?.conversationId ==
                actionModel.conversationId &&
            controller.conversation?.lastMessageSentAt != actionModel.sentAt) {
          unawaited(
            controller.getMessagesFromAPI(
              lastMessageTimestamp: controller.messages.isNotEmpty
                  ? controller.messages.last.sentAt
                  : controller.conversation?.lastMessageSentAt,
            ),
          );
        }
      }

      unawaited(conversationController.getChatConversations());
    }
  }

  /// Updates [isAdmin] on the affected member in local conversation state.
  IsmChatConversationModel _applyAdminDelta(
    IsmChatConversationModel conversation,
    IsmChatMqttActionModel actionModel, {
    required bool isAdmin,
  }) {
    final targetId = (actionModel.memberId ??
            actionModel.members?.firstOrNull?.conversationMemberIdForApi ??
            '')
        .trim();
    if (targetId.isEmpty) return conversation;

    final members = List<UserDetails>.from(conversation.members ?? []);
    for (var i = 0; i < members.length; i++) {
      if (members[i].matchesConversationMember(targetId)) {
        members[i] = members[i].copyWith(isAdmin: isAdmin);
        break;
      }
    }
    return conversation.copyWith(members: members);
  }

  /// Handles an admin remove and add event.
  ///
  /// * `actionModel`: The admin remove and add event model to handle
  void handleAdminRemoveAndAdd(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin &&
        self is IsmChatMqttEventVariablesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      final vars = self as IsmChatMqttEventVariablesMixin;
      // Don't skip if sender is me - we want to receive the event and message
      // when we make someone admin or remove admin
      if (vars.messageId == actionModel.sentAt.toString()) return;
      vars.messageId = actionModel.sentAt.toString();

      if (!IsmChatUtility.conversationControllerRegistered) {
        return;
      }
      final conversationController = IsmChatUtility.conversationController;

      final initiator =
          IsmChatGroupSystemMessageCoordinator.resolveInitiator(actionModel);
      final sentByMe = utils.isSenderMe(initiator.id);

      final isAddAdmin = actionModel.action == IsmChatActionEvents.addAdmin;
      final isRemoveAdmin =
          actionModel.action == IsmChatActionEvents.removeAdmin;
      final adminFlag =
          isAddAdmin ? true : (isRemoveAdmin ? false : null);

      IsmChatConversationModel applyAdminDelta(IsmChatConversationModel conv) {
        if (adminFlag == null) return conv;
        return _applyAdminDelta(conv, actionModel, isAdmin: adminFlag);
      }

      await IsmChatGroupSystemMessageCoordinator.persistAndRefreshOpenChat(
        actionModel: actionModel,
        sentByMe: sentByMe,
        transformBeforeSave:
            adminFlag != null ? applyAdminDelta : null,
        syncInMemoryConversation:
            adminFlag != null ? applyAdminDelta : null,
      );

      await conversationController.getConversationsFromDB();

      if (IsmChatUtility.chatPageControllerRegistered) {
        final chatPageController = IsmChatUtility.chatPageController;
        if (actionModel.conversationId ==
            chatPageController.conversation?.conversationId) {
          if (adminFlag != null) {
            final targetId = (actionModel.memberId ??
                    actionModel.members?.firstOrNull
                        ?.conversationMemberIdForApi ??
                    '')
                .trim();
            if (targetId.isNotEmpty) {
              chatPageController.groupMembers = chatPageController.groupMembers
                  .map(
                    (m) => m.matchesConversationMember(targetId)
                        ? m.copyWith(isAdmin: adminFlag)
                        : m,
                  )
                  .toList();
            }
          }
          await chatPageController.getConverstaionDetails(isLoading: false);
        }
      }

      if (actionModel.memberId ==
              IsmChatConfig.communicationConfig.userConfig.userId &&
          IsmChatUtility.conversationControllerRegistered) {
        await IsmChatUtility.conversationController.getChatConversations();
      }
    }
  }
}
