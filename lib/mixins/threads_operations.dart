part of '../isometrik_chat_flutter.dart';

/// Slack-style threading operations for [IsmChat].
///
/// The public surface host apps use to switch threads on, open a thread panel,
/// and read or post thread replies headlessly.
///
/// ```dart
/// // 1. Turn the threaded interface on (or pass threadsEnabled: true to initialize)
/// await IsmChat.i.setThreadsEnabled(true);
///
/// // 2. Open the thread of a message (the SDK does this from the UI too)
/// await IsmChat.i.openThread(message);
///
/// // 3. Or drive threads from your own UI
/// final replies = await IsmChat.i.getThreadReplies(
///   conversationId: message.conversationId!,
///   threadRootId: message.messageId!,
/// );
/// await IsmChat.i.sendThreadReply(parent: message, text: 'On it');
/// ```
///
/// With threads off ([IsmChatConfig.threadsEnabled] = `false`, the default)
/// the reads return empty, the sends return `false`, and the chat behaves
/// exactly as it does today.
///
/// See `docs/THREADS.md` for the full data model and backend contract.
mixin IsmChatThreadsOperationsMixin {
  /// Gets the delegate instance.
  IsmChatDelegate get _delegate =>
      (this as dynamic)._delegate as IsmChatDelegate;

  /// Whether the Slack-style thread interface is currently on.
  bool get threadsEnabled => _delegate.threadsEnabled;

  /// Turns threading on/off at runtime and refreshes the open chat.
  ///
  /// Use this for a settings switch (see [IsmChatThreadsToggleTile]); pass
  /// `threadsEnabled` to [IsmChat.initialize] for the startup value.
  Future<void> setThreadsEnabled(bool value) =>
      _delegate.setThreadsEnabled(value);

  /// Opens the thread panel for [message] (route on mobile, dialog on web).
  Future<void> openThread(
    IsmChatMessageModel message, {
    IsmChatConversationModel? conversation,
  }) =>
      _delegate.openThread(message, conversation: conversation);

  /// Root message of the thread panel currently open, or `null`.
  IsmChatMessageModel? get openThreadRoot => _delegate.openThreadRoot;

  /// Reads one page of a thread (oldest-first). Empty when threads are off.
  Future<List<IsmChatMessageModel>> getThreadReplies({
    required String conversationId,
    required String threadRootId,
    int limit = 20,
    int skip = 0,
  }) =>
      _delegate.getThreadReplies(
        conversationId: conversationId,
        threadRootId: threadRootId,
        limit: limit,
        skip: skip,
      );

  /// Server count of all replies in a thread, or `null` when unavailable.
  Future<int?> getThreadReplyCount({
    required String conversationId,
    required String threadRootId,
  }) =>
      _delegate.getThreadReplyCount(
        conversationId: conversationId,
        threadRootId: threadRootId,
      );

  /// Posts [text] in [parent]'s thread. [alsoSendToChannel] mirrors Slack's
  /// "Also send to channel" (the reply also lands in the main timeline).
  Future<bool> sendThreadReply({
    required IsmChatMessageModel parent,
    required String text,
    bool alsoSendToChannel = false,
  }) =>
      _delegate.sendThreadReply(
        parent: parent,
        text: text,
        alsoSendToChannel: alsoSendToChannel,
      );
}
