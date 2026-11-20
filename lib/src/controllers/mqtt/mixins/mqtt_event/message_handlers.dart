// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
import 'dart:async';

import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mixins/mqtt_event/utilities.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mixins/mqtt_event/variables.dart';

/// Message handlers mixin for IsmChatMqttEventMixin.
///
/// This mixin contains methods for handling incoming messages and local notifications.
mixin IsmChatMqttEventMessageHandlersMixin {
  /// Handles a message.
  ///
  /// * `message`: The message to handle
  // ignore: unused_element
  // This method is called from event_processing.dart via mixin composition
  Future<void> handleMessage(IsmChatMessageModel message) async {
    _trackCallMeetingLiveness(message);
    final self = this;
    var isFromThisDevice = false;
    var isFromCurrentUser = false;
    if (self is IsmChatMqttEventUtilitiesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      final senderId = message.senderInfo?.userId;
      isFromThisDevice =
          utils.isSenderMe(senderId, deviceId: message.deviceId);
      isFromCurrentUser = utils.isSenderMe(senderId);
      // Allow own call bubbles through so the initiator sees "In call" at start.
      if (isFromThisDevice && !message.isSdkCallBubbleMessage) {
        return;
      }
      if (!isFromCurrentUser) {
        utils.handleUnreadMessages(message.senderInfo?.userId ?? '');
      }
    }
    if (!IsmChatUtility.conversationControllerRegistered) {
      return;
    }
    var conversation = await IsmChatConfig.dbWrapper
        ?.getConversation(message.conversationId ?? '');
    final hideMemberLeave =
        !message.isVisibleInGroupChat(conversation);
    // Slack-style threads: a reply that lives only in a thread must not land
    // in the channel list. It goes to the open thread panel (if any) and only
    // moves the root's "N replies" badge. Always false with threads off.
    final isThreadOnlyReply =
        IsmChatThreadCoordinator.shouldHideFromTimeline(message);
    // True when a thread panel is open on this thread and already moved the
    // root's badge on the channel row — bumping it again would double-count.
    final deliveredToOpenThread = isThreadOnlyReply &&
        IsmChatThreadController.deliverIncomingReply(message);
    if (conversation != null && IsmChatUtility.chatPageControllerRegistered) {
      final controller = IsmChatUtility.chatPageController;
      if (message.conversationId == controller.conversation?.conversationId &&
          !hideMemberLeave) {
        if (isThreadOnlyReply) {
          // Badge only — the reply itself stays out of the channel list.
          if (!deliveredToOpenThread) {
            controller.messages =
                IsmChatThreadCoordinator.applyReplyToRootInList(
              List<IsmChatMessageModel>.from(controller.messages),
              message,
            );
          }
          controller.update();
        } else {
          if (controller.messages.isEmpty) {
            controller.messages =
                controller.commonController.sortMessages([message]);
          } else {
            controller.messages.add(message);
          }
          // Same rules as [getMessagesFromDB]: merge call events into one bubble.
          controller.messages = controller.commonController.sortMessages(
            controller.filterMessages(
              List<IsmChatMessageModel>.from(controller.messages),
            ),
          );
          controller.update();
        }
      }
    }
    if (conversation == null) return;
    if (!isFromThisDevice &&
        conversation.lastMessageDetails?.messageId == message.messageId) {
      return;
    }

    // Never apply an incoming message to the wrong group when multiple groups
    // share the same members/name but have different conversationIds.
    if (conversation.conversationId != message.conversationId) return;

    final conversationId = message.conversationId ?? '';
    if (conversationId.isEmpty ||
        conversation.conversationId != conversationId) {
      return;
    }
    // Invalidate a DB reload that already started so it cannot paint a list
    // that is missing this row. The queued save bumps the counter again.
    if (IsmChatUtility.chatPageControllerRegistered &&
        IsmChatUtility.chatPageController.conversation?.conversationId ==
            conversationId) {
      IsmChatUtility.chatPageController.bumpMessagesGeneration();
    }
    // Persist against the latest stored document. Delivery and read receipts
    // edit this same conversation and must not overwrite this insert.
    await IsmChatConfig.dbWrapper?.updateConversation(
      conversationId: conversationId,
      update: (latest) {
        if (latest == null || latest.conversationId != conversationId) {
          return null;
        }
        final base = latest;
        var next = base;
        // Thread-only replies still bump the unread badge (product decision,
        // matching the backend) but never replace the conversation preview.
        if (!hideMemberLeave && isThreadOnlyReply) {
          if (!isFromCurrentUser) {
            next = next.copyWith(
              unreadMessagesCount: IsmChatResponsive.isWeb(
                        IsmChatConfig.kNavigatorKey.currentContext ??
                            IsmChatConfig.context,
                      ) &&
                      (IsmChatUtility.chatPageControllerRegistered &&
                          IsmChatUtility.chatPageController.conversation
                                  ?.conversationId ==
                              conversationId)
                  ? 0
                  : (next.unreadMessagesCount ?? 0) + 1,
            );
          }
          // Only the root's replyCount / lastThreadReplyAt change on disk.
          return next.copyWith(
            messages: IsmChatThreadCoordinator.applyReplyToRootInMap(
              Map<String, IsmChatMessageModel>.from(next.messages ?? {}),
              message,
            ),
          );
        }
        if (!hideMemberLeave) {
          final alreadyApplied = !isFromThisDevice &&
              next.lastMessageDetails?.messageId == message.messageId;
          if (!alreadyApplied) {
            next = next.copyWith(
              unreadMessagesCount: isFromCurrentUser
                  ? next.unreadMessagesCount
                  : IsmChatResponsive.isWeb(
                          IsmChatConfig.kNavigatorKey.currentContext ??
                              IsmChatConfig.context) &&
                      (IsmChatUtility.chatPageControllerRegistered &&
                          IsmChatUtility.chatPageController.conversation
                                  ?.conversationId ==
                              conversationId)
                  ? 0
                  : (next.unreadMessagesCount ?? 0) + 1,
              lastMessageDetails: next.lastMessageDetails?.copyWith(
                sentByMe: message.sentByMe,
                senderId: message.senderInfo?.userId ?? '',
                showInConversation: true,
                sentAt: message.sentAt,
                senderName: message.senderInfo?.userName,
                messageType: message.messageType?.value ?? 0,
                messageId: message.messageId ?? '',
                conversationId: conversationId,
                body: message.body,
                customType: message.customType,
                action: message.action ?? '',
                meetingId: message.meetingId,
                meetingType: message.meetingType,
                callDurations: message.callDurations,
                deliverCount: 0,
                deliveredTo: [],
                readCount: 0,
                readBy: [],
                reactionType: '',
              ),
            );
          }
        }
        final messages = Map<String, IsmChatMessageModel>.from(
          next.messages ?? {},
        );
        return next.copyWith(
          messages: IsmChatDBWrapper.mergeCallMessageIntoMap(messages, message),
        );
      },
    );
    unawaited(IsmChatUtility.conversationController.getConversationsFromDB());
    if (isFromThisDevice) {
      if (!IsmChatUtility.chatPageControllerRegistered) {
        return;
      }
      var chatController = IsmChatUtility.chatPageController;
      if (chatController.conversation?.conversationId != conversationId) {
        return;
      }
      chatController.scheduleMessagesReload(conversationId);
      return;
    }
    final controller = Get.find<IsmChatMqttController>();
    await controller.pingMessageDelivered(
      conversationId: message.conversationId ?? '',
      messageId: message.messageId ?? '',
    );
    if (!IsmChatUtility.chatPageControllerRegistered) {
      return;
    }
    var chatController = IsmChatUtility.chatPageController;
    if (chatController.conversation?.conversationId != conversationId) {
      return;
    }
    chatController.scheduleMessagesReload(conversationId);
    // Opponent replied / messaged — refresh our sent-message ticks from server
    // in case the read MQTT event was dropped (e.g. shared debouncer race).
    unawaited(chatController.getMessageForStatus());
    await Future.delayed(const Duration(milliseconds: 50));
    final self2 = this;
    if (self2 is IsmChatMqttEventVariablesMixin) {
      final vars = self2 as IsmChatMqttEventVariablesMixin;
      if (vars.isAppInBackground == false) {
        final controller = Get.find<IsmChatMqttController>();
        await controller.readSingleMessage(
          conversationId: message.conversationId ?? '',
          messageId: message.messageId ?? '',
        );
      }
    }
  }

  /// Handles a local notification.
  ///
  /// * `message`: The message to handle
  Future<void> handleLocalNotification(IsmChatMessageModel message) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      // Any device logged into this user — do not show local/foreground banners.
      if (utils.isSenderMe(message.senderInfo?.userId)) {
        return;
      }
    }
    if (message.events != null &&
        message.events?.sendPushNotification == false) {
      return;
    }

    // Skip local alerts when this conversation has push notifications muted.
    final conversationId = message.conversationId ?? '';
    if (conversationId.isNotEmpty) {
      IsmChatConversationModel? conversation;
      if (IsmChatUtility.conversationControllerRegistered) {
        conversation = IsmChatUtility.conversationController
            .getConversation(conversationId);
      }
      conversation ??=
          await IsmChatConfig.dbWrapper?.getConversation(conversationId);
      if (conversation?.isPushNotificationEnabled == false) {
        return;
      }
    }

    final notificationTitle = resolveMessageNotificationTitle(message);
    final notificationBody = _resolveNotificationBody(
      message,
      preferNotificationBody: false,
    );
    if (IsmChatResponsive.isMobile(
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context)) {
      if (self is IsmChatMqttEventVariablesMixin) {
        final vars = self as IsmChatMqttEventVariablesMixin;
        if (vars.isAppInBackground) {
          final notificationData = message.toMap();
          // Ensure conversationId is always included in notification payload
          // even if it was null and removed by removeNullValues()
          if (!notificationData.containsKey('conversationId') ||
              notificationData['conversationId'] == null) {
            notificationData['conversationId'] = message.conversationId ?? '';
          }
          if (self is IsmChatMqttEventUtilitiesMixin) {
            (self as IsmChatMqttEventUtilitiesMixin).showPushNotification(
                title: notificationTitle,
                body: notificationBody,
                data: notificationData);
          }
          return;
        }
      }
    }
    if (IsmChatUtility.chatPageControllerRegistered) {
      if (IsmChatUtility.chatPageController.conversation?.conversationId ==
          message.conversationId) {
        return;
      }
    }
    try {
      final notificationData = message.toMap();
      // Ensure conversationId is always included in notification payload
      // even if it was null and removed by removeNullValues()
      if (!notificationData.containsKey('conversationId') ||
          notificationData['conversationId'] == null) {
        notificationData['conversationId'] = message.conversationId ?? '';
      }
      if (self is IsmChatMqttEventUtilitiesMixin) {
        (self as IsmChatMqttEventUtilitiesMixin).showPushNotification(
            title: notificationTitle,
            body: notificationBody,
            data: notificationData);
      }
    } catch (_) {}
  }
}

