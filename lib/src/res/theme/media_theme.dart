import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Theme for conversation media ([IsmMedia], [IsmDocsView], [IsmLinksView],
/// [IsmMediaView], [IsmMediaPreview]).
///
/// Omit in app config for SDK light/dark defaults ([IsmChatThemeResolver]).
/// Pass a full instance, or tweak a default with
/// `IsmChatMediaTheme.light().copyWith(...)`.
class IsmChatMediaTheme {
  const IsmChatMediaTheme({
    required this.scaffoldBackgroundColor,
    required this.appBarBackgroundColor,
    required this.appBarIconColor,
    required this.previewBackgroundColor,
    required this.previewTitleTextStyle,
    required this.previewSubtitleTextStyle,
    required this.tabBarContainerColor,
    required this.tabSelectedBackgroundColor,
    required this.tabUnselectedBackgroundColor,
    required this.tabSelectedTextStyle,
    required this.tabUnselectedTextStyle,
    required this.sectionTitleTextStyle,
    required this.docTitleTextStyle,
    required this.docSubtitleTextStyle,
    required this.docTrailingTextStyle,
    required this.emptyStateTextStyle,
    required this.dividerColor,
    this.cardBackgroundColor,
  });

  factory IsmChatMediaTheme.light() => IsmChatMediaTheme.fromTokens(
      IsmChatDesignTokens.forBrightness(Brightness.light));

  factory IsmChatMediaTheme.dark() => IsmChatMediaTheme.fromTokens(
      IsmChatDesignTokens.forBrightness(Brightness.dark));

  /// SDK default built from [IsmChatDesignTokens]. The app bar follows
  /// [IsmChatThemeData.chatPageHeaderTheme] → primary colour, like the chat header.
  factory IsmChatMediaTheme.fromTokens(IsmChatDesignTokens tokens) {
    final header = IsmChatConfig.chatTheme.chatPageHeaderTheme;
    final previewBg = chatScreenBackground(tokens);
    final previewFg = IsmChatDesignTokens.foregroundFor(previewBg);
    return IsmChatMediaTheme(
      scaffoldBackgroundColor: tokens.canvas,
      appBarBackgroundColor: header?.backgroundColor ??
          IsmChatConfig.chatTheme.primaryColor ??
          tokens.accent,
      appBarIconColor:
          header?.iconColor ?? IsmChatDesignTokens.viewerForeground,
      // Match chat screen: light canvas / white-ish in light, dark in dark.
      previewBackgroundColor: previewBg,
      previewTitleTextStyle: tokens.bodyStrong.copyWith(color: previewFg),
      previewSubtitleTextStyle: tokens.footnote.copyWith(
        color: previewFg.withValues(alpha: .72),
      ),
      tabBarContainerColor: tokens.segmentTrack,
      tabSelectedBackgroundColor: tokens.segmentThumb,
      tabUnselectedBackgroundColor: Colors.transparent,
      tabSelectedTextStyle: tokens.footnote.copyWith(
        color: tokens.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      tabUnselectedTextStyle: tokens.footnote.copyWith(
        color: tokens.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      sectionTitleTextStyle: tokens.caption,
      docTitleTextStyle: tokens.callout,
      docSubtitleTextStyle: tokens.footnote,
      docTrailingTextStyle: tokens.micro,
      emptyStateTextStyle: tokens.title,
      dividerColor: tokens.hairline,
      cardBackgroundColor: tokens.surface,
    );
  }

  /// Same fill as the chat page scaffold (page theme → theme → canvas).
  ///
  /// Reuse for [previewBackgroundColor] so the full-screen viewer matches the
  /// conversation screen in light and dark — not a forced black film strip.
  static Color chatScreenBackground(IsmChatDesignTokens tokens) =>
      IsmChatConfig.chatTheme.chatPageTheme?.backgroundColor ??
      IsmChatConfig.chatTheme.backgroundColor ??
      tokens.canvas;

  final Color scaffoldBackgroundColor;
  final Color appBarBackgroundColor;
  final Color appBarIconColor;

  /// Full-screen image/video preview ([IsmMediaPreview]).
  final Color previewBackgroundColor;
  final TextStyle previewTitleTextStyle;
  final TextStyle previewSubtitleTextStyle;

  final Color tabBarContainerColor;
  final Color tabSelectedBackgroundColor;
  final Color tabUnselectedBackgroundColor;
  final TextStyle tabSelectedTextStyle;
  final TextStyle tabUnselectedTextStyle;
  final TextStyle sectionTitleTextStyle;
  final TextStyle docTitleTextStyle;
  final TextStyle docSubtitleTextStyle;
  final TextStyle docTrailingTextStyle;
  final TextStyle emptyStateTextStyle;
  final Color dividerColor;

  /// Cards behind link / document rows. Null → SDK surface colour.
  final Color? cardBackgroundColor;

  IsmChatMediaTheme copyWith({
    Color? scaffoldBackgroundColor,
    Color? appBarBackgroundColor,
    Color? appBarIconColor,
    Color? previewBackgroundColor,
    TextStyle? previewTitleTextStyle,
    TextStyle? previewSubtitleTextStyle,
    Color? tabBarContainerColor,
    Color? tabSelectedBackgroundColor,
    Color? tabUnselectedBackgroundColor,
    TextStyle? tabSelectedTextStyle,
    TextStyle? tabUnselectedTextStyle,
    TextStyle? sectionTitleTextStyle,
    TextStyle? docTitleTextStyle,
    TextStyle? docSubtitleTextStyle,
    TextStyle? docTrailingTextStyle,
    TextStyle? emptyStateTextStyle,
    Color? dividerColor,
    Color? cardBackgroundColor,
  }) =>
      IsmChatMediaTheme(
        scaffoldBackgroundColor:
            scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
        appBarBackgroundColor:
            appBarBackgroundColor ?? this.appBarBackgroundColor,
        appBarIconColor: appBarIconColor ?? this.appBarIconColor,
        previewBackgroundColor:
            previewBackgroundColor ?? this.previewBackgroundColor,
        previewTitleTextStyle:
            previewTitleTextStyle ?? this.previewTitleTextStyle,
        previewSubtitleTextStyle:
            previewSubtitleTextStyle ?? this.previewSubtitleTextStyle,
        tabBarContainerColor: tabBarContainerColor ?? this.tabBarContainerColor,
        tabSelectedBackgroundColor:
            tabSelectedBackgroundColor ?? this.tabSelectedBackgroundColor,
        tabUnselectedBackgroundColor:
            tabUnselectedBackgroundColor ?? this.tabUnselectedBackgroundColor,
        tabSelectedTextStyle: tabSelectedTextStyle ?? this.tabSelectedTextStyle,
        tabUnselectedTextStyle:
            tabUnselectedTextStyle ?? this.tabUnselectedTextStyle,
        sectionTitleTextStyle:
            sectionTitleTextStyle ?? this.sectionTitleTextStyle,
        docTitleTextStyle: docTitleTextStyle ?? this.docTitleTextStyle,
        docSubtitleTextStyle: docSubtitleTextStyle ?? this.docSubtitleTextStyle,
        docTrailingTextStyle: docTrailingTextStyle ?? this.docTrailingTextStyle,
        emptyStateTextStyle: emptyStateTextStyle ?? this.emptyStateTextStyle,
        dividerColor: dividerColor ?? this.dividerColor,
        cardBackgroundColor: cardBackgroundColor ?? this.cardBackgroundColor,
      );
}
