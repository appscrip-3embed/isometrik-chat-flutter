import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Rounded grouped surface with hairline dividers between rows (none after the
/// last), as used by message info, contact / group info and the media tabs.
///
/// Colours default to [IsmChatDesignTokens]; pass the host's per-screen theme
/// values (e.g. [IsmChatGroupInfoTheme.surfaceBackgroundColor]) to keep them.
class IsmChatSectionCard extends StatelessWidget {
  const IsmChatSectionCard({
    super.key,
    required this.children,
    this.color,
    this.dividerColor,
    this.dividerIndent = 0,
    this.dividerEndIndent = 0,
    this.margin,
    this.borderRadius,
  });

  final List<Widget> children;

  /// Card background. Null → [IsmChatDesignTokens.surface].
  final Color? color;

  /// Divider colour. Null → [IsmChatDesignTokens.hairline].
  final Color? dividerColor;

  /// Start inset of dividers — align with the row text, e.g.
  /// [IsmChatSettingsTile.iconDividerIndent].
  final double dividerIndent;
  final double dividerEndIndent;

  /// Outer spacing around the card.
  final EdgeInsetsGeometry? margin;

  /// Null → [IsmChatDesignTokens.cardRadius].
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final card = Material(
      color: color ?? tokens.surface,
      borderRadius:
          BorderRadius.circular(borderRadius ?? IsmChatDesignTokens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: dividerIndent,
                endIndent: dividerEndIndent,
                color: dividerColor ?? tokens.hairline,
              ),
            children[i],
          ],
        ],
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// Small caption above an [IsmChatSectionCard] ("PARTICIPANTS", "READ BY"…),
/// with optional leading widget and trailing count / action.
class IsmChatSectionHeader extends StatelessWidget {
  const IsmChatSectionHeader({
    super.key,
    required this.title,
    this.style,
    this.leading,
    this.trailing,
    this.onTap,
    this.uppercase = true,
    this.padding,
  });

  final String title;

  /// Null → [IsmChatDesignTokens.caption].
  final TextStyle? style;
  final Widget? leading;
  final Widget? trailing;

  /// Makes the whole header tappable (e.g. "See all").
  final VoidCallback? onTap;
  final bool uppercase;

  /// Null → 16 start/end, 24 top, 8 bottom.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final textStyle = style ?? tokens.caption;
    Widget row = Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            IsmChatDesignTokens.gutter,
            24,
            IsmChatDesignTokens.gutter,
            8,
          ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                uppercase ? title.toUpperCase() : title,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onTap != null) {
      row = InkWell(onTap: onTap, child: row);
    }
    return row;
  }
}
