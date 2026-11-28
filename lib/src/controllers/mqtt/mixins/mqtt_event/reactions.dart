// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mixins/mqtt_event/utilities.dart';

/// Reactions mixin for IsmChatMqttEventMixin.
///
/// This mixin contains methods for handling message reaction events.
mixin IsmChatMqttEventReactionsMixin
     {
  /// Handles an add and remove reaction event.
  ///
  /// * `actionModel`: The add and remove reaction event model to handle
  void handleAddAndRemoveReaction(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      if (utils.shouldSkipSameDeviceMqttEcho(actionModel)) return;
      final actorUserId = actionModel.userDetails?.userId ?? '';
      var conversation = await IsmChatConfig.dbWrapper
          ?.getConversation(actionModel.conversationId ?? '');
      final allMessages = conversation?.messages;
    if (allMessages != null) {
      MapEntry<String, IsmChatMessageModel>? message;
      for (final entry in allMessages.entries) {
        if (entry.value.messageId == actionModel.messageId) {
          message = entry;
          break;
        }
      }
      if (message == null) {
        IsmChatThreadController.deliverReactionChange(
          messageId: actionModel.messageId ?? '',
          emojiKey: actionModel.reactionType ?? '',
          added: actionModel.action == IsmChatActionEvents.reactionAdd,
          userId: actionModel.userDetails?.userId,
        );
        if (IsmChatUtility.chatPageControllerRegistered) {
          final controller = IsmChatUtility.chatPageController;
          if (controller.conversation?.conversationId ==
              actionModel.conversationId) {
            await controller.getMessagesFromDB(actionModel.conversationId ?? '');
          }
        }
        if (IsmChatUtility.conversationControllerRegistered) {
          await IsmChatUtility.conversationController.getChatConversations();
        }
        return;
      }
      var isEmoji = false;

      // Prefer MessageReactionModel.addUserIfAbsent / removeUser so API success
      // and MQTT echo never double-list the same reactor on the sender device.
      if (actionModel.action == IsmChatActionEvents.reactionAdd) {
        for (var x in message.value.reactions ?? <MessageReactionModel>[]) {
          if (x.emojiKey == actionModel.reactionType) {
            x.addUserIfAbsent(actorUserId);
            isEmoji = true;
            break;
          }
        }
        if (isEmoji == false) {
          message.value.reactions ??= [];
          message.value.reactions?.add(
            MessageReactionModel(
              emojiKey: actionModel.reactionType ?? '',
              userIds: [actorUserId],
            ),
          );
        }
      } else {
        for (var x in message.value.reactions ?? <MessageReactionModel>[]) {
          if (x.emojiKey == actionModel.reactionType && x.userIds.length > 1) {
            x.removeUser(actorUserId);
            isEmoji = true;
          }
        }

        if (isEmoji == false) {
          message.value.reactions ??= [];
          message.value.reactions
              ?.removeWhere((e) => e.emojiKey == actionModel.reactionType);
        }
      }
      allMessages[message.key] = message.value;

      if (conversation != null) {
        conversation = conversation.copyWith(messages: allMessages);
        await IsmChatConfig.dbWrapper
            ?.saveConversation(conversation: conversation);
        IsmChatThreadController.deliverMessageUpdate(message.value);
        if (IsmChatUtility.chatPageControllerRegistered) {
          var controller = IsmChatUtility.chatPageController;
          if (controller.conversation?.conversationId ==
              actionModel.conversationId) {
            await IsmChatUtility.chatPageController
                .getMessagesFromDB(actionModel.conversationId ?? '');
          }
        }
      }
      if (IsmChatUtility.conversationControllerRegistered) {
        await IsmChatUtility.conversationController.getChatConversations();
      }
    }
    }
  }
}

