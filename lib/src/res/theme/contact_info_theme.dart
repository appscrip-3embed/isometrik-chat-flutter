import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Theme for the shared-contact screen ([IsmChatContactsInfoView]).
///
/// Omit in app config for SDK light/dark defaults ([IsmChatThemeResolver]).
/// Pass a full instance, or tweak a default with
/// `IsmChatContactInfoTheme.light().copyWith(...)`.
class IsmChatContactInfoTheme {
  const IsmChatContactInfoTheme({
    required this.scaffoldBackgroundColor,
    required this.cardBackgroundColor,
    required this.nameTextStyle,
    required this.identifierTextStyle,
    required this.addButtonBackgroundColor,
    required this.addButtonTextStyle,
    required this.actionIconColor,
    required this.actionLabelTextStyle,
    required this.dividerColor,
  });

  factory IsmChatContactInfoTheme.light() => IsmChatContactInfoTheme.fromTokens(
      IsmChatDesignTokens.forBrightness(Brightness.light));

  factory IsmChatContactInfoTheme.dark() => IsmChatContactInfoTheme.fromTokens(
      IsmChatDesignTokens.forBrightness(Brightness.dark));

  /// SDK default built from [IsmChatDesignTokens] (carries the host font family).
  factory IsmChatContactInfoTheme.fromTokens(IsmChatDesignTokens tokens) =>
      IsmChatContactInfoTheme(
        scaffoldBackgroundColor: tokens.canvas,
        cardBackgroundColor: tokens.surface,
        nameTextStyle: tokens.bodyStrong,
        identifierTextStyle: tokens.footnote,
        addButtonBackgroundColor: tokens.accent,
        addButtonTextStyle: tokens.button,
        actionIconColor: tokens.accent,
        actionLabelTextStyle: tokens.footnote.copyWith(
          color: tokens.accent,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: tokens.hairline,
      );

  final Color scaffoldBackgroundColor;
  final Color cardBackgroundColor;
  final TextStyle nameTextStyle;
  final TextStyle identifierTextStyle;
  final Color addButtonBackgroundColor;
  final TextStyle addButtonTextStyle;
  final Color actionIconColor;
  final TextStyle actionLabelTextStyle;
  final Color dividerColor;

  IsmChatContactInfoTheme copyWith({
    Color? scaffoldBackgroundColor,
    Color? cardBackgroundColor,
    TextStyle? nameTextStyle,
    TextStyle? identifierTextStyle,
    Color? addButtonBackgroundColor,
    TextStyle? addButtonTextStyle,
    Color? actionIconColor,
    TextStyle? actionLabelTextStyle,
    Color? dividerColor,
  }) =>
      IsmChatContactInfoTheme(
        scaffoldBackgroundColor:
            scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
        cardBackgroundColor: cardBackgroundColor ?? this.cardBackgroundColor,
        nameTextStyle: nameTextStyle ?? this.nameTextStyle,
        identifierTextStyle: identifierTextStyle ?? this.identifierTextStyle,
        addButtonBackgroundColor:
            addButtonBackgroundColor ?? this.addButtonBackgroundColor,
        addButtonTextStyle: addButtonTextStyle ?? this.addButtonTextStyle,
        actionIconColor: actionIconColor ?? this.actionIconColor,
        actionLabelTextStyle: actionLabelTextStyle ?? this.actionLabelTextStyle,
        dividerColor: dividerColor ?? this.dividerColor,
      );
}
