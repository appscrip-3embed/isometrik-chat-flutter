import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Composer / message input styling on [IsmChatPageTheme.textFiledTheme].
///
/// Omit for SDK light/dark defaults via [IsmChatThemeResolver.textFieldFromConfig].
/// Pass only the fields you need to override (e.g. [recordingTimerTextStyle]).
class IsmChatTextFiledTheme {
  const IsmChatTextFiledTheme({
    this.inputTextStyle,
    this.decoration,
    this.backgroundColor,
    this.cursorColor,
    this.textfieldInsets,
    this.attchmentColor,
    this.emojiColor,
    this.borderColor,
    this.hintTextStyle,
    this.recordingTimerTextStyle,
    this.emojiBoardBackgroundColor,
    this.emojiBoardCategoryIconColor,
    this.emojiBoardActionIconColor,
  });

  factory IsmChatTextFiledTheme.light() {
    final primary = IsmChatConfig.chatTheme.primaryColor ??
        IsmChatColors.primaryColorLight;
    final tokens = IsmChatDesignTokens.forBrightness(Brightness.light);
    return IsmChatTextFiledTheme(
      inputTextStyle: IsmChatStyles.w400Black12,
      hintTextStyle: IsmChatStyles.w400Black12.copyWith(
        color: IsmChatColors.greyColor,
      ),
      backgroundColor: IsmChatColors.whiteColor,
      cursorColor: IsmChatColors.primaryColorLight,
      attchmentColor: IsmChatColors.primaryColorLight,
      // Composer smile button — follows host primary (not hardcoded purple).
      emojiColor: primary,
      borderColor: IsmChatColors.primaryColorLight,
      recordingTimerTextStyle: IsmChatStyles.w600Black20,
      emojiBoardBackgroundColor: IsmChatColors.whiteColor,
      // Unselected emoji-picker category icons (selected uses primary in picker).
      emojiBoardCategoryIconColor: tokens.textSecondary,
      emojiBoardActionIconColor: IsmChatColors.blackColor,
    );
  }

  factory IsmChatTextFiledTheme.dark() {
    final primary = IsmChatConfig.chatTheme.primaryColor ??
        IsmChatColors.primaryColorDark;
    final tokens = IsmChatDesignTokens.forBrightness(Brightness.dark);
    return IsmChatTextFiledTheme(
      inputTextStyle: IsmChatStyles.w400White14,
      hintTextStyle: IsmChatStyles.w400White12.copyWith(
        color: IsmChatColors.greyColorLight,
      ),
      backgroundColor: const Color(0xFF353535),
      cursorColor: IsmChatColors.primaryColorDark,
      attchmentColor: IsmChatColors.primaryColorDark,
      // Composer smile button — follows host primary (not hardcoded purple).
      emojiColor: primary,
      borderColor: IsmChatColors.greyColor,
      recordingTimerTextStyle: IsmChatStyles.w600White16.copyWith(
        fontSize: IsmChatDimens.twenty,
      ),
      emojiBoardBackgroundColor: const Color(0xFF353535),
      // Unselected emoji-picker category icons (selected uses primary in picker).
      emojiBoardCategoryIconColor: tokens.textSecondary,
      emojiBoardActionIconColor: IsmChatColors.whiteColor,
    );
  }

  final TextStyle? inputTextStyle;
  final TextStyle? hintTextStyle;
  final Decoration? decoration;
  final Color? backgroundColor;
  final Color? cursorColor;
  final EdgeInsetsGeometry? textfieldInsets;
  final Color? attchmentColor;

  /// Composer emoji (smile) affordance color.
  ///
  /// Category-tab **selected** color is driven by
  /// [IsmChatThemeData.primaryColor] in [IsmChatComposerEmojiPicker], not
  /// this field. Defaults follow host primary.
  final Color? emojiColor;
  final Color? borderColor;

  /// Voice-note recording timer in [IsmChatMessageField].
  final TextStyle? recordingTimerTextStyle;

  /// [EmojiBoard] panel, category bar, and search backgrounds.
  final Color? emojiBoardBackgroundColor;

  /// Unselected category (and search) icons on [EmojiBoard].
  ///
  /// Defaults to [IsmChatDesignTokens.textSecondary]. Selected category
  /// icons use host [IsmChatThemeData.primaryColor] in the picker.
  final Color? emojiBoardCategoryIconColor;

  /// Bottom action bar icons on [EmojiBoard].
  final Color? emojiBoardActionIconColor;
}
