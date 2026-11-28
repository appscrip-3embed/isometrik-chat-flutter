import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// One tile of the conversation media grid / strip. Fills its parent; audio
/// and file items show a tinted icon tile instead of a thumbnail.
class ConversationMediaWidget extends StatelessWidget {
  const ConversationMediaWidget({
    super.key,
    required this.media,
    required this.iconData,
    required this.url,
    this.borderRadius,
  });

  final IsmChatMessageModel media;
  final IconData iconData;
  final String url;

  /// Null → [IsmChatDesignTokens.thumbRadius]. Pass 0 for edge-to-edge grids.
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final isFile = [
      IsmChatCustomMessageType.audio,
      IsmChatCustomMessageType.file,
    ].contains(media.customType);
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(borderRadius ?? IsmChatDesignTokens.thumbRadius),
      child: ColoredBox(
        color: isFile ? tokens.accentSoft : tokens.surfaceMuted,
        child: SizedBox.expand(
          child: isFile
              ? Icon(iconData, color: tokens.accent, size: 36)
              : IsmChatImage(
                  url,
                  isNetworkImage: url.isValidUrl,
                  radius: borderRadius ?? IsmChatDesignTokens.thumbRadius,
                ),
        ),
      ),
    );
  }
}
