import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Resolved label / icon / row colors for [IsmChatFocusMenu] items.
class _FocusMenuItemStyle {
  const _FocusMenuItemStyle({
    required this.backgroundColor,
    required this.labelColor,
    required this.iconColor,
  });

  final Color backgroundColor;
  final Color labelColor;
  final Color iconColor;
}

/// Rounds only the top or bottom of a focus-menu row so the last item (often
/// [IsmChatFocusMenuType.delete]) fills the card through the bottom corners.
BorderRadius? _focusMenuItemBorderRadius(
  int index,
  int itemCount,
  BorderRadius menuRadius,
) {
  if (itemCount <= 0) return null;
  if (itemCount == 1) return menuRadius;
  if (index == 0) {
    return BorderRadius.only(
      topLeft: menuRadius.topLeft,
      topRight: menuRadius.topRight,
    );
  }
  if (index == itemCount - 1) {
    return BorderRadius.only(
      bottomLeft: menuRadius.bottomLeft,
      bottomRight: menuRadius.bottomRight,
    );
  }
  return null;
}

_FocusMenuItemStyle _focusMenuItemStyle(
  BuildContext context,
  IsmChatFocusMenuType item,
) {
  if (item == IsmChatFocusMenuType.delete) {
    return const _FocusMenuItemStyle(
      backgroundColor: IsmChatColors.redColor,
      labelColor: IsmChatColors.whiteColor,
      iconColor: IsmChatColors.whiteColor,
    );
  }

  final headerTheme = IsmChatConfig.chatTheme.chatPageHeaderTheme;
  final isDark = IsmChatThemeResolver.brightness(context) == Brightness.dark;
  return _FocusMenuItemStyle(
    backgroundColor: headerTheme?.popupBackgroundColor ??
        (isDark ? const Color(0xFF353535) : IsmChatColors.whiteColor),
    labelColor: headerTheme?.popupLableColor ??
        (isDark ? IsmChatColors.whiteColor : IsmChatColors.blackColor),
    iconColor: headerTheme?.iconColor ??
        (isDark ? IsmChatColors.whiteColor : IsmChatColors.blackColor),
  );
}

class IsmChatFocusMenu extends StatelessWidget {
  /// [pageController] must be supplied by [IsmChatPageController.showOverlay] /
  /// `showOverlayWeb` — do not resolve via [IsmChatUtility.chatPageController]
  /// in the constructor; GetX may unregister the controller while this route
  /// or overlay is still building (e.g. app [MaterialApp] rebuild).
  IsmChatFocusMenu(
    this.message, {
    super.key,
    required this.pageController,
    required this.animation,
    this.blur,
    this.blurBackgroundColor,
    this.anchorRect,
  }) : canReact = IsmChatProperties.chatPageProperties.features
            .contains(IsmChatFeature.reaction);

  /// Where the message bubble sat in the chat list, in the navigator's
  /// coordinates. Mobile only: the preview opens in place when it fits.
  final Rect? anchorRect;

  final double? blur;
  final Color? blurBackgroundColor;
  final IsmChatMessageModel message;
  final Animation<double> animation;
  final bool canReact;
  final IsmChatPageController pageController;

  int? _messageReversedIndexForGridPreview() {
    final allMessages = pageController.messages
        .where((msg) => msg.customType != IsmChatCustomMessageType.date)
        .toList();
    if (allMessages.isEmpty) return null;

    final chronologicalIndex = allMessages.indexWhere(
      (msg) => msg.key == message.key,
    );
    if (chronologicalIndex == -1) return null;

    // MessageBubble expects index from reversed list.
    return allMessages.length - 1 - chronologicalIndex;
  }

