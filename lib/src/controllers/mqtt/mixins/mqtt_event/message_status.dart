// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
import 'dart:async';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mixins/mqtt_event/utilities.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mixins/mqtt_event/variables.dart';

/// Message status mixin for IsmChatMqttEventMixin.
///
/// This mixin contains methods for handling message delivery and read status events.
mixin IsmChatMqttEventMessageStatusMixin {
  /// Handles a message delivered event.
  ///
  /// * `actionModel`: The message delivered event model to handle
  // ignore: unused_element
  // This method is called from event_processing.dart via mixin composition
  void handleMessageDelivered(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin &&
        self is IsmChatMqttEventVariablesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      final vars = self as IsmChatMqttEventVariablesMixin;
      final conversation =
          await _conversationForStatusEvent(actionModel.conversationId);
      if (_skipStatusUpdateForOwnUser(utils, actionModel, conversation)) return;

      vars.deliverdActions.add(actionModel);
      final actionsData =
          List<IsmChatMqttActionModel>.from(vars.deliverdActions);
      vars.ismChatDeliveredDebounce.run(() async {
        for (final action in actionsData) {
          final conversationId = action.conversationId ?? '';
          // Read and write inside the per-conversation queue so a delivery
          // receipt cannot save a snapshot that is missing a message inserted
          // while this handler was waiting.
          final updated = await IsmChatConfig.dbWrapper?.updateConversation(
            conversationId: conversationId,
            update: (conversation) {
              if (conversation == null) return null;
              final located = _storedMessage(
                conversation.messages,
                action.messageId,
              );
              if (located == null) return null;
              final message = located.message;
              final isDelivered = message.deliveredTo
                  ?.any((e) => e.userId == action.userDetails?.userId);
              if (isDelivered != true) {
                message.deliveredTo?.add(
                  MessageStatus(
                    userId: action.userDetails?.userId ?? '',
                    timestamp: action.sentAt,
                  ),
                );
              }
              message.deliveredToAll = message.deliveredTo?.length ==
                  _othersToAckCount(conversation);
              // Keep the key the row was stored under. [message.key] can
              // differ when metadata has no messageSentAt.
              located.messages[located.storageKey] = message;
              return conversation.copyWith(
                messages: located.messages,
                lastMessageDetails: conversation.lastMessageDetails?.copyWith(
                  deliverCount: message.deliveredTo?.length,
                  deliveredTo: message.deliveredTo,
                ),
              );
            },
          );
          if (updated != null && IsmChatUtility.chatPageControllerRegistered) {
            await IsmChatUtility.chatPageController
                .getMessagesFromDB(conversationId);
            IsmChatUtility.chatPageController.update();
          }
          if (updated != null &&
              IsmChatUtility.conversationControllerRegistered) {
            unawaited(IsmChatUtility.conversationController
                .getConversationsFromDB());
          }
          vars.deliverdActions.remove(action);
        }
      });
    }
  }

  /// Handles a message read event.
  ///
  /// * `actionModel`: The message read event model to handle
  // ignore: unused_element
  // This method is called from event_processing.dart via mixin composition
  void handleMessageRead(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin &&
        self is IsmChatMqttEventVariablesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      final vars = self as IsmChatMqttEventVariablesMixin;
      final conversation =
          await _conversationForStatusEvent(actionModel.conversationId);
      if (_skipStatusUpdateForOwnUser(utils, actionModel, conversation)) return;
      vars.readActions.add(actionModel);
      vars.ismChatReadDebounce.run(() async {
        final actionsData = List<IsmChatMqttActionModel>.from(vars.readActions);
        for (var action in actionsData) {
          final conversationId = action.conversationId ?? '';
          final updated = await IsmChatConfig.dbWrapper?.updateConversation(
            conversationId: conversationId,
            update: (conversation) {
              if (conversation == null) return null;
              final located = _storedMessage(
                conversation.messages,
                action.messageId,
              );
              if (located == null) return null;
              final message = located.message;
              final isRead = message.readBy
                  ?.any((e) => e.userId == action.userDetails?.userId);
              final isDelivered = message.deliveredTo
                  ?.any((e) => e.userId == action.userDetails?.userId);
              if (isDelivered != true) {
                message.deliveredTo?.add(
                  MessageStatus(
                    userId: action.userDetails?.userId ?? '',
                    timestamp: action.sentAt,
                  ),
                );
              }
              if (isRead != true) {
                message.readBy?.add(
                  MessageStatus(
                    userId: action.userDetails?.userId ?? '',
                    timestamp: action.sentAt,
                  ),
                );
              }
              message.readByAll =
                  message.readBy?.length == _othersToAckCount(conversation);
              // If readByAll is true, deliveredToAll must also be true
              // (you can't read a message that hasn't been delivered)
              if (message.readByAll == true) {
                message.deliveredToAll = true;
              } else {
                message.deliveredToAll = message.deliveredTo?.length ==
                    _othersToAckCount(conversation);
              }
              located.messages[located.storageKey] = message;
              return conversation.copyWith(
                messages: located.messages,
                lastMessageDetails: conversation.lastMessageDetails?.copyWith(
                  readCount: message.readBy?.length,
                  readBy: message.readBy,
                ),
              );
            },
          );
          if (updated != null && IsmChatUtility.chatPageControllerRegistered) {
            await IsmChatUtility.chatPageController
                .getMessagesFromDB(conversationId);
            IsmChatUtility.chatPageController.update();
          }
          if (updated != null &&
              IsmChatUtility.conversationControllerRegistered) {
            unawaited(IsmChatUtility.conversationController
                .getConversationsFromDB());
          }
          vars.readActions.remove(action);
        }
      });
    }
  }

  /// Handles a multiple message read event.
  ///
  /// * `actionModel`: The multiple message read event model to handle
  void handleMultipleMessageRead(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      final conversation =
          await _conversationForStatusEvent(actionModel.conversationId);
      if (_skipStatusUpdateForOwnUser(utils, actionModel, conversation)) return;
      final conversationId = actionModel.conversationId ?? '';
      // Group chats emit this event for a whole page of messages. Reuse each
      // row's existing map key. Keying by metaData.messageSentAt collapses
      // every incoming message onto "0" (MQTT metadata omits that field) and
      // the next DB reload deletes them from the screen.
      await IsmChatConfig.dbWrapper?.updateConversation(
        conversationId: conversationId,
        update: (conversation) {
          if (conversation == null) return null;
          final allMessages = conversation.messages ?? {};
          final modifiedMessages = <String, IsmChatMessageModel>{};
          for (final entry in allMessages.entries) {
            final message = entry.value;
            if (message.deliveredToAll == true && message.readByAll == true) {
              modifiedMessages[entry.key] = message;
              continue;
            }
            final isDelivered = message.deliveredTo
                ?.any((e) => e.userId == actionModel.userDetails?.userId);
            final isRead = message.readBy
                ?.any((e) => e.userId == actionModel.userDetails?.userId);
            final deliveredTo = message.deliveredTo ?? [];
            final readBy = message.readBy ?? [];
            var modified = message.copyWith(
              deliveredTo: isDelivered == true
                  ? deliveredTo
                  : [
                      ...deliveredTo,
                      MessageStatus(
                        userId: actionModel.userDetails?.userId ?? '',
                        timestamp: actionModel.sentAt,
                      ),
                    ],
              readBy: isRead == true
                  ? readBy
                  : [
                      ...readBy,
                      MessageStatus(
                        userId: actionModel.userDetails?.userId ?? '',
                        timestamp: actionModel.sentAt,
                      ),
                    ],
            );

            final readByAllValue =
                modified.readBy?.length == _othersToAckCount(conversation);
            final deliveredToAllValue = modified.deliveredTo?.length ==
                _othersToAckCount(conversation);

            modified = modified.copyWith(
              readByAll: readByAllValue,
              // If readByAll is true, deliveredToAll must also be true
              // (you can't read a message that hasn't been delivered)
              deliveredToAll: readByAllValue ? true : deliveredToAllValue,
            );

            modifiedMessages[entry.key] = modified;
          }
          return conversation.copyWith(
            messages: modifiedMessages,
            lastMessageDetails: conversation.lastMessageDetails?.copyWith(
              deliverCount: modifiedMessages.isEmpty
                  ? 1
                  : modifiedMessages.values.last.deliveredTo?.length ?? 0,
              readCount: modifiedMessages.isEmpty
                  ? 1
                  : modifiedMessages.values.last.readBy?.length ?? 0,
              readBy: modifiedMessages.isEmpty
                  ? []
                  : modifiedMessages.values.last.readBy,
              deliveredTo: modifiedMessages.isEmpty
                  ? []
                  : modifiedMessages.values.last.deliveredTo,
            ),
          );
        },
      );
      if (IsmChatUtility.chatPageControllerRegistered) {
        var controller = IsmChatUtility.chatPageController;
        if (controller.conversation?.conversationId ==
            actionModel.conversationId) {
          await controller.getMessagesFromDB(actionModel.conversationId ?? '');
          controller.update();
        }
      }
      if (IsmChatUtility.conversationControllerRegistered) {
        await IsmChatUtility.conversationController.getConversationsFromDB();
      }
    }
  }

  /// Handles a message delete for everyone event.
  ///
  /// * `actionModel`: The message delete for everyone event model to handle
  void handleMessageDelelteForEveryOne(
      IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      if (_skipDeleteForAllLocalEcho(utils, actionModel)) return;
      final targetIds = _deleteForAllTargetIds(actionModel);
      if (targetIds.isEmpty) return;
      final conversationId = actionModel.conversationId ?? '';
      await IsmChatConfig.dbWrapper?.updateConversation(
        conversationId: conversationId,
        update: (conversation) {
          if (conversation == null) return null;
          final allMessages =
              Map<String, IsmChatMessageModel>.from(conversation.messages ?? {});
          if (allMessages.isEmpty) return null;
          var changed = false;
          IsmChatMessageModel? patchedLastMessage;
          final lastId = conversation.lastMessageDetails?.messageId?.trim() ?? '';
          for (final messageId in targetIds) {
            final located = _storedMessage(allMessages, messageId);
            if (located == null) continue;
            final updated = located.message.copyWith(
              customType: IsmChatCustomMessageType.deletedForEveryone,
              reactions: [],
            );
            located.messages[located.storageKey] = updated;
            changed = true;
            if (lastId.isNotEmpty && messageId == lastId) {
              patchedLastMessage = updated;
            }
          }
          if (!changed) return null;
          var next = conversation.copyWith(messages: allMessages);
          if (patchedLastMessage != null) {
            next = next.copyWith(
              lastMessageDetails: next.lastMessageDetails?.copyWith(
                customType: IsmChatCustomMessageType.deletedForEveryone,
                body: IsmChatUtility.lastMessageBodyForConversationSync(
                  patchedLastMessage!,
                ),
              ),
            );
          }
          return next;
        },
      );

      if (IsmChatUtility.chatPageControllerRegistered) {
        final controller = IsmChatUtility.chatPageController;
        if (controller.conversation?.conversationId ==
            actionModel.conversationId) {
          await controller.getMessagesFromDB(actionModel.conversationId ?? '');
          controller.update();
        }
      }
      if (IsmChatUtility.conversationControllerRegistered) {
        unawaited(
          IsmChatUtility.conversationController.getConversationsFromDB(),
        );
      }
    }
  }

  /// Handles `messagesDeleteLocal` (delete for me) on the user's Status topic.
  ///
  /// Only affects this account's local cache; must propagate to other devices
  /// logged into the same user (same rules as delete-for-everyone echoes).
  void handleMessageDeleteLocal(IsmChatMqttActionModel actionModel) async {
    final self = this;
    if (self is IsmChatMqttEventUtilitiesMixin) {
      final utils = self as IsmChatMqttEventUtilitiesMixin;
      if (!utils.isSenderMe(actionModel.userDetails?.userId)) return;
      if (_skipDeleteForAllLocalEcho(utils, actionModel)) return;
      final targetIds = _deleteForAllTargetIds(actionModel);
      if (targetIds.isEmpty) return;
      final targetIdSet = targetIds.toSet();
      final conversationId = actionModel.conversationId ?? '';
      await IsmChatConfig.dbWrapper?.updateConversation(
        conversationId: conversationId,
        update: (conversation) {
          if (conversation == null) return null;
          final allMessages =
              Map<String, IsmChatMessageModel>.from(conversation.messages ?? {});
          if (allMessages.isEmpty) return null;
          final beforeCount = allMessages.length;
          allMessages.removeWhere(
            (_, value) => targetIdSet.contains(value.messageId),
          );
          if (allMessages.length == beforeCount) return null;
          return _conversationWithResyncedLastMessage(
            conversation.copyWith(messages: allMessages),
            conversationId,
          );
        },
      );

      if (IsmChatUtility.chatPageControllerRegistered) {
        final controller = IsmChatUtility.chatPageController;
        if (controller.conversation?.conversationId ==
            actionModel.conversationId) {
          await controller.getMessagesFromDB(actionModel.conversationId ?? '');
          controller.update();
        }
      }
      if (IsmChatUtility.conversationControllerRegistered) {
        unawaited(
          IsmChatUtility.conversationController.getConversationsFromDB(),
        );
      }
    }
  }
}

