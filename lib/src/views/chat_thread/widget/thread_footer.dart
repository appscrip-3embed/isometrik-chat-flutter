import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// The "N replies" row Slack shows under a message that roots a thread.
///
/// Rendered by [MessageCard] under the bubble, and only when
/// [IsmChatThreadCoordinator.shouldShowFooter] is true — i.e. threads are on,
/// the host kept [IsmChatFeature.threadReply], and the root has at least one
/// reply. With threads off the bubble is exactly what it is today.
///
/// Tapping it opens [IsmChatThreadView] for that root. Hosts can replace the
/// whole row with [IsmChatThreadProperties.replyFooterBuilder].
class IsmChatThreadFooter extends StatelessWidget {
  const IsmChatThreadFooter({
    required this.message,
    this.onTap,
    super.key,
  });

  /// The root message whose thread this footer summarises.
  final IsmChatMessageModel message;

  /// Overrides the default "open the thread panel" tap action.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final replyCount = IsmChatThreadCoordinator.replyCountOf(message);
    if (replyCount <= 0) return const SizedBox.shrink();

    final custom = IsmChatProperties.threadProperties.replyFooterBuilder
        ?.call(context, message, replyCount);
    if (custom != null) return custom;

    final theme = IsmChatThemeResolver.threadFromConfig(context);
    return Padding(
      padding: EdgeInsets.only(
        top: IsmChatDimens.four,
        left: message.sentByMe ? 0 : IsmChatDimens.four,
        right: message.sentByMe ? IsmChatDimens.four : 0,
      ),
      child: InkWell(
        key: const Key('ism-thread-footer'),
        borderRadius: BorderRadius.circular(IsmChatDimens.twelve),
        onTap: onTap ?? () => unawaitedOpenThread(message),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: IsmChatDimens.six,
            vertical: IsmChatDimens.four,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: IsmChatDimens.forteen,
                color: theme.footerIconColor,
              ),
              IsmChatDimens.boxWidth4,
              Text(
                IsmChatStrings.threadReplyCountLabel(replyCount),
                style: theme.footerLabelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the thread panel for [message] without awaiting it (tap handlers
  /// are synchronous).
  static void unawaitedOpenThread(IsmChatMessageModel message) {
    IsmChat.i.openThread(message);
  }
}