String _resolveNotificationBody(
  IsmChatMessageModel message, {
  required bool preferNotificationBody,
}) {
  if (message.encrypted == true) {
    return IsmChatUtility.truncateNotificationBody(
      _decryptedNotificationBody(message),
    );
  }
  final notification = message.notificationBody?.trim() ?? '';
  final content = message.body.trim();
  // Web PDF sends store the file name in body. Alerts should say "Document".
  if (_isDocumentAlert(message)) {
    return IsmChatUtility.resolveDocumentNotificationBody(
      body: content,
      attachmentName: message.attachments?.firstOrNull?.name,
      notificationBody: notification,
    );
  }
  // MQTT often sends plaintext in [body] while [notificationBody] is empty.
  // Prefer explicit notification copy when present (e.g. "Sent an image").
  if (preferNotificationBody) {
    return notification.isNotEmpty ? notification : content;
  }
  return content.isNotEmpty ? content : notification;
}

bool _isDocumentAlert(IsmChatMessageModel message) {
  if (message.customType == IsmChatCustomMessageType.file) return true;
  final attachment = message.attachments?.firstOrNull;
  if (attachment == null) return false;
  final mime = (attachment.mimeType ?? '').toLowerCase();
  final extension = (attachment.extension ?? '').toLowerCase();
  final name = (attachment.name ?? '').toLowerCase();
  return mime.contains('pdf') || extension == 'pdf' || name.endsWith('.pdf');
}

