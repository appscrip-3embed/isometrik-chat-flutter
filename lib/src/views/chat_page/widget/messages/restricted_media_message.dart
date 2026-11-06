import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Bubble content for a message whose media is past the owner's storage
/// allowance (`restricted: true`).
///
/// The server blanks the media/thumbnail URLs for such attachments, so the chat
/// must not render a broken image. This shows a neutral "media unavailable"
/// placeholder and preserves any caption/text on the message.
///
/// Rendered centrally by [IsmChatMessageWrapper] for media messages whose
/// attachments report [AttachmentModel.restricted].
class IsmChatRestrictedMediaMessage extends StatelessWidget {
  const IsmChatRestrictedMediaMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final caption = _caption;
    final textColor = message.textColor ?? IsmChatColors.greyColor;
    return Padding(
      padding: IsmChatDimens.edgeInsets4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: IsmChatDimens.edgeInsets8,
            decoration: BoxDecoration(
              color: textColor.applyIsmOpacity(0.08),
              borderRadius: BorderRadius.circular(IsmChatDimens.eight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hide_image_outlined,
                  size: IsmChatDimens.twenty,
                  color: textColor,
                ),
                IsmChatDimens.boxWidth8,
                Flexible(
                  child: Text(
                    'Media unavailable',
                    style: message.style.copyWith(fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (caption.isNotEmpty) ...[
            IsmChatDimens.boxHeight4,
            Text(
              caption,
              style: message.style,
            ),
          ],
        ],
      ),
    );
  }

  /// Caption/text to preserve under the placeholder, if any.
  String get _caption {
    final fromMeta = message.metaData?.caption?.trim() ?? '';
    if (fromMeta.isNotEmpty) return fromMeta;
    final body = message.body.trim();
    // Ignore protocol/sentinel bodies that are not human captions.
    if (body.isEmpty || body.startsWith('AttachmentMessage:')) return '';
    return body;
  }
}
