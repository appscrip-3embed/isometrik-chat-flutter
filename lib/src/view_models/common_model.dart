// coverage:ignore-file
// Remaining branches need plugins, a live broker, or are documented parsing bugs.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatCommonViewModel {
  IsmChatCommonViewModel(this._repository);

  final IsmChatCommonRepository _repository;

  IsmChatConversationModel? chatPendingMessages;

  Future<int?> updatePresignedUrl({
    String? presignedUrl,
    Uint8List? bytes,
    bool isLoading = false,
  }) async {
    final respone = await _repository.updatePresignedUrl(
      presignedUrl: presignedUrl,
      bytes: bytes,
      isLoading: isLoading,
    );
    if (!(respone?.hasError == true)) {
      return respone?.errorCode;
    }
    return null;
  }

  Future<PresignedUrlModel?> getPresignedUrl({
    required bool isLoading,
    required String userIdentifier,
    required String mediaExtension,
    required Uint8List bytes,
  }) async {
    final responseGetPresigned = await _repository.getPresignedUrl(
      isLoading: isLoading,
      userIdentifier: userIdentifier,
      mediaExtension: mediaExtension,
    );
    if (responseGetPresigned != null) {
      final response = await updatePresignedUrl(
        bytes: bytes,
        isLoading: isLoading,
        presignedUrl: responseGetPresigned.presignedUrl,
      );
      if (response == 200) {
        return responseGetPresigned;
      }
    }
    return null;
  }

  /// Presign (+ PUT) with same-name / storage-quota branching.
  Future<SameNameUploadOutcome?> postMediaUrlWithSameNameHandling({
    required String conversationId,
    required String nameWithExtension,
    required int mediaType,
    required String mediaId,
    required bool isLoading,
    required Uint8List bytes,
    bool isUpdateThumbnail = false,
    int conversationType = 0,
  }) =>
      IsmChatSameNameAttachmentUpload.resolveAndUpload(
        fileBytes: bytes.length,
        isThumbnailPresign: isUpdateThumbnail,
        presign: ({required bool forceUpload}) async {
          final result = await _repository.requestMessagePresignedUrls(
            conversationId: conversationId,
            nameWithExtension: nameWithExtension,
            mediaType: mediaType,
            mediaId: mediaId,
            isLoading: isLoading,
            conversationType: conversationType,
            forceUpload: forceUpload,
          );
          if (result.response.hasError) {
            await IsmChatStorageQuotaGuard.handleResponseIfQuota(
              result.response,
            );
            return null;
          }
          final urls = result.urls;
          if (urls == null || urls.isEmpty) {
            return null;
          }
          return urls.first;
        },
        putBytes: (presignedPutUrl, Uint8List data) => updatePresignedUrl(
          presignedUrl: presignedPutUrl,
          bytes: data,
          isLoading: isLoading,
        ),
        mediaBytes: bytes,
      );

  Future<PresignedUrlModel?> postMediaUrl({
    required String conversationId,
    required String nameWithExtension,
    required int mediaType,
    required String mediaId,
    required bool isLoading,
    required Uint8List bytes,
    bool isUpdateThumbnail = false,
    int conversationType = 0,
  }) async {
    final outcome = await postMediaUrlWithSameNameHandling(
      conversationId: conversationId,
      nameWithExtension: nameWithExtension,
      mediaType: mediaType,
      mediaId: mediaId,
      isLoading: isLoading,
      bytes: bytes,
      isUpdateThumbnail: isUpdateThumbnail,
      conversationType: conversationType,
    );
    if (outcome == null || outcome.cancelled) {
      return null;
    }
    return outcome.presigned;
  }

  Future<bool> sendMessage({
    required bool showInConversation,
    required int messageType,
    required bool encrypted,
    required String deviceId,
    required String conversationId,
    required String body,
    required int createdAt,
    required String notificationBody,
    required String notificationTitle,
    required String customType,
    String? parentMessageId,
    IsmChatMetaData? metaData,
    List<Map<String, dynamic>>? mentionedUsers,
    Map<String, dynamic>? events,
    List<Map<String, dynamic>>? attachments,
    List<String>? searchableTags,
    bool isBroadcast = false,
    bool isUpdateMesage = true,
  }) async {
    try {
      final response = await _repository.sendMessage(
        showInConversation: showInConversation,
        attachments: attachments,
        events: events,
        mentionedUsers: mentionedUsers,
        metaData: metaData,
        messageType: messageType,
        customType: customType,
        parentMessageId: parentMessageId,
        encrypted: encrypted,
        deviceId: deviceId,
        conversationId: conversationId,
        notificationBody: notificationBody,
        notificationTitle: notificationTitle,
        body: body,
        searchableTags: searchableTags,
      );
      if (response == null) return false;
      if (!isUpdateMesage) return false;
      if (isBroadcast) {
        final chatPageController = IsmChatUtility.chatPageController;
        // If server rejected the message, mark it invalid so UI shows error icon.
        if (response.respone.hasError == true) {
          for (var x = 0; x < chatPageController.messages.length; x++) {
            final msg = chatPageController.messages[x];
            if (msg.sentAt != createdAt || msg.messageId?.isNotEmpty == true) {
              continue;
            }
            msg
              ..messageId = ''
              ..isInvalidMessage = true
              ..isUploading = false;
            chatPageController.messages[x] = msg;
            break;
          }
          return false;
        }
        for (var x = 0; x < chatPageController.messages.length; x++) {
          var messages = chatPageController.messages[x];
          if (messages.messageId?.isNotEmpty == true ||
              messages.sentAt != createdAt) {
            continue;
          }
          messages
            ..messageId = response.messageId
            ..deliveredToAll = false
            ..readByAll = false
            ..isUploading = false;
          chatPageController.messages[x] = messages;
        }
      } else {
        final dbBox = IsmChatConfig.dbWrapper;
        final chatPendingMessagesData = await dbBox
            ?.getConversation(conversationId, dbBox: IsmChatDbBox.pending);
        if (chatPendingMessagesData != null) {
          chatPendingMessages = chatPendingMessagesData;
        }
        final pendingMessage = chatPendingMessages?.messages?['$createdAt'];
        if (pendingMessage != null &&
            [200, 403].contains(response.respone.errorCode)) {
          if (response.messageId.isNotEmpty) {
            pendingMessage
              ..messageId = response.messageId
              ..deliveredToAll = false
              ..readByAll = false
              ..isUploading = false;

            // Update attachments with server URLs (from ismPostMediaUrl)
            // This replaces local file paths with server URLs after media upload
            if (attachments != null && attachments.isNotEmpty) {
              final updatedAttachments =
                  attachments.map(AttachmentModel.fromMap).toList();
              pendingMessage.attachments = updatedAttachments;
            }
          } else if (response.respone.errorCode == 403) {
            final quotaHandled =
                await IsmChatStorageQuotaGuard.handleResponseIfQuota(
              response.respone,
            );
            if (quotaHandled) {
              // Storage quota — keep pending draft for retry (same-name handoff).
              pendingMessage
                ..messageId = ''
                ..isInvalidMessage = false
                ..isUploading = true;
              if (chatPendingMessages != null) {
                await dbBox?.saveConversation(
                  conversation: chatPendingMessages!,
                  dbBox: IsmChatDbBox.pending,
                );
              }
              return false;
            }
            pendingMessage
              ..messageId = ''
              ..isInvalidMessage = true;
            // Profanity (`errorCode` 3): only surface the API error text.
            if (response.respone.isProfanityBlocked) {
              unawaited(
                IsmChatUtility.showErrorDialog(
                  response.respone.apiErrorMessage(
                    fallback: 'Message not sent',
                  ),
                ),
              );
            }
          }
          chatPendingMessages?.messages
              ?.removeWhere((key, value) => key == '$createdAt');
          await dbBox?.saveConversation(
              conversation: chatPendingMessages!, dbBox: IsmChatDbBox.pending);
          if (chatPendingMessages?.messages?.isEmpty == true) {
            await dbBox?.pendingMessageBox
                .delete(chatPendingMessages?.conversationId ?? '');
          }
          // Slack-style threads: a reply that lives only in a thread is stored
          // like any message (so it survives a restart and the panel can show
          // it), but it must not become the conversation's preview — the
          // channel timeline filters it out either way.
          final isThreadOnlyReply =
              IsmChatThreadCoordinator.isThreadOnlyReply(pendingMessage);
          var conversationModel = await dbBox?.getConversation(conversationId);
          if (conversationModel != null) {
            final messages = (conversationModel.messages ?? {})
              ..addEntries({'$createdAt': pendingMessage}.entries);
            conversationModel = conversationModel.copyWith(
              lastMessageDetails: isThreadOnlyReply
                  ? conversationModel.lastMessageDetails
                  : conversationModel.lastMessageDetails?.copyWith(
                      reactionType: '',
                      messageId: pendingMessage.messageId,
                      action: '',
                    ),
              messages: messages,
            );
          }
          await dbBox?.saveConversation(conversation: conversationModel!);
          // Hand the server id to the open thread panel so its optimistic row
          // becomes a real message and the root badge moves once.
          if (isThreadOnlyReply && response.messageId.isNotEmpty) {
            IsmChatThreadController.instance?.confirmLocalReply(
              sentAt: createdAt,
              messageId: response.messageId,
            );
          }
          return true;
        }
        // Server rejected message -> mark it failed so UI shows error icon
        // instead of clock forever, and stop retrying automatically.
        if (pendingMessage != null && response.respone.hasError == true) {
          final quotaHandled =
              await IsmChatStorageQuotaGuard.handleResponseIfQuota(
            response.respone,
          );
          if (quotaHandled) {
            pendingMessage
              ..messageId = ''
              ..isInvalidMessage = false
              ..isUploading = true;
            if (chatPendingMessages != null) {
              await dbBox?.saveConversation(
                conversation: chatPendingMessages!,
                dbBox: IsmChatDbBox.pending,
              );
            }
            return false;
          }

          pendingMessage
            ..messageId = ''
            ..isInvalidMessage = true
            ..isUploading = false;
          // Same failure UI inside the thread panel.
          if (IsmChatThreadCoordinator.isThreadOnlyReply(pendingMessage)) {
            IsmChatThreadController.instance?.mutateLocalReply(
              createdAt,
              (row) {
                row
                  ..messageId = ''
                  ..isInvalidMessage = true
                  ..isUploading = false;
                return true;
              },
              onlyUnsent: true,
            );
          }

          chatPendingMessages?.messages
              ?.removeWhere((key, value) => key == '$createdAt');
          await dbBox?.saveConversation(
            conversation: chatPendingMessages!,
            dbBox: IsmChatDbBox.pending,
          );
          if (chatPendingMessages?.messages?.isEmpty == true) {
            await dbBox?.pendingMessageBox
                .delete(chatPendingMessages?.conversationId ?? '');
          }

          // Persist the failed message into main conversation so the user sees it.
          var conversationModel = await dbBox?.getConversation(conversationId);
          if (conversationModel != null) {
            final messages = (conversationModel.messages ?? {})
              ..addEntries({'$createdAt': pendingMessage}.entries);
            conversationModel = conversationModel.copyWith(
              messages: messages,
              lastMessageDetails:
                  conversationModel.lastMessageDetails?.copyWith(
                reactionType: '',
                messageId: '',
                action: '',
                customType: pendingMessage.customType,
                body: pendingMessage.body,
                sentAt: pendingMessage.sentAt,
              ),
              lastMessageSentAt: pendingMessage.sentAt,
            );
            await dbBox?.saveConversation(conversation: conversationModel);
          }

          // Show the API error text (not a static "Message not sent").
          // [IsmChatResponseModel.apiErrorMessage] also covers nested keys.
          final message = response.respone.apiErrorMessage(
            fallback: [413, 422].contains(response.respone.errorCode)
                ? 'Message is too long to send.'
                : 'Message not sent',
          );
          unawaited(IsmChatUtility.showErrorDialog(message));

          return false;
        }
      }
      return false;
    } catch (e, st) {
      IsmChatLog.error(e, st);
      return false;
    }
  }

  Future<(bool, IsmChatResponseModel?)> sendPaidWalletMessage({
    required bool showInConversation,
    required int messageType,
    required bool encrypted,
    required String deviceId,
    required String conversationId,
    required String body,
    required String notificationBody,
    required String notificationTitle,
    required int createdAt,
    required String customType,
    String? parentMessageId,
    Map<String, dynamic>? metaData,
    List<Map<String, dynamic>>? mentionedUsers,
    Map<String, dynamic>? events,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final response = await _repository.sendPaidWalletMessage(
        showInConversation: showInConversation,
        messageType: messageType,
        encrypted: encrypted,
        deviceId: deviceId,
        conversationId: conversationId,
        body: body,
        notificationBody: notificationBody,
        notificationTitle: notificationTitle,
        attachments: attachments,
        customType: customType,
        events: events,
        mentionedUsers: mentionedUsers,
        parentMessageId: parentMessageId,
        metaData: metaData,
      );
      if (response == null) return (false, response?.$2);
      final dbBox = IsmChatConfig.dbWrapper;
      final chatPendingMessagesData = await dbBox
          ?.getConversation(conversationId, dbBox: IsmChatDbBox.pending);
      if (chatPendingMessagesData != null) {
        chatPendingMessages = chatPendingMessagesData;
      }

      final pendingMessage = chatPendingMessages?.messages?['$createdAt'];
      if (pendingMessage != null) {
        pendingMessage
          ..messageId = response.$1
          ..deliveredToAll = false
          ..readByAll = false
          ..isUploading = false;
        chatPendingMessages?.messages
            ?.removeWhere((key, value) => key == '$createdAt');
        await dbBox?.saveConversation(
            conversation: chatPendingMessages!, dbBox: IsmChatDbBox.pending);
        if (chatPendingMessages?.messages?.isEmpty == true) {
          await dbBox?.pendingMessageBox
              .delete(chatPendingMessages?.conversationId ?? '');
        }
        var conversationModel = await dbBox?.getConversation(conversationId);
        if (conversationModel != null) {
          final messages = (conversationModel.messages ?? {})
            ..addEntries({'$createdAt': pendingMessage}.entries);
          conversationModel = conversationModel.copyWith(
            lastMessageDetails: conversationModel.lastMessageDetails?.copyWith(
              reactionType: '',
              messageId: pendingMessage.messageId,
            ),
            messages: messages,
          );
        }
        await dbBox?.saveConversation(conversation: conversationModel!);
      }
      return (true, response.$2);
    } catch (e, st) {
      IsmChatLog.error(e, st);
      return (false, null);
    }
  }

  List<IsmChatMessageModel> sortMessages(List<IsmChatMessageModel> messages) {
    // Date rows are UI-only; strip any persisted/in-memory copies before
    // re-inserting so unblock/reload flows do not show duplicate date stamps.
    final withoutDateStamps = messages
        .where((m) => m.customType != IsmChatCustomMessageType.date)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    return _parseMessagesWithDate(withoutDateStamps);
  }

  List<IsmChatMessageModel> _parseMessagesWithDate(
    List<IsmChatMessageModel> messages,
  ) {
    if (messages.isEmpty) {
      return [];
    }

    final dayGroups = <List<IsmChatMessageModel>>[];
    var currentGroup = <IsmChatMessageModel>[messages.first];

    for (var index = 1; index < messages.length; index++) {
      final previous = messages[index - 1];
      final current = messages[index];
      final sameDay = DateTime.fromMillisecondsSinceEpoch(previous.sentAt)
          .isSameDay(DateTime.fromMillisecondsSinceEpoch(current.sentAt));
      if (sameDay) {
        currentGroup.add(current);
      } else {
        dayGroups.add(currentGroup);
        currentGroup = [current];
      }
    }
    dayGroups.add(currentGroup);

    final allMessages = <IsmChatMessageModel>[];
    for (final group in dayGroups) {
      allMessages
        ..add(IsmChatMessageModel.fromDate(group.first.sentAt))
        ..addAll(group);
    }
    return allMessages;
  }

  Future<IsmChatResponseModel?> createConversation({
    required bool typingEvents,
    required bool readEvents,
    required bool pushNotifications,
    required List<String> members,
    required bool isGroup,
    required int conversationType,
    List<String>? searchableTags,
    Map<String, dynamic>? metaData,
    String? conversationTitle,
    String? conversationImageUrl,
    String? customType,
    bool selfChat = false,
    bool isLoading = false,
  }) async =>
      await _repository.createConversation(
        typingEvents: typingEvents,
        readEvents: readEvents,
        pushNotifications: pushNotifications,
        members: members,
        isGroup: isGroup,
        metaData: metaData,
        conversationType: conversationType,
        conversationImageUrl: conversationImageUrl,
        conversationTitle: conversationTitle,
        isLoading: isLoading,
        customType: customType,
        searchableTags: searchableTags,
        selfChat: selfChat,
      );

  Future<List<IsmChatMessageModel>> getChatMessages({
    required String conversationId,
    int? lastMessageTimestamp,
    int limit = 20,
    int skip = 0,
    String? searchText,
    bool isLoading = false,
  }) async {
    var messages = await _repository.getChatMessages(
      conversationId: conversationId,
      lastMessageTimestamp: lastMessageTimestamp,
      limit: limit,
      skip: skip,
      searchText: searchText,
      isLoading: isLoading,
    );

    if (messages == null) {
      return [];
    }
    messages.removeWhere((e) => [
          IsmChatActionEvents.clearConversation.name,
          IsmChatActionEvents.deleteConversationLocally.name,
          IsmChatActionEvents.reactionAdd.name,
          IsmChatActionEvents.reactionRemove.name,
          IsmChatActionEvents.conversationDetailsUpdated.name,
        ].contains(e.action));
    messages = sortMessages(messages);
    return messages;
  }
}
