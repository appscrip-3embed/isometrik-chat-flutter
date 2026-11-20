import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Reads pixel dimensions for chat attachment layout (aspect ratio).
///
/// Used when sending local images and when displaying
/// bubbles that lack server-provided `mediaWidth` / `mediaHeight`.
class IsmChatImageAttachmentDimensions {
  IsmChatImageAttachmentDimensions._();

  /// Width and height from in-memory or on-disk image bytes (sync).
  static ({int width, int height})? fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return null;
      }
      return (width: decoded.width, height: decoded.height);
    } catch (_) {
      return null;
    }
  }

  /// Flutter codec decode — handles formats `image` may not (e.g. some HEIC/JPEG).
  static Future<double?> aspectRatioFromBytesCodec(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      if (w <= 0 || h <= 0) return null;
      return w / h;
    } catch (_) {
      return null;
    }
  }

  /// Dimensions for an outbound pick (bytes preferred, then local path).
  static ({int width, int height})? forOutboundPick({
    Uint8List? bytes,
    String? localPath,
  }) {
    if (bytes != null && bytes.isNotEmpty) {
      final fromBytes_ = fromBytes(bytes);
      if (fromBytes_ != null) return fromBytes_;
    }
    if (!kIsWeb && localPath != null && localPath.isNotEmpty) {
      try {
        final file = File(localPath);
        if (file.existsSync()) {
          return fromBytes(file.readAsBytesSync());
        }
      } catch (_) {}
    }
    return null;
  }

  /// Aspect ratio from attachment metadata, bytes, or local path.
  static double? aspectRatioFromAttachment(AttachmentModel? attachment) {
    final meta = attachment?.mediaAspectRatio;
    if (meta != null && meta > 0) return meta;

    final bytes = attachment?.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final dims = fromBytes(bytes);
      if (dims != null) return dims.width / dims.height;
    }

    if (!kIsWeb) {
      final path = attachment?.mediaUrl ?? '';
      if (path.isNotEmpty && !path.isValidUrl) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            final dims = fromBytes(file.readAsBytesSync());
            if (dims != null) return dims.width / dims.height;
          }
        } catch (_) {}
      }
    }

    if (kIsWeb) {
      final path = attachment?.mediaUrl ?? '';
      if (path.isNotEmpty && !path.isValidUrl) {
        final webBytes = path.strigToUnit8List;
        if (webBytes.isNotEmpty) {
          final dims = fromBytes(webBytes);
          if (dims != null) return dims.width / dims.height;
        }
      }
    }
    return null;
  }
}