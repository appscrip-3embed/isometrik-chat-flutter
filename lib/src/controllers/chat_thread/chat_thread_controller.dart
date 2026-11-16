import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Reactive state + actions for one open thread (Slack-style replies).
///
/// Owns everything the thread panel ([IsmChatThreadView]) shows: the root
/// message, the replies loaded so far, paging, the composer and the
/// "also send to channel" switch. One instance serves the thread currently on
/// screen; [openThread] re-targets it, so opening a different thread never
/// leaks the previous thread's replies.
///
/// **Isolation from the channel.** The controller never writes to the local
/// database and never touches [IsmChatPageController.messages], except to bump
/// the root's `replyCount` badge. With threads off it is never registered at
/// all, which is what keeps the classic chat experience unchanged.
///
/// Lifecycle: registered on demand by [IsmChatThreadBinding] (which
/// [IsmChatThreadView] runs) and removed on logout by `IsmChat.i.logout`.
///
/// ```dart
/// IsmChatThreadBinding().dependencies();
/// final controller = Get.find<IsmChatThreadController>();
/// await controller.openThread(root: rootMessage, conversation: conversation);
/// ```
class IsmChatThreadController extends GetxController {
  IsmChatThreadController(this._viewModel);

  final IsmChatThreadViewModel _viewModel;

  /// Replies fetched per page.
  static const int pageLimit = 20;

  /// The registered instance, or `null` when no thread panel is live.
  ///
  /// Reuse this (never `Get.find` directly) from code that may run with
  /// threads off — e.g. the MQTT handlers.
  static IsmChatThreadController? get instance =>
      Get.isRegistered<IsmChatThreadController>()
          ? Get.find<IsmChatThreadController>()
          : null;

  // ------------------------------------------------------------------- root

  final _root = Rx<IsmChatMessageModel?>(null);

  /// The thread's root message (the channel message replies hang under).
  IsmChatMessageModel? get root => _root.value;
  set root(IsmChatMessageModel? value) => _root.value = value;

  final _conversation = Rx<IsmChatConversationModel?>(null);

  /// Conversation the thread lives in — used for ids, titles and send headers.
  IsmChatConversationModel? get conversation => _conversation.value;
  set conversation(IsmChatConversationModel? value) =>
      _conversation.value = value;

  /// `threadRootId` every reply in this thread carries.
  String get threadRootId => IsmChatThreadCoordinator.threadIdOf(root);

  /// Conversation id of the open thread (empty when none).
  String get conversationId =>
      conversation?.conversationId ?? root?.conversationId ?? '';

  // ---------------------------------------------------------------- replies

  final _replies = <IsmChatMessageModel>[].obs;

  /// Replies loaded so far, oldest-first (thread reading order).
  List<IsmChatMessageModel> get replies => _replies;

  /// Replies in this thread as known locally: the server `replyCount` on the
  /// root, or the loaded rows when that is higher (own reply just sent).
  int get replyCount {
    final serverCount = IsmChatThreadCoordinator.replyCountOf(root);
    return serverCount > _replies.length ? serverCount : _replies.length;
  }

  // -------------------------------------------------------------- composer

  /// Text field behind the thread composer.
  final replyController = TextEditingController();

  /// Focus node so opening a thread can put the caret in the composer.
  final replyFocusNode = FocusNode();

  final _alsoSendToChannel = false.obs;

  /// Slack's "Also send to channel": posts the reply with
  /// `showInConversation: true` so it appears in the channel too.
  ///
  /// Resets to `false` whenever a different thread is opened. Also applies to
  /// attachments picked from the thread composer, through [sendTarget].
  bool get alsoSendToChannel => _alsoSendToChannel.value;
  set alsoSendToChannel(bool value) {
    _alsoSendToChannel.value = value;
    syncSendTarget();
  }

  final _replyTo = Rx<IsmChatMessageModel?>(null);

  /// The reply being answered, for a nested reply ("reply to a reply").
  ///
  /// `null` means the next send targets the root, which is Slack's default.
  /// Either way the message stays in the same thread: the server derives
  /// `threadRootId` from the parent.
  IsmChatMessageModel? get replyTo => _replyTo.value;
  set replyTo(IsmChatMessageModel? value) {
    _replyTo.value = value;
    syncSendTarget();
  }

