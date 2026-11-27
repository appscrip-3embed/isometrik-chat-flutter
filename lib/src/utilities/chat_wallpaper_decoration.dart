import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Chat wallpaper (image or colour) set for the open conversation.
///
/// Shared by [IsmChatPageView] and [IsmChatMessageInfo] so the message info
/// preview sits on the same background as the chat.
class IsmChatWallpaper {
  IsmChatWallpaper._();

  static bool hasImage(IsmChatPageController controller) =>
      controller.backgroundImage.isNotEmpty &&
      controller.backgroundImage.isSupportedChatWallpaperUrl;

  static bool hasColor(IsmChatPageController controller) =>
      controller.backgroundColor.isNotEmpty;

  /// True when the conversation has an image or colour wallpaper.
  static bool hasWallpaper(IsmChatPageController controller) =>
      hasImage(controller) || hasColor(controller);

  /// Colour / image decoration for the conversation wallpaper.
  ///
  /// With no wallpaper set, the colour is [fallbackColor].
  static BoxDecoration decoration(
    IsmChatPageController controller, {
    Color fallbackColor = IsmChatColors.whiteColor,
  }) {
    final hasImageWallpaper = hasImage(controller);
    final hasColorWallpaper = hasColor(controller);
    return BoxDecoration(
      color: hasColorWallpaper
          ? controller.backgroundColor.toColor
          : hasImageWallpaper
              ? Colors.transparent
              : fallbackColor,
      image: hasImageWallpaper
          ? DecorationImage(
              image: _imageProvider(controller.backgroundImage),
              fit: BoxFit.cover,
            )
          : null,
    );
  }

  static ImageProvider _imageProvider(String backgroundImage) {
    if (backgroundImage.isValidUrl) {
      return NetworkImage(backgroundImage);
    }
    if (!IsmChatProperties
        .chatPageProperties.backgroundImageUrl.isNullOrEmpty) {
      return AssetImage(backgroundImage);
    }
    if (backgroundImage.contains('packages/isometrik_chat_flutter/assets')) {
      return AssetImage(backgroundImage);
    }
    return FileImage(File(backgroundImage));
  }
}
