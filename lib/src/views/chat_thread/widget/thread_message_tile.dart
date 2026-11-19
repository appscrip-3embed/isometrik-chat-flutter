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

  /// Whether taps on this row should open media / files (not nested-reply).
  static bool usesMediaTapBehavior(IsmChatMessageModel message) =>
      message.threadPanelBubbleType != null;

  /// Bubble kinds that open routes from the channel message card tap target on
  /// channel timeline but do not attach their own [IsmChatTapHandler] (unlike
  /// image / video / file). The thread panel reuses [IsmChatMessageWrapper]
  /// without that outer tap — wire the same behavior here.
  static bool threadPanelBubbleNeedsMessageCardTap(
    IsmChatCustomMessageType type,
  ) =>
      type == IsmChatCustomMessageType.contact;

  /// Opens shared-contact details for a thread row (root or reply).
  ///
  /// Reuses [IsmChatPageController.tapForMediaPreview] when the chat page is
  /// mounted; otherwise navigates directly so a thread opened in isolation
  /// still works (e.g. deep link before chat loads).
  static void openContactDetailsFromThread(IsmChatMessageModel message) {
    if (message.contacts.isEmpty) return;
    if (IsmChatUtility.chatPageControllerRegistered) {
      IsmChatUtility.chatPageController.tapForMediaPreview(message);
      return;
    }
    IsmChatRoute.goToRoute(
      IsmChatContactsInfoView(contacts: message.contacts),
    );
  }

  /// Opens image / video preview from a thread row (delegates to coordinator).
  static Future<void> openMediaPreviewFromThread(
    IsmChatMessageModel message,
  ) =>
      IsmChatThreadCoordinator.openMediaPreviewFromThread(message);

  /// Short human label for a message with no text body, used when the real
  /// bubble cannot be rendered (no chat page controller — e.g. a thread opened
  /// from a notification before chat mounted).
  ///
  /// Returns `null` for text-ish messages, whose [IsmChatMessageModel.body] is
  /// shown as-is. Pass [contentType] from [IsmChatMessageModel.threadPanelBubbleType]
  /// when wire `customType` is `reply`.
  static String? threadPreviewLabel(
    IsmChatMessageModel message, [
    IsmChatCustomMessageType? contentType,
  ]) =>
      IsmChatThreadCoordinator.threadContentTypeLabel(message, contentType);

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
    final bubbleType = message.threadPanelBubbleType;
    final label = threadPreviewLabel(message, bubbleType);
    final body = message.body.trim();
    // Media / location / contact replies reuse the channel's own widgets, so a
    // photo in a thread looks like a photo in the chat (and an in-flight
    // upload shows the same progress state).
    final asBubble = bubbleType != null &&
        IsmChatUtility.chatPageControllerRegistered;
    final showBodyText = body.isNotEmpty &&
        !(asBubble && IsmChatUtility.isOutboundAttachmentPlaceholderBody(body));
    final bubbleMessage =
        asBubble ? message.copyWith(customType: bubbleType) : message;

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
                _threadPanelBubbleTapTarget(
                  bubbleType: bubbleType,
                  message: bubbleMessage,
                  child: _threadAttachmentPreview(
                    context,
                    bubbleType: bubbleType,
                    theme: theme,
                    child: IsmChatMessageWrapper(bubbleMessage),
                  ),
                )
              else if (label != null && body.isEmpty)
                Text(label, style: theme.attachmentLabelStyle)
              else ...[
                if (label != null) ...[
                  Text(label, style: theme.attachmentLabelStyle),
                  IsmChatDimens.boxHeight2,
                ],
                if (showBodyText) Text(body, style: theme.bodyStyle),
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

/// Adds channel-style tap handling when the bubble does not handle taps itself.
Widget _threadPanelBubbleTapTarget({
  required IsmChatCustomMessageType? bubbleType,
  required IsmChatMessageModel message,
  required Widget child,
}) {
  if (bubbleType == null ||
      !IsmChatThreadMessageTile.threadPanelBubbleNeedsMessageCardTap(
        bubbleType,
      )) {
    return child;
  }
  return IsmChatTapHandler(
    onTap: () =>
        IsmChatThreadMessageTile.openContactDetailsFromThread(message),
    child: child,
  );
}

/// Outlines document previews in the thread panel.
///
/// Thread rows reuse [IsmChatFileMessage] without [MessageBubble] chrome, so
/// the PDF / text / Office preview would otherwise blend into the panel
/// background. Only file attachments get the frame (other media keep full-bleed).
Widget _threadAttachmentPreview(
  BuildContext context, {
  required IsmChatCustomMessageType? bubbleType,
  required IsmChatThreadTheme theme,
  required Widget child,
}) {
  if (bubbleType != IsmChatCustomMessageType.file) return child;
  final radius = BorderRadius.circular(IsmChatDimens.ten);
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      border: Border.all(color: theme.rootCardBorderColor),
    ),
    child: ClipRRect(borderRadius: radius, child: child),
  );
}
