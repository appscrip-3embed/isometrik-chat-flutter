// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Handles `messageDetailsUpdated` MQTT events (edited message body/metadata).
mixin IsmChatMqttEventMessageDetailsUpdatedMixin {
  /// Finds a message row already on screen (thread panel or channel list).
  ///
  /// Thread replies are often absent from the conversation DB map until reload.
  IsmChatMessageModel? _liveMessageForMqttEdit(
    String conversationId,
    String messageId,
  ) {
    final fromThread =
        IsmChatThreadController.findMessageInOpenPanel(messageId);
    if (fromThread != null) return fromThread;

    if (!IsmChatUtility.chatPageControllerRegistered) return null;
    final page = IsmChatUtility.chatPageController;
    if ((page.conversation?.conversationId ?? '').trim() != conversationId) {
      return null;
    }
    for (final row in page.messages) {
      if ((row.messageId ?? '').trim() == messageId) return row;
    }
    return null;
  }

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

    IsmChatMessageModel? existing;
    String? cachedKey;
    if (conversation != null) {
      final messages = conversation.messages ?? {};
      for (final entry in messages.entries) {
        if ((entry.value.messageId ?? '').trim() == messageId) {
          existing = entry.value;
          cachedKey = entry.key;
          break;
        }
      }
    }
    existing ??= _liveMessageForMqttEdit(conversationId, messageId);

    final groupCastId = existing?.metaData?.groupCastId?.trim() ?? '';
    final decryptionId =
        existing?.metaData?.isBroadCastMessage == true && groupCastId.isNotEmpty
            ? groupCastId
            : conversationId;

    final plainBody = detailsBody != null
        ? IsmChatUtility.decryptMessage(detailsBody, decryptionId)
        : existing?.body;

    final base = existing ??
        IsmChatMessageModel(
          body: plainBody ?? '',
          customType: details?.customType ?? IsmChatCustomMessageType.text,
          sentAt: actionModel.sentAt,
          sentByMe: false,
          conversationId: conversationId,
          messageId: messageId,
        );

    final updated = base.copyWith(
      body: plainBody ?? base.body,
      conversationId: conversationId,
      messageId: messageId,
      searchableTags: details?.searchableTags ?? base.searchableTags,
      customType: details?.customType ?? base.customType,
      metaData: details?.metaData ?? base.metaData,
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
    } else if (conversation != null && cachedKey != null) {
      final messages = Map<String, IsmChatMessageModel>.from(
        conversation.messages ?? {},
      );
      messages[cachedKey] = updated;
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