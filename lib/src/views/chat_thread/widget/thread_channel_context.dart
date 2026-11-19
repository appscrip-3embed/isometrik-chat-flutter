import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Slack-style **replied to a thread: …** line just above the channel bubble
/// for an also-sent thread reply. Spacing to [MessageBubble] is owned by
/// [MessageCard._threadAwareMessageBody] (gap above the line + below before the bubble).
///
/// Only shown when [IsmChatThreadCoordinator.shouldShowChannelThreadContext] is
/// true. Tapping opens the same thread panel as **View thread** in the focus
/// menu. Hosts can replace the row via
/// [IsmChatThreadProperties.channelThreadContextBuilder].
class IsmChatThreadChannelContext extends StatelessWidget {
  const IsmChatThreadChannelContext({
    required this.message,
    super.key,
  });

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    if (!IsmChatThreadCoordinator.shouldShowChannelThreadContext(message)) {
      return const SizedBox.shrink();
    }

    final custom = IsmChatProperties.threadProperties.channelThreadContextBuilder
        ?.call(context, message);
    if (custom != null) return custom;

    return GetBuilder<IsmChatPageController>(
      tag: IsmChat.i.chatPageTag,
      builder: (controller) {
        final parent = IsmChatThreadCoordinator.resolveParentInTimeline(
          message,
          controller.messages,
        );
        final subject =
            IsmChatThreadCoordinator.threadReplyContextSubject(parent);
        return IsmChatTapHandler(
          onTap: () {
            final root = IsmChatThreadCoordinator.resolveThreadPanelRoot(
              message,
              controller.messages,
            );
            IsmChat.i.openThread(
              root,
              conversation: controller.conversation,
            );
          },
          child: Text.rich(
            key: const Key('ism-thread-channel-context'),
            TextSpan(
              style: message.channelThreadContextStyle,
              children: [
                TextSpan(text: IsmChatStrings.repliedToThreadPrefix),
                TextSpan(
                  text: subject,
                  style: message.channelThreadContextSubjectStyle,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}