String _decryptedNotificationBody(IsmChatMessageModel message) {
  if (message.body.isNotEmpty) return message.body;

  final encryptedText = message.notificationBody ?? '';
  if (encryptedText.isEmpty) return '';

  final metaData = message.metaData;
  final isBroadcast = metaData?.isBroadCastMessage == true;
  final groupcastId = metaData?.groupCastId ?? '';
  final decryptionId = isBroadcast && groupcastId.isNotEmpty
      ? groupcastId
      : message.conversationId ?? '';
  return IsmChatUtility.decryptMessage(encryptedText, decryptionId);
}

/// MQTT / new chat rows only — never call from history/API load.
void _trackCallMeetingLiveness(IsmChatMessageModel message) {
  if (!message.isSdkCallBubbleMessage) return;
  final action = (message.action ?? '').trim();
  if (action.startsWith('meetingEnded')) {
    IsmChatCallMeetingLiveness.markEnded(message.meetingId);
    return;
  }
  if (action == IsmChatActionEvents.memberJoin.name) {
    IsmChatCallMeetingLiveness.markConnected(message.meetingId);
    return;
  }
  if (action == IsmChatActionEvents.meetingCreated.name ||
      action == IsmChatActionEvents.memberLeave.name) {
    IsmChatCallMeetingLiveness.markLive(message.meetingId);
  }
}
