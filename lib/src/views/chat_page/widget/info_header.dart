import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Avatar, name, subtitle and quick actions at the top of contact / group
/// info ([IsmChatUserInfo], [IsmChatConverstaionInfoView]).
class IsmChatInfoHeader extends StatelessWidget {
  const IsmChatInfoHeader({
    super.key,
    required this.avatar,
    required this.title,
    this.titleStyle,
    this.onTitleTap,
    this.subtitle,
    this.subtitleStyle,
    this.caption,
    this.captionStyle,
    this.actions = const [],
  });

  final Widget avatar;
  final String title;

  /// Null → [IsmChatDesignTokens.headline].
  final TextStyle? titleStyle;
  final VoidCallback? onTitleTap;
  final String? subtitle;

  /// Null → [IsmChatDesignTokens.subhead].
  final TextStyle? subtitleStyle;

  /// Small line under the subtitle (e.g. "Group · 12 participants").
  final String? caption;
  final TextStyle? captionStyle;

  /// [IsmChatInfoAction]s shown in a row under the text.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    Widget titleText = Text(
      title,
      style: titleStyle ?? tokens.headline,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    if (onTitleTap != null) {
      titleText = IsmChatTapHandler(onTap: onTitleTap, child: titleText);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 14),
        Semantics(header: true, child: titleText),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: subtitleStyle ?? tokens.subhead,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: captionStyle ?? tokens.footnote,
            textAlign: TextAlign.center,
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final action in actions)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: SizedBox(width: 112, child: action),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Tonal quick-action button (icon over label) for [IsmChatInfoHeader].
class IsmChatInfoAction extends StatelessWidget {
  const IsmChatInfoAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.backgroundColor,
    this.labelStyle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Icon + label colour. Null → accent.
  final Color? color;

  /// Null → [IsmChatDesignTokens.surface].
  final Color? backgroundColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final foreground = color ?? tokens.accent;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(IsmChatDesignTokens.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: labelStyle ??
                      tokens.footnote.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of the latest media thumbnails, shown under the
/// "Media, links and docs" row on contact / group info.
class IsmChatMediaStrip extends StatelessWidget {
  const IsmChatMediaStrip({
    super.key,
    required this.media,
    required this.onTap,
    this.maxItems = 6,
  });

  /// Oldest → newest, as collected by the info pages.
  final List<IsmChatMessageModel> media;
  final ValueChanged<IsmChatMessageModel> onTap;
  final int maxItems;

  static const double _tile = 76;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final latest = media.reversed.take(maxItems).toList();
    return SizedBox(
      height: _tile + 14,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          IsmChatDesignTokens.gutter,
          0,
          IsmChatDesignTokens.gutter,
          14,
        ),
        itemCount: latest.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) => SizedBox.square(
          dimension: _tile,
          child: IsmChatMediaThumbnail(
            message: latest[index],
            onTap: () => onTap(latest[index]),
          ),
        ),
      ),
    );
  }
}
