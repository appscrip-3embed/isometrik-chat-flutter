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

  /// Slack "also send to channel" — a thread reply visible on the channel
  /// timeline as well as in the panel.
  static bool isAlsoSentThreadReply(IsmChatMessageModel? message) =>
      isEnabled &&
      isThreadReply(message) &&
      message?.showInConversation == true;

  /// Focus menu reads **View thread** instead of **Reply in thread**.
  static bool shouldUseViewThreadMenuLabel(IsmChatMessageModel? message) =>
      isUiEnabled && isAlsoSentThreadReply(message);

  /// Channel row shows **replied to a thread: …** above the bubble.
  static bool shouldShowChannelThreadContext(IsmChatMessageModel? message) =>
      isUiEnabled && isAlsoSentThreadReply(message);

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

  /// Canonical thread **root** to load when the user opens a thread from
  /// [message] (e.g. "Reply in thread" on an also-sent channel row).
  ///
  /// Channel rows that open a thread panel (root or any `messageType: 2` reply).
  static bool isThreadPanelEntry(IsmChatMessageModel? message) {
    if (message == null || !isEnabled) return false;
    if ((message.messageId ?? '').trim().isEmpty) return false;
    if (message.messageType == IsmChatMessageType.reply) return true;
    return isThreadReply(message);
  }

  /// Thread replies carry `threadRootId`; without it, [threadIdOf] would use
  /// the reply's own `messageId` and fetch the wrong panel. Walks
  /// [channelTimeline] for the root row when possible.

  static IsmChatMessageModel resolveThreadPanelRoot(
    IsmChatMessageModel message,
    List<IsmChatMessageModel> channelTimeline,
  ) {
    if (!isThreadPanelEntry(message)) {
      return message;
    }
    var rootId = (message.threadRootId ?? '').trim();
    if (rootId.isEmpty) {
      final parentId = (message.parentMessageId ?? '').trim();
      if (parentId.isNotEmpty) {
        for (final row in channelTimeline) {
          final id = (row.messageId ?? '').trim();
          if (id != parentId) continue;
          if (!isThreadReply(row)) return row;
          rootId = threadIdOf(row);
          if (rootId.isNotEmpty) break;
        }
      }
    }
    if (rootId.isEmpty) return message;

    for (final row in channelTimeline) {
      if ((row.messageId ?? '').trim() == rootId) return row;
    }
    // Root not on the timeline yet — still open the thread by server root id.
    return message.copyWith(
      messageId: rootId,
      threadRootId: null,
      parentMessageId: null,
      messageType: IsmChatMessageType.normal,
    );
  }

  /// Parent row for channel thread-context copy ([parentMessageId] on
  /// [message]). Falls back to the thread root when the immediate parent is
  /// thread-only and absent from the channel list.
  static IsmChatMessageModel? resolveParentInTimeline(
    IsmChatMessageModel message,
    List<IsmChatMessageModel> channelTimeline,
  ) {
    final parentId = (message.parentMessageId ?? '').trim();
    if (parentId.isNotEmpty) {
      for (final row in channelTimeline) {
        if ((row.messageId ?? '').trim() == parentId) return row;
      }
    }
    final rootId = (message.threadRootId ?? '').trim();
    if (rootId.isEmpty || rootId == parentId) return null;
    for (final row in channelTimeline) {
      if ((row.messageId ?? '').trim() == rootId) return row;
    }
    return null;
  }

  /// Max visible characters for the subject in **replied to a thread: …**
  /// (file names, text, type labels) before `...` is appended.
  static const int channelThreadContextSubjectMaxLength = 10;

  static String _truncateChannelThreadSubject(String text) =>
      IsmChatUtility.truncateNotificationBody(
        text,
        maxLength: channelThreadContextSubjectMaxLength,
      );

  /// Human label for the parent in **replied to a thread: …**
  ///
  /// Media rows use localized type names ([IsmChatStrings.image],
  /// [IsmChatStrings.document], …), not attachment file names. Plain text
  /// parents show a short body snippet.
  static String threadReplyContextSubject(IsmChatMessageModel? parent) {
    late final String subject;
    if (parent == null) {
      subject = IsmChatStrings.threadContextSubjectFallback;
    } else {
      final typeLabel = threadContentTypeLabel(parent);
      if (typeLabel != null && typeLabel.isNotEmpty) {
        subject = typeLabel;
      } else if (parent.customType ==
          IsmChatCustomMessageType.multipleAttachments) {
        subject = parent.multipleAttachmentsPreviewLabel;
      } else {
        final body =
            IsmChatUtility.lastMessageBodyForConversationSync(parent).trim();
        if (body.isNotEmpty &&
            !IsmChatUtility.isOutboundAttachmentPlaceholderBody(body)) {
          subject = body;
        } else {
          subject = IsmChatStrings.threadContextSubjectFallback;
        }
      }
    }
    return _truncateChannelThreadSubject(subject);
  }

  /// Non-text bubble label (photo, document, …) for thread panel and channel
  /// context. Returns `null` for plain text rows ([body] is shown instead).
  static String? threadContentTypeLabel(
    IsmChatMessageModel message, [
    IsmChatCustomMessageType? contentType,
  ]) {
    final bubble =
        contentType ?? message.threadPanelBubbleType ?? message.customType;
    switch (bubble) {
      case IsmChatCustomMessageType.image:
        return IsmChatStrings.image;
      case IsmChatCustomMessageType.video:
        return IsmChatStrings.video;
      case IsmChatCustomMessageType.audio:
        return IsmChatStrings.audio;
      case IsmChatCustomMessageType.file:
        return IsmChatStrings.document;
      case IsmChatCustomMessageType.multipleAttachments:
        return IsmChatStrings.document;
      case IsmChatCustomMessageType.location:
        return IsmChatStrings.location;
      case IsmChatCustomMessageType.contact:
        return IsmChatL10n.get('contact');
      case IsmChatCustomMessageType.deletedForEveryone:
      case IsmChatCustomMessageType.deletedForMe:
        return IsmChatStrings.wasDeletedMessage;
      default:
        return null;
    }
  }

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

  /// When [getMessagesFromDB] reloads, keep thread root badges that were bumped
  /// in memory but not yet written to Hive (e.g. user popped the thread fast).
  static List<IsmChatMessageModel> mergeThreadRootBadgesInList(
    List<IsmChatMessageModel> fromDb,
    List<IsmChatMessageModel> previous,
  ) {
    if (!isEnabled || previous.isEmpty) {
      return List<IsmChatMessageModel>.from(fromDb);
    }
    final byId = <String, IsmChatMessageModel>{};
    for (final m in previous) {
      final id = (m.messageId ?? '').trim();
      if (id.isNotEmpty) byId[id] = m;
    }
    return fromDb.map((db) {
      final id = (db.messageId ?? '').trim();
      final mem = byId[id];
      if (mem == null) return db;
      final memCount = replyCountOf(mem);
      final dbCount = replyCountOf(db);
      final memLast = mem.lastThreadReplyAt ?? 0;
      final dbLast = db.lastThreadReplyAt ?? 0;
      if (memCount <= dbCount && memLast <= dbLast) return db;
      return db.copyWith(
        replyCount: memCount > dbCount ? memCount : dbCount,
        lastThreadReplyAt: memLast > dbLast ? memLast : dbLast,
      );
    }).toList();
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

  // -------------------------------------------------------- media preview

  /// Stable key for deduping swipe-preview rows across channel + thread lists.
  static String mediaGalleryItemKey(IsmChatMessageModel item) {
    final id = (item.messageId ?? '').trim();
    if (id.isNotEmpty) return id;
    final url = item.attachments?.firstOrNull?.mediaUrl ?? '';
    return '${item.sentAt}_$url';
  }

  /// Expands in-panel thread replies into image/video gallery rows.
  ///
  /// API replies may use wire `customType` `AttachmentMessage:Reply`; resolve
  /// the bubble type via [IsmChatMessageModel.threadPanelBubbleType]. See
  /// `docs/THREADS.md`.
  static List<IsmChatMessageModel> mediaGalleryItemsFromThreadReplies(
    List<IsmChatMessageModel> replies,
  ) {
    final items = <IsmChatMessageModel>[];
    for (final reply in replies) {
      final bubble = reply.threadPanelBubbleType;
      if (bubble == null) continue;
      final row = reply.copyWith(customType: bubble);
      items.addAll(row.toMediaGalleryItems(includeAudio: false));
    }
    return items;
  }

  /// Merges two preview lists without duplicate messages.
  static List<IsmChatMessageModel> mergeMediaGalleryItems(
    List<IsmChatMessageModel> primary,
    List<IsmChatMessageModel> extra,
  ) {
    final seen = <String>{};
    final merged = <IsmChatMessageModel>[];
    for (final item in [...primary, ...extra]) {
      final key = mediaGalleryItemKey(item);
      if (key.isNotEmpty && seen.contains(key)) continue;
      if (key.isNotEmpty) seen.add(key);
      merged.add(item);
    }
    return merged;
  }

  /// Channel + thread entry for tapping an image, GIF, sticker, or video.
  ///
  /// Uses [IsmChatPageController.tapForMediaPreview] when registered so swipe
  /// preview merges channel and in-panel thread media; otherwise opens a
  /// single-item gallery via [openMediaPreviewList].
  static Future<void> openMediaPreviewFromThread(
    IsmChatMessageModel message,
  ) async {
    if (IsmChatUtility.chatPageControllerRegistered) {
      IsmChatUtility.chatPageController.tapForMediaPreview(message);
      return;
    }
    final bubble = message.threadPanelBubbleType;
    final normalized =
        bubble != null ? message.copyWith(customType: bubble) : message;
    final gallery = normalized.toMediaGalleryItems(includeAudio: false);
    if (gallery.isEmpty) return;
    await openMediaPreviewList(
      mediaList: gallery,
      selectedIndex: 0,
      message: gallery.first,
    );
  }

  /// Pushes the shared image/video preview route (channel or thread panel).
  ///
  /// Reused by [IsmChatPageController] and [IsmChatThreadMessageTile] when the
  /// chat page is not mounted so thread-only previews still work.
  static Future<void> openMediaPreviewList({
    required List<IsmChatMessageModel> mediaList,
    required int selectedIndex,
    required IsmChatMessageModel message,
  }) async {
    if (IsmChatResponsive.isWeb(
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context)) {
      await IsmChatRoute.goToRoute(IsmWebMessageMediaPreview(
        previewData: {
          'mediaIndex': selectedIndex,
          'messageData': mediaList,
          'mediaUserName': message.chatName,
          'initiated': message.sentByMe,
          'mediaTime': message.sentAt,
        },
      ));
    } else {
      await IsmChatRoute.goToRoute(IsmMediaPreview(
        mediaIndex: selectedIndex,
        messageData: mediaList,
        mediaUserName: message.chatName,
        initiated: message.sentByMe,
        mediaTime: message.sentAt,
      ));
    }
  }

  // ------------------------------------------------------------ delete rules

  /// Whether a delete-for-everyone was rejected because the message roots a
  /// thread with replies (`errorCode: 4`).
  static bool isRootDeleteBlocked(IsmChatResponseModel? response) {
    if (response == null || !response.hasError) return false;
    return response.applicationErrorCode == rootHasRepliesErrorCode;
  }
}
