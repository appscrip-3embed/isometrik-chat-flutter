import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatMessage extends StatefulWidget {
  /// Paints [message] as passed by the list.
  ///
  /// The chat list and [ValueKey] must stay on the same instance. Looking the
  /// row up again with [index] shows the wrong message when a group burst
  /// inserts or removes rows under a reverse list. Search results still resolve
  /// by [index] because that list is built in the opposite order from the model
  /// it passes in.
  IsmChatMessage(
    this.index,
    IsmChatMessageModel? message, {
    bool isIgnorTap = false,
    bool isFromSearchMessage = false,
    super.key,
  })  : _message =
            isFromSearchMessage && IsmChatUtility.chatPageControllerRegistered
                ? IsmChatUtility.chatPageController.searchMessages.reversed
                    .toList()[index]
                : message,
        _isIgnorTap = isIgnorTap;

  final IsmChatMessageModel? _message;
  final bool? _isIgnorTap;
  final int index;

  @override
  State<IsmChatMessage> createState() => _IsmChatMessageState();
}

class _IsmChatMessageState extends State<IsmChatMessage>
    with AutomaticKeepAliveClientMixin<IsmChatMessage> {
  @override
  bool get wantKeepAlive => mounted;

  final coverstaionController = IsmChatUtility.conversationController;

  late bool showMessageInCenter;
  late bool isGroup;

  void _updateWidget() {
    showMessageInCenter = [
      IsmChatCustomMessageType.date,
      IsmChatCustomMessageType.block,
      IsmChatCustomMessageType.unblock,
      IsmChatCustomMessageType.conversationCreated,
      IsmChatCustomMessageType.removeMember,
      IsmChatCustomMessageType.addMember,
      IsmChatCustomMessageType.addAdmin,
      IsmChatCustomMessageType.removeAdmin,
      IsmChatCustomMessageType.memberLeave,
      IsmChatCustomMessageType.conversationImageUpdated,
      IsmChatCustomMessageType.conversationTitleUpdated,
      IsmChatCustomMessageType.memberJoin,
      IsmChatCustomMessageType.observerJoin,
      IsmChatCustomMessageType.observerLeave,
    ].contains(widget._message?.customType);
    isGroup = coverstaionController.currentConversation?.isGroup ?? false;
  }

  @override
  void initState() {
    super.initState();
    _updateWidget();
  }

  @override
  void didUpdateWidget(covariant IsmChatMessage oldWidget) {
    _updateWidget();
    super.didUpdateWidget(oldWidget);
  }

  /// Group-message avatar URL: host override → senderInfo → initiatorImageUrl.
  /// Empty strings are treated as missing so the next source is used.
  String _groupSenderProfileUrl(
      BuildContext context, IsmChatPageController controller) {
    final customUrl = IsmChatProperties
        .chatPageProperties.messageSenderProfileUrl
        ?.call(context, widget._message!, controller.conversation);
    if (!customUrl.isNullOrEmpty) return customUrl!;

    final senderUrl = widget._message?.senderInfo?.profileUrl;
    if (!senderUrl.isNullOrEmpty) return senderUrl!;

    return widget._message?.initiatorImageUrl ?? '';
  }

  /// Group-message avatar name: senderInfo → initiatorName.
  String _groupSenderName() {
    final senderName = widget._message?.senderInfo?.userName;
    if (!senderName.isNullOrEmpty) return senderName!;
    return widget._message?.initiatorName ?? '';
  }

  /// Checks if this message should be hidden because it's part of a grid group
  /// but not the first message in that group
  bool _shouldHideMessage(IsmChatPageController controller) {
    final message = widget._message;
    if (message == null || !message.isGridDisplayableMedia) {
      return false;
    }

    final cache = _GridHideCache.forFrame(controller.messages);
    return cache.results.putIfAbsent(message, () {
      final group =
          IsmChatMediaGridGrouping.collect(cache.chronologic, message);
      return IsmChatMediaGridGrouping.shouldHide(group, message);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final conversation = IsmChatUtility.chatPageControllerRegistered
        ? IsmChatUtility.chatPageController.conversation
        : coverstaionController.currentConversation;
    if (widget._message != null &&
        !widget._message!.isVisibleInGroupChat(conversation)) {
      return const SizedBox.shrink();
    }
    var theme = IsmChatConfig.chatTheme.chatPageTheme;
    return GetBuilder<IsmChatPageController>(
      tag: IsmChat.i.chatPageTag,
      builder: (controller) {
        // Hide the entire message if it's part of a grid but not the first message
        if (IsmChatUtility.chatPageControllerRegistered &&
            _shouldHideMessage(controller)) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          ignoring: showMessageInCenter || widget._isIgnorTap!,
          child: IsmChatTapHandler(
            onLongPress: showMessageInCenter ||
                    (IsmChatProperties.chatPageProperties.shouldShowHoverHold
                            ?.call(context, controller.conversation,
                                widget._message!) ??
                        false)
                ? null
                : () => controller.onMessageLongPress(
                      context,
                      widget._message!,
                      showMessageInCenter: showMessageInCenter,
                    ),
            onTap: showMessageInCenter
                ? null
                : () {
                    IsmChatUtility.hideKeyboard();
                    controller.onMessageSelect(widget._message!);
                    if (controller.showEmojiBoard) {
                      controller.toggleEmojiBoard(false, false);
                    }
                  },
            child: AbsorbPointer(
              absorbing: controller.isMessageSeleted,
              child: Container(
                padding: IsmChatDimens.edgeInsets4_0,
                color: controller.isMessageInSelection(widget._message!)
                    ? (IsmChatConfig.chatTheme.chatPageTheme
                                ?.messageSelectionColor ??
                            IsmChatConfig.chatTheme.primaryColor!)
                        .applyIsmOpacity(.2)
                    : null,
                child: UnconstrainedBox(
                  clipBehavior: Clip.none,
                  alignment: showMessageInCenter
                      ? Alignment.center
                      : widget._message?.sentByMe == true
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                  child: Padding(
                    padding: showMessageInCenter
                        ? IsmChatDimens.edgeInsets0
                        : IsmChatDimens.edgeInsets0_4,
                    child: Row(
                      crossAxisAlignment:
                          theme?.selfMessageTheme?.showProfile != null &&
                                  theme?.selfMessageTheme?.showProfile
                                          ?.isPostionBottom ==
                                      true
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        if (isGroup &&
                            !showMessageInCenter &&
                            !(widget._message?.sentByMe == true)) ...[
                          IsmChatProperties.chatPageProperties
                                  .messageSenderProfileBuilder
                                  ?.call(
                                context,
                                widget._message!,
                                controller.conversation,
                              ) ??
                              IsmChatTapHandler(
                                onTap: () async {
                                  await controller.showUserDetails(
                                    widget._message!.senderInfo!,
                                  );
                                },
                                child: IsmChatImage.profile(
                                  _groupSenderProfileUrl(context, controller),
                                  name: _groupSenderName(),
                                  dimensions: IsmChatConfig.chatTheme
                                          .chatPageTheme?.profileImageSize ??
                                      35,
                                ),
                              )
                        ],
                        if (theme?.opponentMessageTheme?.showProfile !=
                            null) ...[
                          if (theme?.opponentMessageTheme?.showProfile
                                      ?.isShowProfile ==
                                  true &&
                              !isGroup &&
                              !showMessageInCenter &&
                              !(widget._message?.sentByMe == true)) ...[
                            IsmChatImage.profile(
                              IsmChatProperties.chatPageProperties.header
                                      ?.profileImageUrl
                                      ?.call(
                                          context,
                                          controller.conversation,
                                          controller.conversation?.profileUrl ??
                                              '') ??
                                  controller.conversation?.profileUrl ??
                                  '',
                              name: IsmChatProperties
                                      .chatPageProperties.header?.title
                                      ?.call(
                                          context,
                                          controller.conversation,
                                          controller.conversation?.chatName ??
                                              '') ??
                                  controller.conversation?.chatName,
                              dimensions: IsmChatConfig.chatTheme.chatPageTheme
                                      ?.profileImageSize ??
                                  IsmChatDimens.thirty,
                            ),
                            if (IsmChatProperties
                                    .chatPageProperties.messageBuilder ==
                                null) ...[
                              IsmChatDimens.boxWidth2,
                            ],
                          ],
                        ] else ...[
                          IsmChatDimens.boxWidth4,
                        ],
                        if (IsmChatUtility.chatPageControllerRegistered) ...[
                          MessageCard(
                            message: widget._message!,
                            showMessageInCenter: showMessageInCenter,
                            index: widget.index,
                          )
                        ],
                        if (theme?.selfMessageTheme?.showProfile != null)
                          if (theme?.selfMessageTheme?.showProfile
                                      ?.isShowProfile ==
                                  true &&
                              !isGroup &&
                              !showMessageInCenter &&
                              widget._message?.sentByMe == true) ...[
                            if (IsmChatProperties
                                    .chatPageProperties.messageBuilder ==
                                null) ...[
                              IsmChatDimens.boxWidth4,
                            ],
                            IsmChatImage.profile(
                              IsmChatConfig.communicationConfig.userConfig
                                      .userProfile ??
                                  coverstaionController
                                      .userDetails?.userProfileImageUrl ??
                                  '',
                              name: IsmChatConfig.communicationConfig.userConfig
                                      .userName ??
                                  coverstaionController.userDetails?.userName,
                              dimensions: IsmChatConfig.chatTheme.chatPageTheme
                                      ?.profileImageSize ??
                                  IsmChatDimens.thirty,
                            ),
                          ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shares the date-filtered message list and per-message "hide this grid tile"
/// results across every row built in the same frame.
///
/// Without it, each media row re-filtered the whole conversation on every
/// controller update. With many kept-alive rows in a busy group, that was
/// O(rows x messages) work per incoming message and made scrolling stutter.
/// The cache is keyed by frame, list instance and length, so it never outlives
/// the build pass that produced it.
class _GridHideCache {
  _GridHideCache._(this._source, this._length, this._frame, this.chronologic);

  final List<IsmChatMessageModel> _source;
  final int _length;
  final Duration? _frame;
  final List<IsmChatMessageModel> chronologic;
  final Map<IsmChatMessageModel, bool> results =
      Map<IsmChatMessageModel, bool>.identity();

  static _GridHideCache? _current;

  static _GridHideCache forFrame(List<IsmChatMessageModel> messages) {
    final scheduler = SchedulerBinding.instance;
    final frame = scheduler.schedulerPhase == SchedulerPhase.idle
        ? null
        : scheduler.currentFrameTimeStamp;
    final cached = _current;
    if (cached != null &&
        frame != null &&
        cached._frame == frame &&
        identical(cached._source, messages) &&
        cached._length == messages.length) {
      return cached;
    }
    return _current = _GridHideCache._(
      messages,
      messages.length,
      frame,
      messages
          .where((msg) => msg.customType != IsmChatCustomMessageType.date)
          .toList(),
    );
  }
}
