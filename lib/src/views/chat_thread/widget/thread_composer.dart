import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/utilities/blob_io.dart'
    if (dart.library.html) 'package:isometrik_chat_flutter/src/utilities/blob_html.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Composer at the bottom of the thread panel.
///
/// Visual parity with [IsmChatMessageField]: chat text-field theme, mobile
/// emoji prefix, web emoji/attach chips, voice-note chrome, and mic/send.
/// The emoji / GIF panel lives in [IsmChatThreadView] below this widget
/// ([IsmChatComposerEmojiBoard]), matching the channel layout.
class IsmChatThreadComposer extends StatelessWidget {
  const IsmChatThreadComposer({required this.controller, super.key});

  final IsmChatThreadController controller;

  IsmChatThreadProperties get _props => IsmChatProperties.threadProperties;

  @override
  Widget build(BuildContext context) {
    final threadTheme = IsmChatThemeResolver.threadFromConfig(context);
    final textFieldTheme = IsmChatThemeResolver.textFieldFromConfig(context);
    return Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.sendErrorMessage.isNotEmpty) ...[
            Text(controller.sendErrorMessage,
                style: threadTheme.errorTextStyle),
            IsmChatDimens.boxHeight4,
          ],
          if (controller.replyTo != null) _replyToChip(threadTheme),
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (controller.isEnableRecordingAudio) ...[
                Expanded(child: _recordingBar(context, textFieldTheme)),
              ] else ...[
                if (IsmChatResponsive.isWeb(context)) ...[
                  if (_props.isEmojiEnabled) ...[
                    Container(
                      margin: IsmChatDimens.edgeInsetsBottom4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: IsmChatConfig.chatTheme.primaryColor,
                      ),
                      child: _ThreadEmojiButton(
                        controller: controller,
                        color: IsmChatColors.whiteColor,
                      ),
                    ),
                    IsmChatDimens.boxWidth8,
                  ],
                  if (_props.showAttachments &&
                      IsmChatProperties
                          .chatPageProperties.attachments.isNotEmpty) ...[
                    Container(
                      margin: IsmChatDimens.edgeInsetsBottom4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: IsmChatConfig.chatTheme.primaryColor,
                      ),
                      child: _ThreadWebAttachButton(
                        controller: controller,
                        textFieldTheme: textFieldTheme,
                      ),
                    ),
                    IsmChatDimens.boxWidth2,
                  ],
                ],
                Expanded(
                  child: Container(
                    margin: IsmChatDimens.edgeInsets4.copyWith(
                      bottom: controller.replyTo != null
                          ? IsmChatDimens.twelve
                          : IsmChatDimens.eight,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: textFieldTheme.borderColor ??
                            IsmChatConfig.chatTheme.primaryColor!,
                      ),
                      borderRadius: BorderRadius.circular(IsmChatDimens.twenty),
                      color: textFieldTheme.backgroundColor ??
                          IsmChatConfig.chatTheme.backgroundColor,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('ism-thread-composer-field'),
                            controller: controller.replyController,
                            focusNode: controller.replyFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: textFieldTheme.inputTextStyle,
                            cursorColor: textFieldTheme.cursorColor ??
                                IsmChatConfig.chatTheme.primaryColor,
                            onSubmitted: (_) => _sendText(),
                            onTapOutside: (_) => IsmChatUtility.hideKeyboard(),
                            onChanged: controller.handleComposerTextChanged,
                            decoration: InputDecoration(
                              hintText: _props.composerHintText ??
                                  IsmChatStrings.threadReplyHint,
                              hintStyle: textFieldTheme.hintTextStyle ??
                                  IsmChatStyles.w400Black12,
                              fillColor: textFieldTheme.backgroundColor ??
                                  IsmChatConfig.chatTheme.backgroundColor,
                              contentPadding: IsmChatResponsive.isWeb(context)
                                  ? IsmChatDimens.edgeInsets12
                                  : IsmChatDimens.edgeInsets8,
                              prefixIcon: IsmChatResponsive.isWeb(context)
                                  ? null
                                  : (_props.isEmojiEnabled
                                      ? _ThreadEmojiButton(
                                          controller: controller,
                                          color: textFieldTheme.emojiColor,
                                        )
                                      : null),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(IsmChatDimens.twenty),
                                borderSide: const BorderSide(
                                  color: Colors.transparent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(IsmChatDimens.twenty),
                                borderSide: const BorderSide(
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_props.showAttachments &&
                            !IsmChatResponsive.isWeb(context))
                          _attachButton(context, textFieldTheme),
                      ],
                    ),
                  ),
                ),
              ],
              _ThreadMicOrSendButton(
                controller: controller,
                audioEnabled: _props.isAudioMessageEnabled,
              ),
              IsmChatDimens.boxWidth4,
            ],
          ),
          if (_props.showAlsoSendToChannel) ...[
            IsmChatDimens.boxHeight4,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: InkWell(
                key: const Key('ism-thread-also-send-toggle'),
                onTap: () => controller.alsoSendToChannel =
                    !controller.alsoSendToChannel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: IsmChatDimens.twenty,
                      height: IsmChatDimens.twenty,
                      child: Checkbox(
                        value: controller.alsoSendToChannel,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) =>
                            controller.alsoSendToChannel = value ?? false,
                      ),
                    ),
                    IsmChatDimens.boxWidth8,
                    Text(
                      _props.alsoSendToChannelLabel ??
                          IsmChatStrings.threadAlsoSendToChannel,
                      style: threadTheme.alsoSendToChannelLabelStyle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sendText() => unawaited(controller.sendReply());

  /// Same layout as [IsmChatMessageField] voice capture (no bordered box).
  Widget _recordingBar(
    BuildContext context,
    IsmChatTextFiledTheme textFieldTheme,
  ) =>
      Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: IsmChatDimens.edgeInsets20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IsmChatTapHandler(
              onTap: () => unawaited(controller.recordDelete()),
              child: Icon(
                Icons.delete_outlined,
                size: IsmChatDimens.thirty,
                color: IsmChatConfig.chatTheme.primaryColor ??
                    IsmChatColors.blackColor,
              ),
            ),
            IsmChatDimens.boxWidth12,
            IsmChatTapHandler(
              onTap: () => unawaited(controller.recordPlayPauseVoice()),
              child: Icon(
                controller.isRecordPlay
                    ? Icons.pause_circle_outline_outlined
                    : Icons.play_circle_outline_outlined,
                size: IsmChatDimens.thirty,
                color: IsmChatConfig.chatTheme.primaryColor ??
                    IsmChatColors.blackColor,
              ),
            ),
            IsmChatDimens.boxWidth12,
            const Icon(
              Icons.radio_button_checked_outlined,
              color: Colors.red,
            ),
            IsmChatDimens.boxWidth32,
            Text(
              controller.recordingSeconds.getTimerRecord,
              style: textFieldTheme.recordingTimerTextStyle,
            ),
          ],
        ),
      );

  Widget _attachButton(
    BuildContext context,
    IsmChatTextFiledTheme textFieldTheme,
  ) =>
      IconButton(
        key: const Key('ism-thread-attach-button'),
        onPressed: () {
          if (!IsmChatUtility.chatPageControllerRegistered) return;
          controller.syncSendTarget();
          unawaited(
            IsmChatUtility.chatPageController.openAttachmentPicker(context),
          );
        },
        color: textFieldTheme.attchmentColor ??
            IsmChatConfig.chatTheme.primaryColor,
        icon: const Icon(Icons.attach_file_rounded),
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
}

