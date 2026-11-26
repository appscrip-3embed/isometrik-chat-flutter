// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Handles `messageDetailsUpdated` MQTT events (edited message body/metadata).
mixin IsmChatMqttEventMessageDetailsUpdatedMixin {
  Future<void> handleMessageDetailsUpdated(
    IsmChatMqttActionModel actionModel,
  ) async {
    final conversationId = actionModel.conversationId?.trim() ?? '';
    final messageId = actionModel.messageId?.trim() ?? '';
    if (conversationId.isEmpty || messageId.isEmpty) return;

    final details = actionModel.messageDetails;
    final detailsBody = details?.body;
    if (detailsBody == null && details?.metaData == null) return;

    final conversation =
        await IsmChatConfig.dbWrapper?.getConversation(conversationId);
    if (conversation == null) return;

    final messages = Map<String, IsmChatMessageModel>.from(
      conversation.messages ?? {},
    );
    MapEntry<String, IsmChatMessageModel>? match;
    for (final entry in messages.entries) {
      if (entry.value.messageId == messageId) {
        match = entry;
        break;
      }
    }
    if (match == null) {
      if (IsmChatUtility.chatPageControllerRegistered &&
          IsmChatUtility.chatPageController.conversation?.conversationId ==
              conversationId) {
        await IsmChatUtility.chatPageController.getMessagesFromDB(
          conversationId,
        );
      }
      return;
    }

    final existing = match.value;
    final groupCastId = existing.metaData?.groupCastId?.trim() ?? '';
    final decryptionId =
        existing.metaData?.isBroadCastMessage == true && groupCastId.isNotEmpty
            ? groupCastId
            : conversationId;

    final plainBody = detailsBody != null
        ? IsmChatUtility.decryptMessage(detailsBody, decryptionId)
        : existing.body;

    final updated = existing.copyWith(
      body: plainBody,
      searchableTags: details?.searchableTags ?? existing.searchableTags,
      customType: details?.customType ?? existing.customType,
      metaData: details?.metaData ?? existing.metaData,
      messageUpdated: true,
    );

    IsmChatThreadController.applyMessageDetailsUpdate(updated);

    final pageOpen = IsmChatUtility.chatPageControllerRegistered &&
        IsmChatUtility.chatPageController.conversation?.conversationId ==
            conversationId;
    if (pageOpen) {
      await IsmChatUtility.chatPageController.applyMessageEditFromRemote(
        updated,
      );
    } else {
      messages[match.key] = updated;
      var nextConversation = conversation.copyWith(messages: messages);
      if (nextConversation.lastMessageDetails?.messageId == messageId) {
        nextConversation = nextConversation.copyWith(
          lastMessageDetails: nextConversation.lastMessageDetails?.copyWith(
            body: updated.body,
          ),
        );
      }
      await IsmChatConfig.dbWrapper?.saveConversation(
        conversation: nextConversation,
      );
    }

    if (IsmChatUtility.conversationControllerRegistered) {
      await IsmChatUtility.conversationController.getConversationsFromDB();
    }
  }
}