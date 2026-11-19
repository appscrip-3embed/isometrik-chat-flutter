import 'dart:convert';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Data access for Slack-style threads (`chat-messages` v1.1.0+).
///
/// Three calls, all on endpoints the SDK already uses — threading is new query
/// params and new body fields, not new routes:
///
/// | Method | Request |
/// |---|---|
/// | [getThreadMessages] | `GET /chat/messages?feedType=thread&threadRootId=…` |
/// | [getThreadReplyCount] | `GET /chat/messages/count?threadRootId=…` |
/// | [sendThreadReply] | `POST /chat/message` with `messageType: 2` |
///
/// Nothing here is called while [IsmChatConfig.threadsEnabled] is `false`.
///
/// **See also:** [IsmChatThreadViewModel], [IsmChatThreadController],
/// [IsmChatPageRepository.getChatMessages] (the channel timeline, which gains
/// `feedType=main` when threads are on), `docs/THREADS.md`.
class IsmChatThreadRepository {
  /// Creates the repository. `apiWrapper` exists for test injection; production
  /// code uses the default.
  IsmChatThreadRepository({IsmChatApiWrapper? apiWrapper})
      : _apiWrapper = apiWrapper ?? IsmChatApiWrapper();

  final IsmChatApiWrapper _apiWrapper;

  /// Loads one thread: every reply whose `threadRootId` is [threadRootId],
  /// including replies-to-replies.
  ///
  /// - [sort] `1` is oldest-first (how a thread panel reads); `-1` newest-first.
  /// - [skip] / [limit] page the thread; the server caps nothing beyond the
  ///   usual message limits.
  ///
  /// Returns `null` on transport / server error (callers keep the current list
  /// and surface a retry), an empty list when the thread has no replies.
  Future<List<IsmChatMessageModel>?> getThreadMessages({
    required String conversationId,
    required String threadRootId,
    int limit = 20,
    int skip = 0,
    int sort = 1,
    bool isLoading = false,
  }) async {
    if (conversationId.trim().isEmpty || threadRootId.trim().isEmpty) {
      return null;
    }
    try {
      final url = '${IsmChatAPI.chatMessages}'
          '?conversationId=$conversationId'
          '&feedType=${IsmChatFeedType.thread.queryValue}'
          '&threadRootId=$threadRootId'
          '&sort=$sort&limit=$limit&skip=$skip';
      final response = await _apiWrapper.get(
        url,
        headers: IsmChatUtility.tokenCommonHeader(),
        showLoader: isLoading,
      );
      if (response.hasError) {
        // A brand-new thread often returns HTTP 404 before the first reply.
        // Treat that as an empty page, not a hard load failure.
        if (_isEmptyThreadFetch(response)) return [];
        return null;
      }
      final data = jsonDecode(response.data);
      final messages = (data as Map<String, dynamic>)['messages'];
      if (messages is! List) return [];
      return messages
          .map((e) => IsmChatMessageModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      IsmChatLog.error('GetThreadMessages $e', st);
      return null;
    }
  }

  /// Benign errors that mean "this thread exists but has no replies yet".
  static bool _isEmptyThreadFetch(IsmChatResponseModel response) =>
      response.errorCode == 404;

  /// Server count of every reply in the thread rooted at [threadRootId].
  ///
  /// Prefer the root message's `replyCount` when you already have it; this is
  /// the authoritative re-check (e.g. after opening a thread from a push).
  /// Returns `null` when the call fails.
  Future<int?> getThreadReplyCount({
    required String conversationId,
    required String threadRootId,
  }) async {
    if (conversationId.trim().isEmpty || threadRootId.trim().isEmpty) {
      return null;
    }
    try {
      final response = await _apiWrapper.get(
        '${IsmChatAPI.chatMessagesCount}'
        '?conversationId=$conversationId&threadRootId=$threadRootId',
        headers: IsmChatUtility.tokenCommonHeader(),
      );
      if (response.hasError) {
        return null;
      }
      final data = jsonDecode(response.data);
      if (data is! Map) return null;
      final count = data['messagesCount'] ?? data['count'] ?? data['total'];
      if (count is num) return count.toInt();
      if (count is String) return int.tryParse(count);
      return null;
    } catch (e, st) {
      IsmChatLog.error('GetThreadReplyCount $e', st);
      return null;
    }
  }

  /// Posts a thread reply.
  ///
  /// - [parentMessageId] is the **immediate** parent (root, or another reply);
  ///   the server derives `threadRootId` from it.
  /// - [showInConversation] `false` keeps the reply in the thread only; `true`
  ///   is Slack's "also send to channel"
  ///   ([IsmChatThreadCoordinator.showInConversationForReply]).
  ///
  /// Returns the new `messageId` plus the raw response so callers can surface
  /// server errors (e.g. `404 errorCode: 1` — parent not found in this
  /// conversation). `null` only on an unexpected exception.
  Future<({String messageId, IsmChatResponseModel response})?> sendThreadReply({
    required String conversationId,
    required String parentMessageId,
    required String body,
    required bool showInConversation,
    required String deviceId,
    required String customType,
    required String notificationBody,
    required String notificationTitle,
    bool encrypted = false,
    bool sendPushNotification = true,
    IsmChatMetaData? metaData,
    List<Map<String, dynamic>>? attachments,
    List<Map<String, dynamic>>? mentionedUsers,
    List<String>? searchableTags,
  }) async {
    try {
      final fcmNotificationBody = encrypted
          ? IsmChatUtility.resolveEncryptedNotificationBody(
              notificationBody: notificationBody,
              body: body,
              conversationId: conversationId,
            )
          : notificationBody;
      final payload = {
        'showInConversation': showInConversation,
        'messageType': IsmChatMessageType.reply.value,
        'encrypted': encrypted,
        'deviceId': deviceId,
        'conversationId': conversationId,
        'body': body,
        'parentMessageId': parentMessageId,
        'customType': customType,
        'metaData': IsmChatSensitiveContentMasker.stripLocalUnmaskedFromMeta(
          metaData,
        )?.toMap(),
        'events': {
          'updateUnreadCount': true,
          'sendPushNotification': sendPushNotification,
        },
        'attachments': attachments,
        'notificationBody': fcmNotificationBody,
        'notificationTitle': notificationTitle,
        if (searchableTags != null)
          'searchableTags': searchableTags
        else if (!encrypted)
          'searchableTags': [body],
        'mentionedUsers': mentionedUsers,
      }.removeNullValues();

      final response = await _apiWrapper.post(
        IsmChatAPI.sendMessage,
        payload: payload,
        headers: IsmChatUtility.tokenCommonHeader(),
      );
      if (response.hasError) {
        IsmChatLog.error(
          'sendThreadReply API rejected parent=$parentMessageId '
          'code=${response.errorCode} body=${response.data}',
        );
        return (messageId: '', response: response);
      }
      final data = jsonDecode(response.data);
      final messageId = (data as Map<String, dynamic>)['messageId'] as String?;
      return (messageId: messageId ?? '', response: response);
    } catch (e, st) {
      IsmChatLog.error('SendThreadReply $e', st);
      return null;
    }
  }
}
