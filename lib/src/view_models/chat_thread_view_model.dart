import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Business rules between [IsmChatThreadController] and
/// [IsmChatThreadRepository].
///
/// Keeps the controller free of transport concerns and applies the same
/// response hygiene the channel timeline uses (drop action-only rows, drop
/// locally-managed block banners), so a thread panel never renders a system
/// row the chat page would have filtered out.
///
/// Thread replies are **not** written to the local database: a thread is
/// fetched on open and kept in memory for the life of the panel. That keeps the
/// cached conversation (and therefore the channel timeline, unread counts and
/// previews) exactly as it is today — see `docs/THREADS.md`.
class IsmChatThreadViewModel {
  IsmChatThreadViewModel(this._repository);

  final IsmChatThreadRepository _repository;

  /// Action events that are state changes, not chat rows.
  static const _ignoredActions = [
    'clearConversation',
    'deleteConversationLocally',
    'reactionAdd',
    'reactionRemove',
    'conversationDetailsUpdated',
    'messageDetailsUpdated',
  ];

  /// Loads one page of a thread, oldest-first by default.
  ///
  /// Returns `null` when the request failed (the controller keeps what it has
  /// and shows a retry), otherwise the renderable replies for that page.
  Future<List<IsmChatMessageModel>?> getThreadMessages({
    required String conversationId,
    required String threadRootId,
    int limit = 20,
    int skip = 0,
    int sort = 1,
  }) async {
    final messages = await _repository.getThreadMessages(
      conversationId: conversationId,
      threadRootId: threadRootId,
      limit: limit,
      skip: skip,
      sort: sort,
    );
    if (messages == null) return null;
    return sanitize(messages);
  }

  /// Drops rows a thread panel must never show. Exposed for tests.
  static List<IsmChatMessageModel> sanitize(
    List<IsmChatMessageModel> messages,
  ) =>
      List<IsmChatMessageModel>.from(messages)
        ..removeWhere((e) => _ignoredActions.contains(e.action))
        ..removeWhere(IsmChatBlockUnblockCoordinator.isBannerMessage)
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

  /// Authoritative reply count for a thread, or `null` when the call failed.
  Future<int?> getThreadReplyCount({
    required String conversationId,
    required String threadRootId,
  }) =>
      _repository.getThreadReplyCount(
        conversationId: conversationId,
        threadRootId: threadRootId,
      );

  /// Sends a reply into the thread rooted at the parent of [parentMessageId].
  ///
  /// [alsoSendToChannel] mirrors Slack's checkbox: the reply is posted with
  /// `showInConversation: true` so it shows in the channel timeline as well as
  /// in the thread.
  Future<({String messageId, IsmChatResponseModel response})?> sendThreadReply({
    required String conversationId,
    required String parentMessageId,
    required String body,
    required bool alsoSendToChannel,
    required String deviceId,
    required String notificationTitle,
    required String notificationBody,
    bool encrypted = false,
    IsmChatMetaData? metaData,
    List<Map<String, dynamic>>? mentionedUsers,
  }) =>
      _repository.sendThreadReply(
        conversationId: conversationId,
        parentMessageId: parentMessageId,
        body: body,
        showInConversation:
            IsmChatThreadCoordinator.showInConversationForReply(
          alsoSendToChannel: alsoSendToChannel,
        ),
        deviceId: deviceId,
        customType: IsmChatCustomMessageType.text.name,
        notificationBody: notificationBody,
        notificationTitle: notificationTitle,
        encrypted: encrypted,
        metaData: metaData,
        mentionedUsers: mentionedUsers,
      );
}
