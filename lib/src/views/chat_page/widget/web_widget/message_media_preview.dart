import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/utilities/blob_io.dart'
    if (dart.library.html) 'package:isometrik_chat_flutter/src/utilities/blob_html.dart';
import 'package:photo_view/photo_view.dart';

class IsmWebMessageMediaPreview extends StatefulWidget {
  const IsmWebMessageMediaPreview({super.key, required this.previewData});

  final Map<String, dynamic> previewData;

  @override
  State<IsmWebMessageMediaPreview> createState() =>
      _WebMessageMediaPreviewState();
}

class _WebMessageMediaPreviewState extends State<IsmWebMessageMediaPreview> {
  PageController? pageController;
  final chatPageController = IsmChatUtility.chatPageController;

  String mediaTime = '';
  String mediaSize = '';
  String mediaUserName = '';
  bool initiated = false;
  List<IsmChatMessageModel> messageData = [];

  @override
  void initState() {
    super.initState();
    startInit();
  }

  void startInit() {
    messageData = widget.previewData['messageData'] ?? [];
    mediaUserName = widget.previewData['mediaUserName'] ?? '';
    initiated = widget.previewData['initiated'] ?? false;
    chatPageController.assetsIndex = widget.previewData['mediaIndex'] ?? 0;
    final timeStamp = DateTime.fromMillisecondsSinceEpoch(
      widget.previewData['mediaTime'] ?? 0,
    );
    final time = DateFormat.jm().format(timeStamp);
    final monthDay = DateFormat.MMMd().format(timeStamp);
    mediaTime = '$monthDay, $time';
    mediaSize = IsmChatUtility.formatBytes(
      int.parse(
          '${messageData[chatPageController.assetsIndex].attachments?.first.size}'),
    );
    pageController =
        PageController(initialPage: chatPageController.assetsIndex);
    updateState();
  }

  void updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveCurrent() async {
    final attachment =
        messageData[chatPageController.assetsIndex].attachments?.first;
    if (attachment?.mediaUrl?.isValidUrl ?? false) {
      IsmChatBlob.fileDownloadWithUrl(attachment?.mediaUrl ?? '');
    } else {
      IsmChatBlob.fileDownloadWithBytes(
          attachment?.mediaUrl?.strigToUnit8List ?? [],
          downloadName: '${attachment!.name}.${attachment.extension}');
      IsmChatUtility.showToast('Save your media');
    }
  }

  Future<void> _goTo(int index) async {
    chatPageController.assetsIndex = index;
    initiated = messageData[index].sentByMe;
    mediaTime = messageData[index].sentAt.deliverTime;
    updateState();
    await pageController?.animateToPage(
      index,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    final headerTheme = IsmChatConfig.chatTheme.chatPageHeaderTheme;
    final tokens = IsmChatDesignTokens.of(context);
    // Match chat page light/dark fill (see [IsmChatMediaTheme.chatScreenBackground]).
    final hostTheme = IsmChatThemeResolver.hasCustomMediaTheme;
    final background = mediaTheme.previewBackgroundColor;
    final foreground = hostTheme
        ? headerTheme?.iconColor ?? mediaTheme.appBarIconColor
        : IsmChatDesignTokens.foregroundFor(background);
    final index = chatPageController.assetsIndex;
    final total = messageData.length;
    final subtitle = total > 1
        ? '$mediaTime  ·  ${IsmChatStrings.mediaCounter(index + 1, total)}'
        : mediaTime;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SizedBox.shrink(),
        leadingWidth: IsmChatDimens.zero,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              initiated ? IsmChatStrings.you : mediaUserName,
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
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: IsmChatStrings.saveMedia,
            onPressed: _saveCurrent,
            icon: Icon(Icons.download_rounded, color: foreground),
          ),
          IconButton(
            tooltip: IsmChatStrings.deleteMedia,
            onPressed: () async {
              await chatPageController.showDialogForMessageDelete(
                  messageData[chatPageController.assetsIndex],
                  fromMediaPrivew: true);
            },
            icon: Icon(Icons.delete_outline_rounded, color: foreground),
          ),
          IconButton(
            alignment: Alignment.center,
            icon: Icon(Icons.close_rounded, color: foreground),
            onPressed: IsmChatRoute.goBack,
          ),
          IsmChatDimens.boxWidth16,
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: messageData.length,
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    final media = messageData[index];
                    final attachment = media.attachments?.firstOrNull;
                    final url = attachment?.mediaUrl ?? '';
                    final customType = media.mediaPreviewContentType;
                    if (customType == IsmChatCustomMessageType.image) {
                      // Match chat bubbles: CachedNetworkImageProvider (not
                      // NetworkImage) so the viewer reuses the bubble cache.
                      final provider =
                          IsmChatMediaImageProvider.fromAttachment(attachment);
                      if (provider == null) {
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: foreground.withValues(alpha: .5),
                            size: 48,
                          ),
                        );
                      }
                      return PhotoView(
                        backgroundDecoration:
                            BoxDecoration(color: background),
                        imageProvider: provider,
                        loadingBuilder: (context, event) =>
                            const IsmChatLoadingDialog(),
                        wantKeepAlive: true,
                      );
                    }
                    return VideoViewPage(path: url);
                  },
                  onPageChanged: (index) {
                    var media = messageData[index];
                    initiated = media.sentByMe;
                    mediaTime = media.sentAt.deliverTime;
                    chatPageController.assetsIndex = index;
                    mediaSize = IsmChatUtility.formatBytes(
                      int.parse('${media.attachments?.first.size}'),
                    );
                    updateState();
                  },
                ),
                Padding(
                  padding: IsmChatDimens.edgeInsets20_0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavButton(
                        icon: Icons.chevron_left_rounded,
                        visible: index != 0,
                        foreground: foreground,
                        onTap: () => _goTo(index - 1),
                      ),
                      _NavButton(
                        icon: Icons.chevron_right_rounded,
                        visible: index != total - 1,
                        foreground: foreground,
                        onTap: () => _goTo(index + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 76,
            child: Center(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: IsmChatDesignTokens.gutter,
                  vertical: 10,
                ),
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                separatorBuilder: (context, index) => IsmChatDimens.boxWidth8,
                itemCount: messageData.length,
                itemBuilder: (context, index) {
                  final item = messageData[index];
                  final isVideo =
                      item.mediaPreviewContentType ==
                          IsmChatCustomMessageType.video;
                  final selected = chatPageController.assetsIndex == index;
                  // Shared URL + cache path as [IsmChatMediaThumbnail].
                  final url =
                      IsmChatMediaImageProvider.displayUrlForMessage(item);
                  return Semantics(
                    button: true,
                    selected: selected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        chatPageController.isVideoVisible = false;
                        await _goTo(index);
                      },
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: selected ? 1 : .6,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  selected ? tokens.accent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: ConversationMediaWidget(
                                  media: item,
                                  iconData: Icons.description_rounded,
                                  url: url,
                                  borderRadius: 8,
                                ),
                              ),
                              if (isVideo)
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Previous / next arrow over the web viewer, hidden at either end.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.visible,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final bool visible;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: visible ? 1 : 0,
          child: Material(
            color: foreground.withValues(alpha: .14),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: foreground, size: 32),
              ),
            ),
          ),
        ),
      );
}