  /// Clears the nested-reply target.
  void clearReplyTo() => replyTo = null;

  final _isSending = false.obs;

  /// Whether a reply send is in flight (composer shows a spinner).
  bool get isSending => _isSending.value;

  // -------------------------------------------------------------- lifecycle

  final _isLoading = false.obs;

  /// First-page load of the thread.
  bool get isLoading => _isLoading.value;

  final _isPaginating = false.obs;

  /// Older-replies load triggered by scrolling up.
  bool get isPaginating => _isPaginating.value;

  final _hasMore = true.obs;

  /// Whether the server may hold more replies than are loaded.
  bool get hasMore => _hasMore.value;

  final _loadError = ''.obs;

  /// Last failure while loading the thread ('' when healthy). The panel shows
  /// it with a retry button in place of the reply list.
  String get loadErrorMessage => _loadError.value;

  final _sendError = ''.obs;

  /// Last failure while sending a reply ('' when healthy). The composer shows
  /// it above the text field, so a send error never hides the replies.
  String get sendErrorMessage => _sendError.value;

  int _skip = 0;

  @override
  void onClose() {
    replyController.dispose();
    replyFocusNode.dispose();
    super.onClose();
  }

  // ------------------------------------------------------------- open/close

  /// Targets this controller at [root] and loads the thread's first page.
  ///
  /// Safe to call repeatedly: state from a previously open thread is cleared
  /// first. Does nothing when threading is off or [root] has no server id.
  Future<void> openThread({
    required IsmChatMessageModel root,
    IsmChatConversationModel? conversation,
  }) async {
    if (!IsmChatThreadCoordinator.canOpenThread(root)) return;
    this.root = root;
    this.conversation = conversation ??
        (IsmChatUtility.chatPageControllerRegistered
            ? IsmChatUtility.chatPageController.conversation
            : null);
    _replies.clear();
    _skip = 0;
    _hasMore.value = true;
    _loadError.value = '';
    _sendError.value = '';
    _alsoSendToChannel.value = false;
    _replyTo.value = null;
    replyController.clear();
    // From here on, attachments picked in the panel are thread replies.
    syncSendTarget();
    await loadReplies();
  }

  /// Clears the panel state (called when the thread view is popped).
  void closeThread() {
    _root.value = null;
    _conversation.value = null;
    _replies.clear();
    _skip = 0;
    _hasMore.value = true;
    _loadError.value = '';
    _sendError.value = '';
    _alsoSendToChannel.value = false;
    _replyTo.value = null;
    replyController.clear();
    clearSendTarget();
  }

  // ----------------------------------------------------------------- loading

  /// Loads the first page of replies (replacing what is loaded).
  Future<void> loadReplies() async {
    final rootId = threadRootId;
    final convId = conversationId;
    if (rootId.isEmpty || convId.isEmpty) return;
    _isLoading.value = true;
    _loadError.value = '';
    try {
      final page = await _viewModel.getThreadMessages(
        conversationId: convId,
        threadRootId: rootId,
        limit: pageLimit,
        skip: 0,
      );
      // Thread switched while the request was in flight — drop the response.
      if (threadRootId != rootId) return;
      if (page == null) {
        _loadError.value = IsmChatStrings.threadLoadFailed;
        return;
      }
      _replies.value = page;
      _skip = page.length;
      _hasMore.value = page.length >= pageLimit;
      _syncRootReplyCount(page.length);
      // Replies still waiting to be sent (offline) are not on the server yet.
      await _mergeQueuedReplies();
    } finally {
      _isLoading.value = false;
    }
  }

  /// Loads the next page of older replies. No-op while a load is in flight or
  /// the thread is fully loaded.
  Future<void> loadMoreReplies() async {
    if (_isLoading.value || _isPaginating.value || !_hasMore.value) return;
    final rootId = threadRootId;
    final convId = conversationId;
    if (rootId.isEmpty || convId.isEmpty) return;
    _isPaginating.value = true;
    try {
      final page = await _viewModel.getThreadMessages(
        conversationId: convId,
        threadRootId: rootId,
        limit: pageLimit,
        skip: _skip,
      );
      if (threadRootId != rootId) return;
      if (page == null) {
        _loadError.value = IsmChatStrings.threadLoadFailed;
        return;
      }
      if (page.isEmpty) {
        _hasMore.value = false;
        return;
      }
      for (final reply in page) {
        _mergeReply(reply);
      }
      _skip += page.length;
      _hasMore.value = page.length >= pageLimit;
    } finally {
      _isPaginating.value = false;
    }
  }

