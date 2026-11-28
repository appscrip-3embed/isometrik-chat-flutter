import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Conversation documents tab ([IsmMedia]).
///
/// Date sections of document rows in cards; text from
/// [IsmChatMediaTheme.docTitleTextStyle] / `docSubtitleTextStyle` /
/// `docTrailingTextStyle`.
class IsmDocsView extends StatefulWidget {
  const IsmDocsView({super.key, required this.mediaListDocs});

  final List<IsmChatMessageModel> mediaListDocs;

  @override
  State<IsmDocsView> createState() => _IsmDocsViewState();
}

class _IsmDocsViewState extends State<IsmDocsView> {
  List<Map<String, List<IsmChatMessageModel>>> storeWidgetDocsList = [];

  final chatPageController = IsmChatUtility.chatPageController;

  @override
  void initState() {
    super.initState();
    IsmChatUtility.doLater(
      () {
        var storeSortDocs = chatPageController.commonController
            .sortMessages(widget.mediaListDocs);
        storeWidgetDocsList =
            chatPageController.sortMediaList(storeSortDocs).reversed.toList();
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    final tokens = IsmChatDesignTokens.of(context);
    if (widget.mediaListDocs.isEmpty) {
      return IsmChatEmptyState(
        icon: Icons.description_outlined,
        title: IsmChatStrings.noDocs,
        subtitle: IsmChatStrings.docsEmptyHint,
        titleStyle: mediaTheme.emptyStateTextStyle,
        subtitleStyle: mediaTheme.docSubtitleTextStyle,
      );
    }
    final sections = ismChatMediaSections(storeWidgetDocsList);
    return CustomScrollView(
      key: const PageStorageKey<String>('ism-media-docs'),
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
              SliverToBoxAdapter(
                child: IsmChatSectionCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: IsmChatDesignTokens.gutter,
                  ),
                  color: mediaTheme.cardBackgroundColor ?? tokens.surface,
                  dividerColor: mediaTheme.dividerColor,
                  dividerIndent: _DocRow.dividerIndent,
                  children: [
                    for (final message in section.items)
                      _DocRow(
                        message: message,
                        mediaTheme: mediaTheme,
                        onTap: () =>
                            chatPageController.tapForMediaPreview(message),
                      ),
                  ],
                ),
              ),
            ],
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.message,
    required this.mediaTheme,
    required this.onTap,
  });

  final IsmChatMessageModel message;
  final IsmChatMediaTheme mediaTheme;
  final VoidCallback onTap;

  static const double _iconTile = 44;
  static const double dividerIndent =
      IsmChatDesignTokens.gutter + _iconTile + 12;

  /// "PDF · 1.2 MB"
  String _meta(AttachmentModel? attachment) {
    final name = attachment?.name ?? '';
    var ext = (attachment?.extension ?? '').replaceAll('.', '').trim();
    if (ext.isEmpty && name.contains('.')) ext = name.split('.').last;
    final size = IsmChatUtility.formatBytes(attachment?.size ?? 0);
    return [if (ext.isNotEmpty) ext.toUpperCase(), size].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final attachment = message.attachments?.firstOrNull;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IsmChatDesignTokens.gutter,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: _iconTile,
                height: _iconTile,
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  IsmChatDocumentIcon.assetFor(attachment),
                  height: 26,
                  width: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment?.name ?? '',
                      style: mediaTheme.docTitleTextStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _meta(attachment),
                      style: mediaTheme.docSubtitleTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.sentAt.toLastMessageTimeString,
                style: mediaTheme.docTrailingTextStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
