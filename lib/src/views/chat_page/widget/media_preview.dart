import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:photo_view/photo_view.dart';

/// show the All media Preview view page
class IsmMediaPreview extends StatefulWidget {
  const IsmMediaPreview({
    super.key,
    required this.messageData,
    required this.mediaIndex,
    required this.mediaUserName,
    required this.initiated,
    required this.mediaTime,
  });

  final List<IsmChatMessageModel> messageData;

  final String mediaUserName;

  final bool initiated;

  final int mediaTime;

  final int mediaIndex;

  @override
  State<IsmMediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<IsmMediaPreview> {
  final chatPageController = IsmChatUtility.chatPageController;

  String mediaTime = '';

  bool initiated = false;

  int mediaIndex = -1;

  PageController? pageController;

  /// App bar visibility; tapping an image toggles it (SDK default look only).
  bool _chromeVisible = true;

  @override
  void initState() {
    initiated = widget.initiated;
    mediaIndex = widget.mediaIndex;
    mediaTime = widget.mediaTime.getTime;
    pageController = PageController(
      initialPage: mediaIndex,
    );
    super.initState();
  }

  @override
  void dispose() {
    pageController?.dispose();
    super.dispose();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  Future<void> _onMenuSelected(int value) async {
    final media = widget.messageData[mediaIndex];
    if (value == 1) {
      await chatPageController.shareMedia(media);
    } else if (value == 2) {
      await chatPageController.saveMedia(media);
    } else if (value == 3) {
      await chatPageController.showDialogForMessageDelete(
        media,
        fromMediaPrivew: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    final dialogTheme = IsmChatThemeResolver.dialogFromConfig(context);
    final headerTheme = IsmChatConfig.chatTheme.chatPageHeaderTheme;
    final tokens = IsmChatDesignTokens.of(context);

    // Host media theme → colours exactly as before. SDK default → black
    // viewer with white chrome, whatever the chat header colours are.
    final hostTheme = IsmChatThemeResolver.hasCustomMediaTheme;
    final isDark = IsmChatThemeResolver.brightness(context) == Brightness.dark;
    final background = mediaTheme.previewBackgroundColor;
    final iconColor = hostTheme
        ? headerTheme?.iconColor ?? mediaTheme.appBarIconColor
        : IsmChatDesignTokens.viewerForeground;
    final lightStatusIcons = hostTheme
        ? isDark
        : IsmChatDesignTokens.foregroundFor(background) == Colors.white;
    final menuLabelStyle =
        hostTheme ? mediaTheme.docTitleTextStyle : tokens.body;
    final total = widget.messageData.length;
    final subtitle = total > 1
        ? '$mediaTime  ·  ${IsmChatStrings.mediaCounter(mediaIndex + 1, total)}'
        : mediaTime;

    final appBar = AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness:
            lightStatusIcons ? Brightness.light : Brightness.dark,
        statusBarColor: hostTheme ? background : Colors.transparent,
        statusBarBrightness:
            lightStatusIcons ? Brightness.dark : Brightness.light,
      ),
      backgroundColor:
          hostTheme ? background : background.withValues(alpha: .55),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: iconColor),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            initiated ? IsmChatStrings.you : widget.mediaUserName.toString(),
            style: mediaTheme.previewTitleTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: mediaTheme.previewSubtitleTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      centerTitle: false,
      leading: IconButton(
        onPressed: IsmChatRoute.goBack<void>,
        icon: Icon(
          IsmChatResponsive.isWeb(context)
              ? Icons.close_rounded
              : Icons.arrow_back_rounded,
          color: iconColor,
        ),
      ),
      actions: [
        IconButton(
          tooltip: IsmChatStrings.share,
          onPressed: () => _onMenuSelected(1),
          icon: Icon(Icons.share_outlined, color: iconColor),
        ),
        IconButton(
          tooltip: IsmChatStrings.saveMedia,
          onPressed: () => _onMenuSelected(2),
          icon: Icon(Icons.download_rounded, color: iconColor),
        ),
        PopupMenuButton<int>(
          color: dialogTheme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IsmChatDesignTokens.cardRadius),
          ),
          icon: Icon(Icons.more_vert, color: iconColor),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 3,
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: tokens.danger),
                  IsmChatDimens.boxWidth8,
                  Text(
                    IsmChatStrings.deleteMedia,
                    style: menuLabelStyle.copyWith(color: tokens.danger),
                  ),
                ],
              ),
            ),
          ],
          elevation: 2,
          onSelected: _onMenuSelected,
        ),
        IsmChatDimens.boxWidth4,
      ],
    );

    return Scaffold(
      backgroundColor: background,
      extendBodyBehindAppBar: !hostTheme,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(ignoring: !_chromeVisible, child: appBar),
        ),
      ),
      body: SafeArea(
        // Android gesture/nav bar inset only; iOS and web keep existing layout.
        top: false,
        left: false,
        right: false,
        bottom: !kIsWeb && Platform.isAndroid,
        child: SizedBox(
          height: IsmChatDimens.percentHeight(1),
          width: IsmChatDimens.percentWidth(1),
          child: ColoredBox(
            color: background,
            child: PageView.builder(
              controller: pageController,
              itemBuilder: (BuildContext context, int index) {
                final media = widget.messageData[index];
                var url = media.attachments?.first.mediaUrl ?? '';
                final customType = media.mediaPreviewContentType;
                return customType == IsmChatCustomMessageType.image
                    ? PhotoView(
                        backgroundDecoration: BoxDecoration(
                          color: background,
                        ),
                        imageProvider: url.isValidUrl
                            ? NetworkImage(url) as ImageProvider
                            : kIsWeb
                                ? MemoryImage(url.strigToUnit8List)
                                    as ImageProvider
                                : FileImage(File(url)) as ImageProvider,
                        loadingBuilder: (context, event) =>
                            const IsmChatLoadingDialog(),
                        onTapUp:
                            hostTheme ? null : (_, __, ___) => _toggleChrome(),
                        wantKeepAlive: true,
                      )
                    : SizedBox.expand(
                        child: VideoViewPage(path: url),
                      );
              },
              onPageChanged: (index) {
                final timeStamp = DateTime.fromMillisecondsSinceEpoch(
                    widget.messageData[index].sentAt);
                final time = DateFormat.jm().format(timeStamp);
                final monthDay = DateFormat.MMMd().format(timeStamp);
                setState(
                  () {
                    mediaIndex = index;
                    initiated = widget.messageData[index].sentByMe;
                    mediaTime = '$monthDay, $time';
                    _chromeVisible = true;
                  },
                );
              },
              itemCount: widget.messageData.length,
            ),
          ),
        ),
      ),
    );
  }
}

