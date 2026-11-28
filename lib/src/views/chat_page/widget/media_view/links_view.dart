import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Conversation links tab ([IsmMedia]).
///
/// Date sections of compact link rows (thumbnail, title, domain) in cards.
/// Previews share [IsmChatLinkPreviewCache] with chat bubbles.
class IsmLinksView extends StatefulWidget {
  const IsmLinksView({super.key, required this.mediaListLinks});

  final List<IsmChatMessageModel> mediaListLinks;

  @override
  State<IsmLinksView> createState() => _IsmLinksViewState();
}

class _IsmLinksViewState extends State<IsmLinksView> {
  List<Map<String, List<IsmChatMessageModel>>> storeWidgetLinksList = [];

  final chatPageController = IsmChatUtility.chatPageController;

  @override
  void initState() {
    super.initState();
    IsmChatUtility.doLater(() {
      var storeSortLinks = chatPageController.commonController
          .sortMessages(widget.mediaListLinks);
      storeWidgetLinksList =
          chatPageController.sortMediaList(storeSortLinks).reversed.toList();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    final tokens = IsmChatDesignTokens.of(context);
    if (widget.mediaListLinks.isEmpty) {
      return IsmChatEmptyState(
        icon: Icons.link_rounded,
        title: IsmChatStrings.noLinks,
        subtitle: IsmChatStrings.linksEmptyHint,
        titleStyle: mediaTheme.emptyStateTextStyle,
        subtitleStyle: mediaTheme.docSubtitleTextStyle,
      );
    }
    final sections = ismChatMediaSections(storeWidgetLinksList);
    return CustomScrollView(
      key: const PageStorageKey<String>('ism-media-links'),
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
                  dividerIndent: _LinkRow.dividerIndent,
                  children: [
                    for (final message in section.items)
                      _LinkRow(
                        key: ValueKey(message.messageId ?? message.sentAt),
                        message: message,
                        mediaTheme: mediaTheme,
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

class _LinkRow extends StatefulWidget {
  const _LinkRow({
    super.key,
    required this.message,
    required this.mediaTheme,
  });

  final IsmChatMessageModel message;
  final IsmChatMediaTheme mediaTheme;

  static const double _thumb = 56;
  static const double dividerIndent = IsmChatDesignTokens.gutter + _thumb + 12;

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  String? _title;
  String? _description;
  String? _imageUrl;

  String get _url => widget.message.body.convertToValidUrl;

  String get _key => IsmChatLinkPreviewCache.keyFor(_url);

  String get _domain {
    final host = Uri.tryParse(_key)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  @override
  void initState() {
    super.initState();
    _applyPreview(IsmChatLinkPreviewCache.summaryOf(_key));
    if (_title == null && _imageUrl == null) {
      IsmChatLinkPreviewCache.resolveSummary(_key).then((summary) {
        if (!mounted) return;
        setState(() => _applyPreview(summary));
      });
    }
  }

  void _applyPreview(IsmChatLinkPreviewSummary? summary) {
    if (summary == null) return;
    _title = summary.title;
    _description = summary.description;
    _imageUrl = summary.imageUrl;
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(_key);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final theme = widget.mediaTheme;
    final placeholder = ColoredBox(
      color: tokens.accentSoft,
      child: Icon(Icons.link_rounded, color: tokens.accent, size: 26),
    );
    return Semantics(
      link: true,
      label: _title ?? _domain,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IsmChatDesignTokens.gutter,
            vertical: 12,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(IsmChatDesignTokens.thumbRadius),
                child: SizedBox.square(
                  dimension: _LinkRow._thumb,
                  child: _imageUrl == null
                      ? placeholder
                      : CachedNetworkImage(
                          imageUrl: _imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => placeholder,
                          errorWidget: (_, __, ___) => placeholder,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title ?? _url,
                      style: theme.docTitleTextStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _description!,
                        style: theme.docSubtitleTextStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (_domain.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _domain,
                        style: theme.docSubtitleTextStyle.copyWith(
                          color: tokens.accent,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
