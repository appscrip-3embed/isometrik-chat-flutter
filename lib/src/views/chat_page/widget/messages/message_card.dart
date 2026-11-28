import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class MessageCard extends StatefulWidget {
  MessageCard({
    super.key,
    required this.showMessageInCenter,
    required this.message,
    required this.index,
  }) : canReply = IsmChatProperties.chatPageProperties.features
            .contains(IsmChatFeature.reply);

  final bool showMessageInCenter;
  final IsmChatMessageModel message;
  final int index;
  final bool canReply;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard>
    with SingleTickerProviderStateMixin {
  /// Horizontal travel (px) the bubble must be dragged before releasing
  /// triggers reply. Small accidental movements while scrolling never reach it.
  static const double _replyTriggerDistance = 64;

  /// The bubble follows the finger up to this distance, then stops.
  static const double _maxDragOffset = 88;

  /// Current horizontal offset of the bubble. A [ValueNotifier] so dragging
  /// only repaints the [Transform], not the whole message card.
  final ValueNotifier<double> _dragOffset = ValueNotifier<double>(0);

  late final AnimationController _resetController;
  double _resetFrom = 0;
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: IsmChatConstants.swipeDuration,
    )..addListener(() {
        final t = Curves.easeOut.transform(_resetController.value);
        _dragOffset.value = _resetFrom * (1 - t);
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  bool get _canSwipeToReply =>
      !widget.showMessageInCenter &&
      widget.message.customType !=
          IsmChatCustomMessageType.deletedForEveryone &&
      widget.message.messageId?.isNotEmpty == true &&
      (IsmChatProperties.chatPageProperties.canReplayMessage
              ?.call(widget.message) ??
          true);

  void _onDragStart(DragStartDetails _) {
    _resetController.stop();
    _thresholdReached = _dragOffset.value.abs() >= _replyTriggerDistance;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = (_dragOffset.value + details.delta.dx)
        .clamp(-_maxDragOffset, _maxDragOffset)
        .toDouble();
    _dragOffset.value = next;
    final reached = next.abs() >= _replyTriggerDistance;
    if (reached && !_thresholdReached) {
      HapticFeedback.selectionClick();
    }
    _thresholdReached = reached;
  }

  void _onDragEnd(DragEndDetails _) {
    final shouldReply = _thresholdReached;
    _snapBack();
    if (shouldReply) {
      IsmChatUtility.chatPageController.onReplyTap(widget.message);
    }
  }

  void _snapBack() {
    _thresholdReached = false;
    _resetFrom = _dragOffset.value;
    if (_resetFrom == 0) return;
    _resetController.forward(from: 0);
  }

  /// Bubble + reactions. When this row is an also-sent thread reply, wraps
  /// [IsmChatThreadChannelContext] directly above [MessageBubble] so the label
  /// reads as belonging to the bubble below (not the prior timeline row).
  Widget _threadAwareMessageBody(
    BuildContext context,
    IsmChatPageController controller,
  ) {
    final bubble = _messageBubbleStack(context, controller);
    final showContext =
        !widget.showMessageInCenter && widget.message.showChannelThreadContext;
    if (!showContext) return bubble;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.message.sentByMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Extra space above the line so it is not mistaken for the previous bubble.
        IsmChatDimens.boxHeight8,
        IsmChatThreadChannelContext(message: widget.message),
        // Match reply-preview → body spacing ([IsmChatReplyMessage]).
        IsmChatDimens.boxHeight5,
        bubble,
      ],
    );
  }

  Widget _messageBubbleStack(
    BuildContext context,
    IsmChatPageController controller,
  ) =>
      Stack(
        clipBehavior: Clip.none,
        alignment:
            widget.message.sentByMe ? Alignment.topRight : Alignment.topLeft,
        children: [
          if (widget.message.reactions?.isNotEmpty == true)
            IgnorePointer(
              child: SizedBox(
                width: ImsChatReaction.layoutWidth(
                  widget.message,
                ),
                height: 1,
              ),
            ),
          InkWell(
            splashColor: IsmChatColors.transparent,
            hoverColor: IsmChatColors.transparent,
            highlightColor: IsmChatColors.transparent,
            onTap: () {
              if (widget.message.customType == IsmChatCustomMessageType.video ||
                  widget.message.customType == IsmChatCustomMessageType.image ||
                  widget.message.customType ==
                      IsmChatCustomMessageType.multipleAttachments) {
                return;
              }
              controller.onMessageTap(
                context: context,
                message: widget.message,
              );
            },
            child: AutoScrollTag(
              controller: controller.messagesScrollController,
              index: widget.index,
              key: Key('scroll-${widget.message.messageId}'),
              child: kIsWeb
                  ? IsmChatProperties.chatPageProperties.messageBuilder?.call(
                          context,
                          widget.message,
                          widget.message.customType!,
                          widget.showMessageInCenter) ??
                      MessageBubble(
                        message: widget.message,
                        showMessageInCenter: widget.showMessageInCenter,
                        index: widget.index,
                      )
                  : Hero(
                      tag: widget.message,
                      child: IsmChatProperties.chatPageProperties.messageBuilder
                              ?.call(
                                  context,
                                  widget.message,
                                  widget.message.customType!,
                                  widget.showMessageInCenter) ??
                          MessageBubble(
                            message: widget.message,
                            showMessageInCenter: widget.showMessageInCenter,
                            index: widget.index,
                          ),
                    ),
            ),
          ),
          if (widget.message.reactions?.isNotEmpty == true)
            Positioned(
              right: widget.message.sentByMe ? 0 : null,
              left: widget.message.sentByMe ? null : 0,
              bottom: IsmChatDimens.six,
              child: UnconstrainedBox(
                alignment: widget.message.sentByMe
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                constrainedAxis: Axis.vertical,
                clipBehavior: Clip.none,
                child: ImsChatReaction(
                  message: widget.message,
                ),
              ),
            ),
        ],
      );

  // No GetBuilder here: the parent [IsmChatMessage] already rebuilds on every
  // controller update (and already hides non-first grid tiles). A second
  // listener per row doubled the rebuild work for every real-time message.
  @override
  Widget build(BuildContext context) {
    final controller = IsmChatUtility.chatPageController;
    final canSwipe = _canSwipeToReply;
    return GestureDetector(
      onHorizontalDragStart: canSwipe ? _onDragStart : null,
      onHorizontalDragUpdate: canSwipe ? _onDragUpdate : null,
      onHorizontalDragEnd: canSwipe ? _onDragEnd : null,
      onHorizontalDragCancel: canSwipe ? _snapBack : null,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragOffset,
        builder: (_, dx, child) => dx == 0
            ? child!
            : Transform.translate(offset: Offset(dx, 0), child: child),
        child: MouseRegion(
          onEnter: (_) {
            if (controller.conversationController.isRenderChatPageaScreen !=
                IsRenderChatPageScreen.none) {
              return;
            }
            controller.onMessageHoverIndex = widget.index;
          },
          onExit: (_) {
            if (controller.conversationController.isRenderChatPageaScreen !=
                IsRenderChatPageScreen.none) {
              return;
            }
            controller.onMessageHoverIndex = -1;
          },
          child: Column(
            crossAxisAlignment: widget.message.sentByMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              _threadAwareMessageBody(context, controller),
              // Slack-style threads: "N replies" under the root bubble.
              // [IsmChatThreadCoordinator.shouldShowFooter] is false
              // whenever threading is off, so nothing changes for
              // existing integrations.
              if (!widget.showMessageInCenter &&
                  IsmChatThreadCoordinator.shouldShowFooter(
                    widget.message,
                  ))
                IsmChatThreadFooter(message: widget.message),
              if (!widget.showMessageInCenter &&
                  (IsmChatProperties.chatPageProperties.messageStatus
                          ?.shouldShowTimeStatusOuter ??
                      false)) ...[
                IsmChatDimens.boxHeight5,
                Material(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: widget.message.sentByMe
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (IsmChatProperties.chatPageProperties.messageStatus
                              ?.shouldShowMessageTime ??
                          false) ...[
                        Text(
                          widget.message.sentAt.toTimeString,
                          style: widget.message.style,
                        )
                      ],
                      if ((IsmChatProperties.chatPageProperties.messageStatus
                                  ?.shouldShowMessgaeStatus ??
                              false) &&
                          widget.message.sentByMe &&
                          ![
                            IsmChatCustomMessageType.deletedForEveryone,
                            IsmChatCustomMessageType.oneToOneCall,
                          ].contains(widget.message.customType)) ...[
                        if (widget.message.messageId?.isEmpty == true) ...[
                          IsmChatDimens.boxWidth2,
                          if (widget.message.isInvalidMessage == true) ...[
                            Icon(
                              Icons.error_outlined,
                              color: IsmChatConfig.chatTheme.chatPageTheme
                                      ?.messageStatusTheme?.inValidIconColor ??
                                  IsmChatColors.redColor,
                              size: IsmChatConfig.chatTheme.chatPageTheme
                                      ?.messageStatusTheme?.checkSize ??
                                  IsmChatDimens.forteen,
                            ),
                          ] else ...[
                            Icon(
                              Icons.watch_later_outlined,
                              color: IsmChatConfig.chatTheme.chatPageTheme
                                      ?.messageStatusTheme?.unreadCheckColor ??
                                  IsmChatColors.whiteColor,
                              size: IsmChatConfig.chatTheme.chatPageTheme
                                      ?.messageStatusTheme?.checkSize ??
                                  IsmChatDimens.forteen,
                            ),
                          ]
                        ] else if (IsmChatProperties.chatPageProperties.features
                            .contains(
                          IsmChatFeature.showMessageStatus,
                        )) ...[
                          IsmChatDimens.boxWidth2,
                          Icon(
                            // If readByAll is true, deliveredToAll must also be true
                            // Always show double checkmark if read
                            (widget.message.readByAll ?? false) ||
                                    (widget.message.deliveredToAll ?? false)
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            color: widget.message.readByAll ?? false
                                ? IsmChatConfig.chatTheme.chatPageTheme
                                        ?.messageStatusTheme?.readCheckColor ??
                                    Colors.blue
                                : IsmChatConfig
                                        .chatTheme
                                        .chatPageTheme
                                        ?.messageStatusTheme
                                        ?.unreadCheckColor ??
                                    Colors.black,
                            size: IsmChatConfig.chatTheme.chatPageTheme
                                    ?.messageStatusTheme?.checkSize ??
                                IsmChatDimens.forteen,
                          ),
                        ]
                      ],
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
