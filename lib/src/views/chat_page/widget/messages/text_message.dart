import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatTextMessage extends StatefulWidget {
  const IsmChatTextMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  State<IsmChatTextMessage> createState() => _IsmChatTextMessageState();
}

class _IsmChatTextMessageState extends State<IsmChatTextMessage> {
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

  /// Default SDK text UI (RichText, mentions, show more/less).
  ///
  /// Used when `textMessageWithLinkBuilder` is null, the message has no valid
  /// web link, or the builder returns null.
  Widget _buildDefaultTextContent(IsmChatMessageModel message) =>
      ValueListenableBuilder<bool>(
        valueListenable: _isExpandedNotifier,
        builder: (context, isExpanded, _) {
          // Measure overflow using the same max-width rule the
          // message bubble uses, without LayoutBuilder.
          // LayoutBuilder + IntrinsicWidth can trigger expensive
          // layout/semantics cycles in fast-scrolling chat lists.
          final maxByScreen = IsmChatResponsive.isWeb(context)
              ? context.width * .25
              : context.width * .6;
          final themeConstraints = IsmChatConfig
              .chatTheme.chatPageTheme?.messageConstraints?.messageConstraints;
          final maxWidth = themeConstraints?.maxWidth != null &&
                  themeConstraints!.maxWidth.isFinite
              ? themeConstraints.maxWidth
              : maxByScreen;

          final isOverflowing = _isTextOverflowing(maxWidth, message);

          return Column(
            crossAxisAlignment: message.sentByMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              IsmChatMentionRichText(
                body: message.body,
                style: message.style,
                message: message,
                maxLines: isExpanded ? null : 15,
                overflow: isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (isOverflowing)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: IsmChatDimens.edgeInsets0,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.transparent,
                    ).copyWith(
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      splashFactory: NoSplash.splashFactory,
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
          );
        },
      );

  Widget _buildMessageBody(BuildContext context, IsmChatMessageModel message) {
    if (message.metaData?.isOnelyEmoji == true) {
      return BouncingEmoji(message: message);
    }

    final linkUrl = message.hasValidWebLink ? message.firstValidWebLink : null;

    return Column(
      crossAxisAlignment:
          message.sentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDefaultTextContent(message),
        if (linkUrl != null)
          LinkPreviewView(
            url: linkUrl,
            message: message,
            embedded: true,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);
    return Material(
      color: Colors.transparent,
      child: IntrinsicWidth(
        child: BlurFilter.widget(
          isBlured: data?.shouldBlured ?? false,
          sigmaX: data?.sigmaX ?? 3,
          sigmaY: data?.sigmaY ?? 3,
          child: Container(
            alignment:
                message.sentByMe ? Alignment.centerRight : Alignment.centerLeft,
            constraints: BoxConstraints(
              minHeight: (IsmChatResponsive.isWeb(context))
                  ? context.height * .04
                  : context.height * .05,
            ),
            padding: IsmChatDimens.edgeInsets4,
            child: _buildMessageBody(context, message),
          ),
        ),
      ),
    );
  }

  bool _isTextOverflowing(double maxWidth, IsmChatMessageModel message) {
    final segments = message.mentionList;
    final textSpan = TextSpan(
      style: message.style,
      children: IsmChatMentionRichText.measurementSpans(
        message.body,
        message.style,
        segments,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      maxLines: 15,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.didExceedMaxLines;
  }
}

class BouncingEmoji extends StatefulWidget {
  const BouncingEmoji({super.key, required this.message});
  final IsmChatMessageModel message;

  @override
  State<BouncingEmoji> createState() => _BouncingEmojiState();
}

class _BouncingEmojiState extends State<BouncingEmoji>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;
  bool isMoerThanOneEmoji = false;

  @override
  void initState() {
    super.initState();
    isMoerThanOneEmoji = widget.message.body.length > 2;
    if (!isMoerThanOneEmoji) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      )..repeat(reverse: true);
      _animation = Tween(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isMoerThanOneEmoji) {
      return Text(
        widget.message.body,
        style: widget.message.style.copyWith(
          fontSize: IsmChatDimens.thirty,
        ),
      );
    }
    return ScaleTransition(
      scale: _animation!,
      child: Text(
        widget.message.body,
        style: widget.message.style.copyWith(
          fontSize: IsmChatDimens.fortyFive,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}