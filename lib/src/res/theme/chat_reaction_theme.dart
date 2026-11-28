import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Theme for message reactions ([ImsChatReaction], [ImsChatShowUserReaction]).
///
/// Reuse via [IsmChatConfig.chatTheme.chatPageTheme.reactionTheme] or
/// [IsmChatThemeResolver.reactionFromConfig].
class IsmChatReactionTheme {
  const IsmChatReactionTheme({
    required this.backgroundColor,
    required this.countTextStyle,
    required this.tabLabelTextStyle,
    required this.tabCountTextStyle,
    required this.listTileTitleTextStyle,
    required this.listTileSubtitleTextStyle,
    this.boxShadow,
    this.emojiBackgroundColor,
  });

  factory IsmChatReactionTheme.light() => IsmChatReactionTheme(
        backgroundColor: IsmChatColors.whiteColor,
        countTextStyle: IsmChatStyles.w400Black12,
        tabLabelTextStyle: IsmChatStyles.w400Black18,
        tabCountTextStyle: IsmChatStyles.w400Black16,
        listTileTitleTextStyle: IsmChatStyles.w500Black16,
        listTileSubtitleTextStyle: IsmChatStyles.w400Grey14,
        boxShadow: const [BoxShadow(color: Colors.black26)],
        emojiBackgroundColor: IsmChatColors.backgroundColorLight,
      );

  factory IsmChatReactionTheme.dark() => IsmChatReactionTheme(
        backgroundColor: IsmChatColors.backgroundColorDark,
        countTextStyle: IsmChatStyles.w400White12,
        tabLabelTextStyle: IsmChatStyles.w400White18,
        tabCountTextStyle: IsmChatStyles.w400White16,
        listTileTitleTextStyle: IsmChatStyles.w500White16,
        listTileSubtitleTextStyle: IsmChatStyles.w400White12,
        boxShadow: const [BoxShadow(color: Colors.black45)],
        emojiBackgroundColor: IsmChatColors.blackColor,
      );

  /// Reactions sheet default built from [IsmChatDesignTokens].
  ///
  /// [IsmChatReactionTheme.light] / [IsmChatReactionTheme.dark] stay the
  /// defaults for the reaction chips on message bubbles;
  /// [ImsChatShowUserReaction] uses this when the host passes no
  /// [IsmChatPageTheme.reactionTheme].
  factory IsmChatReactionTheme.fromTokens(IsmChatDesignTokens tokens) =>
      IsmChatReactionTheme(
        backgroundColor: tokens.surface,
        countTextStyle: tokens.footnote.copyWith(color: tokens.textPrimary),
        tabLabelTextStyle: tokens.footnote.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        tabCountTextStyle: tokens.footnote.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        listTileTitleTextStyle: tokens.bodyStrong,
        listTileSubtitleTextStyle: tokens.footnote,
        emojiBackgroundColor: tokens.surfaceMuted,
      );

  /// Chip / sheet background.
  final Color backgroundColor;

  /// Reaction count on message chips ([ImsChatReaction]).
  final TextStyle countTextStyle;

  /// "All" tab label ([ImsChatShowUserReaction]).
  final TextStyle tabLabelTextStyle;

  /// Emoji tab reaction count ([ImsChatShowUserReaction]).
  final TextStyle tabCountTextStyle;

  /// User name in reaction list ([ImsChatShowUserReaction]).
  final TextStyle listTileTitleTextStyle;

  /// Username / remove-reaction subtitle ([ImsChatShowUserReaction]).
  final TextStyle listTileSubtitleTextStyle;

  final List<BoxShadow>? boxShadow;
  final Color? emojiBackgroundColor;

  IsmChatReactionTheme copyWith({
    Color? backgroundColor,
    TextStyle? countTextStyle,
    TextStyle? tabLabelTextStyle,
    TextStyle? tabCountTextStyle,
    TextStyle? listTileTitleTextStyle,
    TextStyle? listTileSubtitleTextStyle,
    List<BoxShadow>? boxShadow,
    Color? emojiBackgroundColor,
  }) =>
      IsmChatReactionTheme(
        backgroundColor: backgroundColor ?? this.backgroundColor,
        countTextStyle: countTextStyle ?? this.countTextStyle,
        tabLabelTextStyle: tabLabelTextStyle ?? this.tabLabelTextStyle,
        tabCountTextStyle: tabCountTextStyle ?? this.tabCountTextStyle,
        listTileTitleTextStyle:
            listTileTitleTextStyle ?? this.listTileTitleTextStyle,
        listTileSubtitleTextStyle:
            listTileSubtitleTextStyle ?? this.listTileSubtitleTextStyle,
        boxShadow: boxShadow ?? this.boxShadow,
        emojiBackgroundColor: emojiBackgroundColor ?? this.emojiBackgroundColor,
      );
}
