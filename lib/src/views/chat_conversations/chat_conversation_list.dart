import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

/// `ChatConversationList` can be used to show the list of all the conversations user has done.
class IsmChatConversationList extends StatelessWidget {
  const IsmChatConversationList({
    super.key,
  });

  Future<void> _onRefresh() async {
    if (!IsmChatUtility.conversationControllerRegistered) {
      return;
    }
    final controller = IsmChatUtility.conversationController;
    FocusManager.instance.primaryFocus?.unfocus();
    controller.searchConversationTEC.clear();
    await controller.getChatConversations(
      origin: ApiCallOrigin.referesh,
    );
    if (Get.isRegistered<IsmChatMqttController>()) {
      await Get.find<IsmChatMqttController>().getChatConversationsUnreadCount();
    }
    unawaited(IsmChat.i.getStorageUsage(forceRefresh: true));
  }

  Future<bool> _onLoading() async {
    if (!IsmChatUtility.conversationControllerRegistered) {
      return true;
    }
    final controller = IsmChatUtility.conversationController;
    final chats = await controller.getChatConversations(
      skip: controller.conversations.length.pagination(),
      origin: ApiCallOrigin.loadMore,
    );
    return chats.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = IsmChatProperties.conversationProperties.height;

    final listBody = kIsWeb
        ? _ConversationPullRefresh(
            onRefresh: _onRefresh,
            onLoading: _onLoading,
            enablePullToRefresh: false,
          )
        : SlidableAutoCloseBehavior(
            child: _ConversationPullRefresh(
              onRefresh: _onRefresh,
              onLoading: _onLoading,
              enablePullToRefresh: true,
            ),
          );

    final body = maxHeight != null
        ? SizedBox(height: maxHeight, child: listBody)
        : listBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IsmChatStorageQuotaListBanner(),
        Expanded(child: body),
      ],
    );
  }
}

/// One stable [ListView] under [SmartRefresher] so [conversationScrollController]
/// is not re-bound after pull-to-refresh (GetX used to rebuild a new list).
class _ConversationPullRefresh extends StatefulWidget {
  const _ConversationPullRefresh({
    required this.onRefresh,
    required this.onLoading,
    required this.enablePullToRefresh,
  });

  final Future<void> Function() onRefresh;
  final Future<bool> Function() onLoading;
  final bool enablePullToRefresh;

  @override
  State<_ConversationPullRefresh> createState() =>
      _ConversationPullRefreshState();
}

class _ConversationPullRefreshState extends State<_ConversationPullRefresh> {
  static const _listKey = PageStorageKey<String>('ism_chat_conversation_list');

  late final IsmChatConversationsController _controller;
  Worker? _conversationsWorker;

