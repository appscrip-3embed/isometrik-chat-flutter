part of '../isometrik_chat_flutter.dart';

/// Slack-style threading mixin for [IsmChatDelegate].
///
/// Implements the threads surface: the on/off switch, opening the thread panel,
/// and reading / sending thread replies without any UI. Work is delegated to
/// [IsmChatThreadController] (registered on demand by [IsmChatThreadBinding])
/// so the panel, host code and realtime updates share one state.
///
/// Everything here is inert while [IsmChatConfig.threadsEnabled] is `false`.
mixin IsmChatDelegateThreadsMixin {
  /// The thread controller, registering it first when needed.
  IsmChatThreadController get _threadController {
    IsmChatThreadBinding().dependencies();
    return Get.find<IsmChatThreadController>();
  }

  /// Whether the Slack-style thread interface is on.
  bool get threadsEnabled => IsmChatConfig.threadsEnabled;

  /// Turns threading on or off at runtime.
  ///
  /// Switching re-reads the open conversation so the timeline is re-fetched
  /// with (`main`) or without (legacy) `feedType`, and drops any open thread
  /// state. Safe to call before chat is opened.
  Future<void> setThreadsEnabled(bool value) async {
    if (IsmChatConfig.threadsEnabled == value) return;
    IsmChatConfig.threadsEnabled = value;

    // Drop thread state so a stale panel cannot survive the switch.
    if (Get.isRegistered<IsmChatThreadController>()) {
      Get.find<IsmChatThreadController>().closeThread();
      await Get.delete<IsmChatThreadController>(force: true);
    }

    // Re-read the open chat: the timeline filter and the `feedType` param both
    // change with this flag.
    if (IsmChatUtility.chatPageControllerRegistered) {
      final controller = IsmChatUtility.chatPageController;
      final conversationId = controller.conversation?.conversationId ?? '';
      if (conversationId.isNotEmpty) {
        await controller.getMessagesFromDB(conversationId);
        await controller.getMessagesFromAPI();
      }
    }
  }

  /// Opens the thread panel for [message].
  ///
  /// Mobile pushes [IsmChatThreadView] as a route; web shows it in a dialog so
  /// the chat stays visible behind it. No-op when threading is off or the
  /// message cannot root a thread (no server id, deleted, system row).
  Future<void> openThread(
    IsmChatMessageModel message, {
    IsmChatConversationModel? conversation,
  }) async {
    final timeline = IsmChatUtility.chatPageControllerRegistered
        ? IsmChatUtility.chatPageController.messages
        : const <IsmChatMessageModel>[];
    final panelRoot =
        IsmChatThreadCoordinator.resolveThreadPanelRoot(message, timeline);
    if (!IsmChatThreadCoordinator.canOpenThread(panelRoot)) return;
    IsmChatThreadBinding().dependencies();
    final resolvedConversation = conversation ??
        (IsmChatUtility.chatPageControllerRegistered
            ? IsmChatUtility.chatPageController.conversation
            : null);
    await _threadController.openThread(
      root: panelRoot,
      conversation: resolvedConversation,
    );
    final view = IsmChatThreadView(
      rootMessage: panelRoot,
      conversation: resolvedConversation,
    );
    final context =
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
    if (IsmChatResponsive.isWeb(context)) {
      await IsmChatContextWidget.showDialogContext(
        content: IsmChatPageDailog(child: view),
      );
      return;
    }
    await IsmChatRoute.goToRoute<void>(view);
  }

  /// The thread currently open in the panel, or `null`.
  IsmChatMessageModel? get openThreadRoot =>
      Get.isRegistered<IsmChatThreadController>()
          ? Get.find<IsmChatThreadController>().root
          : null;

  /// Reads one page of a thread without any UI.
  ///
  /// Returns an empty list when threading is off or the request fails — check
  /// [threadsEnabled] first if you need to tell those apart.
  Future<List<IsmChatMessageModel>> getThreadReplies({
    required String conversationId,
    required String threadRootId,
    int limit = 20,
    int skip = 0,
  }) async {
    if (!IsmChatConfig.threadsEnabled) return [];
    final messages = await IsmChatThreadViewModel(
      IsmChatThreadRepository(),
    ).getThreadMessages(
      conversationId: conversationId,
      threadRootId: threadRootId,
      limit: limit,
      skip: skip,
    );
    return messages ?? [];
  }

  /// Server-side count of every reply in a thread, or `null` when unavailable.
  Future<int?> getThreadReplyCount({
    required String conversationId,
    required String threadRootId,
  }) async {
    if (!IsmChatConfig.threadsEnabled) return null;
    return IsmChatThreadViewModel(IsmChatThreadRepository()).getThreadReplyCount(
      conversationId: conversationId,
      threadRootId: threadRootId,
    );
  }

  /// Sends [text] as a reply in [parent]'s thread.
  ///
  /// [parent] may be the root or another reply; the server derives
  /// `threadRootId` either way. With [alsoSendToChannel] the reply is also
  /// posted to the channel timeline (Slack's "Also send to channel").
  ///
  /// Returns `true` when the server accepted it. When the thread panel is open
  /// on this thread the reply appears there immediately.
  Future<bool> sendThreadReply({
    required IsmChatMessageModel parent,
    required String text,
    bool alsoSendToChannel = false,
  }) async {
    if (!IsmChatConfig.threadsEnabled) return false;
    final body = text.trim();
    if (body.isEmpty) return false;
    final controller = _threadController;
    final rootId = IsmChatThreadCoordinator.threadIdOf(parent);
    // Reuse the open panel when it already shows this thread so its list and
    // badge update; otherwise target the controller at the parent first.
    if (controller.threadRootId != rootId) {
      final root = controller.root;
      if (root == null || IsmChatThreadCoordinator.threadIdOf(root) != rootId) {
        final timeline = IsmChatUtility.chatPageControllerRegistered
            ? IsmChatUtility.chatPageController.messages
            : const <IsmChatMessageModel>[];
        final panelRoot = IsmChatThreadCoordinator.resolveThreadPanelRoot(
          parent,
          timeline,
        );
        await controller.openThread(root: panelRoot);
      }
    }
    controller.alsoSendToChannel = alsoSendToChannel;
    return controller.sendReply(text: body, replyTo: parent);
  }
}
