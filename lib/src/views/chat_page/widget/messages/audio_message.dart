import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatAudioMessage extends StatelessWidget {
  IsmChatAudioMessage(
    this.message, {
    super.key,
  })  : url = message.attachments?.first.mediaUrl ?? '',
        duration = message.metaData?.duration,
        noise = IsmChatUtility.chatPageController
            .getNoise(message.sentAt, message.sentByMe);

  final IsmChatMessageModel message;
  final String url;
  final Duration? duration;
  final Widget noise;

  /// Same as [IsmChatConfig.isChatDarkMode] — set [IsmChatConfig.chatBrightness] from the app.
  static bool get _isSdkDarkMode => IsmChatConfig.isChatDarkMode;

  /// Voice bar fill from [IsmChatMessageTheme.audioMessageBGColor] (set per app
  /// light/dark palette — e.g. white bars in dark mode).
  static Color voiceBarBackgroundColor({
    required bool sentByMe,
  }) {
    final messageTheme = sentByMe
        ? IsmChatConfig.chatTheme.chatPageTheme?.selfMessageTheme
        : IsmChatConfig.chatTheme.chatPageTheme?.opponentMessageTheme;
    return messageTheme?.audioMessageBGColor ??
        IsmChatConfig.chatTheme.primaryColor ??
        IsmChatColors.primaryColorLight;
  }

  static Color? voiceProgressOverlayColor({
    required bool sentByMe,
  }) =>
      sentByMe
          ? IsmChatProperties
              .chatPageProperties.voiceMessageProgressOverlayColorMe
          : IsmChatProperties
              .chatPageProperties.voiceMessageProgressOverlayColorOpponent;

  /// Play button + duration label contrast on the voice bar background.
  static ({
    Color meFgColor,
    Color mePlayIconColor,
    Color contactFgColor,
    Color contactPlayIconColor,
    Color contactPlayIconBgColor,
  }) voiceChromeColors() {
    if (_isSdkDarkMode) {
      // White voice bar in dark apps: dark waveform + inverted control chip.
      return (
        meFgColor: IsmChatColors.blackColor,
        mePlayIconColor: IsmChatColors.whiteColor,
        contactFgColor: IsmChatColors.blackColor,
        contactPlayIconColor: IsmChatColors.whiteColor,
        contactPlayIconBgColor: IsmChatColors.blackColor,
      );
    }
    final primary = IsmChatConfig.chatTheme.primaryColor ??
        IsmChatColors.primaryColorLight;
    return (
      meFgColor: IsmChatColors.whiteColor,
      mePlayIconColor: primary,
      contactFgColor: Colors.grey,
      contactPlayIconColor: Colors.black26,
      contactPlayIconBgColor: Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);
    final voiceBg =
        voiceBarBackgroundColor(sentByMe: message.sentByMe);
    final chrome = voiceChromeColors();
    return Material(
      color: Colors.transparent,
      child: BlurFilter(
        isBlured: data?.shouldBlured ?? false,
        sigmaX: data?.sigmaX ?? 10,
        sigmaY: data?.sigmaY ?? 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VoiceMessage(
              audioSrc: url,
              noise: noise,
              me: message.sentByMe,
              playIcon:
                  IsmChatProperties.chatPageProperties.voiceMessagePlayIcon,
              pauseIcon:
                  IsmChatProperties.chatPageProperties.voiceMessagePauseIcon,
              loadingIcon:
                  IsmChatProperties.chatPageProperties.voiceMessageLoadingIcon,
              meBgColor: voiceBg,
              opponentBgColor: voiceBg,
              meFgColor: chrome.meFgColor,
              mePlayIconColor: chrome.mePlayIconColor,
              contactFgColor: chrome.contactFgColor,
              contactPlayIconColor: chrome.contactPlayIconColor,
              contactPlayIconBgColor: chrome.contactPlayIconBgColor,
              meProgressOverlayColor:
                  voiceProgressOverlayColor(sentByMe: true),
              opponentProgressOverlayColor:
                  voiceProgressOverlayColor(sentByMe: false),
              duration: duration,
            ),
            if (message.isUploading == true)
              IsmChatUtility.circularProgressBar(
                IsmChatColors.blackColor,
                IsmChatColors.whiteColor,
              ),
          ],
        ),
      ),
    );
  }
}

/// document will be added
class Noises extends StatelessWidget {
  const Noises({
    super.key,
    required this.noises,
  });
  final List<Widget> noises;

  @override
  Widget build(BuildContext context) => FittedBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: noises,
        ),
      );
}
