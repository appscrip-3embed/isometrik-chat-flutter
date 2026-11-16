import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Copy and widget overrides for the Slack-style thread surfaces.
///
/// Set once, before opening chat:
/// ```dart
/// IsmChatProperties.threadProperties = IsmChatThreadProperties(
///   title: 'Thread',
///   showAlsoSendToChannel: false, // hide the Slack checkbox
///   replyTileBuilder: (context, reply) => MyReplyRow(reply),
/// );
/// ```
///
/// Every field is optional — the SDK ships a complete, themeable default
/// ([IsmChatThreadView], [IsmChatThreadFooter], [IsmChatThreadTheme]). None of
/// it is reachable while [IsmChatConfig.threadsEnabled] is `false`.
class IsmChatThreadProperties {
  const IsmChatThreadProperties({
    this.title,
    this.composerHintText,
    this.showAlsoSendToChannel = true,
    this.showAttachments = true,
    this.alsoSendToChannelLabel,
    this.replyFooterBuilder,
    this.rootMessageBuilder,
    this.replyTileBuilder,
    this.emptyPlaceholder,
    this.onThreadOpened,
  });

  /// Defaults used when the host sets nothing.
  static const IsmChatThreadProperties defaults = IsmChatThreadProperties();

  /// Thread panel app-bar title. Defaults to [IsmChatStrings.threadTitle].
  final String? title;

  /// Composer placeholder. Defaults to [IsmChatStrings.threadReplyHint].
  final String? composerHintText;

  /// Whether the composer offers Slack's "Also send to channel".
  ///
  /// With `false` every reply is thread-only (`showInConversation: false`).
  final bool showAlsoSendToChannel;

  /// Whether the thread composer shows the paperclip that opens the channel's
  /// attachment sheet (photos, videos, documents, location, contact, camera).
  ///
  /// `false` makes the thread text-only.
  final bool showAttachments;

  /// Label for that checkbox. Defaults to
  /// [IsmChatStrings.threadAlsoSendToChannel].
  final String? alsoSendToChannelLabel;

  /// Replaces the "N replies" footer shown under a root message in the channel
  /// timeline. Return `null` to keep the SDK footer.
  ///
  /// The builder is responsible for opening the thread (e.g. via
  /// `IsmChat.i.openThread(message)`).
  final Widget? Function(
    BuildContext context,
    IsmChatMessageModel message,
    int replyCount,
  )? replyFooterBuilder;

  /// Replaces the root-message card at the top of the thread panel.
  final Widget? Function(
    BuildContext context,
    IsmChatMessageModel root,
  )? rootMessageBuilder;

  /// Replaces a single reply row in the thread panel.
  final Widget? Function(
    BuildContext context,
    IsmChatMessageModel reply,
  )? replyTileBuilder;

  /// Shown instead of the default "No replies yet" empty state.
  final Widget? emptyPlaceholder;

  /// Called whenever a thread panel opens — useful for analytics.
  final void Function(IsmChatMessageModel root)? onThreadOpened;
}