  /// Re-reads the server reply count for the open thread and stores it on the
  /// root, so the channel badge agrees with the panel.
  Future<void> refreshReplyCount() async {
    final rootId = threadRootId;
    final convId = conversationId;
    if (rootId.isEmpty || convId.isEmpty) return;
    final count = await _viewModel.getThreadReplyCount(
      conversationId: convId,
      threadRootId: rootId,
    );
    if (count == null || threadRootId != rootId) return;
    _applyRootReplyCount(count);
  }

  // ------------------------------------------------------------------ send

  /// Sends the composer text as a reply in this thread.
  ///
  /// - `parentMessageId` is [replyTo] when replying to a specific reply,
  ///   otherwise the root (Slack's default).
  /// - [IsmChatThreadController.alsoSendToChannel] decides
  ///   `showInConversation`, i.e. whether the reply also lands in the channel.
  ///
  /// Returns `true` when the server accepted the reply. The optimistic row is
  /// removed again on failure and [sendErrorMessage] is set.
  Future<bool> sendReply({
    String? text,
    IsmChatMessageModel? replyTo,
  }) async {
    final rootMessage = root;
    if (rootMessage == null) return false;
    final body = (text ?? replyController.text).trim();
    if (body.isEmpty || _isSending.value) return false;
    final convId = conversationId;
    if (convId.isEmpty) return false;

    final parent = replyTo ?? this.replyTo ?? rootMessage;
    final parentMessageId = (parent.messageId ?? '').trim();
    if (parentMessageId.isEmpty) return false;

    final sendToChannel = alsoSendToChannel;
    final pending = buildLocalReply(
      body: body,
      parent: parent,
      conversationId: convId,
      alsoSendToChannel: sendToChannel,
    );

    _isSending.value = true;
    _sendError.value = '';
    replyController.clear();
    _replyTo.value = null;
    _replies.add(pending);
    // Queue it like a channel message so a dropped connection retries it from
    // [IsmChatConversationsController.sendPendingMessgae] instead of losing it.
    await _queuePendingReply(pending);
    try {
      final result = await _viewModel.sendThreadReply(
        conversationId: convId,
        parentMessageId: parentMessageId,
        body: body,
        alsoSendToChannel: sendToChannel,
        deviceId: IsmChatConfig.communicationConfig.projectConfig.deviceId,
        notificationTitle: IsmChatUtility.resolveSendNotificationTitle(
          conversation: conversation,
          conversationId: convId,
          senderDetails: _currentUser,
          senderUserName: _currentUser?.userName ?? '',
        ),
        notificationBody: body,
      );
      final accepted = result != null &&
          !result.response.hasError &&
          result.messageId.isNotEmpty;
      if (!accepted) {
        if (result == null) {
          // Never reached the server (offline / transport): keep the row and
          // the queued copy, the pending sender picks it up on reconnect.
          _sendError.value = IsmChatStrings.threadReplyQueued;
          return false;
        }
        // The server rejected it: drop the queued copy so it is not retried
        // forever, and show why.
        await _dequeuePendingReply(pending);
        _replies.removeWhere((e) => e.sentAt == pending.sentAt &&
            (e.messageId ?? '').isEmpty);
        _sendError.value = result.response.apiErrorMessage(
          fallback: IsmChatStrings.threadSendFailed,
        );
        return false;
      }
      await _dequeuePendingReply(pending);
      final confirmed = pending.copyWith(messageId: result.messageId);
      // [_mergeReply], not a direct insert: a realtime echo of this very reply
      // can arrive before the send response does, and must not leave two rows.
      final alreadyShown = _replies.any(
        (e) => (e.messageId ?? '').trim() == result.messageId,
      );
      _mergeReply(confirmed);
      // Own send: the chat page never sees an MQTT echo of its own message, so
      // the panel owns both the in-memory badge and the cached one — unless the
      // echo already counted this reply.
      if (!alreadyShown) {
        _bumpRoot(confirmed, persist: true);
      }
      return true;
    } finally {
      _isSending.value = false;
    }
  }

