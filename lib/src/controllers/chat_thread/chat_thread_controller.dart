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
  /// Highlights picked `@mentions` while typing (same style as bubbles).
  late final TextEditingController replyController =
      IsmChatMentionTextEditingController(
    membersProvider: () =>
        isMentionEnabled ? mentionMembers : const <UserDetails>[],
  );

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

  final _isEditing = false.obs;
  bool get isEditing => _isEditing.value;
  set isEditing(bool value) => _isEditing.value = value;

  final _editingMessage = Rx<IsmChatMessageModel?>(null);
  IsmChatMessageModel? get editingMessage => _editingMessage.value;
  set editingMessage(IsmChatMessageModel? value) =>
      _editingMessage.value = value;

  void cancelEditMessage() {
    isEditing = false;
    editingMessage = null;
    replyController.clear();
    showComposerSendButton = false;
    update();
  }

  /// Focus-menu edit → thread composer (mirrors [IsmChatPageController.beginEditMessage]).
  void beginEditMessage(IsmChatMessageModel message) {
    if (!message.canShowEditInFocusMenu) return;
    if (showEmojiBoard) closeEmojiBoard();
    replyTo = null;
    isEditing = true;
    editingMessage = message;
    replyController.text = message.body;
    showComposerSendButton = true;
    replyFocusNode.requestFocus();
    if (IsmChatUtility.chatPageControllerRegistered) {
      final page = IsmChatUtility.chatPageController;
      page
        ..cancelEditMessage()
        ..isreplying = false
        ..replayMessage = null;
    }
    update();
  }

  Future<bool> submitEditFromThreadComposer() async {
    final original = editingMessage;
    if (!isEditing || original == null) return false;
    if (!IsmChatUtility.chatPageControllerRegistered) return false;
    final plainBody = replyController.text.trim();
    final page = IsmChatUtility.chatPageController;
    final ok = await page.submitTextEditForMessage(original, plainBody);
    if (ok) cancelEditMessage();
    return ok;
  }

  /// Panel counterpart to [IsmChatPageController.onReplyTap]: targets the
  /// thread composer for a nested reply instead of the channel quote bar.
  ///
  /// Thread rows no longer start this on tap; kept for host composers and
  /// the focus-menu path ([IsmChatThreadCoordinator.isMessageInOpenThreadPanel]).
  void beginReplyTo(IsmChatMessageModel message) {
    if (showEmojiBoard) {
      closeEmojiBoard();
    }
    cancelEditMessage();
    replyTo = message;
    replyFocusNode.requestFocus();
    if (IsmChatUtility.chatPageControllerRegistered) {
      final page = IsmChatUtility.chatPageController;
      page
        ..isreplying = false
        ..replayMessage = null;
    }
  }

  final _isSending = false.obs;

  /// Whether a reply send is in flight (composer shows a spinner).
  bool get isSending => _isSending.value;

  /// Wired by [IsmChatThreadView] so sends can scroll the reply list to the end.
  VoidCallback? onScrollRepliesToBottom;

  /// Schedules [onScrollRepliesToBottom] after the next frame once new rows lay out.
  void requestScrollRepliesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onScrollRepliesToBottom?.call();
    });
  }

  // ----------------------------------------- composer (voice / send affordance)

  /// Mic vs send, isolated from the channel composer while a thread is open.
  final _showComposerSendButton = false.obs;
  bool get showComposerSendButton => _showComposerSendButton.value;
  set showComposerSendButton(bool value) =>
      _showComposerSendButton.value = value;

  final _isEnableRecordingAudio = false.obs;
  bool get isEnableRecordingAudio => _isEnableRecordingAudio.value;
  set isEnableRecordingAudio(bool value) =>
      _isEnableRecordingAudio.value = value;

  final _recordingSeconds = 0.obs;
  int get recordingSeconds => _recordingSeconds.value;
  set recordingSeconds(int value) => _recordingSeconds.value = value;

  final _isRecordPlay = true.obs;
  bool get isRecordPlay => _isRecordPlay.value;
  set isRecordPlay(bool value) => _isRecordPlay.value = value;

  Timer? _recordTimer;

  /// Keeps send vs mic in sync with the thread text field.
  void handleComposerTextChanged(String text) {
    _refreshMentionSuggestions(text);
    if (isEnableRecordingAudio) return;
    final audioOn = IsmChatProperties.threadProperties.isAudioMessageEnabled;
    showComposerSendButton = audioOn ? text.trim().isNotEmpty : true;
  }

  // -------------------------------------------------------------- mentions

  final _mentionSuggestions = <UserDetails>[].obs;

  /// Members offered by the thread composer's `@` picker.
  List<UserDetails> get mentionSuggestions => _mentionSuggestions;

  final _showMentionUserList = false.obs;

  /// Whether the thread composer's `@` picker is visible.
  bool get showMentionUserList => _showMentionUserList.value;

  /// Same gate as the channel composer: group chats with
  /// [IsmChatFeature.mentionMember] on.
  bool get isMentionEnabled =>
      conversation?.isGroup == true &&
      IsmChatProperties.chatPageProperties.features
          .contains(IsmChatFeature.mentionMember);

  /// Group members to mention / resolve: the chat page's loaded list when
  /// available, else the conversation's members.
  List<UserDetails> get mentionMembers {
    if (IsmChatUtility.chatPageControllerRegistered) {
      final members = IsmChatUtility.chatPageController.groupMembers;
      if (members.isNotEmpty) return members;
    }
    return conversation?.members ?? const <UserDetails>[];
  }

  void _refreshMentionSuggestions(String text) {
    if (!isMentionEnabled) {
      hideMentionSuggestions();
      return;
    }
    final suggestions = mentionSuggestionsForComposer(text, mentionMembers);
    // assignAll keeps the RxList backing list mutable (a const list would
    // make the later clear() throw).
    _mentionSuggestions.assignAll(suggestions ?? const <UserDetails>[]);
    _showMentionUserList.value = suggestions != null;
  }

  /// Closes the `@` picker.
  void hideMentionSuggestions() {
    _showMentionUserList.value = false;
    _mentionSuggestions.clear();
  }

  /// Inserts [member] for the partial `@query` in the thread composer.
  void selectMention(UserDetails member) {
    if (isCurrentChatUser(member.userId)) {
      hideMentionSuggestions();
      return;
    }
    final updatedText = insertMentionIntoComposerText(
      replyController.text,
      mentionLabelForUser(member),
    );
    hideMentionSuggestions();
    replyController.value = replyController.value.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedText.length),
    );
    handleComposerTextChanged(updatedText);
    replyFocusNode.requestFocus();
  }

  /// Starts the recording affordance (timer only — capture lives on the page).
  void beginRecordingUi() {
    isEnableRecordingAudio = true;
    showComposerSendButton = true;
    recordingSeconds = 0;
    isRecordPlay = true;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      recordingSeconds++;
    });
  }

  void cancelRecordingUi() => _clearComposerRecording();

  /// Deletes an in-progress voice note (channel + thread UI).
  Future<void> recordDelete() async {
    if (IsmChatUtility.chatPageControllerRegistered) {
      await IsmChatUtility.chatPageController.recordVoice.stop();
    }
    _clearComposerRecording();
  }

  Future<void> recordPlayPauseVoice() async {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    final voice = IsmChatUtility.chatPageController.recordVoice;
    if (await voice.isPaused()) {
      await voice.resume();
      isRecordPlay = true;
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordingSeconds++;
      });
    } else {
      await voice.pause();
      isRecordPlay = false;
      _recordTimer?.cancel();
    }
  }

  void _clearComposerRecording() {
    _recordTimer?.cancel();
    _recordTimer = null;
    isEnableRecordingAudio = false;
    recordingSeconds = 0;
    isRecordPlay = true;
    _refreshComposerSendButton();
  }

  void _refreshComposerSendButton() {
    if (isEnableRecordingAudio) {
      showComposerSendButton = true;
      return;
    }
    final audioOn = IsmChatProperties.threadProperties.isAudioMessageEnabled;
    showComposerSendButton = audioOn
        ? replyController.text.trim().isNotEmpty
        : true;
  }

  // ----------------------------------------------------------- emoji board

  final _showEmojiBoard = false.obs;
  bool get showEmojiBoard => _showEmojiBoard.value;

  final _emojiBoardTab = IsmChatEmojiBoardTab.emoji.obs;
  IsmChatEmojiBoardTab get emojiBoardTab => _emojiBoardTab.value;
  set emojiBoardTab(IsmChatEmojiBoardTab value) => _emojiBoardTab.value = value;

  /// Opens or closes the thread emoji / GIF / sticker panel.
  void toggleEmojiBoard([
    bool? showEmoji,
    bool focusKeyboard = true,
  ]) {
    // Same focus/keyboard dance as [IsmChatPageUiStateManagementMixin.toggleEmojiBoard].
    if (showEmoji ?? showEmojiBoard) {
      if (focusKeyboard) {
        replyFocusNode.requestFocus();
      }
    } else {
      final context =
          IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
      IsmChatUtility.rememberKeyboardViewInset(context);
      IsmChatUtility.hideKeyboard();
    }
    _showEmojiBoard.value = showEmoji ?? !showEmojiBoard;
  }

  void closeEmojiBoard() => toggleEmojiBoard(false, false);

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
    _recordTimer?.cancel();
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
    final timeline = IsmChatUtility.chatPageControllerRegistered
        ? IsmChatUtility.chatPageController.messages
        : const <IsmChatMessageModel>[];
    final panelRoot = IsmChatThreadCoordinator.resolveThreadPanelRoot(
      root,
      timeline,
    );
    if (!IsmChatThreadCoordinator.canOpenThread(panelRoot)) return;
    this.root = panelRoot;
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
    hideMentionSuggestions();
    _clearComposerRecording();
    _showEmojiBoard.value = false;
    _emojiBoardTab.value = IsmChatEmojiBoardTab.emoji;
    // From here on, attachments picked in the panel are thread replies.
    syncSendTarget();
    await loadReplies();
  }

  /// Clears the panel state (called when the thread view is popped).
  void closeThread() {
    final rootMessage = root;
    if (rootMessage != null) {
      // Pop/dispose locks the widget tree; syncing the channel timeline touches
      // [IsmChatPageController.messages] and rebuilds stacked GetX on the chat
      // route. Defer until after the frame and pass [conversationIdOverride]
      // because panel state is cleared below before the callback runs.
      final convId = conversationId;
      final snapshot = rootMessage;
      IsmChatUtility.doLater(
        () => _publishRootToTimeline(
          snapshot,
          conversationIdOverride: convId,
        ),
      );
    }
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
    hideMentionSuggestions();
    _clearComposerRecording();
    _showEmojiBoard.value = false;
    _emojiBoardTab.value = IsmChatEmojiBoardTab.emoji;
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
    if (isEditing) {
      return submitEditFromThreadComposer();
    }
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
    final members = isMentionEnabled ? mentionMembers : const <UserDetails>[];
    final mentions = members.isEmpty
        ? const <MentionModel>[]
        : resolveComposerMentions(body, members);
    final pending = buildLocalReply(
      body: body,
      parent: parent,
      conversationId: convId,
      alsoSendToChannel: sendToChannel,
      mentionedUsers: mentionedUserDetailsFor(mentions, members),
    );

    _isSending.value = true;
    _sendError.value = '';
    hideMentionSuggestions();
    replyController.clear();
    _replyTo.value = null;
    _replies.add(pending);
    requestScrollRepliesToBottom();
    if (sendToChannel) {
      _mirrorAlsoSendOnChannel(pending);
    }
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
        mentionedUsers: mentions.isEmpty
            ? null
            : mentions.map((e) => e.toMap()).toList(),
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
        if (sendToChannel) {
          _removeAlsoSendFromChannel(pending.sentAt);
        }
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
        await _bumpRoot(confirmed, persist: true);
      }
      if (sendToChannel) {
        _mirrorAlsoSendOnChannel(confirmed);
        await _persistAlsoSendReplyToDb(confirmed);
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
    List<UserDetails>? mentionedUsers,
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
      mentionedUsers:
          (mentionedUsers?.isNotEmpty ?? false) ? mentionedUsers : null,
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
    if (reply.sentByMe) {
      requestScrollRepliesToBottom();
    }
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
      unawaited(_bumpRoot(confirmed, persist: true));
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

  /// Patches [reactions] (and related fields from [updated]) onto the open
  /// panel row with the same server [messageId].
  ///
  /// Returns `true` when this panel owned that message (root or loaded reply).
  bool applyMessageUpdate(IsmChatMessageModel updated) {
    final id = (updated.messageId ?? '').trim();
    if (id.isEmpty) return false;

    final rootMessage = root;
    if (rootMessage != null && (rootMessage.messageId ?? '').trim() == id) {
      root = rootMessage.copyWith(
        body: updated.body,
        searchableTags: updated.searchableTags,
        messageUpdated: updated.messageUpdated,
        metaData: updated.metaData ?? rootMessage.metaData,
        reactions: _copyReactions(updated.reactions ?? rootMessage.reactions),
      );
      _root.refresh();
      update();
      return true;
    }

    final index = _replies.indexWhere((e) => (e.messageId ?? '').trim() == id);
    if (index == -1) return false;
    final row = _replies[index];
    _replies[index] = row.copyWith(
      body: updated.body,
      searchableTags: updated.searchableTags,
      messageUpdated: updated.messageUpdated,
      metaData: updated.metaData ?? row.metaData,
      reactions: _copyReactions(updated.reactions ?? row.reactions),
    );
    _replies.refresh();
    update();
    return true;
  }

  /// Applies an add/remove reaction to a row that lives only in the panel
  /// (thread-only replies are not kept in the local DB message map).
  bool applyReactionChange({
    required String messageId,
    required String emojiKey,
    required bool added,
    String? userId,
  }) {
    final id = messageId.trim();
    final key = emojiKey.trim();
    if (id.isEmpty || key.isEmpty) return false;
  final uid =
        (userId ?? IsmChatConfig.communicationConfig.userConfig.userId).trim();
    if (uid.isEmpty) return false;

    IsmChatMessageModel patchRow(IsmChatMessageModel row) {
      var reactions = List<MessageReactionModel>.from(row.reactions ?? []);
      if (added) {
        var matched = false;
        for (var i = 0; i < reactions.length; i++) {
          final entry = reactions[i];
          if (entry.emojiKey != key) continue;
          final users = List<String>.from(entry.userIds);
          if (!users.contains(uid)) {
            users.add(uid);
          }
          reactions[i] = entry.copyWith(userIds: users);
          matched = true;
          break;
        }
        if (!matched) {
          reactions.add(MessageReactionModel(emojiKey: key, userIds: [uid]));
        }
      } else {
        for (var i = 0; i < reactions.length; i++) {
          final entry = reactions[i];
          if (entry.emojiKey != key) continue;
          if (entry.userIds.length > 1 && entry.userIds.contains(uid)) {
            reactions[i] = entry.copyWith(
              userIds: entry.userIds.where((e) => e != uid).toList(),
            );
          } else {
            reactions.removeAt(i);
          }
          break;
        }
      }
      return row.copyWith(reactions: _copyReactions(reactions));
    }

    final rootMessage = root;
    if (rootMessage != null && (rootMessage.messageId ?? '').trim() == id) {
      root = patchRow(rootMessage);
      _root.refresh();
      return true;
    }

    final index = _replies.indexWhere((e) => (e.messageId ?? '').trim() == id);
    if (index == -1) return false;
    _replies[index] = patchRow(_replies[index]);
    _replies.refresh();
    update();
    return true;
  }

  /// Pulls reaction chips from the full conversation cache (not just the
  /// filtered channel timeline).
  void syncReactionsFromCache(Iterable<IsmChatMessageModel> cached) {
    for (final row in cached) {
      applyMessageUpdate(row);
    }
  }

  /// Root or reply currently shown in the panel with [messageId], if any.
  ///
  /// Reuse when MQTT edit payloads arrive before the row is in the DB cache.
  static IsmChatMessageModel? findMessageInOpenPanel(String messageId) {
    final id = messageId.trim();
    if (id.isEmpty) return null;
    final controller = instance;
    if (controller == null) return null;
    final rootMessage = controller.root;
    if (rootMessage != null && (rootMessage.messageId ?? '').trim() == id) {
      return rootMessage;
    }
    for (final reply in controller.replies) {
      if ((reply.messageId ?? '').trim() == id) return reply;
    }
    return null;
  }

  /// Routes a reaction add/remove to the open panel when the row has no DB
  /// entry (typical for thread-only replies).
  /// Routes `messageDetailsUpdated` to the open thread panel when applicable.
  static void applyMessageDetailsUpdate(IsmChatMessageModel updated) {
    if (!IsmChatThreadCoordinator.isEnabled) return;
    final controller = instance;
    if (controller == null) return;
    controller.applyMessageUpdate(updated);
  }

  static void deliverReactionChange({
    required String messageId,
    required String emojiKey,
    required bool added,
    String? userId,
  }) {
    if (!IsmChatThreadCoordinator.isEnabled) return;
    final controller = instance;
    if (controller == null || controller.root == null) return;
    controller.applyReactionChange(
      messageId: messageId,
      emojiKey: emojiKey,
      added: added,
      userId: userId,
    );
  }

  /// Refreshes reaction chips for the root and also-sent replies that appear
  /// on [timeline], without overwriting thread badge fields on the root.
  void syncOpenThreadFromChannel(List<IsmChatMessageModel> timeline) {
    if (root == null || timeline.isEmpty) return;

    final rootMessage = root!;
    final rootId = (rootMessage.messageId ?? '').trim();
    var changed = false;

    if (rootId.isNotEmpty) {
      for (final row in timeline) {
        if ((row.messageId ?? '').trim() != rootId) continue;
        final nextReactions = row.reactions;
        if (!_reactionListsEqual(nextReactions, rootMessage.reactions)) {
          root = rootMessage.copyWith(
            reactions: _copyReactions(nextReactions),
            replyCount: rootMessage.replyCount ?? row.replyCount,
            lastThreadReplyAt:
                rootMessage.lastThreadReplyAt ?? row.lastThreadReplyAt,
          );
          _root.refresh();
          changed = true;
        }
        break;
      }
    }

    for (var i = 0; i < _replies.length; i++) {
      final reply = _replies[i];
      final replyId = (reply.messageId ?? '').trim();
      if (replyId.isEmpty) continue;
      for (final row in timeline) {
        if ((row.messageId ?? '').trim() != replyId) continue;
        final nextReactions = row.reactions;
        if (_reactionListsEqual(nextReactions, reply.reactions)) break;
        _replies[i] = reply.copyWith(reactions: _copyReactions(nextReactions));
        changed = true;
        break;
      }
    }

    if (changed) {
      _replies.refresh();
      update();
    }
  }

  /// Routes a reaction (or other) message patch to the open panel, if any.
  static void deliverMessageUpdate(IsmChatMessageModel updated) {
    if (!IsmChatThreadCoordinator.isEnabled) return;
    final controller = instance;
    if (controller == null || controller.root == null) return;
    controller.applyMessageUpdate(updated);
  }

  static bool _reactionListsEqual(
    List<MessageReactionModel>? a,
    List<MessageReactionModel>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<MessageReactionModel>? _copyReactions(
    List<MessageReactionModel>? reactions,
  ) {
    if (reactions == null) return null;
    return reactions
        .map(
          (e) => MessageReactionModel(
            emojiKey: e.emojiKey,
            userIds: List<String>.from(e.userIds),
          ),
        )
        .toList();
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
  Future<void> _bumpRoot(IsmChatMessageModel reply, {required bool persist}) async {
    final rootMessage = root;
    if (rootMessage == null) return;
    final updated = IsmChatThreadCoordinator.applyReplyToRoot(
      rootMessage,
      reply,
    );
    root = updated;
    _publishRootToTimeline(updated);
    if (persist) {
      await _persistRootToDb(updated);
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

  /// Whether [reply] should appear on the live channel timeline (Slack
  /// "also send to channel").
  bool _shouldMirrorOnChannel(IsmChatMessageModel reply) =>
      IsmChatThreadCoordinator.isThreadReply(reply) &&
      reply.showInConversation == true;

  /// Merges [reply] into the open chat page list (own sends never get MQTT).
  void _mirrorAlsoSendOnChannel(IsmChatMessageModel reply) {
    if (!_shouldMirrorOnChannel(reply)) return;
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    final page = IsmChatUtility.chatPageController;
    if (page.conversation?.conversationId != conversationId) return;

    final id = (reply.messageId ?? '').trim();
    var next = List<IsmChatMessageModel>.from(page.messages);
    var replaced = false;
    if (id.isNotEmpty) {
      final byId = next.indexWhere((e) => (e.messageId ?? '').trim() == id);
      if (byId != -1) {
        next[byId] = reply;
        replaced = true;
      }
    }
    if (!replaced) {
      final bySentAt = next.indexWhere((e) => e.sentAt == reply.sentAt);
      if (bySentAt != -1) {
        next[bySentAt] = reply;
        replaced = true;
      }
    }
    if (!replaced) {
      next.add(reply);
    }
    page.messages = page.commonController.sortMessages(
      page.filterMessages(next),
    );
    page.update();
    page.updateLastMessagOnCurrentTime(reply);
  }

  /// Drops an optimistic also-send row from the channel after a hard failure.
  void _removeAlsoSendFromChannel(int sentAt) {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    final page = IsmChatUtility.chatPageController;
    if (page.conversation?.conversationId != conversationId) return;
    final next = List<IsmChatMessageModel>.from(page.messages)
      ..removeWhere(
        (e) => e.sentAt == sentAt && (e.messageId ?? '').isEmpty,
      );
    page.messages = next;
    page.update();
  }

  /// Stores a confirmed also-send reply in the main conversation cache.
  Future<void> _persistAlsoSendReplyToDb(IsmChatMessageModel reply) async {
    final convId = conversationId;
    if (convId.isEmpty) return;
    await IsmChatConfig.dbWrapper?.updateConversation(
      conversationId: convId,
      update: (latest) {
        if (latest == null || latest.conversationId != convId) return null;
        final messages = Map<String, IsmChatMessageModel>.from(
          latest.messages ?? {},
        )..['${reply.sentAt}'] = reply;
        var next = latest.copyWith(messages: messages);
        if (!IsmChatThreadCoordinator.isThreadOnlyReply(reply)) {
          next = next.copyWith(
            lastMessageDetails: next.lastMessageDetails?.copyWith(
              reactionType: '',
              messageId: reply.messageId,
              action: '',
            ),
          );
        }
        return next;
      },
    );
  }

  /// Writes the updated root back into the channel timeline so the
  /// "N replies" footer updates live. Best-effort: the chat page may be gone.
  ///
  /// [conversationIdOverride] is used when the panel was already torn down
  /// (e.g. deferred [closeThread] publish).
  void _publishRootToTimeline(
    IsmChatMessageModel updatedRoot, {
    String? conversationIdOverride,
  }) {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    final pageController = IsmChatUtility.chatPageController;
    final convId = conversationIdOverride ?? conversationId;
    if (convId.isEmpty ||
        pageController.conversation?.conversationId != convId) {
      return;
    }
    IsmChatUtility.notifyRxSafely(
      () => _syncRootOnChannelTimeline(pageController, updatedRoot),
    );
  }

  /// Mirrors [IsmChatThreadCoordinator.applyReplyToRootInList] but applies an
  /// already-updated root document (own send / refresh), so GetX sees a new list.
  static void _syncRootOnChannelTimeline(
    IsmChatPageController pageController,
    IsmChatMessageModel updatedRoot,
  ) {
    final rootId = (updatedRoot.messageId ?? '').trim();
    if (rootId.isEmpty) return;
    final next = List<IsmChatMessageModel>.from(pageController.messages);
    final index = next.indexWhere((e) => (e.messageId ?? '').trim() == rootId);
    if (index == -1) return;
    next[index] = next[index].copyWith(
      replyCount: updatedRoot.replyCount,
      lastThreadReplyAt: updatedRoot.lastThreadReplyAt,
    );
    pageController.messages = next;
    pageController.update();
  }
}
