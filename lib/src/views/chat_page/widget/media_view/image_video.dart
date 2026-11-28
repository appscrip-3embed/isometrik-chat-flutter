import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Conversation media grid tab ([IsmMedia]).
///
/// Edge-to-edge square grid grouped by date with sticky headers
/// ([IsmChatMediaTheme.sectionTitleTextStyle]). Column count grows with width.
class IsmMediaView extends StatefulWidget {
  const IsmMediaView({super.key, required this.mediaList});

  final List<IsmChatMessageModel> mediaList;

  @override
  State<IsmMediaView> createState() => _IsmMediaViewState();
}

class _IsmMediaViewState extends State<IsmMediaView> {
  List<Map<String, List<IsmChatMessageModel>>> storeWidgetMediaList = [];

  final chatPageController = IsmChatUtility.chatPageController;

  @override
  void initState() {
    super.initState();
    IsmChatUtility.doLater(
      () {
        var storeSortMedia =
            chatPageController.commonController.sortMessages(widget.mediaList);
        storeWidgetMediaList =
            chatPageController.sortMediaList(storeSortMedia).reversed.toList();
        if (mounted) setState(() {});
      },
    );
  }

  /// 3 columns on phones, more on tablets / the web panel.
  static int columnsFor(double width) {
    if (width >= 900) return 6;
    if (width >= 640) return 5;
    if (width >= 440) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    if (widget.mediaList.isEmpty) {
      return IsmChatEmptyState(
        icon: Icons.photo_library_outlined,
        title: IsmChatStrings.noMedia,
        subtitle: IsmChatStrings.mediaEmptyHint,
        titleStyle: mediaTheme.emptyStateTextStyle,
        subtitleStyle: mediaTheme.docSubtitleTextStyle,
      );
    }
    final sections = ismChatMediaSections(storeWidgetMediaList);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        return CustomScrollView(
          key: const PageStorageKey<String>('ism-media-grid'),
          slivers: [
            for (final section in sections)
              SliverMainAxisGroup(
                slivers: [
                  IsmChatMediaSectionHeader.sliver(
                    context,
                    title: section.title,
                    style: mediaTheme.sectionTitleTextStyle,
                    backgroundColor: mediaTheme.scaffoldBackgroundColor,
                  ),
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _MediaTile(
                        message: section.items[index],
                        onTap: () => chatPageController
                            .tapForMediaPreview(section.items[index]),
                      ),
                      childCount: section.items.length,
                    ),
                  ),
                ],
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.message, required this.onTap});

  final IsmChatMessageModel message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachments?.firstOrNull;
    final url = message.customType == IsmChatCustomMessageType.image
        ? attachment?.mediaUrl ?? ''
        : attachment?.thumbnailUrl ?? '';
    final iconData = message.customType == IsmChatCustomMessageType.audio
        ? Icons.audio_file_rounded
        : Icons.description_rounded;
    final isVideo = message.customType == IsmChatCustomMessageType.video;

    return Semantics(
      button: true,
      label: isVideo ? IsmChatStrings.video : IsmChatStrings.image,
      child: IsmChatTapHandler(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ConversationMediaWidget(
              media: message,
              iconData: iconData,
              url: url,
              borderRadius: 0,
            ),
            if (isVideo)
              Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
