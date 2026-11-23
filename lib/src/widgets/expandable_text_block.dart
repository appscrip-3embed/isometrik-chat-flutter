import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Collapsible text with **Show more** / **Show less**, matching channel bubbles.
///
/// Pass [message] when the body may contain @mentions so rendering and overflow
/// measurement match [IsmChatTextMessage]. Omit [message] for plain captions.
class IsmChatExpandableTextBlock extends StatefulWidget {
  const IsmChatExpandableTextBlock({
    required this.text,
    required this.textStyle,
    required this.toggleStyle,
    super.key,
    this.collapsedMaxLines = 15,
    this.message,
    this.onExpandedChanged,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String text;
  final TextStyle textStyle;
  final TextStyle toggleStyle;
  final int collapsedMaxLines;
  final IsmChatMessageModel? message;
  final ValueChanged<bool>? onExpandedChanged;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<IsmChatExpandableTextBlock> createState() =>
      _IsmChatExpandableTextBlockState();
}

class _IsmChatExpandableTextBlockState extends State<IsmChatExpandableTextBlock> {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return ValueListenableBuilder<bool>(
          valueListenable: _isExpandedNotifier,
          builder: (context, isExpanded, _) {
            final isOverflowing = _isOverflowing(maxWidth);
            return Column(
              crossAxisAlignment: widget.crossAxisAlignment,
              children: [
                if (widget.message != null)
                  IsmChatMentionRichText(
                    body: widget.text,
                    style: widget.textStyle,
                    message: widget.message,
                    maxLines: isExpanded ? null : widget.collapsedMaxLines,
                    overflow: isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  )
                else
                  Text(
                    widget.text,
                    style: widget.textStyle,
                    textAlign: TextAlign.start,
                    overflow: isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    maxLines: isExpanded ? null : widget.collapsedMaxLines,
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
                        overlayColor:
                            WidgetStateProperty.all(Colors.transparent),
                        splashFactory: NoSplash.splashFactory,
                      ),
                      onPressed: () {
                        final next = !isExpanded;
                        _isExpandedNotifier.value = next;
                        widget.onExpandedChanged?.call(next);
                      },
                      child: Text(
                        isExpanded ? 'Show less' : 'Show more',
                        style: widget.toggleStyle,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isOverflowing(double maxWidth) {
    final text = widget.text.trim();
    if (text.isEmpty) return false;

    final message = widget.message;
    final InlineSpan span;
    if (message != null) {
      final segments = message.mentionListForBody(text);
      span = TextSpan(
        style: widget.textStyle,
        children: IsmChatMentionRichText.measurementSpans(
          text,
          widget.textStyle,
          segments,
        ),
      );
    } else {
      span = TextSpan(text: text, style: widget.textStyle);
    }

    final textPainter = TextPainter(
      text: span,
      maxLines: widget.collapsedMaxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.didExceedMaxLines;
  }
}