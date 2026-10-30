import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Renders AttachmentMessage:Multiple.
///
/// Image and video (including a mix of the two) use the media grid. Docs use
/// stacked rows. Audio uses the audio bubble. A mix of those is one column,
/// in that order. Per-file type comes from each attachment's media type,
/// not from the message customType.
class IsmChatMultipleAttachmentsMessage extends StatelessWidget {
  const IsmChatMultipleAttachmentsMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    if (attachments.length == 1) {
      return _singleAttachmentMessage(attachments.first);
    }

    final gridItems = message.syntheticMessagesForGrid;
    final audio = attachments
        .where((attachment) =>
            attachment.resolvedMediaType == IsmChatMediaType.audio)
        .toList();
    final docs = attachments
        .where((attachment) => attachment.isDocumentAttachment)
        .toList();
    final hasGrid = gridItems.isNotEmpty;
    final hasAudio = audio.isNotEmpty;
    final hasDocs = docs.isNotEmpty;

    if (hasGrid && !hasAudio && !hasDocs) {
      return IsmChatMediaGridMessage(
        messages: gridItems,
        sentByMe: message.sentByMe,
        gridHostMessage: message,
      );
    }
    if (hasDocs && !hasGrid && !hasAudio) {
      return _DocumentAttachmentList(message: message);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasGrid)
          IsmChatMediaGridMessage(
            messages: gridItems,
            sentByMe: message.sentByMe,
            gridHostMessage: message,
          ),
        for (final attachment in audio) ...[
          if (hasGrid || attachment != audio.first) IsmChatDimens.boxHeight8,
          _singleAttachmentMessage(attachment),
        ],
        if (hasDocs) ...[
          if (hasGrid || hasAudio) IsmChatDimens.boxHeight8,
          _DocumentAttachmentList(
            message: message.copyWith(attachments: docs),
            // The column (or the media grid) owns the caption so it is not repeated.
            showCaption: false,
            showUploadIndicator: false,
          ),
        ],
        if (!hasGrid) _MultipleAttachmentCaption(message: message),
        if (message.isUploading == true)
          Padding(
            padding: IsmChatDimens.edgeInsets4,
            child: IsmChatUtility.circularProgressBar(
              IsmChatColors.blackColor,
              IsmChatColors.whiteColor,
            ),
          ),
      ],
    );
  }

  Widget _singleAttachmentMessage(AttachmentModel attachment) {
    final slice = message.copyWith(
      attachments: [attachment],
      customType: _customTypeForAttachment(attachment),
    );
    switch (slice.customType) {
      case IsmChatCustomMessageType.video:
        return IsmChatVideoMessage(slice);
      case IsmChatCustomMessageType.audio:
        return IsmChatAudioMessage(slice);
      case IsmChatCustomMessageType.file:
        return IsmChatFileMessage(slice);
      case IsmChatCustomMessageType.image:
      default:
        return IsmChatImageMessage(slice);
    }
  }

  IsmChatCustomMessageType _customTypeForAttachment(
      AttachmentModel attachment) {
    switch (attachment.resolvedMediaType) {
      case IsmChatMediaType.video:
        return IsmChatCustomMessageType.video;
      case IsmChatMediaType.audio:
        return IsmChatCustomMessageType.audio;
      case IsmChatMediaType.file:
        return IsmChatCustomMessageType.file;
      default:
        return IsmChatCustomMessageType.image;
    }
  }
}

class _DocumentAttachmentList extends StatelessWidget {
  const _DocumentAttachmentList({
    required this.message,
    this.showCaption = true,
    this.showUploadIndicator = true,
  });

  final IsmChatMessageModel message;
  final bool showCaption;
  final bool showUploadIndicator;

  @override
  Widget build(BuildContext context) {
    final attachments = message.attachments ?? [];
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);

    return BlurFilter.widget(
      isBlured: data?.shouldBlured ?? false,
      sigmaX: data?.sigmaX ?? 3,
      sigmaY: data?.sigmaY ?? 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < attachments.length; i++) ...[
            if (i > 0) IsmChatDimens.boxHeight8,
            _DocumentAttachmentRow(
              attachment: attachments[i],
              message: message,
            ),
          ],
          if (showUploadIndicator && message.isUploading == true)
            Padding(
              padding: IsmChatDimens.edgeInsets4,
              child: IsmChatUtility.circularProgressBar(
                IsmChatColors.blackColor,
                IsmChatColors.whiteColor,
              ),
            ),
          if (showCaption) _MultipleAttachmentCaption(message: message),
        ],
      ),
    );
  }
}

/// Caption for a multi-attachment bubble. See multipleAttachmentCaption.
class _MultipleAttachmentCaption extends StatelessWidget {
  const _MultipleAttachmentCaption({required this.message});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final caption = message.multipleAttachmentCaption;
    if (caption.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
      child: Text(
        caption,
        style: message.style,
        textAlign: TextAlign.start,
      ),
    );
  }
}

class _DocumentAttachmentRow extends StatelessWidget {
  const _DocumentAttachmentRow({
    required this.attachment,
    required this.message,
  });

  final AttachmentModel attachment;
  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final rowBg =
        (message.sentByMe ? IsmChatColors.whiteColor : IsmChatColors.greyColor)
            .applyIsmOpacity(0.2);

    return IsmChatTapHandler(
      onTap: () {
        if (IsmChatUtility.chatPageControllerRegistered) {
          IsmChatUtility.chatPageController.openFileAttachment(attachment);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: IsmChatDimens.edgeInsets4,
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(IsmChatDimens.ten),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                IsmChatAssets.pdfSvg,
                height: IsmChatDimens.thirtyTwo,
                width: IsmChatDimens.thirtyTwo,
              ),
              IsmChatDimens.boxWidth4,
              Flexible(
                child: Text(
                  attachment.name ?? '',
                  style: message.style,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
