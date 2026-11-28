import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatVideoMessage extends StatefulWidget {
  const IsmChatVideoMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  State<IsmChatVideoMessage> createState() => _IsmChatVideoMessageState();
}

class _IsmChatVideoMessageState extends State<IsmChatVideoMessage> {
  /// Tracks expand/collapse state for long captions (show more / show less).
  late final ValueNotifier<bool> _isExpandedNotifier;

  /// Video shape (width / height); null until known (frame is square).
  double? _aspectRatio;

  /// Thumbnail currently being measured, so each one is read only once.
  String? _measuringThumbnail;

  @override
  void initState() {
    super.initState();
    _isExpandedNotifier = ValueNotifier(false);
    _syncAspectRatio();
  }

  @override
  void didUpdateWidget(covariant IsmChatVideoMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_aspectRatio == null) _syncAspectRatio();
  }

  /// Attachment metadata first; otherwise measure the thumbnail, which keeps
  /// the video's shape (local bytes before upload, network URL after).
  void _syncAspectRatio() {
    final attachment = widget.message.attachments?.firstOrNull;
    final meta = attachment?.mediaAspectRatio;
    if (meta != null && meta > 0) {
      _aspectRatio = meta;
      return;
    }
    final thumbnail = attachment?.thumbnailUrl ?? '';
    if (thumbnail.isEmpty || thumbnail == _measuringThumbnail) return;
    _measuringThumbnail = thumbnail;
    final ratio = thumbnail.isValidUrl
        ? IsmChatImageAttachmentDimensions.aspectRatioFromProvider(
            CachedNetworkImageProvider(thumbnail),
          )
        : IsmChatImageAttachmentDimensions.aspectRatioFromBytesCodec(
            thumbnail.strigToUnit8List,
          );
    unawaited(ratio.then((value) {
      if (!mounted || _aspectRatio != null || value == null || value <= 0) {
        return;
      }
      setState(() => _aspectRatio = value);
    }));
  }

  @override
  void dispose() {
    _isExpandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);
    final thumbnailUrl = message.attachments?.first.thumbnailUrl ?? '';
    final isNetworkThumbnail = thumbnailUrl.isValidUrl;
    final frame = _frameSize(context);
    return Material(
      color: Colors.transparent,
      child: BlurFilter(
        isBlured: data?.shouldBlured ?? false,
        sigmaX: data?.sigmaX ?? 10,
        sigmaY: data?.sigmaY ?? 10,
        // Caption width is capped at the thumbnail width.
        child: IsmChatMediaCaptionLayout(
          // Keep media interactions isolated to thumbnail.
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
              margin: IsmChatDimens.edgeInsetsBottom4,
              // Tight frame: IsmChatImage fills it with BoxFit.cover, so
              // out-of-range shapes are center-cropped like images.
              child: SizedBox(
                width: frame.width,
                height: frame.height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IsmChatImage(
                      thumbnailUrl,
                      isNetworkImage: isNetworkThumbnail,
                      isBytes: !isNetworkThumbnail,
                    ),
                    Icon(
                      Icons.play_circle,
                      size: IsmChatDimens.sixty,
                      color: IsmChatColors.whiteColor,
                    ),
                    if (message.isUploading == true)
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
            ),
          ),
          caption: message.metaData?.caption?.isNotEmpty == true
              ? Padding(
                  padding: IsmChatDimens.edgeInsetsTop5,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isExpandedNotifier,
                    builder: (context, isExpanded, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IsmChatMentionRichText(
                          body: message.metaData?.caption ?? '',
                          style: message.style,
                          message: message,
                          textAlign: TextAlign.start,
                          overflow: isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          maxLines: isExpanded ? null : 3,
                        ),
                        if (_isCaptionOverflowing(context))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: IsmChatDimens.edgeInsets0,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _isExpandedNotifier.value = !isExpanded;
                              },
                              child: Text(
                                isExpanded ? 'Show less' : 'Show more',
                                style: message.readTextStyle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Returns true if caption exceeds 3 lines so we can show "Show more" button.
  bool _isCaptionOverflowing(BuildContext context) {
    final caption = widget.message.metaData?.caption ?? '';
    if (caption.isEmpty) return false;

    final textPainter = TextPainter(
      text: TextSpan(
        style: widget.message.style,
        children: IsmChatMentionRichText.measurementSpans(
          caption,
          widget.message.style,
          widget.message.mentionListForBody(caption),
        ),
      ),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _frameSize(context).width);

    return textPainter.didExceedMaxLines;
  }

  /// Mobile: same frame as image bubbles (3/4 width, height from the video's
  /// shape clamped to 3:4…16:9). Web keeps its square thumbnail.
  Size _frameSize(BuildContext context) {
    if (IsmChatResponsive.isWeb(context)) {
      final byScreen = context.width * .25;
      final byTheme = IsmChatDimens.twoHundredTwenty;
      return Size.square(byScreen < byTheme ? byScreen : byTheme);
    }
    return IsmChatMediaGridLayout.chatMediaFrameSize(
      screenWidth: context.width,
      isWeb: false,
      aspectRatio: _aspectRatio,
    );
  }
}
