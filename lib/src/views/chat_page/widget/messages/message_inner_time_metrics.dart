import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Width of the bottom-right time + delivery/read indicators painted inside
/// [MessageBubble]'s stack. Short reply bubbles must be at least this wide so
/// those overlays are not clipped after reply [minWidth] was relaxed.
double ismChatInnerTimeStatusMinWidth(
  BuildContext context,
  IsmChatMessageModel message,
) {
  final status = IsmChatProperties.chatPageProperties.messageStatus;
  if (status?.shouldShowTimeStatusInner == false) {
    return 0;
  }

  var width = IsmChatDimens.ten;

  if (status?.shouldShowMessageTime ?? true) {
    final painter = TextPainter(
      text: TextSpan(
        text: message.sentAt.toTimeString,
        style: message.timeStyle,
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    width += painter.width;
  }

  final showDelivery =
      (status?.shouldShowMessgaeStatus ?? true) &&
          message.sentByMe &&
          ![
            IsmChatCustomMessageType.oneToOneCall,
            IsmChatCustomMessageType.deletedForEveryone,
          ].contains(message.customType);

  if (showDelivery) {
    final checkSize = IsmChatConfig.chatTheme.chatPageTheme?.messageStatusTheme
            ?.checkSize ??
        IsmChatDimens.forteen;
    if (message.messageId?.isEmpty == true) {
      width += IsmChatDimens.two + checkSize;
    } else if (IsmChatProperties.chatPageProperties.features
        .contains(IsmChatFeature.showMessageStatus)) {
      width += IsmChatDimens.two + checkSize;
    }
  }

  return width;
}