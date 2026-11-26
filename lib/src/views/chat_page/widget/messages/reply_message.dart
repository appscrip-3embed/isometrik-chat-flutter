import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/views/chat_page/widget/messages/message_inner_time_metrics.dart';

class IsmChatReplyMessage extends StatelessWidget {
  const IsmChatReplyMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);
    return BlurFilter.widget(
      isBlured: data?.shouldBlured ?? false,
      sigmaX: data?.sigmaX ?? 3,
      sigmaY: data?.sigmaY ?? 3,
      // No [Expanded]/[Flexible] in the quote (breaks intrinsic width). Stretch
      // plus [fillReplyBubbleWidth] aligns the quote strip with the reply body.
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReplyMessage(message),
            IsmChatDimens.boxHeight5,
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (IsmChatResponsive.isWeb(context))
                    ? context.height * .04
                    : context.height * .05,
              ),
              child: IsmChatMessageWrapperWithMetaData(
                message,
                fillReplyBubbleWidth: true,
              ),
            ),
            // Width floor so [MessageBubble]'s inner time/status row is not clipped.
            SizedBox(
              width: ismChatInnerTimeStatusMinWidth(context, message),
              height: 0,
            ),
          ],
        ),
      ),
    );
  }
}

double _replyQuoteMaxTextWidth(
  BuildContext context,
  IsmChatMessageModel message, {
  required bool hasThumb,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final maxByScreen =
      IsmChatResponsive.isWeb(context) ? screenWidth * .25 : screenWidth * .6;
  final themeConstraints = IsmChatConfig
      .chatTheme.chatPageTheme?.messageConstraints?.messageConstraints;
  final bubbleMax =
      themeConstraints?.maxWidth != null && themeConstraints!.maxWidth.isFinite
          ? themeConstraints.maxWidth
          : maxByScreen;
  final thumbWidth = hasThumb ? IsmChatDimens.fifty + IsmChatDimens.five : 0.0;
  final overhead = IsmChatDimens.four +
      (IsmChatDimens.four * 2) +
      IsmChatDimens.twenty +
      IsmChatDimens.four;
  return (bubbleMax - overhead - thumbWidth).clamp(48.0, bubbleMax);
}

class _ReplyMessage extends StatelessWidget {
  const _ReplyMessage(this.message);

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) => GetBuilder<IsmChatPageController>(
        tag: IsmChat.i.chatPageTag,
        builder: (controller) {
          var replyingMyMessage = message.sentByMe ==
              (message.metaData?.replyMessage?.parentMessageInitiator ?? false);
          return Material(
            color: Colors.transparent,
            child: IsmChatTapHandler(
              onTap: () {
                controller.scrollToMessage(message.parentMessageId ?? '');
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(IsmChatDimens.eight),
                child: Builder(
                  builder: (context) {
                    final thumb = ReplayParentMessage(
                      replayData: message.metaData?.replyMessage,
                    );
                    final parentType = message
                        .metaData?.replyMessage?.parentMessageMessageType;
                    final hasThumb = [
                      IsmChatCustomMessageType.image,
                      IsmChatCustomMessageType.video,
                      IsmChatCustomMessageType.location,
                    ].contains(parentType);
                    final maxTextWidth = _replyQuoteMaxTextWidth(
                      context,
                      message,
                      hasThumb: hasThumb,
                    );

                    return Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        minHeight: (IsmChatResponsive.isWeb(context))
                            ? context.height * .04
                            : context.height * .05,
                      ),
                      decoration: BoxDecoration(
                        color: (message.sentByMe
                                ? IsmChatColors.whiteColor
                                : IsmChatColors.greyColor)
                            .applyIsmOpacity(0.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: IsmChatDimens.four,
                            height: IsmChatDimens.fifty,
                            child: ColoredBox(
                              color: IsmChatConfig.chatTheme.chatPageTheme
                                          ?.replyMessageTheme !=
                                      null
                                  ? replyingMyMessage
                                      ? IsmChatConfig
                                              .chatTheme
                                              .chatPageTheme
                                              ?.replyMessageTheme
                                              ?.selfMessage ??
                                          IsmChatColors.yellowColor
                                      : IsmChatConfig
                                              .chatTheme
                                              .chatPageTheme
                                              ?.replyMessageTheme
                                              ?.opponentMessage ??
                                          IsmChatColors.blueColor
                                  : replyingMyMessage
                                      ? IsmChatColors.yellowColor
                                      : IsmChatColors.blueColor,
                            ),
                          ),
                          Padding(
                            padding: IsmChatDimens.edgeInsets4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Builder(builder: (context) {
                                  var name = '';

                                  if (controller.conversation?.isGroup ??
                                      false) {
                                    if (replyingMyMessage) {
                                      name = IsmChatStrings.you;
                                    } else {
                                      name = ((controller.conversation
                                                              ?.members ??
                                                          [])
                                                      .firstWhereOrNull(
                                                        (e) =>
                                                            message
                                                                .metaData
                                                                ?.replyMessage
                                                                ?.parentMessageUserId ==
                                                            e.userId,
                                                      )
                                                      ?.userName ??
                                                  message.metaData?.replyMessage
                                                      ?.parentMessageUserName ??
                                                  '')
                                              .capitalizeFirst ??
                                          '';
                                    }
                                  } else {
                                    name = replyingMyMessage
                                        ? IsmChatStrings.you
                                        : controller.conversation?.replyName
                                                .capitalizeFirst ??
                                            '';
                                  }

                                  return Text(
                                    name,
                                    style: IsmChatStyles.w500Black14.copyWith(
                                      fontSize: IsmChatConfig
                                                  .chatTheme
                                                  .chatPageTheme
                                                  ?.replyMessageTheme !=
                                              null
                                          ? IsmChatConfig
                                              .chatTheme
                                              .chatPageTheme
                                              ?.replyMessageTheme
                                              ?.fontSizeMessage
                                          : IsmChatDimens.forteen,
                                      color: IsmChatConfig
                                                  .chatTheme
                                                  .chatPageTheme
                                                  ?.replyMessageTheme !=
                                              null
                                          ? replyingMyMessage
                                              ? IsmChatConfig
                                                  .chatTheme
                                                  .chatPageTheme
                                                  ?.replyMessageTheme
                                                  ?.selfMessage
                                              : IsmChatConfig
                                                  .chatTheme
                                                  .chatPageTheme
                                                  ?.replyMessageTheme
                                                  ?.opponentMessage
                                          : replyingMyMessage
                                              ? IsmChatColors.yellowColor
                                              : IsmChatColors.blueColor,
                                    ),
                                  );
                                }),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _replayParentIcon(message),
                                    IsmChatDimens.boxWidth4,
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: maxTextWidth,
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          final parentBody =
                                              IsmChatUtility.decryptMessage(
                                            message.metaData?.replyMessage
                                                    ?.parentMessageBody ??
                                                '',
                                            message.conversationId ?? '',
                                          );
                                          final parentId =
                                              (message.parentMessageId ?? '')
                                                  .trim();
                                          final parentMessage = parentId.isEmpty
                                              ? null
                                              : controller.messages
                                                  .firstWhereOrNull(
                                                  (m) =>
                                                      (m.messageId ?? '')
                                                          .trim() ==
                                                      parentId,
                                                );
                                          return IsmChatMentionRichText(
                                            body: parentBody,
                                            style: message.style,
                                            message: parentMessage,
                                            mentionedUsers:
                                                parentMessage?.mentionedUsers,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            enableMentionTap:
                                                parentMessage != null,
                                          );
                                        },
                                      ),
                                    ),
                                    if (message.metaData?.replyMessage
                                            ?.parentMessageMessageType ==
                                        IsmChatCustomMessageType.audio)
                                      Text(
                                        ' (${Duration(seconds: message.metaData?.replyMessage?.parentMessageAttachmentDuration ?? 0).formatDuration})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: message.style,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (hasThumb) thumb,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );

  Widget _replayParentIcon(IsmChatMessageModel? message) {
    final messageType =
        message?.metaData?.replyMessage?.parentMessageMessageType;
    final icon = switch (messageType) {
      IsmChatCustomMessageType.image => Icons.image_outlined,
      IsmChatCustomMessageType.video => Icons.play_circle_outlined,
      IsmChatCustomMessageType.audio => Icons.mic_outlined,
      IsmChatCustomMessageType.location => Icons.location_on_outlined,
      IsmChatCustomMessageType.file => Icons.description_outlined,
      IsmChatCustomMessageType.multipleAttachments =>
        Icons.description_outlined,
      IsmChatCustomMessageType.contact => Icons.contact_page_outlined,
      _ => null,
    };
    if (icon == null) return IsmChatDimens.box0;
    return Icon(
      icon,
      color: message?.style.color ?? IsmChatColors.greyColor,
      size: IsmChatDimens.twenty,
    );
  }
}

class ReplayParentMessage extends StatelessWidget {
  ReplayParentMessage(
      {super.key, this.replayData, double? height, double? width})
      : _height = height ?? IsmChatDimens.fifty,
        _width = width ?? IsmChatDimens.fifty;

  final IsmChatReplyMessageModel? replayData;
  final double _height;
  final double _width;
  @override
  Widget build(BuildContext context) {
    try {
      if ([IsmChatCustomMessageType.image, IsmChatCustomMessageType.video]
          .contains(replayData?.parentMessageMessageType)) {
        Uint8List? bytes;
        if (IsmChatCustomMessageType.video ==
                replayData?.parentMessageMessageType &&
            (replayData?.parentMessageAttachmentUrl?.isValidUrl == false)) {
          bytes =
              (replayData?.parentMessageAttachmentUrl ?? '').strigToUnit8List;
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: _height,
              width: _width,
              child: IsmChatImage(
                replayData?.parentMessageAttachmentUrl ?? '',
                isNetworkImage:
                    replayData?.parentMessageAttachmentUrl?.isValidUrl ?? false,
                isBytes: bytes != null,
              ),
            ),
            if (IsmChatCustomMessageType.video ==
                replayData?.parentMessageMessageType) ...[
              const Icon(
                Icons.play_circle_filled_outlined,
                color: IsmChatColors.whiteColor,
              ),
            ]
          ],
        );
      }
      if (IsmChatCustomMessageType.location ==
          replayData?.parentMessageMessageType) {
        var url = replayData?.parentMessageAttachmentUrl ?? '';
        var position = url.position;
        return SizedBox(
          height: _height,
          width: _width,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: position,
              zoom: 10,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('1'),
                position: position,
                infoWindow: const InfoWindow(title: 'Shared Location'),
              )
            },
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            rotateGesturesEnabled: false,
            scrollGesturesEnabled: false,
            buildingsEnabled: true,
            mapToolbarEnabled: false,
            tiltGesturesEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: false,
            trafficEnabled: false,
          ),
        );
      }
    } catch (_) {
      return IsmChatDimens.box0;
    }
    return IsmChatDimens.box0;
  }
}

/// Strip shown above the composer while editing an existing text message.
class IsmChatComposerEditBar extends StatelessWidget {
  const IsmChatComposerEditBar({
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Padding(
        padding: IsmChatDimens.edgeInsets8,
        child: Row(
          children: [
            Icon(
              Icons.edit_outlined,
              size: IsmChatDimens.sixteen,
              color: IsmChatConfig.chatTheme.primaryColor,
            ),
            IsmChatDimens.boxWidth8,
            Expanded(
              child: Text(
                IsmChatStrings.editingMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IsmChatStyles.w600Black12.copyWith(
                  color: IsmChatConfig.chatTheme.primaryColor,
                ),
              ),
            ),
            IsmChatTapHandler(
              onTap: onDismiss,
              child: Icon(Icons.close, size: IsmChatDimens.twenty),
            ),
          ],
        ),
      );
}

/// Channel-style reply strip above a composer (sender, body, media thumb).
///
/// Reuse in [IsmChatMessageField] and [IsmChatThreadComposer] so thread
/// nested-reply targets show the same preview as inline channel replies.
class IsmChatComposerReplyBar extends StatelessWidget {
  const IsmChatComposerReplyBar({
    required this.parentMessage,
    required this.messageBody,
    required this.onDismiss,
    this.conversation,
    super.key,
  });

  final IsmChatMessageModel parentMessage;
  final String messageBody;
  final VoidCallback onDismiss;
  final IsmChatConversationModel? conversation;

  /// Display label for the quoted parent (GIF, Photo, … or body text).
  ///
  /// Delegates to [IsmChatPageController.getMessageBody] when the chat page is
  /// mounted; otherwise falls back to [IsmChatThreadCoordinator] labels so the
  /// thread panel still works in isolation.
  static String displayBodyFor(IsmChatMessageModel? message) {
    if (message == null) return '';
    if (IsmChatUtility.chatPageControllerRegistered) {
      return IsmChatUtility.chatPageController.getMessageBody(message);
    }
    final label = IsmChatThreadCoordinator.threadContentTypeLabel(message);
    if (label != null) return label;
    return message.body.trim();
  }

  /// Thumbnail / type payload for [ReplayParentMessage].
  ///
  /// Uses [IsmChatMessageModel.threadPanelBubbleType] so image and video
  /// replies in the thread panel resolve attachments like the channel.
  static IsmChatReplyMessageModel replayDataFor(
    IsmChatMessageModel? replayMessage,
  ) {
    final customType =
        replayMessage?.threadPanelBubbleType ?? replayMessage?.customType;
    final attachment = replayMessage?.attachments?.isNotEmpty == true
        ? replayMessage?.attachments?.first
        : null;
    final contact = replayMessage?.metaData?.contacts?.isNotEmpty == true
        ? replayMessage?.metaData?.contacts?.first
        : null;
    final attachmentUrl = switch (customType) {
      IsmChatCustomMessageType.audio ||
      IsmChatCustomMessageType.file ||
      IsmChatCustomMessageType.multipleAttachments =>
        attachment?.name,
      IsmChatCustomMessageType.contact => contact?.contactIdentifier,
      IsmChatCustomMessageType.location ||
      IsmChatCustomMessageType.image =>
        attachment?.mediaUrl,
      IsmChatCustomMessageType.video => attachment?.thumbnailUrl,
      _ => replayMessage?.body,
    };
    return IsmChatReplyMessageModel(
      parentMessageAttachmentUrl: attachmentUrl,
      parentMessageAttachmentDuration:
          replayMessage?.metaData?.duration?.inSeconds,
      parentMessageMessageType: customType,
      parentMessageInitiator: replayMessage?.sentByMe,
      parentMessageBody: replayMessage?.body,
      parentMessageUserId: replayMessage?.senderInfo?.userId,
    );
  }

  String _senderName(BuildContext context) {
    if (parentMessage.sentByMe) return IsmChatStrings.you;
    if (conversation?.isGroup ?? false) {
      final fromSender = parentMessage.senderInfo?.userName ?? '';
      if (fromSender.isNotEmpty) return fromSender.capitalizeFirst ?? '';
      final memberName = conversation?.members
          ?.firstWhereOrNull(
            (e) => e.userId == parentMessage.senderInfo?.userId,
          )
          ?.userName;
      if (memberName?.isNotEmpty == true) {
        return memberName!.capitalizeFirst ?? '';
      }
    }
    return IsmChatProperties.chatPageProperties.header?.title?.call(
          context,
          conversation,
          conversation?.chatName ?? '',
        ) ??
        conversation?.chatName.capitalizeFirst ??
        (parentMessage.senderInfo?.userName ?? '');
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: IsmChatDimens.edgeInsets4.copyWith(
          bottom: IsmChatDimens.zero,
        ),
        width: IsmChatDimens.percentWidth(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(IsmChatDimens.sixteen),
          color: IsmChatConfig.chatTheme.primaryColor?.applyIsmOpacity(.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: IsmChatDimens.edgeInsets8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_senderName(context)),
                    IsmChatMentionRichText(
                      body: messageBody,
                      style: IsmChatConfig
                              .chatTheme.chatPageTheme?.textFiledTheme
                              ?.inputTextStyle ??
                          parentMessage.style ??
                          const TextStyle(),
                      message: parentMessage,
                      mentionedUsers: parentMessage.mentionedUsers,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(IsmChatDimens.eight),
                  child: ReplayParentMessage(
                    replayData: replayDataFor(parentMessage),
                    height: IsmChatDimens.fiftyFive,
                    width: IsmChatDimens.hundred,
                  ),
                ),
                ReplyPreviewDismissButton(onTap: onDismiss),
              ],
            ),
          ],
        ),
      );
}

/// Dismiss control for the composer reply bar when [ReplayParentMessagePreview]
/// shows media; the white circle keeps the close icon visible on dark thumbnails.
class ReplyPreviewDismissButton extends StatelessWidget {
  const ReplyPreviewDismissButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IsmChatTapHandler(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          width: IsmChatDimens.twentyFour,
          height: IsmChatDimens.twentyFour,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            color: IsmChatColors.whiteColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close_rounded,
            size: IsmChatDimens.sixteen,
            color: IsmChatColors.blackColor,
          ),
        ),
      );
}

class ReplayParentMessagePreview extends StatelessWidget {
  const ReplayParentMessagePreview({
    super.key,
    required this.controller,
  });

  final IsmChatPageController controller;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(IsmChatDimens.eight),
        child: ReplayParentMessage(
          replayData:
              IsmChatComposerReplyBar.replayDataFor(controller.replayMessage),
          height: IsmChatDimens.fiftyFive,
          width: IsmChatDimens.hundred,
        ),
      );
}
