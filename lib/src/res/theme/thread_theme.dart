import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Theme for the Slack-style thread surfaces: the "N replies" footer under a
/// root message ([IsmChatThreadFooter]) and the thread panel
/// ([IsmChatThreadView]).
///
/// Omit [IsmChatThemeData.threadTheme] for the SDK light/dark defaults
/// ([IsmChatThemeResolver.threadFromConfig]).
class IsmChatThreadTheme {
  const IsmChatThreadTheme({
    required this.scaffoldBackgroundColor,
    required this.footerLabelStyle,
    required this.footerIconColor,
    required this.rootCardBackgroundColor,
    required this.rootCardBorderColor,
    required this.senderNameStyle,
    required this.timeStyle,
    required this.bodyStyle,
    required this.attachmentLabelStyle,
    required this.dividerColor,
    required this.replyCountSummaryStyle,
    required this.composerBackgroundColor,
    required this.composerHintStyle,
    required this.composerTextStyle,
    required this.alsoSendToChannelLabelStyle,
    required this.channelContextPrefixStyle,
    required this.channelContextSubjectStyle,
    required this.sendButtonColor,
    required this.sendButtonIconColor,
    required this.errorTextStyle,
    required this.emptyTextStyle,
  });

  factory IsmChatThreadTheme.light() => IsmChatThreadTheme(
        scaffoldBackgroundColor: IsmChatColors.backgroundColorLight,
        footerLabelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: IsmChatConfig.chatTheme.primaryColor ??
              IsmChatColors.primaryColorLight,
        ),
        footerIconColor: IsmChatConfig.chatTheme.primaryColor ??
            IsmChatColors.primaryColorLight,
        rootCardBackgroundColor: IsmChatColors.whiteColor,
        rootCardBorderColor:
            IsmChatColors.greyColorLight.withValues(alpha: 0.4),
        senderNameStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        timeStyle: const TextStyle(
          fontSize: 11,
          color: IsmChatColors.greyColor,
        ),
        bodyStyle: const TextStyle(fontSize: 14.5),
        attachmentLabelStyle: const TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: IsmChatColors.greyColor,
        ),
        dividerColor: IsmChatColors.greyColorLight.withValues(alpha: 0.4),
        replyCountSummaryStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: IsmChatColors.greyColor,
        ),
        composerBackgroundColor: IsmChatColors.whiteColor,
        composerHintStyle: const TextStyle(
          fontSize: 14,
          color: IsmChatColors.greyColor,
        ),
        composerTextStyle: const TextStyle(fontSize: 14.5),
        alsoSendToChannelLabelStyle: const TextStyle(fontSize: 12.5),
        channelContextPrefixStyle: const TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.greyColor,
        ),
        channelContextSubjectStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: IsmChatConfig.chatTheme.primaryColor ??
              IsmChatColors.primaryColorLight,
        ),
        sendButtonColor: IsmChatConfig.chatTheme.primaryColor ??
            IsmChatColors.primaryColorLight,
        sendButtonIconColor: IsmChatColors.whiteColor,
        errorTextStyle: TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.redColor.withValues(alpha: 0.9),
        ),
        emptyTextStyle: const TextStyle(
          fontSize: 13.5,
          color: IsmChatColors.greyColor,
        ),
      );

  factory IsmChatThreadTheme.dark() => IsmChatThreadTheme(
        scaffoldBackgroundColor: IsmChatColors.backgroundColorDark,
        footerLabelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: IsmChatConfig.chatTheme.primaryColor ??
              IsmChatColors.primaryColorDark,
        ),
        footerIconColor: IsmChatConfig.chatTheme.primaryColor ??
            IsmChatColors.primaryColorDark,
        rootCardBackgroundColor:
            IsmChatColors.blackColor.withValues(alpha: 0.35),
        rootCardBorderColor: IsmChatColors.greyColor.withValues(alpha: 0.4),
        senderNameStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: IsmChatColors.whiteColor,
        ),
        timeStyle: const TextStyle(
          fontSize: 11,
          color: IsmChatColors.greyColorLight,
        ),
        bodyStyle: const TextStyle(
          fontSize: 14.5,
          color: IsmChatColors.whiteColor,
        ),
        attachmentLabelStyle: const TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: IsmChatColors.greyColorLight,
        ),
        dividerColor: IsmChatColors.greyColor.withValues(alpha: 0.4),
        replyCountSummaryStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: IsmChatColors.greyColorLight,
        ),
        composerBackgroundColor:
            IsmChatColors.blackColor.withValues(alpha: 0.35),
        composerHintStyle: const TextStyle(
          fontSize: 14,
          color: IsmChatColors.greyColorLight,
        ),
        composerTextStyle: const TextStyle(
          fontSize: 14.5,
          color: IsmChatColors.whiteColor,
        ),
        alsoSendToChannelLabelStyle: const TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.whiteColor,
        ),
        channelContextPrefixStyle: const TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.greyColorLight,
        ),
        channelContextSubjectStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: IsmChatConfig.chatTheme.primaryColor ??
              IsmChatColors.primaryColorDark,
        ),
        sendButtonColor: IsmChatConfig.chatTheme.primaryColor ??
            IsmChatColors.primaryColorDark,
        sendButtonIconColor: IsmChatColors.whiteColor,
        errorTextStyle: TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.redColor.withValues(alpha: 0.9),
        ),
        emptyTextStyle: const TextStyle(
          fontSize: 13.5,
          color: IsmChatColors.greyColorLight,
        ),
      );

  /// Background of the thread panel.
  final Color scaffoldBackgroundColor;

  /// "3 replies" label under a root message in the channel timeline.
  final TextStyle footerLabelStyle;
  final Color footerIconColor;

  /// Card that shows the thread's root message at the top of the panel.
  final Color rootCardBackgroundColor;
  final Color rootCardBorderColor;

  final TextStyle senderNameStyle;
  final TextStyle timeStyle;
  final TextStyle bodyStyle;

  /// Used for non-text replies (e.g. "Photo", "Document").
  final TextStyle attachmentLabelStyle;

  final Color dividerColor;

  /// "3 replies" separator row between the root and the replies.
  final TextStyle replyCountSummaryStyle;

  final Color composerBackgroundColor;
  final TextStyle composerHintStyle;
  final TextStyle composerTextStyle;
  final TextStyle alsoSendToChannelLabelStyle;

  /// **replied to a thread:** prefix on also-sent channel rows.
  final TextStyle channelContextPrefixStyle;

  /// Clickable parent summary (file name, snippet, media type).
  final TextStyle channelContextSubjectStyle;

  final Color sendButtonColor;
  final Color sendButtonIconColor;

  final TextStyle errorTextStyle;
  final TextStyle emptyTextStyle;
}