class _ThreadEmojiButton extends StatelessWidget {
  const _ThreadEmojiButton({
    required this.controller,
    this.color,
  });

  final IsmChatThreadController controller;
  final Color? color;

  @override
  Widget build(BuildContext context) => Obx(
        () => IconButton(
          key: const Key('ism-thread-emoji-button'),
          color: color ?? IsmChatConfig.chatTheme.primaryColor,
          icon: AnimatedSwitcher(
            duration: IsmChatConfig.animationDuration,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: controller.showEmojiBoard
                ? Icon(Icons.keyboard_rounded, key: UniqueKey())
                : IsmChatProperties.chatPageProperties.emojiIcon ??
                    Icon(Icons.emoji_emotions_rounded, key: UniqueKey()),
          ),
          onPressed: () {
            final conv = controller.conversation;
            if (!(conv?.isChattingAllowed == true)) {
              if (IsmChatUtility.chatPageControllerRegistered) {
                IsmChatUtility.chatPageController.showDialogCheckBlockUnBlock();
              }
              return;
            }
            controller.toggleEmojiBoard();
          },
        ),
      );
}

class _ThreadWebAttachButton extends StatelessWidget {
  const _ThreadWebAttachButton({
    required this.controller,
    required this.textFieldTheme,
  });

  final IsmChatThreadController controller;
  final IsmChatTextFiledTheme textFieldTheme;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: () {
          if (!IsmChatUtility.chatPageControllerRegistered) return;
          controller.syncSendTarget();
          unawaited(
            IsmChatUtility.chatPageController.openAttachmentPicker(context),
          );
        },
        color: IsmChatColors.whiteColor,
        icon: const Icon(Icons.attach_file_rounded),
      );
}

class _ThreadMicOrSendButton extends StatelessWidget {
  const _ThreadMicOrSendButton({
    required this.controller,
    required this.audioEnabled,
  });

  final IsmChatThreadController controller;
  final bool audioEnabled;