/// Number of *other* participants that must acknowledge a message for it to be
/// considered delivered/read by all.
///
/// For 1-1 chats there is always exactly one other participant, so we must not
/// derive this from [IsmChatConversationModel.membersCount]: 1-1 conversations
/// are frequently created with `membersCount` of `1` or `null`, which made the
/// old `membersCount - 1` evaluate to `0`/`-1`. That never matched
/// `readBy.length`/`deliveredTo.length` (always 1 once the opponent acted), so
/// real-time delivered/read ticks stayed stuck until an API status re-sync.
/// Group behaviour is unchanged (`membersCount - 1`).
int _othersToAckCount(IsmChatConversationModel? conversation) {
  if (conversation?.isGroup ?? false) {
    return (conversation?.membersCount ?? 0) - 1;
  }
  return 1;
}

/// Loads the conversation row used by deliver/read guards and receipt updates.
Future<IsmChatConversationModel?> _conversationForStatusEvent(
  String? conversationId,
) async {
  final id = conversationId?.trim() ?? '';
  if (id.isEmpty) return null;
  return IsmChatConfig.dbWrapper?.getConversation(id);
}

/// Latest timeline row usable for conversation-list preview.
IsmChatMessageModel? _lastTimelineMessageForPreview(
  Iterable<IsmChatMessageModel> messages,
) {
  final sorted = messages.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  for (var i = sorted.length - 1; i >= 0; i--) {
    final m = sorted[i];
    switch (m.customType) {
      case IsmChatCustomMessageType.conversationCreated:
      case IsmChatCustomMessageType.date:
      case IsmChatCustomMessageType.block:
      case IsmChatCustomMessageType.unblock:
        continue;
      default:
        return m;
    }
  }
  return null;
}

