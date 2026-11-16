import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Composer at the bottom of the thread panel.
///
/// Text + send, plus Slack's **"Also send to channel"** switch: with it on the
/// reply is posted with `showInConversation: true`, so the same message shows
/// in the channel timeline as well as in the thread
/// ([IsmChatThreadCoordinator.showInConversationForReply]). Hide the switch
/// with [IsmChatThreadProperties.showAlsoSendToChannel].
///
/// The paperclip opens the **same** attachment sheet as the channel composer
/// ([IsmChatPageController.openAttachmentPicker]). While the panel is open the
/// thread's [IsmChatThreadSendTarget] is published to the chat page controller,
/// so the existing media / audio / document / location / contact pipelines post
/// their result as a thread reply — uploads, progress, quota checks and offline
/// retry all behave exactly as they do in the channel.
class IsmChatThreadComposer extends StatelessWidget {
  const IsmChatThreadComposer({required this.controller, super.key});

  final IsmChatThreadController controller;

  IsmChatThreadProperties get _props => IsmChatProperties.threadProperties;

  @override
  Widget build(BuildContext context) {
    final theme = IsmChatThemeResolver.threadFromConfig(context);
    return Obx(
      () => Container(
        color: theme.composerBackgroundColor,
        padding: EdgeInsets.fromLTRB(
          IsmChatDimens.twelve,
          IsmChatDimens.eight,
          IsmChatDimens.twelve,
          IsmChatDimens.eight + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.sendErrorMessage.isNotEmpty) ...[
              Text(controller.sendErrorMessage, style: theme.errorTextStyle),
              IsmChatDimens.boxHeight4,
            ],
            // Nested reply: the next send answers this reply instead of the
            // root (still the same thread).
            if (controller.replyTo != null) _replyToChip(theme),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_props.showAttachments) _attachButton(context, theme),
                Expanded(
                  child: TextField(
                    key: const Key('ism-thread-composer-field'),
                    controller: controller.replyController,
                    focusNode: controller.replyFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.composerTextStyle,
                    onSubmitted: (_) => controller.sendReply(),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: _props.composerHintText ??
                          IsmChatStrings.threadReplyHint,
                      hintStyle: theme.composerHintStyle,
                    ),
                  ),
                ),
                IsmChatDimens.boxWidth8,
                _sendButton(theme),
              ],
            ),
            if (_props.showAlsoSendToChannel) ...[
              IsmChatDimens.boxHeight4,
              InkWell(
                key: const Key('ism-thread-also-send-toggle'),
                onTap: () =>
                    controller.alsoSendToChannel = !controller.alsoSendToChannel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: IsmChatDimens.twenty,
                      height: IsmChatDimens.twenty,
                      child: Checkbox(
                        value: controller.alsoSendToChannel,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) =>
                            controller.alsoSendToChannel = value ?? false,
                      ),
                    ),
                    IsmChatDimens.boxWidth8,
                    Text(
                      _props.alsoSendToChannelLabel ??
                          IsmChatStrings.threadAlsoSendToChannel,
                      style: theme.alsoSendToChannelLabelStyle,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Fire-and-forget send; the controller owns the in-flight / error state.
  void _send() => unawaited(controller.sendReply());

  /// Opens the channel's attachment sheet with this thread as the send target.
  Widget _attachButton(BuildContext context, IsmChatThreadTheme theme) =>
      IsmChatTapHandler(
        key: const Key('ism-thread-attach-button'),
        onTap: () {
          if (!IsmChatUtility.chatPageControllerRegistered) return;
          // Re-publish first: the panel may have been re-opened on another
          // thread since the last sync.
          controller.syncSendTarget();
          unawaited(
            IsmChatUtility.chatPageController.openAttachmentPicker(context),
          );
        },
        child: Padding(
          padding: EdgeInsets.only(right: IsmChatDimens.four),
          child: Icon(
            Icons.attach_file_rounded,
            size: IsmChatDimens.twentyFour,
            color: theme.footerIconColor,
          ),
        ),
      );

  Widget _replyToChip(IsmChatThreadTheme theme) {
    final target = controller.replyTo!;
    final name = target.sentByMe
        ? IsmChatStrings.you
        : (target.senderInfo?.userName ?? '');
    return Container(
      key: const Key('ism-thread-reply-to-chip'),
      margin: EdgeInsets.only(bottom: IsmChatDimens.four),
      padding: EdgeInsets.symmetric(
        horizontal: IsmChatDimens.eight,
        vertical: IsmChatDimens.four,
      ),
      decoration: BoxDecoration(
        color: theme.rootCardBackgroundColor,
        borderRadius: BorderRadius.circular(IsmChatDimens.eight),
        border: Border.all(color: theme.rootCardBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${IsmChatStrings.focusMenuReply} · $name: ${target.body}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.timeStyle,
            ),
          ),
          IsmChatTapHandler(
            key: const Key('ism-thread-reply-to-clear'),
            onTap: controller.clearReplyTo,
            child: Icon(
              Icons.close_rounded,
              size: IsmChatDimens.forteen,
              color: theme.footerIconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendButton(IsmChatThreadTheme theme) => IsmChatTapHandler(
        key: const Key('ism-thread-send-button'),
        onTap: controller.isSending ? null : _send,
        child: Container(
          height: IsmChatDimens.forty,
          width: IsmChatDimens.forty,
          decoration: BoxDecoration(
            color: theme.sendButtonColor,
            shape: BoxShape.circle,
          ),
          child: controller.isSending
              ? Padding(
                  padding: EdgeInsets.all(IsmChatDimens.twelve),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.sendButtonIconColor,
                  ),
                )
              : Icon(
                  Icons.send_rounded,
                  size: IsmChatDimens.twenty,
                  color: theme.sendButtonIconColor,
                ),
        ),
      );
}
