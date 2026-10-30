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
        final id = member.userId.trim();
        if (id.isEmpty) continue;
        if (!existingMembers.any((e) => e.userId.trim() == id)) {
          existingMembers.add(member);
        }
      }
    } else if (actionModel.action == IsmChatActionEvents.membersRemove) {
      final removedIds = eventMembers
          .map((e) => e.userId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (removedIds.isNotEmpty) {
        existingMembers.removeWhere(
          (e) => removedIds.contains(e.userId.trim()),
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
      if (actionModel.action == IsmChatActionEvents.addMember) {
        await conversationController.getChatConversations();
      }

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

      await IsmChatGroupSystemMessageCoordinator.persistAndRefreshOpenChat(
        actionModel: actionModel,
        sentByMe: sentByMe,
      );

      await conversationController.getConversationsFromDB();

      if (actionModel.memberId ==
              IsmChatConfig.communicationConfig.userConfig.userId &&
          IsmChatUtility.conversationControllerRegistered) {
        await IsmChatUtility.conversationController.getChatConversations();
      }
    }
  }
}
