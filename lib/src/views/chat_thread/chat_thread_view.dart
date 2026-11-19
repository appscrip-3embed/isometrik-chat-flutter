import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// The Slack-style thread panel: one root message and all of its replies.
///
/// Opened by tapping the "N replies" footer ([IsmChatThreadFooter]) or the
/// "Reply in thread" focus-menu action, and by host apps via
/// `IsmChat.i.openThread(message)`. Mobile pushes it as a route; web shows it
/// in a dialog (see `IsmChatDelegate.openThread`).
///
/// Everything on screen comes from [IsmChatThreadController]:
/// - the root card (sticky at the top),
/// - the replies, oldest-first, paging older ones in on scroll,
/// - the composer with "Also send to channel".
///
/// Customize copy / rows with [IsmChatProperties.threadProperties] and styling
/// with [IsmChatThemeData.threadTheme]. Requires
/// [IsmChatConfig.threadsEnabled]; with threads off this view is never shown.
class IsmChatThreadView extends StatefulWidget {
  const IsmChatThreadView({
    required this.rootMessage,
    this.conversation,
    super.key,
  });

  /// The channel message whose thread is being opened.
  final IsmChatMessageModel rootMessage;

  /// Conversation the thread belongs to. Falls back to the live chat page's
  /// conversation when omitted.
  final IsmChatConversationModel? conversation;

  @override
  State<IsmChatThreadView> createState() => _IsmChatThreadViewState();
}

class _IsmChatThreadViewState extends State<IsmChatThreadView> {
  final _scrollController = ScrollController();
  late final IsmChatThreadController _controller;

  IsmChatThreadProperties get _props => IsmChatProperties.threadProperties;

  /// Expected thread id for [widget.rootMessage] (resolves also-sent rows).
  String get _targetThreadId =>
      IsmChatThreadCoordinator.threadIdOf(widget.rootMessage);

  /// Panel state matches [widget.rootMessage] (avoids stale reply lists).
  bool get _isPanelSynced => _controller.threadRootId == _targetThreadId;

