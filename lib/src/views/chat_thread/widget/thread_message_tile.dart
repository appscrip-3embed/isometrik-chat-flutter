import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// One row inside the thread panel: avatar, sender, time and body.
///
/// Deliberately self-contained (it does not reuse the channel [MessageBubble])
/// so a thread can render without the chat-page controller — the panel is
/// pushed as its own route and may outlive a chat page rebuild.
///
/// Text replies render as a plain Slack-style row. Non-text replies (photo,
/// video, voice note, document, location, contact) render with the SDK's own
/// message widgets via [IsmChatMessageWrapper], so thumbnails, players,
/// upload progress and the restricted-media placeholder all behave exactly as
/// they do in the channel. Hosts can replace a row entirely with
/// [IsmChatThreadProperties.replyTileBuilder].
class IsmChatThreadMessageTile extends StatelessWidget {
  const IsmChatThreadMessageTile({
    required this.message,
    this.isRoot = false,
    super.key,
  });

  /// The reply (or, with [isRoot], the thread's root message).
  final IsmChatMessageModel message;

  /// Renders the root variant: card background and border.
  final bool isRoot;

  /// Message kinds whose body is rendered by the SDK's own message widgets
  /// (the same ones the channel uses) instead of as plain text.
  static bool rendersAsBubble(IsmChatMessageModel message) => const [
        IsmChatCustomMessageType.image,
        IsmChatCustomMessageType.video,
        IsmChatCustomMessageType.audio,
        IsmChatCustomMessageType.file,
        IsmChatCustomMessageType.multipleAttachments,
        IsmChatCustomMessageType.location,
        IsmChatCustomMessageType.contact,
        IsmChatCustomMessageType.link,
      ].contains(message.customType);

  /// Short human label for a message with no text body, used when the real
  /// bubble cannot be rendered (no chat page controller — e.g. a thread opened
  /// from a notification before chat mounted).
  ///
  /// Returns `null` for text-ish messages, whose [IsmChatMessageModel.body] is
  /// shown as-is.
  static String? threadPreviewLabel(IsmChatMessageModel message) {
    switch (message.customType) {
      case IsmChatCustomMessageType.image:
        return 'Photo';
      case IsmChatCustomMessageType.video:
        return 'Video';
      case IsmChatCustomMessageType.audio:
        return 'Audio';
      case IsmChatCustomMessageType.file:
        return 'Document';
      case IsmChatCustomMessageType.multipleAttachments:
        return 'Attachments';
      case IsmChatCustomMessageType.location:
        return 'Location';
      case IsmChatCustomMessageType.contact:
        return 'Contact';
      case IsmChatCustomMessageType.deletedForEveryone:
      case IsmChatCustomMessageType.deletedForMe:
        return 'This message was deleted';
      default:
        return null;
    }
  }

  String get _senderName {
    if (message.sentByMe) return IsmChatStrings.you;
    final name = message.senderInfo?.userName.trim() ?? '';
    return name.isNotEmpty ? name : IsmChatStrings.deletedUser;
  }

  @override
  Widget build(BuildContext context) {
    if (!isRoot) {
      final custom = IsmChatProperties.threadProperties.replyTileBuilder
          ?.call(context, message);
      if (custom != null) return custom;
    } else {
      final custom = IsmChatProperties.threadProperties.rootMessageBuilder
          ?.call(context, message);
      if (custom != null) return custom;
    }

    final theme = IsmChatThemeResolver.threadFromConfig(context);
    final label = threadPreviewLabel(message);
    final body = message.body.trim();
    // Media / location / contact replies reuse the channel's own widgets, so a
    // photo in a thread looks like a photo in the chat (and an in-flight
    // upload shows the same progress state).
    final asBubble = rendersAsBubble(message) &&
        IsmChatUtility.chatPageControllerRegistered;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IsmChatImage.profile(
          message.senderInfo?.userProfileImageUrl ?? '',
          name: message.senderInfo?.userName,
          dimensions: isRoot ? IsmChatDimens.thirtyFive : IsmChatDimens.thirty,
        ),
        IsmChatDimens.boxWidth8,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.senderNameStyle,
                    ),
                  ),
                  IsmChatDimens.boxWidth4,
                  Text(
                    message.sentAt.toTimeString,
                    style: theme.timeStyle,
                  ),
                ],
              ),
              IsmChatDimens.boxHeight2,
              if (asBubble)
                IsmChatMessageWrapper(message)
              else if (label != null && body.isEmpty)
                Text(label, style: theme.attachmentLabelStyle)
              else ...[
                if (label != null) ...[
                  Text(label, style: theme.attachmentLabelStyle),
                  IsmChatDimens.boxHeight2,
                ],
                Text(body, style: theme.bodyStyle),
              ],
              // "Also sent to channel" replies carry showInConversation: true.
              if (!isRoot && message.showInConversation == true) ...[
                IsmChatDimens.boxHeight2,
                Text(
                  IsmChatStrings.threadAlsoSendToChannel,
                  style: theme.timeStyle,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (!isRoot) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: IsmChatDimens.twelve,
          vertical: IsmChatDimens.eight,
        ),
        child: content,
      );
    }
    return Container(
      margin: EdgeInsets.all(IsmChatDimens.twelve),
      padding: EdgeInsets.all(IsmChatDimens.twelve),
      decoration: BoxDecoration(
        color: theme.rootCardBackgroundColor,
        borderRadius: BorderRadius.circular(IsmChatDimens.twelve),
        border: Border.all(color: theme.rootCardBorderColor),
      ),
      child: content,
    );
  }
}
