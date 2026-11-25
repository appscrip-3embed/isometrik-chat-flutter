import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Self-chat only: after a successful send, ACK deliver + read so the server
/// emits `messageDelivered` / `messageRead` over MQTT (normal 1:1 does this
/// on inbound messages; self chat skips that path for same-device sends).
///
/// Reuse from [IsmChatCommonViewModel.sendMessage] — do not call for other chats.
class IsmChatSelfChatStatusCoordinator {
  const IsmChatSelfChatStatusCoordinator._();

  /// Synchronous checks before any network / DB work (unit-tested).
  static bool passesStaticGuards({
    required String conversationId,
    required String messageId,
    IsmChatConversationModel? conversation,
    bool? enableSelfChat,
  }) {
    if (conversationId.trim().isEmpty || messageId.trim().isEmpty) {
      return false;
    }
    final featureOn = enableSelfChat ??
        IsmChatProperties.conversationProperties.enableSelfChat;
    if (!featureOn) {
      return false;
    }
    if (conversation != null && !conversation.isSelfChat) {
      return false;
    }
    return true;
  }

  static Future<bool> _resolveIsSelfChat(
    String conversationId,
    IsmChatConversationModel? conversation,
  ) async {
    if (conversation != null) {
      return conversation.isSelfChat;
    }
    final fromDb =
        await IsmChatConfig.dbWrapper?.getConversation(conversationId);
    if (fromDb?.isSelfChat == true) return true;
    if (IsmChatUtility.chatPageControllerRegistered) {
      final page = IsmChatUtility.chatPageController;
      if (page.conversation?.conversationId == conversationId &&
          page.conversation?.isSelfChat == true) {
        return true;
      }
    }
    return false;
  }

  static Future<void> acknowledgeAfterSend({
    required String conversationId,
    required String messageId,
    IsmChatConversationModel? conversation,
  }) async {
    if (!passesStaticGuards(
      conversationId: conversationId,
      messageId: messageId,
      conversation: conversation,
    )) {
      return;
    }
    if (!(await _resolveIsSelfChat(conversationId, conversation))) {
      return;
    }
    if (!Get.isRegistered<IsmChatMqttController>()) {
      return;
    }

    try {
      final mqtt = Get.find<IsmChatMqttController>();
      await mqtt.pingMessageDelivered(
        conversationId: conversationId,
        messageId: messageId,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await mqtt.readSingleMessage(
        conversationId: conversationId,
        messageId: messageId,
      );
    } catch (e, st) {
      IsmChatLog.error('Self chat deliver/read ack failed', st);
    }
  }
}