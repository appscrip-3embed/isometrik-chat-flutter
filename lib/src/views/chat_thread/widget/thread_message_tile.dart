import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// One row inside the thread panel: avatar, sender, time and body.
///
/// Deliberately self-contained (it does not reuse the channel [MessageBubble])
/// so a thread can render without the chat-page controller — the panel is
/// pushed as its own route and may outlive a chat page rebuild.
///
/// Reactions and the focus-menu reaction picker reuse the channel stack
/// ([ImsChatReaction], [IsmChatFocusMenu]) when [IsmChatUtility.chatPageController]
/// is registered — same constraint as [IsmChatMessageWrapper] for media rows.
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
    final attachmentCaption =
        _threadBubbleAttachmentCaption(message, bubbleType);
    final bubbleMessage = asBubble
        ? _threadPanelBubbleMessageForWrapper(message, bubbleType!)
        : message;

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
                  if (message.messageUpdated) ...[
                    Text(
                      IsmChatStrings.messageEdited,
                      style: theme.timeStyle.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    IsmChatDimens.boxWidth4,
                  ],
                  Text(
                    message.sentAt.toTimeString,
                    style: theme.timeStyle,
                  ),
                ],
              ),
              IsmChatDimens.boxHeight2,
              if (asBubble) ...[
                _threadPanelBubbleTapTarget(
                  bubbleType: bubbleType,
                  message: bubbleMessage,
                  child: _threadAttachmentPreview(
                    context,
                    bubbleType: bubbleType,
                    theme: theme,
                    child: IsmChatMessageWrapper(bubbleMessage),
                  ),
                ),
                if (attachmentCaption.isNotEmpty) ...[
                  IsmChatDimens.boxHeight2,
                  IsmChatExpandableTextBlock(
                    text: attachmentCaption,
                    textStyle: theme.bodyStyle,
                    toggleStyle: _threadExpandToggleStyle(theme),
                    collapsedMaxLines: 3,
                  ),
                ],
              ] else if (label != null && body.isEmpty)
                Text(label, style: theme.attachmentLabelStyle)
              else ...[
                if (label != null) ...[
                  Text(label, style: theme.attachmentLabelStyle),
                  IsmChatDimens.boxHeight2,
                ],
                if (showBodyText)
                  IsmChatExpandableTextBlock(
                    text: body,
                    textStyle: theme.bodyStyle,
                    toggleStyle: _threadExpandToggleStyle(theme),
                    collapsedMaxLines: 15,
                    message: _threadBodyUsesMentionRichText(message, body)
                        ? message
                        : null,
                  ),
              ],
              // "Also sent to channel" replies carry showInConversation: true.
              if (!isRoot && message.showInConversation == true) ...[
                IsmChatDimens.boxHeight2,
                Text(
                  IsmChatStrings.threadAlsoSendToChannel,
                  style: theme.timeStyle,
                ),
              ],
              if (_showsReactionRow(message)) ...[
                IsmChatDimens.boxHeight4,
                Align(
                  alignment: Alignment.centerLeft,
                  child: IsmChatThreadReactionRow(
                    key: ValueKey(_reactionRowKey(message)),
                    message: message,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final wrapped = _wrapWithFocusMenu(context, message, content);

    if (!isRoot) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: IsmChatDimens.twelve,
          vertical: IsmChatDimens.eight,
        ),
        child: wrapped,
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
      child: wrapped,
    );
  }

  static String _reactionRowKey(IsmChatMessageModel message) {
    final id = message.messageId ?? message.sentAt.toString();
    final reactions = message.reactions
        ?.where((e) => e.emojiKey.isNotEmpty && e.userIds.isNotEmpty)
        .toList();
    if (reactions == null || reactions.isEmpty) return '$id-r0';
    final summary = reactions
        .map((e) => '${e.emojiKey}:${e.userIds.join(',')}')
        .join('|');
    return '$id-$summary';
  }

  static bool _showsReactionRow(IsmChatMessageModel message) {
    if (!IsmChatProperties.chatPageProperties.features
        .contains(IsmChatFeature.reaction)) {
      return false;
    }
    if (!IsmChatUtility.chatPageControllerRegistered) return false;
    final reactions = message.reactions
        ?.where((e) => e.emojiKey.isNotEmpty && e.userIds.isNotEmpty)
        .toList();
    return reactions?.isNotEmpty == true;
  }

  /// Long-press / secondary-tap opens the same focus menu as the channel
  /// (including [ReactionGrid] when reactions are enabled).
  static Widget _wrapWithFocusMenu(
    BuildContext context,
    IsmChatMessageModel message,
    Widget child,
  ) {
    if (!IsmChatUtility.chatPageControllerRegistered) return child;
    if (message.customType == IsmChatCustomMessageType.deletedForEveryone) {
      return child;
    }
    return GestureDetector(
      onLongPress: () => unawaited(openFocusMenu(context, message)),
      onSecondaryTap:
          kIsWeb ? () => unawaited(openFocusMenu(context, message)) : null,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  /// Delegates to [IsmChatPageController] focus-menu / reaction flows.
  static Future<void> openFocusMenu(
    BuildContext context,
    IsmChatMessageModel message,
  ) async {
    if (!IsmChatUtility.chatPageControllerRegistered) return;
    final controller = IsmChatUtility.chatPageController;
    if (!(controller.conversation?.isChattingAllowed ?? false)) {
      controller.showDialogCheckBlockUnBlock();
      return;
    }
    if (message.customType == IsmChatCustomMessageType.deletedForEveryone) {
      return;
    }
    if (kIsWeb) {
      await controller.holdController?.forward();
      final animation = controller.holdAnimation;
      if (animation != null) {
        await controller.showOverlayWeb(context, message, animation);
      }
      return;
    }
    await controller.onMessageLongPress(context, message);
  }
}

/// Caption under the bubble in the thread panel.
///
/// File messages already show the name on [IsmChatFileMessage]; only show
/// text here when the user added a [IsmChatMetaData.caption].
String _threadBubbleAttachmentCaption(
  IsmChatMessageModel message,
  IsmChatCustomMessageType? bubbleType,
) {
  if (bubbleType == IsmChatCustomMessageType.file) {
    return message.metaData?.caption?.trim() ?? '';
  }
  return message.attachmentDisplayCaption;
}

/// Show more / Show less accent on the thread panel (readable on any background).
TextStyle _threadExpandToggleStyle(IsmChatThreadTheme theme) =>
    theme.footerLabelStyle;

/// @mentions / autolinks need [IsmChatMentionRichText]; plain text uses [Text].
bool _threadBodyUsesMentionRichText(
  IsmChatMessageModel message,
  String body,
) =>
    message.mentionListForBody(body).any((s) => s.isLink);

/// Channel bubble widgets paint captions with [IsmChatMessageModel.style] (white
/// on self bubbles). Thread rows strip metadata captions for the wrapper and
/// render [IsmChatMessageModel.attachmentDisplayCaption] with [IsmChatThreadTheme.bodyStyle].
IsmChatMessageModel _threadPanelBubbleMessageForWrapper(
  IsmChatMessageModel message,
  IsmChatCustomMessageType bubbleType,
) {
  final meta = message.metaData;
  final strippedMeta = meta != null && (meta.caption?.trim().isNotEmpty == true)
      ? meta.copyWith(captionMessage: '')
      : meta;
  return message.copyWith(
    customType: bubbleType,
    metaData: strippedMeta,
  );
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
