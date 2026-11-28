import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatImageMessage extends StatefulWidget {
  const IsmChatImageMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  State<IsmChatImageMessage> createState() => _IsmChatImageMessageState();
}

class _IsmChatImageMessageState extends State<IsmChatImageMessage> {
  late final ValueNotifier<bool> _isExpandedNotifier;

  @override
  void initState() {
    super.initState();
    _isExpandedNotifier = ValueNotifier(false);
  }

  @override
  void dispose() {
    _isExpandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isSticker = message.isStickerMessage;
    final isGif = message.isGifMessage;
    final isWeb = IsmChatResponsive.isWeb(context);
    final maxWidth = isSticker
        ? IsmChatDimens.hundredFourty
        : IsmChatMediaGridLayout.chatMediaBubbleMaxWidth(
            context.width,
            isWeb: isWeb,
          );
    final maxHeight = isSticker
        ? IsmChatDimens.hundredFourty
        : IsmChatMediaGridLayout.chatMediaMaxHeight(
            context.width,
            isWeb: isWeb,
          );
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);
    return Material(
      color: Colors.transparent,
      child: BlurFilter(
        isBlured: data?.shouldBlured ?? false,
        sigmaX: data?.sigmaX ?? 10,
        sigmaY: data?.sigmaY ?? 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Caption width is capped at the rendered image width.
            IsmChatMediaCaptionLayout(
              media: IsmChatTapHandler(
                onTap: () {
                  IsmChatThreadCoordinator.openMediaPreviewFromThread(message);
                },
                onLongPress: () {
                  if (IsmChatUtility.chatPageControllerRegistered) {
                    IsmChatUtility.chatPageController.onMessageLongPress(
                      context,
                      message,
                    );
                  }
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: _MessageMediaImage(
                    message: message,
                    isSticker: isSticker,
                    isGif: isGif,
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                ),
              ),
              caption: (!isGif &&
                      !isSticker &&
                      message.metaData?.caption?.isNotEmpty == true)
                  ? Padding(
                      padding: IsmChatDimens.edgeInsetsTop5,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final caption = message.metaData?.caption ?? '';
                          final textSpan = TextSpan(
                            style: message.style,
                            children: IsmChatMentionRichText.measurementSpans(
                              caption,
                              message.style,
                              message.mentionListForBody(caption),
                            ),
                          );
                          final textPainter = TextPainter(
                            text: textSpan,
                            maxLines: _isExpandedNotifier.value ? null : 3,
                            textDirection: TextDirection.ltr,
                          )..layout(
                              maxWidth: constraints.maxWidth > 0
                                  ? constraints.maxWidth
                                  : context.width * 0.7);

                          final didOverflow = textPainter.didExceedMaxLines;

                          return ValueListenableBuilder<bool>(
                            valueListenable: _isExpandedNotifier,
                            builder: (context, isExpanded, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IsmChatMentionRichText(
                                  body: caption,
                                  style: message.style,
                                  message: message,
                                  textAlign: TextAlign.start,
                                  overflow: isExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  maxLines: isExpanded ? null : 3,
                                ),
                                if (!isExpanded && didOverflow)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: IsmChatDimens.edgeInsets0,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        _isExpandedNotifier.value = true;
                                      },
                                      child: Text(
                                        'Show more',
                                        style: message.readTextStyle,
                                      ),
                                    ),
                                  ),
                                if (isExpanded)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: IsmChatDimens.edgeInsets0,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        _isExpandedNotifier.value = false;
                                      },
                                      child: Text(
                                        'Show less',
                                        style: message.readTextStyle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : null,
            ),
            if (message.isUploading == true &&
                !_MessageMediaImage.hasDisplayableMedia(message))
              Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: IsmChatUtility.circularProgressBar(
                    IsmChatColors.blackColor,
                    IsmChatColors.whiteColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageMediaImage extends StatefulWidget {
  const _MessageMediaImage({
    required this.message,
    required this.isSticker,
    required this.isGif,
    required this.maxWidth,
    required this.maxHeight,
  });

  final IsmChatMessageModel message;
  final bool isSticker;
  final bool isGif;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_MessageMediaImage> createState() => _MessageMediaImageState();

  static bool hasDisplayableMedia(IsmChatMessageModel message) {
    final attachment = message.attachments?.firstOrNull;
    if (attachment == null) {
      return false;
    }
    final mediaUrl = attachment.mediaUrl ?? '';
    if (mediaUrl.isValidUrl) {
      return true;
    }
    if (attachment.bytes != null && attachment.bytes!.isNotEmpty) {
      return true;
    }
    if (!kIsWeb && mediaUrl.isNotEmpty && File(mediaUrl).existsSync()) {
      return true;
    }
    if (kIsWeb && mediaUrl.isNotEmpty && mediaUrl.strigToUnit8List.isNotEmpty) {
      return true;
    }
    return false;
  }
}

class _MessageMediaImageState extends State<_MessageMediaImage> {
  double? _aspectRatio;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  IsmChatMessageModel get message => widget.message;
  bool get isSticker => widget.isSticker;
  bool get isGif => widget.isGif;
  double get maxWidth => widget.maxWidth;
  double get maxHeight => widget.maxHeight;

  double? _layoutAspectRatio(AttachmentModel? attachment) =>
      _aspectRatio ??
      IsmChatImageAttachmentDimensions.aspectRatioFromAttachment(attachment);

  @override
  void initState() {
    super.initState();
    final attachment = message.attachments?.firstOrNull;
    _aspectRatio = IsmChatImageAttachmentDimensions.aspectRatioFromAttachment(
      attachment,
    );
    if (_aspectRatio == null && !isSticker) {
      _scheduleAspectRatioResolution(attachment);
    }
  }

  @override
  void didUpdateWidget(covariant _MessageMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_aspectRatio != null) {
      return;
    }
    final attachment = message.attachments?.firstOrNull;
    final fromMeta = IsmChatImageAttachmentDimensions.aspectRatioFromAttachment(
      attachment,
    );
    if (fromMeta != null) {
      _stopNetworkAspectListen();
      setState(() => _aspectRatio = fromMeta);
      return;
    }
    _scheduleAspectRatioResolution(attachment);
  }

  void _scheduleAspectRatioResolution(AttachmentModel? attachment) {
    final bytes = attachment?.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      unawaited(_decodeAspectFromCodec(bytes));
      return;
    }
    if (!kIsWeb) {
      final path = attachment?.mediaUrl ?? '';
      if (path.isNotEmpty && !path.isValidUrl) {
        unawaited(_decodeAspectFromLocalFile(path));
        return;
      }
    }
    final mediaUrl = attachment?.mediaUrl ?? '';
    if (mediaUrl.isValidUrl) {
      _listenNetworkAspectRatio(mediaUrl);
    }
  }

  Future<void> _decodeAspectFromLocalFile(String path) async {
    if (_aspectRatio != null) return;
    try {
      final fileBytes = await File(path).readAsBytes();
      await _decodeAspectFromCodec(fileBytes);
    } catch (_) {}
  }

  Future<void> _decodeAspectFromCodec(Uint8List bytes) async {
    if (_aspectRatio != null) return;
    final ratio =
        await IsmChatImageAttachmentDimensions.aspectRatioFromBytesCodec(bytes);
    if (!mounted || _aspectRatio != null || ratio == null || ratio <= 0) {
      return;
    }
    setState(() => _aspectRatio = ratio);
  }

  @override
  void dispose() {
    _stopNetworkAspectListen();
    super.dispose();
  }

  void _stopNetworkAspectListen() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _listenNetworkAspectRatio(String url) {
    if (_aspectRatio != null) return;
    _stopNetworkAspectListen();
    final provider = CachedNetworkImageProvider(url);
    _imageStream = provider.resolve(const ImageConfiguration());
    _imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (_aspectRatio != null) {
          _stopNetworkAspectListen();
          return;
        }
        final w = info.image.width;
        final h = info.image.height;
        if (w > 0 && h > 0 && mounted) {
          setState(() => _aspectRatio = w / h);
        }
        _stopNetworkAspectListen();
      },
      onError: (_, __) => _stopNetworkAspectListen(),
    );
    _imageStream!.addListener(_imageStreamListener!);
  }

  static Widget _loadingPlaceholder(Size size) => ColoredBox(
        color: IsmChatColors.greyColor.applyIsmOpacity(0.12),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );

  static Widget _placeholderImage({
    required Size size,
    required String? imageUrl,
    required BoxFit fit,
  }) {
    if (imageUrl == null || !imageUrl.isValidUrl) {
      return _loadingPlaceholder(size);
    }
    // Fill the reserved frame so still → animated swap never changes layout.
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      width: size.width,
      height: size.height,
      memCacheWidth: size.width.round(),
      memCacheHeight: size.height.round(),
      placeholder: (_, __) => _loadingPlaceholder(size),
      errorWidget: (_, __, ___) => _loadingPlaceholder(size),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachments?.firstOrNull;
    final mediaUrl = attachment?.mediaUrl ?? '';
    final bytes = attachment?.bytes;
    final hasNetworkUrl = mediaUrl.isValidUrl;
    final hasBytes = bytes != null && bytes.isNotEmpty;
    final hasLocalFile = !kIsWeb &&
        !hasNetworkUrl &&
        mediaUrl.isNotEmpty &&
        File(mediaUrl).existsSync();
    // Cover: the mobile frame clamps extreme ratios, so the image is
    // center-cropped into it (WhatsApp-style) instead of letterboxed.
    final fit = isSticker ? BoxFit.contain : BoxFit.cover;
    final borderRadius = isSticker
        ? BorderRadius.zero
        : BorderRadius.circular(IsmChatDimens.eight);
    final layoutAspect = _layoutAspectRatio(attachment);
    final reservedSize = isSticker
        ? null
        : IsmChatMediaGridLayout.chatMediaFrameSize(
            screenWidth: context.width,
            isWeb: IsmChatResponsive.isWeb(context),
            aspectRatio: layoutAspect,
          );
    final placeholderUrl = isGif ? _gifPlaceholderUrl(attachment) : null;

    Widget child;
    // Keep local preview while upload finishes — avoids swap to network spinner.
    if (hasBytes) {
      child = Image.memory(
        bytes,
        fit: fit,
        width: reservedSize?.width,
        height: reservedSize?.height,
        gaplessPlayback: true,
      );
    } else if (hasLocalFile) {
      child = Image.file(
        File(mediaUrl),
        fit: fit,
        width: reservedSize?.width,
        height: reservedSize?.height,
        gaplessPlayback: true,
      );
    } else if (hasNetworkUrl) {
      child = CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: fit,
        // Zero fade avoids a brief dual-layout during placeholder → image.
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        width: reservedSize?.width,
        height: reservedSize?.height,
        memCacheWidth: reservedSize?.width.round(),
        memCacheHeight: reservedSize?.height.round(),
        placeholder: (_, __) => _placeholderImage(
          size: reservedSize ?? Size(maxWidth, maxHeight),
          imageUrl: placeholderUrl,
          fit: fit,
        ),
        errorWidget: (_, __, ___) => _mediaError(reservedSize),
      );
    } else if (IsmChatResponsive.isWeb(context) && mediaUrl.isNotEmpty) {
      final webBytes = mediaUrl.strigToUnit8List;
      child = webBytes.isEmpty
          ? _mediaError(reservedSize)
          : Image.memory(
              webBytes,
              fit: fit,
              width: reservedSize?.width,
              height: reservedSize?.height,
              gaplessPlayback: true,
            );
    } else {
      child = _mediaError(reservedSize);
    }

    // Hard-lock the frame: StackFit.expand forces the image to the reserved
    // size so Android GIF decode cannot expand intrinsic layout.
    final media = reservedSize != null
        ? SizedBox(
            width: reservedSize.width,
            height: reservedSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [child],
            ),
          )
        : child;

    return ClipRRect(
      borderRadius: borderRadius,
      child: media,
    );
  }

  /// Prefer still frame while the animated GIF loads (Giphy sends this).
  static String? _gifPlaceholderUrl(AttachmentModel? attachment) {
    if (attachment == null) return null;
    final still = attachment.stillUrl ?? '';
    if (still.isValidUrl) return still;
    final thumb = attachment.thumbnailUrl ?? '';
    if (thumb.isValidUrl) return thumb;
    return null;
  }

  Widget _mediaError(Size? reservedSize) => Container(
        width: reservedSize?.width,
        height: reservedSize?.height,
        alignment: Alignment.center,
        color: IsmChatColors.greyColor.applyIsmOpacity(0.15),
        child: const Icon(Icons.broken_image_outlined),
      );
}