  /// Builds the optimistic local row for a reply that is being sent.
  ///
  /// Mirrors what the server will store: `messageType: 2`, the immediate
  /// `parentMessageId`, the derived `threadRootId` and the `showInConversation`
  /// the send used. Exposed for tests and host-built composers.
  @visibleForTesting
  IsmChatMessageModel buildLocalReply({
    required String body,
    required IsmChatMessageModel parent,
    required String conversationId,
    required bool alsoSendToChannel,
  }) {
    final sentAt = DateTime.now().millisecondsSinceEpoch;
    return IsmChatMessageModel(
      body: body,
      customType: IsmChatCustomMessageType.text,
      sentAt: sentAt,
      sentByMe: true,
      conversationId: conversationId,
      senderInfo: _currentUser,
      messageId: '',
      messageType: IsmChatMessageType.reply,
      parentMessageId: parent.messageId,
      threadRootId: IsmChatThreadCoordinator.resolveThreadRootId(parent),
      showInConversation: IsmChatThreadCoordinator.showInConversationForReply(
        alsoSendToChannel: alsoSendToChannel,
      ),
      deviceId: IsmChatConfig.communicationConfig.projectConfig.deviceId,
      metaData: IsmChatMetaData(messageSentAt: sentAt),
    );
  }

  // ---------------------------------------------------------- send target

  /// What the open thread would send right now.
  ///
  /// `null` when no thread is open. Media, voice notes, documents, locations
  /// and contacts are sent by the **chat page** pipelines, so the panel keeps
  /// this on [IsmChatPageController.threadSendTarget] while it is on screen;
  /// those pipelines stamp it onto their local echo and post a thread reply.
  IsmChatThreadSendTarget? get sendTarget {
    final rootMessage = root;
    if (rootMessage == null) return null;
    final target = IsmChatThreadSendTarget.forThread(
      root: rootMessage,
      replyTo: replyTo,
      alsoSendToChannel: alsoSendToChannel,
    );
    return target.isValid ? target : null;
  }

  /// Publishes [sendTarget] to the chat page controller.
  ///
  /// Called when the panel opens and whenever the nested-reply target or the
  /// "also send to channel" switch changes. Safe to call with no chat page.
  void syncSendTarget() {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    IsmChatUtility.chatPageController.threadSendTarget = sendTarget;
  }

  /// Stops routing attachment sends into this thread (panel closed).
  void clearSendTarget() {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    IsmChatUtility.chatPageController.threadSendTarget = null;
  }

  // --------------------------------------------------------- offline queue

  /// Stores [reply] in the pending box, exactly like a channel send, so the
  /// existing retry-on-reconnect path can re-send it.
  Future<void> _queuePendingReply(IsmChatMessageModel reply) async {
    if (!IsmChatConfig.shouldPendingMessageSend) return;
    await IsmChatConfig.dbWrapper?.saveMessage(reply, IsmChatDbBox.pending);
  }

  /// Drops the queued copy of [reply] once it reached the server (or was
  /// rejected for good).
  Future<void> _dequeuePendingReply(IsmChatMessageModel reply) async {
    final convId = reply.conversationId ?? '';
    if (convId.isEmpty) return;
    await IsmChatConfig.dbWrapper?.removePendingMessage(
      convId,
      {reply.key: reply},
    );
  }

  /// Merges still-queued replies for this thread into the panel.
  ///
  /// A reply written while offline is not on the server yet, so the API page
  /// cannot contain it; without this it would vanish from the panel until it
  /// was finally sent.
  Future<void> _mergeQueuedReplies() async {
    final rootId = threadRootId;
    final convId = conversationId;
    if (rootId.isEmpty || convId.isEmpty) return;
    if (!IsmChatConfig.shouldPendingMessageSend) return;
    final queued = await IsmChatConfig.dbWrapper
        ?.getMessage(convId, IsmChatDbBox.pending);
    if (queued == null || queued.isEmpty) return;
    for (final reply in queued.values) {
      if ((reply.threadRootId ?? '').trim() != rootId) continue;
      _mergeReply(reply);
    }
  }