  @override
  Widget build(BuildContext context) => IsmChatResponsive.isWeb(context)
      ? IsmChatTapHandler(
          onTap: pageController.closeOverlay,
          child: Padding(
            padding: IsmChatDimens.edgeInsets8,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: message.sentByMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (canReact && !pageController.isBroadcast)
                  _FocusAnimationBuilder(
                    animation: animation,
                    child: ReactionGrid(message),
                  ),
                IsmChatDimens.boxHeight8,
                _FocusAnimationBuilder(
                  animation: animation,
                  child: Container(
                    width: IsmChatConfig.chatTheme.chatPageTheme
                            ?.messgaeFocusedTheme?.width ??
                        IsmChatDimens.oneHundredSeventy,
                    decoration: IsmChatConfig.chatTheme.chatPageTheme
                            ?.messgaeFocusedTheme?.decoration ??
                        BoxDecoration(
                          border: Border.all(
                            color: IsmChatColors.blackColor,
                          ),
                          borderRadius:
                              BorderRadius.circular(IsmChatDimens.sixteen),
                        ),
                    child: ClipRRect(
                      borderRadius: IsmChatConfig.chatTheme.chatPageTheme
                              ?.messgaeFocusedTheme?.decoration?.borderRadius ??
                          BorderRadius.circular(IsmChatDimens.sixteen),
                      clipBehavior: Clip.antiAlias,
                      child: GetBuilder<IsmChatPageController>(
                          tag: IsmChat.i.chatPageTag,
                          builder: (controller) {
                            final menuItems = message.focusMenuList;
                            final menuRadius = BorderRadius.circular(
                              IsmChatDimens.sixteen,
                            );
                            return ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: menuItems.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (_, index) {
                                  var item = menuItems[index];
                                  final itemStyle =
                                      _focusMenuItemStyle(context, item);
                                  return IsmChatTapHandler(
                                    onTap: () async {
                                      if (!context.mounted) return;
                                      controller.closeOverlay();
                                      try {
                                        await controller.onMenuItemSelected(
                                          item,
                                          message,
                                          context,
                                        );
                                      } catch (e, st) {
                                        IsmChatLog.error(
                                          'Focus menu action failed: $e',
                                          st,
                                        );
                                      }
                                    },
                                    child: Container(
                                      height: IsmChatConfig
                                              .chatTheme
                                              .chatPageTheme
                                              ?.messgaeFocusedTheme
                                              ?.hight ??
                                          IsmChatDimens.forty,
                                      padding: IsmChatDimens.edgeInsets16_0,
                                      decoration: BoxDecoration(
                                        color: itemStyle.backgroundColor,
                                        borderRadius:
                                            _focusMenuItemBorderRadius(
                                          index,
                                          menuItems.length,
                                          menuRadius,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              message.focusMenuLabel(item),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                              style: IsmChatStyles.w400Black12
                                                  .copyWith(
                                                fontSize: IsmChatConfig
                                                    .chatTheme
                                                    .chatPageTheme
                                                    ?.messgaeFocusedTheme
                                                    ?.fontSize,
                                                color: itemStyle.labelColor,
                                              ),
                                            ),
                                          ),
                                          IsmChatDimens.boxWidth8,
                                          Icon(
                                            item.icon,
                                            color: itemStyle.iconColor,
                                            size: IsmChatConfig
                                                .chatTheme
                                                .chatPageTheme
                                                ?.messgaeFocusedTheme
                                                ?.iconSize,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                          }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      : IsmChatTapHandler(
          onTap: () {
            if (IsmChatResponsive.isWeb(context)) {
              pageController.closeOverlay();
            } else {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Builder(
              builder: (context) {
                // Edge-to-edge Android often reports MediaQuery.padding.bottom
                // as 0; use viewPadding (same pattern as EmojiBoard) so Delete
                // stays above the system navigation bar.
                final padding = MediaQuery.paddingOf(context);
                final insets = EdgeInsets.only(
                  left: padding.left,
                  top: padding.top + IsmChatDimens.eight,
                  right: padding.right,
                  bottom: MediaQuery.viewPaddingOf(context).bottom +
                      IsmChatDimens.eight,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blur ?? 4,
                        sigmaY: blur ?? 4,
                      ),
                      child: Container(
                        color: (blurBackgroundColor ?? Colors.black)
                            .applyIsmOpacity(0.5),
                      ),
                    ),
                    Padding(
                      padding: insets,
                      child: CustomMultiChildLayout(
                        delegate: _FocusMenuLayoutDelegate(
                          sentByMe: message.sentByMe,
                          anchor: anchorRect?.shift(
                            Offset(-insets.left, -insets.top),
                          ),
                        ),
                        children: [
                          if (canReact && !pageController.isBroadcast)
                            LayoutId(
                              id: _FocusMenuSlot.reactions,
                              child: _FocusAnimationBuilder(
                                animation: animation,
                                alignment: message.sentByMe
                                    ? Alignment.bottomRight
                                    : Alignment.bottomLeft,
                                child: ReactionGrid(message),
                              ),
                            ),
                          LayoutId(
                            id: _FocusMenuSlot.message,
                            // Clips a message taller than the space under the
                            // reactions; the menu covers its lower part.
                            child: SingleChildScrollView(
                              primary: false,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Hero(
                                tag: message,
                                child: IsmChatProperties
                                        .chatPageProperties.messageBuilder
                                        ?.call(context, message,
                                            message.customType!, false) ??
                                    MessageBubble(
                                      message: message,
                                      showMessageInCenter: false,
                                      index:
                                          _messageReversedIndexForGridPreview(),
                                    ),
                              ),
                            ),
                          ),
                          LayoutId(
                            id: _FocusMenuSlot.menu,
                            child: _FocusAnimationBuilder(
                              animation: animation,
                              alignment: message.sentByMe
                                  ? Alignment.topRight
                                  : Alignment.topLeft,
                              child: _buildMobileMenu(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );

  Widget _buildMobileMenu() => Container(
        width: IsmChatDimens.oneHundredSeventy,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(IsmChatDimens.sixteen),
        ),
        clipBehavior: Clip.antiAlias,
        child: GetBuilder<IsmChatPageController>(
          tag: IsmChat.i.chatPageTag,
          builder: (controller) {
            final menuItems = message.focusMenuList;
            final menuRadius = BorderRadius.circular(IsmChatDimens.sixteen);
            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: menuItems.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                var item = menuItems[index];
                final itemStyle = _focusMenuItemStyle(context, item);
                return IsmChatTapHandler(
                  onTap: () async {
                    // Menu route context is disposed after pop — never use it
                    // for follow-up UI. Dismiss first, then run the action on
                    // the app navigator context.
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                    controller.closeOverlay();
                    await WidgetsBinding.instance.endOfFrame;
                    final safeContext =
                        IsmChatConfig.kNavigatorKey.currentContext ??
                            IsmChatConfig.context;
                    if (!safeContext.mounted) {
                      return;
                    }
                    try {
                      await controller.onMenuItemSelected(
                        item,
                        message,
                        safeContext,
                      );
                    } catch (e, st) {
                      IsmChatLog.error('Focus menu action failed: $e', st);
                    }
                  },
                  child: Container(
                    height: IsmChatDimens.forty,
                    padding: IsmChatDimens.edgeInsets16_0,
                    decoration: BoxDecoration(
                      color: itemStyle.backgroundColor,
                      borderRadius: _focusMenuItemBorderRadius(
                        index,
                        menuItems.length,
                        menuRadius,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.focusMenuLabel(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: IsmChatStyles.w400Black12.copyWith(
                              color: itemStyle.labelColor,
                            ),
                          ),
                        ),
                        IsmChatDimens.boxWidth8,
                        Icon(
                          item.icon,
                          color: itemStyle.iconColor,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

enum _FocusMenuSlot { reactions, message, menu }

/// WhatsApp-style placement for the mobile long-press overlay.
///
/// - Everything fits: the message stays where it sat in the list (or is
///   centered when that position is unknown), reactions just above it, the
///   menu just below; the group shifts only as far as needed to stay on screen.
/// - Too tall (e.g. a 3:4 photo with a caption): reactions pin to the top, the
///   message sits right under them, and the menu pins to the bottom, drawn over
///   the lower part of the message.
///
/// Reactions and menu are never pushed off screen, so nothing has to scroll.
class _FocusMenuLayoutDelegate extends MultiChildLayoutDelegate {
  _FocusMenuLayoutDelegate({required this.sentByMe, this.anchor});

  final bool sentByMe;

  /// The message's rect in the chat list, in this layout's coordinates.
  final Rect? anchor;

  static const double _gap = 8;
  static const double _edge = 8;

  @override
  void performLayout(Size size) {
    final sideMaxWidth = math.max(0.0, size.width - 2 * _edge);

    var reactionSize = Size.zero;
    var reactionBlock = 0.0;
    if (hasChild(_FocusMenuSlot.reactions)) {
      reactionSize = layoutChild(
        _FocusMenuSlot.reactions,
        BoxConstraints(maxWidth: sideMaxWidth),
      );
      reactionBlock = reactionSize.height + _gap;
    }

    final menuSize = layoutChild(
      _FocusMenuSlot.menu,
      BoxConstraints(maxWidth: sideMaxWidth),
    );
    final menuBlock = _gap + menuSize.height;

    // Capped so a tall message can never push the reactions off the top.
    final messageSize = layoutChild(
      _FocusMenuSlot.message,
      BoxConstraints(
        maxWidth: size.width,
        maxHeight: math.max(0.0, size.height - reactionBlock),
      ),
    );

    final double messageTop;
    final double menuTop;
    final slack = size.height - reactionBlock - messageSize.height - menuBlock;
    if (slack >= 0) {
      messageTop = (anchor?.top ?? reactionBlock + slack / 2)
          .clamp(reactionBlock, reactionBlock + slack)
          .toDouble();
      menuTop = messageTop + messageSize.height + _gap;
    } else {
      messageTop = reactionBlock;
      menuTop = math.max(0.0, size.height - menuSize.height);
    }

    final messageLeft = (anchor?.left ??
            (sentByMe ? size.width - _edge - messageSize.width : _edge))
        .clamp(0.0, math.max(0.0, size.width - messageSize.width))
        .toDouble();
    positionChild(_FocusMenuSlot.message, Offset(messageLeft, messageTop));

    if (hasChild(_FocusMenuSlot.reactions)) {
      positionChild(
        _FocusMenuSlot.reactions,
        Offset(
          _sideLeft(size, reactionSize.width, messageLeft, messageSize.width),
          messageTop - reactionBlock,
        ),
      );
    }
    positionChild(
      _FocusMenuSlot.menu,
      Offset(
        _sideLeft(size, menuSize.width, messageLeft, messageSize.width),
        menuTop,
      ),
    );
  }

  /// Lines a [width]-wide child up with the message's outer edge, keeping it
  /// [_edge] away from the screen sides.
  double _sideLeft(
    Size size,
    double width,
    double messageLeft,
    double messageWidth,
  ) {
    final left = sentByMe ? messageLeft + messageWidth - width : messageLeft;
    return left
        .clamp(_edge, math.max(_edge, size.width - _edge - width))
        .toDouble();
  }

  @override
  bool shouldRelayout(_FocusMenuLayoutDelegate oldDelegate) =>
      oldDelegate.sentByMe != sentByMe || oldDelegate.anchor != anchor;
}

class _FocusAnimationBuilder extends StatelessWidget {
  const _FocusAnimationBuilder({
    required this.animation,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Animation<double> animation;
  final Widget child;

  /// Point the child grows from (e.g. the corner nearest the message).
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, widget) => ScaleTransition(
          scale: animation,
          alignment: alignment,
          child: widget!,
        ),
        child: child,
      );
}
