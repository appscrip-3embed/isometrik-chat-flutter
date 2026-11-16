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

  @override
  void initState() {
    super.initState();
    IsmChatThreadBinding().dependencies();
    _controller = Get.find<IsmChatThreadController>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.openThread(
        root: widget.rootMessage,
        conversation: widget.conversation,
      );
      _props.onThreadOpened?.call(widget.rootMessage);
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = IsmChatThemeResolver.threadFromConfig(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
            IsmChatThreadMessageTile(
              message: _controller.root ?? widget.rootMessage,
              isRoot: true,
            ),
            _replyCountRow(theme),
            Expanded(child: _replies(theme)),
            IsmChatThreadComposer(controller: _controller),
          ],
        ),
      ),
    );
  }

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

  Widget _replies(IsmChatThreadTheme theme) {
    if (_controller.isLoading && _controller.replies.isEmpty) {
      return const Center(child: IsmChatLoadingDialog());
    }
    if (_controller.replies.isEmpty) {
      if (_controller.loadErrorMessage.isNotEmpty) {
        return _retry(theme);
      }
      return _props.emptyPlaceholder ??
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
          );
    }
    return ListView.separated(
      key: const Key('ism-thread-replies'),
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: IsmChatDimens.eight),
      itemCount: _controller.replies.length + (_controller.isPaginating ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
        height: IsmChatDimens.one,
        color: theme.dividerColor,
      ),
      itemBuilder: (_, index) {
        if (index >= _controller.replies.length) {
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
        final reply = _controller.replies[index];
        // Tap a reply to answer it (nested reply inside the same thread).
        return IsmChatTapHandler(
          onTap: () => _controller.replyTo = reply,
          child: IsmChatThreadMessageTile(message: reply),
        );
      },
    );
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
