import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Conversation media (tabs: media, links, docs).
///
/// Uses [IsmChatThemeResolver.mediaFromConfig]; omit [IsmChatPageTheme.mediaTheme]
/// in app config for SDK light/dark defaults. The app bar follows the chat
/// header ([IsmChatThemeData.chatPageHeaderTheme]) unless the host passes a
/// media theme, whose app bar colours are then used as before.
class IsmMedia extends StatefulWidget {
  const IsmMedia({
    super.key,
    required this.mediaList,
    required this.mediaListLinks,
    required this.mediaListDocs,
  });

  final List<IsmChatMessageModel> mediaList;
  final List<IsmChatMessageModel> mediaListLinks;
  final List<IsmChatMessageModel> mediaListDocs;

  @override
  State<IsmMedia> createState() => _IsmMediaState();
}

class _IsmMediaState extends State<IsmMedia> with TickerProviderStateMixin {
  late final TabController _tabController;

  bool get _isDocumentAllowed => IsmChatProperties
      .chatPageProperties.attachments
      .contains(IsmChatAttachmentType.document);

  int get _tabCount => _isDocumentAllowed ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _tabCount);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    final headerTheme = IsmChatConfig.chatTheme.chatPageHeaderTheme;
    final tokens = IsmChatDesignTokens.of(context);
    final titleStyle = IsmChatThemeResolver.hasCustomMediaTheme
        ? tokens.title.copyWith(color: mediaTheme.appBarIconColor)
        : headerTheme?.titleStyle ?? IsmChatStyles.w600White18;

    return Scaffold(
      backgroundColor: mediaTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: mediaTheme.appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: headerTheme?.systemUiOverlayStyle,
        centerTitle: true,
        title: Text(
          _isDocumentAllowed
              ? IsmChatStrings.mediaLinksAndDocs
              : IsmChatStrings.mediaLinks,
          style: titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: IsmChatResponsive.isWeb(context)
              ? () {
                  IsmChatUtility.conversationController
                      .isRenderChatPageaScreen = IsRenderChatPageScreen.none;
                }
              : IsmChatRoute.goBack,
          icon: Icon(
            IsmChatResponsive.isWeb(context)
                ? Icons.close_rounded
                : Icons.arrow_back_rounded,
            color: mediaTheme.appBarIconColor,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IsmChatDesignTokens.gutter,
                12,
                IsmChatDesignTokens.gutter,
                4,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: IsmChatSegmentedTabs(
                    controller: _tabController,
                    labels: [
                      IsmChatStrings.media,
                      IsmChatStrings.links,
                      if (_isDocumentAllowed) IsmChatStrings.docs,
                    ],
                    trackColor: mediaTheme.tabBarContainerColor,
                    thumbColor: mediaTheme.tabSelectedBackgroundColor,
                    selectedStyle: mediaTheme.tabSelectedTextStyle,
                    unselectedStyle: mediaTheme.tabUnselectedTextStyle,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  IsmMediaView(mediaList: widget.mediaList),
                  IsmLinksView(mediaListLinks: widget.mediaListLinks),
                  if (_isDocumentAllowed)
                    IsmDocsView(mediaListDocs: widget.mediaListDocs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Month / day header that sticks to the top while its section scrolls
/// (inside a [SliverMainAxisGroup]).
class IsmChatMediaSectionHeader extends StatelessWidget {
  const IsmChatMediaSectionHeader({
    super.key,
    required this.title,
    required this.style,
    required this.backgroundColor,
  });

  final String title;
  final TextStyle style;
  final Color backgroundColor;

  /// Pinned header sliver for one section.
  static Widget sliver(
    BuildContext context, {
    required String title,
    required TextStyle style,
    required Color backgroundColor,
  }) {
    final fontSize = style.fontSize ?? 12;
    final extent =
        MediaQuery.textScalerOf(context).scale(fontSize) * 1.4 + 24;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SectionHeaderDelegate(
        extent: extent,
        child: IsmChatMediaSectionHeader(
          title: title,
          style: style,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            IsmChatDesignTokens.gutter,
            12,
            IsmChatDesignTokens.gutter,
            8,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}

/// Groups `sortMediaList` output into `(title, items)` pairs, skipping empty
/// sections.
List<({String title, List<IsmChatMessageModel> items})> ismChatMediaSections(
  List<Map<String, List<IsmChatMessageModel>>> grouped,
) =>
    [
      for (final group in grouped)
        for (final entry in group.entries)
          if (entry.value.isNotEmpty) (title: entry.key, items: entry.value),
    ];
