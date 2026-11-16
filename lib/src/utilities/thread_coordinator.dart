import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Single source of truth for Slack-style threading rules.
///
/// Every threading decision the SDK makes — which messages belong in the
/// channel timeline, which `feedType` to request, what a reply's
/// `threadRootId` / `showInConversation` must be, and how a root's
/// `replyCount` moves — lives here as a pure function, so the chat page, the
/// thread panel, the MQTT handlers and host apps can never drift apart.
///
/// **Dormant by default.** Every method is a no-op passthrough while
/// [IsmChatConfig.threadsEnabled] is `false`: timelines are not filtered, no
/// `feedType` is sent, and no footer is shown. That is what keeps the existing
/// chat experience bit-for-bit unchanged for integrations that do not opt in.
///
/// Backend contract (`chat-messages` v1.1.0+):
/// - a reply is `messageType: 2` + `parentMessageId` (the immediate parent),
/// - the server derives `threadRootId` (always the thread root),
/// - `showInConversation: false` keeps it out of the channel timeline,
///   `true` is Slack's "also send to channel",
/// - the root message carries `replyCount` / `lastThreadReplyAt`,
/// - deleting a root that still has replies fails with
///   [rootHasRepliesErrorCode].
///
/// See also: `docs/THREADS.md`, [IsmChatThreadController],
/// [IsmChatBlockUnblockCoordinator] (same coordinator pattern).
class IsmChatThreadCoordinator {
  const IsmChatThreadCoordinator._(); // coverage:ignore-line

  /// Application error code returned by `DELETE /chat/message` when the target
  /// is a thread root that still has replies.
  static const int rootHasRepliesErrorCode = 4;

  /// Whether threading is switched on for this app ([IsmChatConfig.threadsEnabled]).
  static bool get isEnabled => IsmChatConfig.threadsEnabled;

  /// Whether threading is on **and** the host kept
  /// [IsmChatFeature.threadReply] in `IsmChatPageProperties.features`.
  ///
  /// Gates the UI entry points (focus-menu action, "N replies" footer) only —
  /// data-level rules use [isEnabled] so fetches and realtime stay consistent
  /// even when a host hides the buttons.
  static bool get isUiEnabled =>
      isEnabled &&
      IsmChatProperties.chatPageProperties.features
          .contains(IsmChatFeature.threadReply);

  /// `feedType` for the channel timeline: [IsmChatFeedType.main] with threads
  /// on, `null` (no param, legacy behavior) with threads off.
  static IsmChatFeedType? get timelineFeedType =>
      isEnabled ? IsmChatFeedType.main : null;

  // --------------------------------------------------------------- classify

  /// Whether [message] is a reply that belongs to a thread.
  ///
  /// Requires both `messageType: 2` and a non-empty `threadRootId`, so legacy
  /// inline quotes (reply type, no `threadRootId`) are *not* treated as thread
  /// replies and keep rendering inline as they do today.
  static bool isThreadReply(IsmChatMessageModel? message) {
    if (message == null) return false;
    if (message.messageType != IsmChatMessageType.reply) return false;
    return (message.threadRootId ?? '').trim().isNotEmpty;
  }

  /// A thread reply that the sender did **not** also post to the channel
  /// (`showInConversation: false`) — thread panel only.
  static bool isThreadOnlyReply(IsmChatMessageModel? message) =>
      isThreadReply(message) && message?.showInConversation == false;

  /// Whether [message] must be kept out of the channel timeline.
  ///
  /// Always `false` while threads are off, which is why disabling the feature
  /// restores the inline behavior for messages already in the local database.
  static bool shouldHideFromTimeline(IsmChatMessageModel? message) =>
      isEnabled && isThreadOnlyReply(message);

  /// Removes thread-only replies from a timeline list (no-op when threads are
  /// off). Returns a new list; the input is left untouched.
  static List<IsmChatMessageModel> filterTimeline(
    List<IsmChatMessageModel> messages,
  ) {
    if (!isEnabled) return List<IsmChatMessageModel>.from(messages);
    return messages.where((e) => !shouldHideFromTimeline(e)).toList();
  }

  /// [filterTimeline] for the `conversationId → messages` map stored in the
  /// local database.
  static Map<String, IsmChatMessageModel> filterTimelineMap(
    Map<String, IsmChatMessageModel> messages,
  ) {
    if (!isEnabled) return Map<String, IsmChatMessageModel>.from(messages);
    return Map<String, IsmChatMessageModel>.from(messages)
      ..removeWhere((_, value) => shouldHideFromTimeline(value));
  }

  // ------------------------------------------------------------- thread ids

  /// The thread a message belongs to: its own `threadRootId` when it is a
  /// reply, otherwise its own `messageId` (it is the root).
  ///
  /// Empty string when neither is known (e.g. an un-sent local message).
  static String threadIdOf(IsmChatMessageModel? message) {
    if (message == null) return '';
    final rootId = (message.threadRootId ?? '').trim();
    if (rootId.isNotEmpty) return rootId;
    return (message.messageId ?? '').trim();
  }

  /// Client-side mirror of the server's `threadRootId` derivation, used for the
  /// optimistic local echo before the send response arrives.
  ///
  /// `parent.threadRootId` when replying to a reply, else `parent.messageId`.
  /// The server value always wins once the message is re-fetched.
  static String resolveThreadRootId(IsmChatMessageModel parent) =>
      threadIdOf(parent);