  @override
  void initState() {
    super.initState();
    IsmChatThreadBinding().dependencies();
    _controller = Get.find<IsmChatThreadController>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPanelIfNeeded());
  }

  @override
  void didUpdateWidget(covariant IsmChatThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootMessage.messageId != widget.rootMessage.messageId ||
        IsmChatThreadCoordinator.threadIdOf(oldWidget.rootMessage) !=
            _targetThreadId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPanelIfNeeded());
    }
  }

  /// Opens or re-targets the panel when the delegate has not already done so.
  Future<void> _syncPanelIfNeeded() async {
    if (!IsmChatThreadCoordinator.canOpenThread(widget.rootMessage)) return;
    if (!_isPanelSynced) {
      await _controller.openThread(
        root: widget.rootMessage,
        conversation: widget.conversation,
      );
    }
    _props.onThreadOpened?.call(widget.rootMessage);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.closeThread();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      _controller.loadMoreReplies();
    }
  }

  /// Dismisses the composer keyboard when scrolling replies or tapping the
  /// thread content (same pattern as [IsmChatSearchMessgae]).
  Widget _wrapKeyboardDismissBehavior(Widget child) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            IsmChatUtility.hideKeyboard();
          }
          return false;
        },
        child: GestureDetector(
          onTap: IsmChatUtility.hideKeyboard,
          behavior: HitTestBehavior.translucent,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = IsmChatThemeResolver.threadFromConfig(context);
    // Match [IsmChatConversations] unless the host set [IsmChatThemeData.threadTheme].
    final scaffoldBackground = IsmChatConfig.chatTheme.threadTheme != null
        ? theme.scaffoldBackgroundColor
        : IsmChatConfig.chatTheme.chatListTheme?.backGroundColor ??
            theme.scaffoldBackgroundColor;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: scaffoldBackground,
      appBar: IsmChatAppBar(
        title: Text(
          _props.title ?? IsmChatStrings.threadTitle,
          style: IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
              IsmChatStyles.w600White18,
        ),
        onBack: () => IsmChatRoute.goBack<void>(),
      ),
      body: Obx(
        () => Column(
          children: [
            Expanded(
              // Single scrollable: root + replies. A nested [Column] with a
              // fixed root tile overflowed when the keyboard shrank the body.
              child: _wrapKeyboardDismissBehavior(
                CustomScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: IsmChatThreadMessageTile(
                        message: _controller.root ?? widget.rootMessage,
                        isRoot: true,
                      ),
                    ),
                    SliverToBoxAdapter(child: _replyCountRow(theme)),
                    ..._replySlivers(theme),
                  ],
                ),
              ),
            ),
            // Same stack order as [_IsmChatPageView]: shell then emoji board.
            _threadComposerShell(context),
            Offstage(
              offstage: !_controller.showEmojiBoard,
              child: IsmChatComposerEmojiBoard(
                key: const Key('ism-thread-emoji-board'),
                textController: _controller.replyController,
                emojiBoardTab: _controller.emojiBoardTab,
                onTabChanged: (tab) => _controller.emojiBoardTab = tab,
                onBeforeGiphySend: () async {
                  _controller.syncSendTarget();
                },
                onAfterGiphySend: _controller.closeEmojiBoard,
              ),
            ),
          ],
        ),
      ),
    ).withUnfocusGestureDetctor(context);
  }

  /// Outer composer chrome matches [_IsmChatPageView._defaultComposer].
  /// Field background, border, emoji, and attach icons use the same
  /// [IsmChatPageTheme.textFiledTheme] as [IsmChatMessageField].
  Widget _threadComposerShell(BuildContext context) => Container(
        padding: IsmChatConfig
            .chatTheme.chatPageTheme?.textFiledTheme?.textfieldInsets,
        decoration:
            IsmChatConfig.chatTheme.chatPageTheme?.textFiledTheme?.decoration,
        child: SafeArea(
          bottom: !_controller.showEmojiBoard,
          child: IsmChatThreadComposer(controller: _controller),
        ),
      );

  Widget _replyCountRow(IsmChatThreadTheme theme) {
    final count = _controller.replyCount;
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: IsmChatDimens.twelve,
        vertical: IsmChatDimens.four,
      ),
      child: Row(
        children: [
          Text(
            IsmChatStrings.threadReplyCountLabel(count),
            key: const Key('ism-thread-reply-count'),
            style: theme.replyCountSummaryStyle,
          ),
          IsmChatDimens.boxWidth8,
          Expanded(child: Divider(color: theme.dividerColor)),
        ],
      ),
    );
  }

  /// Reply list as slivers for [CustomScrollView] (keyboard-safe layout).
  List<Widget> _replySlivers(IsmChatThreadTheme theme) {
    if (!_isPanelSynced && _controller.replies.isNotEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: IsmChatLoadingDialog()),
        ),
      ];
    }
    if (_controller.isLoading && _controller.replies.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: IsmChatLoadingDialog()),
        ),
      ];
    }
    if (_controller.replies.isEmpty) {
      if (_controller.loadErrorMessage.isNotEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _retry(theme),
          ),
        ];
      }
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _props.emptyPlaceholder ??
              Center(
                child: Padding(
                  padding: EdgeInsets.all(IsmChatDimens.twenty),
                  child: Text(
                    IsmChatStrings.threadNoReplies,
                    key: const Key('ism-thread-empty'),
                    textAlign: TextAlign.center,
                    style: theme.emptyTextStyle,
                  ),
                ),
              ),
        ),
      ];
    }

    final replyCount = _controller.replies.length;
    final hasPaginator = _controller.isPaginating;
    final childCount = replyCount * 2 - 1 + (hasPaginator ? 1 : 0);

    return [
      SliverPadding(
        key: const Key('ism-thread-replies'),
        padding: EdgeInsets.only(bottom: IsmChatDimens.eight),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, index) {
              if (hasPaginator && index == childCount - 1) {
                return Padding(
                  padding: EdgeInsets.all(IsmChatDimens.twelve),
                  child: Center(
                    child: SizedBox(
                      height: IsmChatDimens.twenty,
                      width: IsmChatDimens.twenty,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (index.isOdd) {
                return Divider(
                  height: IsmChatDimens.one,
                  color: theme.dividerColor,
                );
              }
              final reply = _controller.replies[index ~/ 2];
              final tile = IsmChatThreadMessageTile(message: reply);
              // Media rows handle their own taps (preview / open file). Text keeps
              // the Slack-style "tap to reply to this message" gesture.
              if (IsmChatThreadMessageTile.usesMediaTapBehavior(reply)) {
                return tile;
              }
              return IsmChatTapHandler(
                onTap: () {
                  IsmChatUtility.hideKeyboard();
                  _controller.replyTo = reply;
                },
                child: tile,
              );
            },
            childCount: childCount,
          ),
        ),
      ),
    ];
  }

  Widget _retry(IsmChatThreadTheme theme) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _controller.loadErrorMessage,
              textAlign: TextAlign.center,
              style: theme.errorTextStyle,
            ),
            IsmChatDimens.boxHeight8,
            TextButton(
              key: const Key('ism-thread-retry'),
              onPressed: _controller.loadReplies,
              child: Text(IsmChatStrings.threadRetry),
            ),
          ],
        ),
      );
}