/// Recomputes [IsmChatConversationModel.lastMessageDetails] after rows are removed.
IsmChatConversationModel _conversationWithResyncedLastMessage(
  IsmChatConversationModel conversation,
  String conversationId,
) {
  final last = _lastTimelineMessageForPreview(
    conversation.messages?.values ?? const [],
  );
  if (last == null) return conversation;
  final base = conversation.lastMessageDetails;
  final lastDetails = base != null
      ? base.copyWith(
          sentByMe: last.sentByMe,
          senderId: last.senderInfo?.userId ?? last.initiatorId ?? '',
          senderName: last.senderInfo?.userName ??
              last.userName ??
              last.initiatorName ??
              '',
          showInConversation: true,
          sentAt: last.sentAt,
          messageType: last.messageType?.value ?? 0,
          messageId: last.messageId ?? '',
          conversationId: last.conversationId ?? conversationId,
          body: IsmChatUtility.lastMessageBodyForConversationSync(last),
          customType: last.customType,
          action: last.action,
        )
      : LastMessageDetails(
          showInConversation: true,
          sentAt: last.sentAt,
          senderName: last.senderInfo?.userName ??
              last.userName ??
              last.initiatorName ??
              '',
          senderId: last.senderInfo?.userId ?? last.initiatorId ?? '',
          messageType: last.messageType?.value ?? 0,
          messageId: last.messageId ?? '',
          conversationId: last.conversationId ?? conversationId,
          body: IsmChatUtility.lastMessageBodyForConversationSync(last),
          sentByMe: last.sentByMe,
          customType: last.customType,
          action: last.action,
        );
  return conversation.copyWith(
    lastMessageDetails: lastDetails,
    lastMessageSentAt: last.sentAt,
  );
}