  // ------------------------------------------------- local echoes (uploads)

  /// Shows a locally-built reply that another send pipeline created (media,
  /// voice note, document, location, contact composed inside this thread).
  ///
  /// Returns `false` when the row does not belong to the open thread, so the
  /// caller can decide what to do with it.
  bool addLocalReply(IsmChatMessageModel reply) {
    final rootId = threadRootId;
    if (rootId.isEmpty) return false;
    if ((reply.threadRootId ?? '').trim() != rootId) return false;
    _mergeReply(reply);
    return true;
  }

  /// Applies [mutate] to the un-sent reply created at [sentAt] (upload progress,
  /// presigned URLs, failure flag) and refreshes the panel.
  ///
  /// Returns `true` when a row matched and [mutate] reported a change. Called
  /// through [IsmChatPageController.mutateLocalRow], which owns the channel
  /// list and falls back to the open thread.
  bool mutateLocalReply(
    int sentAt,
    bool Function(IsmChatMessageModel row) mutate, {
    bool onlyUnsent = false,
  }) {
    final index = _replies.indexWhere(
      (row) =>
          row.sentAt == sentAt &&
          (!onlyUnsent || row.messageId?.isEmpty == true),
    );
    if (index == -1) return false;
    final row = _replies[index];
    if (!mutate(row)) return false;
    _replies[index] = row;
    _replies.refresh();
    update();
    return true;
  }

  /// Confirms a locally-built reply once its send pipeline got a server id.
  ///
  /// Mirrors what [sendReply] does for text: swap the pending row for the
  /// confirmed one and move the root badge exactly once.
  void confirmLocalReply({
    required int sentAt,
    required String messageId,
  }) {
    final id = messageId.trim();
    if (id.isEmpty) return;
    final index = _replies.indexWhere(
      (row) => row.sentAt == sentAt && (row.messageId ?? '').isEmpty,
    );
    if (index == -1) return;
    final confirmed = _replies[index].copyWith(messageId: id);
    final alreadyShown = _replies.any(
      (row) => (row.messageId ?? '').trim() == id,
    );
    _replies[index] = confirmed;
    if (!alreadyShown) {
      _bumpRoot(confirmed, persist: true);
    }
  }

  /// Drops a locally-built reply whose send failed for good.
  void removeLocalReply(int sentAt) =>
      _replies.removeWhere(
        (row) => row.sentAt == sentAt && (row.messageId ?? '').isEmpty,
      );

  // -------------------------------------------------------------- realtime

  /// Applies an incoming reply (MQTT) to the open thread.
  ///
  /// Returns `true` when it belonged to this thread and was shown. Replies for
  /// other threads are ignored here — the channel list keeps its own badge in
  /// step through [IsmChatThreadCoordinator.applyReplyToRootInList].
  bool applyIncomingReply(IsmChatMessageModel reply) {
    final rootId = threadRootId;
    if (rootId.isEmpty) return false;
    if ((reply.threadRootId ?? '').trim() != rootId) return false;
    _mergeReply(reply);
    // The MQTT handler already wrote the cached root, so only move it here.
    _bumpRoot(reply, persist: false);
    return true;
  }

  /// Routes an incoming thread reply to the open panel, if any.
  ///
  /// Static so MQTT handlers can call it without caring whether a thread is on
  /// screen (or whether threading is on at all).
  static bool deliverIncomingReply(IsmChatMessageModel reply) {
    if (!IsmChatThreadCoordinator.isEnabled) return false;
    final controller = instance;
    if (controller == null) return false;
    return controller.applyIncomingReply(reply);
  }

  /// Drops a deleted reply from the open thread and decrements the root badge.
  void applyReplyDeleted(String messageId) {
    final id = messageId.trim();
    if (id.isEmpty) return;
    final before = _replies.length;
    _replies.removeWhere((e) => (e.messageId ?? '').trim() == id);
    if (_replies.length == before) return;
    if (_skip > 0) _skip -= 1;
    final rootMessage = root;
    if (rootMessage != null) {
      root = IsmChatThreadCoordinator.applyReplyRemovalToRoot(rootMessage);
    }
  }

  // --------------------------------------------------------------- internals

