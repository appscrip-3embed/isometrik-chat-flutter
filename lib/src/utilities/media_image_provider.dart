import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Resolves [ImageProvider]s for media grid tiles and the full-screen viewer.
///
/// **Reuse:** call [fromAttachment] / [fromUrl] anywhere a chat image must match
/// what the bubble already showed. Do not use raw [NetworkImage] for remote
/// chat media — it skips [CachedNetworkImage]'s disk cache, so PhotoView often
/// shows its broken-image icon while the bubble (which hit the cache) still
/// looks fine.
///
/// Order: in-memory [AttachmentModel.bytes] → network URL (cache) → local file
/// → web byte-string. For video/grid tiles pass `preferThumbnail: true` so
/// `thumbnailUrl` wins over `mediaUrl`.
class IsmChatMediaImageProvider {
  const IsmChatMediaImageProvider._();

  /// Provider for one attachment, or `null` when nothing is loadable.
  static ImageProvider? fromAttachment(
    AttachmentModel? attachment, {
    bool preferThumbnail = false,
  }) {
    final bytes = attachment?.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return MemoryImage(bytes);
    }

    final media = (attachment?.mediaUrl ?? '').trim();
    final thumb = (attachment?.thumbnailUrl ?? '').trim();
    final primary = preferThumbnail
        ? (thumb.isNotEmpty ? thumb : media)
        : (media.isNotEmpty ? media : thumb);
    return fromUrl(primary);
  }

  /// Provider for a raw URL / local path / web byte string.
  static ImageProvider? fromUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url == 'null') return null;

    if (url.isValidUrl) {
      return CachedNetworkImageProvider(url);
    }

    if (!kIsWeb) {
      try {
        final file = File(url);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (_) {
        // Path may be a byte string on some platforms — fall through.
      }
    }

    final decoded = url.strigToUnit8List;
    if (decoded.isNotEmpty) {
      return MemoryImage(decoded);
    }
    return null;
  }

  /// Best display URL for a tile (image → media, video → thumbnail).
  static String displayUrlForMessage(IsmChatMessageModel message) {
    final attachment = message.attachments?.firstOrNull;
    if (attachment == null) return '';
    if (message.customType == IsmChatCustomMessageType.image) {
      final media = (attachment.mediaUrl ?? '').trim();
      if (media.isNotEmpty) return media;
      return (attachment.thumbnailUrl ?? '').trim();
    }
    final thumb = (attachment.thumbnailUrl ?? '').trim();
    if (thumb.isNotEmpty) return thumb;
    return (attachment.mediaUrl ?? '').trim();
  }
}