/// Audio preview dialog (from [IsmMedia] or chat). Uses [IsmChatThemeResolver.mediaFromConfig].
class AudioPreview extends StatelessWidget {
  const AudioPreview({super.key, required this.message});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    final tokens = IsmChatDesignTokens.of(context);
    final hostTheme = IsmChatThemeResolver.hasCustomMediaTheme;

    return Dialog(
      backgroundColor:
          hostTheme ? mediaTheme.scaffoldBackgroundColor : tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: IsmChatDimens.edgeInsets16,
      child: GetBuilder<IsmChatPageController>(
        tag: IsmChat.i.chatPageTag,
        builder: (controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              IsmChatAudioPlayer(message: message),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AudioAction(
                    icon: Icons.share_outlined,
                    label: IsmChatStrings.share,
                    mediaTheme: mediaTheme,
                    hostTheme: hostTheme,
                    onTap: () async {
                      IsmChatRoute.goBack();
                      await controller.shareMedia(message);
                    },
                  ),
                  _AudioAction(
                    icon: Icons.download_rounded,
                    label: IsmChatStrings.save,
                    mediaTheme: mediaTheme,
                    hostTheme: hostTheme,
                    onTap: () async {
                      IsmChatRoute.goBack();
                      await controller.saveMedia(message);
                    },
                  ),
                  _AudioAction(
                    icon: Icons.delete_outline_rounded,
                    label: IsmChatStrings.delete,
                    mediaTheme: mediaTheme,
                    hostTheme: hostTheme,
                    destructive: true,
                    onTap: () async {
                      IsmChatRoute.goBack();
                      await controller.showDialogForMessageDelete(
                        message,
                        fromMediaPrivew: true,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular action with a label under it ([AudioPreview]).
class _AudioAction extends StatelessWidget {
  const _AudioAction({
    required this.icon,
    required this.label,
    required this.mediaTheme,
    required this.hostTheme,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final IsmChatMediaTheme mediaTheme;
  final bool hostTheme;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final Color foreground;
    final Color background;
    final TextStyle labelStyle;
    if (hostTheme) {
      foreground = mediaTheme.appBarIconColor;
      background = mediaTheme.tabBarContainerColor;
      labelStyle = mediaTheme.docTitleTextStyle.copyWith(
        fontWeight: FontWeight.w700,
      );
    } else {
      foreground = destructive ? tokens.danger : tokens.accent;
      background = destructive ? tokens.dangerSoft : tokens.accentSoft;
      labelStyle = tokens.footnote.copyWith(
        color: destructive ? tokens.danger : tokens.textPrimary,
        fontWeight: FontWeight.w500,
      );
    }
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: 22),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(child: Text(label, style: labelStyle)),
            ],
          ),
        ),
      ),
    );
  }
}
