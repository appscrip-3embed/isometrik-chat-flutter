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
                      (context, index) => IsmChatMediaThumbnail(
                        message: section.items[index],
                        borderRadius: 0,
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