  /// Whether a thread can be opened for [message] at all: threading on, a real
  /// server message id, and not a deleted / system row.
  static bool canOpenThread(IsmChatMessageModel? message) {
    if (!isEnabled || message == null) return false;
    if ((message.messageId ?? '').trim().isEmpty) return false;
    return !const [
      IsmChatCustomMessageType.deletedForEveryone,
      IsmChatCustomMessageType.deletedForMe,
      IsmChatCustomMessageType.date,
      IsmChatCustomMessageType.conversationCreated,
      IsmChatCustomMessageType.block,
      IsmChatCustomMessageType.unblock,
    ].contains(message.customType);
  }

  // ------------------------------------------------------------ reply count

  /// `replyCount` of [message], treating `null` (legacy / unknown) as `0`.
  static int replyCountOf(IsmChatMessageModel? message) =>
      message?.replyCount ?? 0;

  /// Whether [message] roots a thread that already has replies.
  static bool hasThreadReplies(IsmChatMessageModel? message) =>
      replyCountOf(message) > 0;

  /// Whether the channel timeline should show the "N replies" footer for
  /// [message] ([IsmChatThreadFooter]).
  static bool shouldShowFooter(IsmChatMessageModel? message) =>
      isUiEnabled && hasThreadReplies(message) && canOpenThread(message);

  /// Root document after a reply lands: `replyCount + 1` and
  /// `lastThreadReplyAt` moved forward (never backwards, so out-of-order
  /// realtime events cannot rewind the badge).
  static IsmChatMessageModel applyReplyToRoot(
    IsmChatMessageModel root,
    IsmChatMessageModel reply,
  ) {
    final previous = root.lastThreadReplyAt ?? 0;
    return root.copyWith(
      replyCount: replyCountOf(root) + 1,
      lastThreadReplyAt: reply.sentAt > previous ? reply.sentAt : previous,
    );
  }

  /// Root document after one of its replies is deleted (never below `0`).
  static IsmChatMessageModel applyReplyRemovalToRoot(
    IsmChatMessageModel root,
  ) {
    final next = replyCountOf(root) - 1;
    return root.copyWith(replyCount: next < 0 ? 0 : next);
  }

  /// Applies [applyReplyToRoot] to the root of [reply] inside a local database
  /// messages map. Returns a new map; unchanged when the root is not cached
  /// (the next fetch brings the server count).
  static Map<String, IsmChatMessageModel> applyReplyToRootInMap(
    Map<String, IsmChatMessageModel> messages,
    IsmChatMessageModel reply,
  ) {
    final rootId = (reply.threadRootId ?? '').trim();
    if (rootId.isEmpty) {
      return Map<String, IsmChatMessageModel>.from(messages);
    }
    final next = Map<String, IsmChatMessageModel>.from(messages);
    for (final entry in next.entries.toList()) {
      if ((entry.value.messageId ?? '').trim() != rootId) continue;
      next[entry.key] = applyReplyToRoot(entry.value, reply);
      break;
    }
    return next;
  }

  /// [applyReplyToRootInMap] for the in-memory timeline list.
  static List<IsmChatMessageModel> applyReplyToRootInList(
    List<IsmChatMessageModel> messages,
    IsmChatMessageModel reply,
  ) {
    final rootId = (reply.threadRootId ?? '').trim();
    final next = List<IsmChatMessageModel>.from(messages);
    if (rootId.isEmpty) return next;
    final index =
        next.indexWhere((e) => (e.messageId ?? '').trim() == rootId);
    if (index == -1) return next;
    next[index] = applyReplyToRoot(next[index], reply);
    return next;
  }

  // ------------------------------------------------------------ send target

  /// Stamps a locally-built outgoing message **in place** with [target]'s
  /// thread fields, and returns it for chaining.
  ///
  /// Leaves [message] untouched when there is no target (a channel send) or the
  /// target is incomplete — that is what keeps every existing send path
  /// byte-for-byte what it is today.
  ///
  /// In place on purpose: the same object is the row in the list, the row saved
  /// to the pending box, and the `localEcho` the API call reads its thread
  /// fields from, so an upload's progress updates and its request can never
  /// disagree. Reuse it at **every** local-echo construction site (media,
  /// audio, document, location, contact).
  static IsmChatMessageModel stampThreadTarget(
    IsmChatMessageModel message,
    IsmChatThreadSendTarget? target,
  ) {
    if (!isEnabled || target == null || !target.isValid) return message;
    return message
      ..messageType = IsmChatMessageType.reply
      ..parentMessageId = target.parentMessageId
      ..threadRootId = target.threadRootId
      ..showInConversation = target.showInConversation;
  }

  /// Whether a locally-built echo was composed inside a thread, i.e. it belongs
  /// in the thread panel and not in the channel list.
  static bool isThreadTargetedEcho(IsmChatMessageModel message) =>
      isEnabled && isThreadOnlyReply(message);

  // ------------------------------------------------------------ send fields

  /// `showInConversation` to send for a thread reply.
  ///
  /// `false` is a normal Slack thread reply (thread panel only); `true` is
  /// "also send to channel", which makes the same message appear in both the
  /// thread and the channel timeline.
  static bool showInConversationForReply({required bool alsoSendToChannel}) =>
      alsoSendToChannel;

  // ------------------------------------------------------------ delete rules

  /// Whether a delete-for-everyone was rejected because the message roots a
  /// thread with replies (`errorCode: 4`).
  static bool isRootDeleteBlocked(IsmChatResponseModel? response) {
    if (response == null || !response.hasError) return false;
    return response.applicationErrorCode == rootHasRepliesErrorCode;
  }
}