/// Target message ids from delete-for-all / delete-local MQTT payloads.
///
/// Brokers may send either `messageIds` or a single `messageId`.
List<String> _deleteForAllTargetIds(IsmChatMqttActionModel action) {
  final fromList = action.messageIds ?? const <String>[];
  if (fromList.isNotEmpty) return fromList;
  final single = action.messageId?.trim() ?? '';
  if (single.isNotEmpty) return [single];
  return const [];
}

/// Skip only when the delete was performed on **this** device.
///
/// Unlike deliver/read, delete-for-everyone must reach every device logged into
/// the same account. When `deviceId` is missing we apply the update rather than
/// fall back to user-only matching (that would keep other phones stale).
bool _skipDeleteForAllLocalEcho(
  IsmChatMqttEventUtilitiesMixin utils,
  IsmChatMqttActionModel action,
) {
  final deviceId = action.deviceId?.trim() ?? '';
  if (deviceId.isEmpty) return false;
  return utils.isSenderMe(action.userDetails?.userId, deviceId: deviceId);
}

/// Whether to ignore a deliver/read MQTT action from the logged-in user.
///
/// Self-chat acks use the same [userId] as the sender; 1:1 events from "me" are
/// still ignored (multi-device echoes).
bool _skipStatusUpdateForOwnUser(
  IsmChatMqttEventUtilitiesMixin utils,
  IsmChatMqttActionModel action,
  IsmChatConversationModel? conversation,
) {
  if (conversation?.isSelfChat == true) return false;
  return utils.isSenderMe(action.userDetails?.userId);
}

/// One stored row, addressed by the key already used in the conversation map.
///
/// Receipt handlers must write back to [storageKey]. Replacing the row under
/// the message timestamp key drops it when that key does not match the key
/// used at insert time.
class _StoredMessage {
  _StoredMessage(this.messages, this.storageKey, this.message);

  final Map<String, IsmChatMessageModel> messages;
  final String storageKey;
  final IsmChatMessageModel message;
}

_StoredMessage? _storedMessage(
  Map<String, IsmChatMessageModel>? source,
  String? messageId,
) {
  if (source == null || messageId == null || messageId.isEmpty) return null;
  for (final entry in source.entries) {
    if (entry.value.messageId == messageId) {
      return _StoredMessage(source, entry.key, entry.value);
    }
  }
  return null;
}