  @override
  void initState() {
    super.initState();
    _controller = IsmChatUtility.conversationController;
    _conversationsWorker = ever<List<IsmChatConversationModel>>(
      _controller.conversations as RxInterface<List<IsmChatConversationModel>>,
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _conversationsWorker?.dispose();
    super.dispose();
  }

  int _itemCount() {
    if (_controller.userConversations.isNotEmpty) {
      return _controller.userConversations.length;
    }
    return 1;
  }

  bool get _showingPlaceholder => _controller.userConversations.isEmpty;

  double _placeholderExtent(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return screenHeight * 0.45;
  }

  Widget _emptyChild() {
    final isSearching = _controller.isSearchingConversations;
    if (isSearching) {
      return IsmChatProperties.conversationProperties.searchPlaceholder ??
          IsmChatEmptyView(
            icon: Icon(
              Icons.search_off_outlined,
              size: IsmChatDimens.fifty,
              color: IsmChatColors.greyColor,
            ),
            text: IsmChatStrings.noResultsFound,
          );
    }
    return IsmChatProperties.conversationProperties.placeholder ??
        IsmChatEmptyView(
          icon: Icon(Icons.chat_outlined),
          text: IsmChatStrings.noConversation,
        );
  }

  Widget _placeholderTile(BuildContext context) {
    final content = _controller.isConversationsLoading
        ? const IsmChatLoadingDialog()
        : _emptyChild();
    return SizedBox(
      height: _placeholderExtent(context),
      child: Center(child: content),
    );
  }

  Widget _conversationTile(BuildContext context, int index) {
    final conversation = _controller.userConversations[index];
    return IsmChatTapHandler(
      onTap: () async {
        IsmChatProperties.conversationProperties.onChatTap
            ?.call(context, conversation);
        if (IsmChatProperties.conversationProperties.shouldGoToChatPage
                ?.call(context, conversation) ??
            true) {
          await _controller.updateLocalConversation(conversation);
          await _controller.goToChatPage();
        }
      },
      child: IsmChatProperties.conversationProperties.cardBuilder
              ?.call(context, conversation, index) ??
          _SlidableWidget(conversation: conversation),
    );
  }

  Widget _listView() {
    return ListView.separated(
      key: _listKey,
      padding: IsmChatDimens.edgeInsets0_10,
      itemCount: _itemCount(),
      controller: _controller.conversationScrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      separatorBuilder: (context, index) {
        if (_showingPlaceholder) return const SizedBox.shrink();
        return IsmChatProperties.conversationProperties.conversationDivider ??
            IsmChatDimens.boxHeight2;
      },
      addAutomaticKeepAlives: true,
      itemBuilder: (context, index) {
        if (_showingPlaceholder) {
          return _placeholderTile(context);
        }
        return _conversationTile(context, index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _listView();

    if (!widget.enablePullToRefresh) {
      return list;
    }

    return RefreshConfiguration(
      enableScrollWhenRefreshCompleted: true,
      // Don't reserve footer space when the list is shorter than the screen.
      hideFooterWhenNotFull: true,
      child: IsmChatPullToRefresh(
        header: const RefreshHeader(),
        footer: const RefreshFooter(),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        onRefresh: widget.onRefresh,
        onLoading: widget.onLoading,
        child: list,
      ),
    );
  }
}

class _SlidableWidget extends StatefulWidget {
  const _SlidableWidget({required this.conversation});

  final IsmChatConversationModel conversation;

  @override
  State<_SlidableWidget> createState() => _SlidableWidgetState();
}

class _SlidableWidgetState extends State<_SlidableWidget>
    with SingleTickerProviderStateMixin {
  SlidableController? slidableController;

  final controller = IsmChatUtility.conversationController;

  @override
  void initState() {
    slidableController = SlidableController(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Slidable(
        controller: slidableController,
        direction: Axis.horizontal,
        enabled: IsmChatProperties.conversationProperties.isSlidableEnable
                ?.call(context, widget.conversation) ??
            false,
        startActionPane: !(IsmChatProperties
                    .conversationProperties.startActionSlidableEnable
                    ?.call(context, widget.conversation) ??
                false)
            ? null
            : (IsmChatProperties.conversationProperties.actions == null ||
                    IsmChatProperties.conversationProperties.actions?.isEmpty ==
                        true)
                ? null
                : ActionPane(
                    extentRatio: 0.3,
                    motion: const ScrollMotion(),
                    children: [
                      ...IsmChatProperties.conversationProperties.actions?.map(
                            (e) => IsmChatActionWidget(
                              onTap: () {
                                slidableController?.close();
                                e.onTap.call(widget.conversation);
                              },
                              decoration: e.decoration,
                              icon: e.icon,
                              label: e.label,
                              labelStyle: e.labelStyle,
                            ),
                          ) ??
                          [],
                    ],
                  ),
        endActionPane: !IsmChatProperties.conversationProperties.allowDelete &&
                !(IsmChatProperties
                        .conversationProperties.endActionSlidableEnable
                        ?.call(context, widget.conversation) ??
                    true)
            ? null
            : !IsmChatProperties.conversationProperties.allowDelete &&
                    (IsmChatProperties.conversationProperties.endActions ==
                            null ||
                        IsmChatProperties
                                .conversationProperties.endActions?.isEmpty ==
                            true)
                ? null
                : ActionPane(
                    extentRatio: 0.3,
                    motion: const StretchMotion(),
                    children: [
                      ...IsmChatProperties.conversationProperties.endActions
                              ?.map(
                            (e) => IsmChatActionWidget(
                              onTap: () {
                                slidableController?.close();
                                e.onTap.call(widget.conversation);
                              },
                              decoration: e.decoration,
                              icon: e.icon,
                              label: e.label,
                              labelStyle: e.labelStyle,
                            ),
                          ) ??
                          [],
                      if (IsmChatProperties.conversationProperties.allowDelete)
                        SlidableAction(
                          onPressed: (_) async {
                            await IsmChatContextWidget.showBottomsheetContext(
                              content: IsmChatClearConversationBottomSheet(
                                widget.conversation,
                              ),
                              backgroundColor: IsmChatColors.transparent,
                              isDismissible: true,
                              elevation: 0,
                            );
                          },
                          flex: 1,
                          backgroundColor: IsmChatColors.redColor,
                          foregroundColor: IsmChatColors.whiteColor,
                          icon: Icon(
                            widget.conversation.isGroup == true
                                ? Icons.logout_rounded
                                : Icons.delete_rounded,
                            color: IsmChatColors.whiteColor,
                          ).icon,
                          label: widget.conversation.isGroup == true
                              ? IsmChatStrings.exitGroup
                              : IsmChatStrings.delete,
                        ),
                    ],
                  ),
        child: Obx(
          () => IsmChatConversationCard(
            canShowStack: IsmChatProperties
                .conversationProperties.cardElementBuilders?.canShowStack,
            onProfileTap: IsmChatProperties
                .conversationProperties.cardElementBuilders?.onProfileTap,
            isShowBackgroundColor: IsmChatResponsive.isWeb(context)
                ? controller.currentConversationId ==
                    widget.conversation.conversationId
                : false,
            name: IsmChatProperties
                .conversationProperties.cardElementBuilders?.name,
            nameBuilder: IsmChatProperties
                .conversationProperties.cardElementBuilders?.nameBuilder,
            trailing: IsmChatProperties
                .conversationProperties.cardElementBuilders?.trailing,
            trailingBuilder: IsmChatProperties
                .conversationProperties.cardElementBuilders?.trailingBuilder,
            profileImageUrl: IsmChatProperties
                .conversationProperties.cardElementBuilders?.profileImageUrl,
            subtitle: IsmChatProperties
                .conversationProperties.cardElementBuilders?.subtitle,
            widget.conversation,
            profileImageBuilder: IsmChatProperties.conversationProperties
                .cardElementBuilders?.profileImageBuilder,
            subtitleBuilder: !widget.conversation.isSomeoneTyping
                ? IsmChatProperties
                    .conversationProperties.cardElementBuilders?.subtitleBuilder
                : (_, __, ___) => Text(
                      widget.conversation.typingUsers,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IsmChatStyles.typing,
                    ),
            onTap: () async {
              if (IsmChatProperties.conversationProperties.onChatTap != null) {
                IsmChatProperties.conversationProperties.onChatTap?.call(
                  context,
                  widget.conversation,
                );
              }
              if (IsmChatProperties.conversationProperties.shouldGoToChatPage
                      ?.call(context, widget.conversation) ??
                  true) {
                await controller.updateLocalConversation(widget.conversation);

                await controller.goToChatPage();
              }
            },
            onLongPress: () {
              if (IsmChatProperties.conversationProperties.onLongPress !=
                  null) {
                IsmChatProperties.conversationProperties.onLongPress?.call(
                  context,
                  widget.conversation,
                );
              }
            },
          ),
        ),
      );
}
