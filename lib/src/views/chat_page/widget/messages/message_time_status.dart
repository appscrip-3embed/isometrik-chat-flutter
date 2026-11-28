import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Shared time + delivery/read status row used by [MessageBubble].
///
/// **Reuse:**
/// - Overlay path for normal bubbles (transparent, bottom-right).
/// - Capsule path for stickers via [IsmChatStickerTimeCapsule].
/// - Prefer this over copying the icon/time branches into [message_card]
///   outer-time UI if that path is ever unified.
///
/// Visibility of time vs status follows
/// [IsmChatProperties.chatPageProperties.messageStatus] and
/// [IsmChatFeature.showMessageStatus].
class IsmChatMessageTimeStatusRow extends StatelessWidget {
  const IsmChatMessageTimeStatusRow({
    super.key,
    required this.message,
  });

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final status = IsmChatProperties.chatPageProperties.messageStatus;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          message.sentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (status?.shouldShowMessageTime ?? true) ...[
          if (message.messageUpdated) ...[
            Text(
              IsmChatStrings.messageEdited,
              style: message.timeStyle.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            IsmChatDimens.boxWidth4,
          ],
          Text(
            message.sentAt.toTimeString,
            style: message.timeStyle,
          ),
        ],
        if ((status?.shouldShowMessgaeStatus ?? true) &&
            message.sentByMe &&
            ![
              IsmChatCustomMessageType.oneToOneCall,
              IsmChatCustomMessageType.deletedForEveryone,
            ].contains(message.customType)) ...[
          if (message.messageId?.isEmpty == true) ...[
            IsmChatDimens.boxWidth2,
            if (message.isInvalidMessage == true) ...[
              Icon(
                Icons.error_outlined,
                color: IsmChatConfig.chatTheme.chatPageTheme
                        ?.messageStatusTheme?.inValidIconColor ??
                    IsmChatColors.redColor,
                size: IsmChatConfig.chatTheme.chatPageTheme?.messageStatusTheme
                        ?.checkSize ??
                    IsmChatDimens.forteen,
              ),
            ] else ...[
              Icon(
                Icons.watch_later_outlined,
                color: IsmChatConfig.chatTheme.chatPageTheme
                        ?.messageStatusTheme?.unreadCheckColor ??
                    IsmChatColors.whiteColor,
                size: IsmChatConfig.chatTheme.chatPageTheme?.messageStatusTheme
                        ?.checkSize ??
                    IsmChatDimens.forteen,
              ),
            ],
          ] else if (IsmChatProperties.chatPageProperties.features
              .contains(IsmChatFeature.showMessageStatus)) ...[
            IsmChatDimens.boxWidth2,
            Icon(
              // If readByAll is true, deliveredToAll must also be true.
              // Always show double checkmark if read.
              (message.readByAll ?? false) ||
                      (message.deliveredToAll ?? false)
                  ? Icons.done_all_rounded
                  : Icons.done_rounded,
              color: message.readByAll ?? false
                  ? IsmChatConfig.chatTheme.chatPageTheme?.messageStatusTheme
                          ?.readCheckColor ??
                      Colors.blue
                  : IsmChatConfig.chatTheme.chatPageTheme?.messageStatusTheme
                          ?.unreadCheckColor ??
                      IsmChatColors.whiteColor,
              size: IsmChatConfig.chatTheme.chatPageTheme?.messageStatusTheme
                      ?.checkSize ??
                  IsmChatDimens.forteen,
            ),
          ],
        ],
      ],
    );
  }
}

/// Mini chat bubble under a sticker: same fill, border, and corner radius as
/// the sender/receiver message shell ([IsmChatMessageModel.backgroundColor],
/// [IsmChatMessageModel.borderColor], theme `borderRadius`). No full bubble
/// behind the sticker art — only this compact time/status chrome.
///
/// **Reuse:** only for sticker (transparent) messages. Normal bubbles keep
/// the overlay time inside the decorated shell; do not wrap those in this
/// capsule. Align via [sentByMe] at the call site (end for sent, start for
/// received) so it sits under the sticker edge.
class IsmChatStickerTimeCapsule extends StatelessWidget {
  const IsmChatStickerTimeCapsule({
    super.key,
    required this.message,
  });

  final IsmChatMessageModel message;

  /// Same radii as [MessageBubble]'s decorated shell so the time chip reads
  /// as a small chat bubble, not a plain pill.
  BorderRadius get _bubbleBorderRadius {
    final pageTheme = IsmChatConfig.chatTheme.chatPageTheme;
    if (message.sentByMe) {
      return pageTheme?.selfMessageTheme?.borderRadius ??
          BorderRadius.circular(IsmChatDimens.twelve).copyWith(
            bottomRight: Radius.circular(IsmChatDimens.four),
          );
    }
    return pageTheme?.opponentMessageTheme?.borderRadius ??
        BorderRadius.circular(IsmChatDimens.twelve).copyWith(
          topLeft: Radius.circular(IsmChatDimens.four),
        );
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          padding: IsmChatDimens.edgeInsets8_4,
          decoration: BoxDecoration(
            color: message.backgroundColor,
            gradient: message.gradient,
            border: message.borderColor != null
                ? Border.all(color: message.borderColor!)
                : null,
            borderRadius: _bubbleBorderRadius,
          ),
          child: IsmChatMessageTimeStatusRow(message: message),
        ),
      );
}
