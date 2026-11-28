import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// One tile of the conversation media grid / strip. Fills its parent; audio
/// and file items show a tinted icon tile instead of a thumbnail.
///
/// **Reuse:** prefer [IsmChatMediaThumbnail] for tappable grid/strip cells.
/// Image loading goes through [IsmChatMediaImageProvider] so tiles share the
/// same cache as chat bubbles and the full-screen viewer.
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
    final radius = borderRadius ?? IsmChatDesignTokens.thumbRadius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: isFile ? tokens.accentSoft : tokens.surfaceMuted,
        child: SizedBox.expand(
          child: isFile
              ? Icon(iconData, color: tokens.accent, size: 36)
              : _MediaTileImage(url: url, tokens: tokens),
        ),
      ),
    );
  }
}

/// Fills the tile. [IsmChatImage] sizes to `0.6 * screen width` (bubble), which
/// overflows grid cells and often paints as an empty/placeholder square.
class _MediaTileImage extends StatelessWidget {
  const _MediaTileImage({required this.url, required this.tokens});

  final String url;
  final IsmChatDesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final provider = IsmChatMediaImageProvider.fromUrl(url);
    if (provider == null) {
      return Icon(
        Icons.image_outlined,
        color: tokens.textSecondary,
        size: 28,
      );
    }

    // Network: CachedNetworkImage keeps parity with bubbles + viewer.
    if (url.isValidUrl) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 400,
        placeholder: (_, __) => ColoredBox(color: tokens.surfaceMuted),
        errorWidget: (_, __, ___) => Icon(
          Icons.broken_image_outlined,
          color: tokens.textSecondary,
          size: 28,
        ),
      );
    }

    return Image(
      image: provider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        color: tokens.textSecondary,
        size: 28,
      ),
    );
  }
}

/// Tappable media tile: [ConversationMediaWidget] plus a play badge for
/// videos. Used by the media grid ([IsmMediaView]) and the media strip on
/// contact / group info.
class IsmChatMediaThumbnail extends StatelessWidget {
  const IsmChatMediaThumbnail({
    super.key,
    required this.message,
    required this.onTap,
    this.borderRadius,
  });

  final IsmChatMessageModel message;
  final VoidCallback onTap;

  /// Null → [IsmChatDesignTokens.thumbRadius].
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = IsmChatMediaImageProvider.displayUrlForMessage(message);
    final iconData = message.customType == IsmChatCustomMessageType.audio
        ? Icons.audio_file_rounded
        : Icons.description_rounded;
    final isVideo = message.customType == IsmChatCustomMessageType.video;

    return Semantics(
      button: true,
      label: isVideo ? IsmChatStrings.video : IsmChatStrings.image,
      child: IsmChatTapHandler(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ConversationMediaWidget(
              media: message,
              iconData: iconData,
              url: url,
              borderRadius: borderRadius,
            ),
            if (isVideo)
              Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