  @override
  Widget build(BuildContext context) {
    final sendTheme = IsmChatConfig.chatTheme.chatPageTheme?.sendButtonTheme;
    final bg =
        sendTheme?.backgroundColor ?? IsmChatConfig.chatTheme.primaryColor;
    final iconColor = sendTheme?.iconColor ?? IsmChatColors.whiteColor;

    return Obx(
      () => Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: IconButton(
          key: const Key('ism-thread-send-button'),
          onPressed: controller.isSending
              ? null
              : () => unawaited(_onPressed(context)),
          icon: controller.isSending
              ? SizedBox(
                  height: IsmChatDimens.twenty,
                  width: IsmChatDimens.twenty,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              : AnimatedSwitcher(
                  duration: IsmChatConfig.animationDuration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: controller.showComposerSendButton
                      ? Icon(
                          Icons.send_rounded,
                          key: const ValueKey('send'),
                          color: iconColor,
                        )
                      : audioEnabled
                          ? Icon(
                              Icons.mic_rounded,
                              key: const ValueKey('mic'),
                              color: iconColor,
                            )
                          : Icon(
                              Icons.send_rounded,
                              key: const ValueKey('send-fallback'),
                              color: iconColor,
                            ),
                ),
        ),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    if (!IsmChatUtility.chatPageControllerRegistered) {
      if (controller.replyController.text.trim().isNotEmpty) {
        await controller.sendReply();
      }
      return;
    }
    final page = IsmChatUtility.chatPageController;
    final conv = controller.conversation;
    if (!(conv?.isChattingAllowed == true) || conv?.isBlockedByMe == true) {
      page.showDialogCheckBlockUnBlock();
      return;
    }

    if (controller.showComposerSendButton) {
      if (controller.isEnableRecordingAudio) {
        await _finishRecordingAndSend(page);
      } else if (controller.replyController.text.trim().isNotEmpty) {
        await controller.sendReply();
      }
      return;
    }

    if (!audioEnabled) return;

    if (controller.showEmojiBoard) {
      controller.toggleEmojiBoard(false, false);
    }

    final mediaContext =
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
    if (!(await IsmChatProperties.chatPageProperties.isSendMediaAllowed
            ?.call(mediaContext, conv) ??
        true)) {
      return;
    }

    var allowPermission = false;
    if (kIsWeb) {
      final state = await IsmChatBlob.checkPermission('microphone');
      if (state == 'prompt') {
        unawaited(
          Get.dialog(
            IsmChatAlertDialogBox(
              title: IsmChatStrings.micePermission,
              cancelLabel: IsmChatStrings.okay,
            ),
          ),
        );
        await page.recordVoice.hasPermission();
        return;
      } else if (state == 'denied') {
        await Get.dialog(
          IsmChatAlertDialogBox(
            title: IsmChatStrings.micePermissionBlock,
            cancelLabel: IsmChatStrings.okay,
          ),
        );
        return;
      } else {
        allowPermission = true;
      }
    } else if (await page.recordVoice.hasPermission()) {
      allowPermission = true;
    }

    if (!allowPermission) return;

    controller.syncSendTarget();
    controller.beginRecordingUi();

    String? audioPath;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      audioPath = p.join(
        dir.path,
        'audio_thread_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
    } else {
      audioPath = 'audio_thread_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    if (!kIsWeb) {
      const encoder = AudioEncoder.aacLc;
      if (!await page.isEncoderSupported(encoder)) {
        controller.cancelRecordingUi();
        return;
      }
      const config = RecordConfig(encoder: encoder, numChannels: 1);
      await page.recordVoice.start(config, path: audioPath);
    } else {
      await page.recordVoice.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: audioPath,
      );
    }
  }

  Future<void> _finishRecordingAndSend(IsmChatPageController page) async {
    final secondsCaptured = controller.recordingSeconds;
    final audioPath = await page.recordVoice.stop() ?? '';
    controller.cancelRecordingUi();
    if (audioPath.isEmpty) return;

    final sendContext =
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
    final audioAllowed = await IsmChatProperties
        .chatPageProperties.messageAllowedConfig
        .shouldAllowOutboundSend(
      context: sendContext,
      conversation: controller.conversation,
      customType: IsmChatCustomMessageType.audio,
      messageText: '',
    );
    if (!audioAllowed) return;

    WebMediaModel? webMediaModel;
    final duration = Duration(seconds: secondsCaptured);

    if (kIsWeb) {
      final bytes = await IsmChatUtility.fetchBytesFromBlobUrl(audioPath);
      webMediaModel = WebMediaModel(
        platformFile: IsmchPlatformFile(
          name: '${DateTime.now().millisecondsSinceEpoch}.mp3',
          size: bytes.length,
          bytes: bytes,
          path: audioPath,
          extension: 'mp3',
        ),
        isVideo: false,
        dataSize: await IsmChatUtility.bytesToSize(bytes),
        duration: duration,
      );
    }

    final audioFileBytes = kIsWeb
        ? (webMediaModel?.platformFile.size ?? 0)
        : await File(audioPath).length();
    final sizeAllowed =
        await IsmChatStorageQuotaGuard.ensureAttachmentSizeAllowed(
      fileBytes: audioFileBytes,
    );
    if (!sizeAllowed) return;

    controller.syncSendTarget();
    final conv = controller.conversation;
    page.sendAudio(
      webMediaModel: webMediaModel,
      path: audioPath,
      conversationId: conv?.conversationId ?? controller.conversationId,
      userId: conv?.opponentDetails?.userId ?? '',
      duration: Duration(seconds: secondsCaptured),
    );
  }
}
