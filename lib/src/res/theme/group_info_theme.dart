import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Theme for group / conversation info ([IsmChatConverstaionInfoView]) and
/// message info ([IsmChatMessageInfo]).
///
/// Omit on [IsmChatPageTheme] to use SDK light/dark defaults via [IsmChatThemeResolver].
/// Pass a full instance, or tweak a default with
/// `IsmChatGroupInfoTheme.light().copyWith(...)`.
class IsmChatGroupInfoTheme {
  const IsmChatGroupInfoTheme({
    required this.scaffoldBackgroundColor,
    required this.surfaceBackgroundColor,
    required this.primaryTitleTextStyle,
    required this.secondaryTextStyle,
    required this.captionTextStyle,
    required this.metaTextStyle,
    required this.sectionTitleTextStyle,
    required this.bodyTextStyle,
    required this.listTileTitleTextStyle,
    required this.listTileSubtitleTextStyle,
    required this.actionIconColor,
    required this.menuIconColor,
    required this.inputTextStyle,
    required this.searchFillColor,
    required this.searchHintTextStyle,
    required this.searchIconColor,
    required this.adminBadgeTextStyle,
    required this.dividerColor,
    this.destructiveColor,
  });

  factory IsmChatGroupInfoTheme.light() => IsmChatGroupInfoTheme.fromTokens(
      IsmChatDesignTokens.forBrightness(Brightness.light));

  factory IsmChatGroupInfoTheme.dark() => IsmChatGroupInfoTheme.fromTokens(
      IsmChatDesignTokens.forBrightness(Brightness.dark));

  /// SDK default built from [IsmChatDesignTokens].
  factory IsmChatGroupInfoTheme.fromTokens(IsmChatDesignTokens tokens) =>
      IsmChatGroupInfoTheme(
        scaffoldBackgroundColor: tokens.canvas,
        surfaceBackgroundColor: tokens.surface,
        primaryTitleTextStyle: tokens.headline,
        secondaryTextStyle: tokens.subhead,
        captionTextStyle: tokens.caption,
        metaTextStyle: tokens.footnote,
        sectionTitleTextStyle: tokens.body,
        bodyTextStyle: tokens.body,
        listTileTitleTextStyle: tokens.bodyStrong,
        listTileSubtitleTextStyle: tokens.footnote,
        actionIconColor: tokens.textTertiary,
        menuIconColor: tokens.textPrimary,
        inputTextStyle: tokens.body,
        searchFillColor: tokens.surfaceMuted,
        searchHintTextStyle: tokens.body.copyWith(color: tokens.textTertiary),
        searchIconColor: tokens.textTertiary,
        adminBadgeTextStyle: tokens.micro.copyWith(
          color: tokens.accent,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: tokens.hairline,
        destructiveColor: tokens.danger,
      );

  final Color scaffoldBackgroundColor;
  final Color surfaceBackgroundColor;
  final TextStyle primaryTitleTextStyle;
  final TextStyle secondaryTextStyle;
  final TextStyle captionTextStyle;
  final TextStyle metaTextStyle;
  final TextStyle sectionTitleTextStyle;
  final TextStyle bodyTextStyle;
  final TextStyle listTileTitleTextStyle;
  final TextStyle listTileSubtitleTextStyle;
  final Color actionIconColor;
  final Color menuIconColor;
  final TextStyle inputTextStyle;
  final Color searchFillColor;
  final TextStyle searchHintTextStyle;
  final Color searchIconColor;
  final TextStyle adminBadgeTextStyle;
  final Color dividerColor;

  /// Clear chat / exit / delete / block rows. Null → SDK danger red.
  final Color? destructiveColor;

  IsmChatGroupInfoTheme copyWith({
    Color? scaffoldBackgroundColor,
    Color? surfaceBackgroundColor,
    TextStyle? primaryTitleTextStyle,
    TextStyle? secondaryTextStyle,
    TextStyle? captionTextStyle,
    TextStyle? metaTextStyle,
    TextStyle? sectionTitleTextStyle,
    TextStyle? bodyTextStyle,
    TextStyle? listTileTitleTextStyle,
    TextStyle? listTileSubtitleTextStyle,
    Color? actionIconColor,
    Color? menuIconColor,
    TextStyle? inputTextStyle,
    Color? searchFillColor,
    TextStyle? searchHintTextStyle,
    Color? searchIconColor,
    TextStyle? adminBadgeTextStyle,
    Color? dividerColor,
    Color? destructiveColor,
  }) =>
      IsmChatGroupInfoTheme(
        scaffoldBackgroundColor:
            scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
        surfaceBackgroundColor:
            surfaceBackgroundColor ?? this.surfaceBackgroundColor,
        primaryTitleTextStyle:
            primaryTitleTextStyle ?? this.primaryTitleTextStyle,
        secondaryTextStyle: secondaryTextStyle ?? this.secondaryTextStyle,
        captionTextStyle: captionTextStyle ?? this.captionTextStyle,
        metaTextStyle: metaTextStyle ?? this.metaTextStyle,
        sectionTitleTextStyle:
            sectionTitleTextStyle ?? this.sectionTitleTextStyle,
        bodyTextStyle: bodyTextStyle ?? this.bodyTextStyle,
        listTileTitleTextStyle:
            listTileTitleTextStyle ?? this.listTileTitleTextStyle,
        listTileSubtitleTextStyle:
            listTileSubtitleTextStyle ?? this.listTileSubtitleTextStyle,
        actionIconColor: actionIconColor ?? this.actionIconColor,
        menuIconColor: menuIconColor ?? this.menuIconColor,
        inputTextStyle: inputTextStyle ?? this.inputTextStyle,
        searchFillColor: searchFillColor ?? this.searchFillColor,
        searchHintTextStyle: searchHintTextStyle ?? this.searchHintTextStyle,
        searchIconColor: searchIconColor ?? this.searchIconColor,
        adminBadgeTextStyle: adminBadgeTextStyle ?? this.adminBadgeTextStyle,
        dividerColor: dividerColor ?? this.dividerColor,
        destructiveColor: destructiveColor ?? this.destructiveColor,
      );
}