  UserDetails? get _currentUser => IsmChatUtility.conversationControllerRegistered
      ? IsmChatUtility.conversationController.userDetails
      : null;

  /// Inserts [reply] in `sentAt` order, replacing an existing row with the same
  /// `messageId` (so an echo of our own send does not duplicate).
  void _mergeReply(IsmChatMessageModel reply) {
    final id = (reply.messageId ?? '').trim();
    if (id.isNotEmpty) {
      final existing =
          _replies.indexWhere((e) => (e.messageId ?? '').trim() == id);
      if (existing != -1) {
        _replies[existing] = reply;
        return;
      }
      // Our own optimistic row for the same text/timestamp.
      final pending = _replies.indexWhere(
        (e) => (e.messageId ?? '').isEmpty && e.body == reply.body,
      );
      if (pending != -1) {
        _replies[pending] = reply;
        return;
      }
    }
    final insertAt = _replies.indexWhere((e) => e.sentAt > reply.sentAt);
    if (insertAt == -1) {
      _replies.add(reply);
    } else {
      _replies.insert(insertAt, reply);
    }
  }

  /// Keeps the root badge at least as high as what the panel shows.
  void _syncRootReplyCount(int loaded) {
    final rootMessage = root;
    if (rootMessage == null) return;
    if (IsmChatThreadCoordinator.replyCountOf(rootMessage) >= loaded) return;
    _applyRootReplyCount(loaded);
  }

  void _applyRootReplyCount(int count) {
    final rootMessage = root;
    if (rootMessage == null) return;
    root = rootMessage.copyWith(replyCount: count);
    _publishRootToTimeline(root!);
  }

  /// Moves the root's `replyCount` / `lastThreadReplyAt` forward for a reply
  /// that just landed and mirrors it onto the channel row.
  ///
  /// [persist] also writes the new figures into the cached conversation, so
  /// the "N replies" footer survives a chat reload. Pass `false` for realtime
  /// replies, whose cached root is written by the MQTT handler — otherwise the
  /// badge would be counted twice.
  void _bumpRoot(IsmChatMessageModel reply, {required bool persist}) {
    final rootMessage = root;
    if (rootMessage == null) return;
    final updated = IsmChatThreadCoordinator.applyReplyToRoot(
      rootMessage,
      reply,
    );
    root = updated;
    _publishRootToTimeline(updated);
    if (persist) {
      unawaited(_persistRootToDb(updated));
    }
  }

  /// Writes the root's thread figures into the cached conversation.
  ///
  /// Only the root document changes — thread replies are never persisted (see
  /// `docs/THREADS.md`).
  Future<void> _persistRootToDb(IsmChatMessageModel updatedRoot) async {
    final convId = conversationId;
    final rootId = (updatedRoot.messageId ?? '').trim();
    if (convId.isEmpty || rootId.isEmpty) return;
    await IsmChatConfig.dbWrapper?.updateConversation(
      conversationId: convId,
      update: (latest) {
        if (latest == null) return null;
        final messages = Map<String, IsmChatMessageModel>.from(
          latest.messages ?? {},
        );
        for (final entry in messages.entries.toList()) {
          if ((entry.value.messageId ?? '').trim() != rootId) continue;
          messages[entry.key] = entry.value.copyWith(
            replyCount: updatedRoot.replyCount,
            lastThreadReplyAt: updatedRoot.lastThreadReplyAt,
          );
          return latest.copyWith(messages: messages);
        }
        return null;
      },
    );
  }

  /// Writes the updated root back into the channel timeline so the
  /// "N replies" footer updates live. Best-effort: the chat page may be gone.
  void _publishRootToTimeline(IsmChatMessageModel updatedRoot) {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    final pageController = IsmChatUtility.chatPageController;
    if (pageController.conversation?.conversationId != conversationId) return;
    final rootId = (updatedRoot.messageId ?? '').trim();
    if (rootId.isEmpty) return;
    final index = pageController.messages
        .indexWhere((e) => (e.messageId ?? '').trim() == rootId);
    if (index == -1) return;
    pageController.messages[index] = pageController.messages[index].copyWith(
      replyCount: updatedRoot.replyCount,
      lastThreadReplyAt: updatedRoot.lastThreadReplyAt,
    );
    pageController.update();
  }
}
