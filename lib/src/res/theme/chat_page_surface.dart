import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Resolves chat-page background, wallpaper, and composer field chrome.
///
/// Shared by [IsmChatPageView] and [IsmChatThreadView] so hosts only configure
/// [IsmChatThemeData.chatPageTheme] (and per-conversation wallpaper via
/// [IsmChatPageController.backgroundColor] / [IsmChatPageController.backgroundImage]).
class IsmChatChatPageSurface {
  const IsmChatChatPageSurface({
    required this.hasConversationWallpaper,
    required this.outerDecoration,
    required this.scaffoldBackgroundColor,
    required this.bodyDecoration,
  });

  final bool hasConversationWallpaper;
  final BoxDecoration outerDecoration;
  final Color scaffoldBackgroundColor;
  final Decoration? bodyDecoration;

  /// [pageController] may be null (tests / routes without an open chat page).
  static IsmChatChatPageSurface resolve(IsmChatPageController? pageController) {
    final backgroundImage = pageController?.backgroundImage ?? '';
    final backgroundColor = pageController?.backgroundColor ?? '';

    final hasImageWallpaper =
        backgroundImage.isNotEmpty && backgroundImage.isSupportedChatWallpaperUrl;
    final hasColorWallpaper = backgroundColor.isNotEmpty;
    final hasConversationWallpaper = hasImageWallpaper || hasColorWallpaper;

    return IsmChatChatPageSurface(
      hasConversationWallpaper: hasConversationWallpaper,
      outerDecoration: BoxDecoration(
        color: hasColorWallpaper
            ? backgroundColor.toColor
            : hasImageWallpaper
                ? Colors.transparent
                : IsmChatColors.whiteColor,
        image: hasImageWallpaper
            ? DecorationImage(
                image: _wallpaperImageProvider(backgroundImage),
                fit: BoxFit.cover,
              )
            : null,
      ),
      scaffoldBackgroundColor: hasConversationWallpaper
          ? Colors.transparent
          : IsmChatConfig.chatTheme.chatPageTheme?.backgroundColor ??
              Colors.transparent,
      bodyDecoration: hasConversationWallpaper
          ? null
          : IsmChatConfig.chatTheme.chatPageTheme?.pageDecoration,
    );
  }

  static ImageProvider<Object> _wallpaperImageProvider(String backgroundImage) {
    if (backgroundImage.isValidUrl) {
      return NetworkImage(backgroundImage);
    }
    if (IsmChatProperties.chatPageProperties.backgroundImageUrl.isNullOrEmpty) {
      if (backgroundImage.contains('packages/isometrik_chat_flutter/assets')) {
        return AssetImage(backgroundImage);
      }
      return FileImage(File(backgroundImage));
    }
    return AssetImage(backgroundImage);
  }

  /// Inner composer field fill — matches [IsmChatMessageField].
  static Color composerFieldBackgroundColor() =>
      IsmChatConfig.chatTheme.chatPageTheme?.textFiledTheme?.backgroundColor ??
      IsmChatConfig.chatTheme.backgroundColor ??
      IsmChatColors.whiteColor;

  /// Inner composer field border — matches [IsmChatMessageField].
  static Color composerFieldBorderColor() =>
      IsmChatConfig.chatTheme.chatPageTheme?.textFiledTheme?.borderColor ??
      IsmChatConfig.chatTheme.primaryColor ??
      IsmChatColors.primaryColorLight;

  static IsmChatTextFiledTheme? get _composerTheme =>
      IsmChatConfig.chatTheme.chatPageTheme?.textFiledTheme;

  /// Prefix emoji icon — same optional override as [IsmChatMessageField].
  static Color? composerEmojiColor() => _composerTheme?.emojiColor;

  /// In-field attachment icon — same override as [IsmChatMessageField].
  static Color composerAttachmentColor() =>
      _composerTheme?.attchmentColor ??
      IsmChatConfig.chatTheme.primaryColor ??
      IsmChatColors.primaryColorLight;

  static TextStyle? composerInputTextStyle() => _composerTheme?.inputTextStyle;

  static TextStyle composerHintTextStyle() =>
      _composerTheme?.hintTextStyle ?? IsmChatStyles.w400Black12;

  static Color composerCursorColor() =>
      _composerTheme?.cursorColor ??
      IsmChatConfig.chatTheme.primaryColor ??
      IsmChatColors.primaryColorLight;
}