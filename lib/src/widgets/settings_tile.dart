import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// One row inside an [IsmChatSectionCard]: leading icon, title / subtitle and a
/// trailing value, chevron, switch or custom widget.
///
/// - [icon] draws an SDK icon in a tinted rounded square.
/// - [leading] is shown as-is — use it for host overrides such as
///   `IsmChatProperties.conversationInfoAssets.clearChatIcon`, so app-supplied
///   assets are never re-tinted or boxed.
/// - [destructive] paints the title / icon in [destructiveColor]
///   (→ [IsmChatDesignTokens.danger]).
class IsmChatSettingsTile extends StatelessWidget {
  const IsmChatSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.iconColor,
    this.iconBackgroundColor,
    this.value,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.destructive = false,
    this.destructiveColor,
    this.titleStyle,
    this.subtitleStyle,
    this.valueStyle,
    this.chevronColor,
    this.minHeight,
    this.titleMaxLines = 1,
  });

  /// Start inset for dividers between tiles that have an [icon] / [leading].
  static const double iconDividerIndent = IsmChatDesignTokens.gutter +
      IsmChatDesignTokens.iconBoxSize +
      _leadingGap;

  static const double _leadingGap = 14;

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;

  /// Icon tint. Null → accent (or destructive colour).
  final Color? iconColor;

  /// Icon box. Null → soft accent (or soft destructive colour).
  final Color? iconBackgroundColor;

  /// Short trailing text such as a count ("24").
  final String? value;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool destructive;
  final Color? destructiveColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? valueStyle;
  final Color? chevronColor;

  /// Null → [IsmChatDesignTokens.rowHeight].
  final double? minHeight;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = IsmChatDesignTokens.of(context);
    final danger = destructiveColor ?? tokens.danger;
    final tint = destructive ? danger : tokens.accent;

    final leadingWidget = leading ??
        (icon == null
            ? null
            : Container(
                width: IsmChatDesignTokens.iconBoxSize,
                height: IsmChatDesignTokens.iconBoxSize,
                decoration: BoxDecoration(
                  color: iconBackgroundColor ??
                      (destructive
                          ? danger.withValues(alpha: tokens.isDark ? .22 : .12)
                          : tokens.accentSoft),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor ?? tint),
              ));

    var resolvedTitleStyle = titleStyle ?? tokens.body;
    if (destructive) {
      resolvedTitleStyle = resolvedTitleStyle.copyWith(
        color: danger,
        fontWeight: FontWeight.w500,
      );
    }

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight ?? IsmChatDesignTokens.rowHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IsmChatDesignTokens.gutter,
              vertical: 10,
            ),
            child: Row(
              children: [
                if (leadingWidget != null) ...[
                  SizedBox(
                    width: IsmChatDesignTokens.iconBoxSize,
                    child: Center(child: leadingWidget),
                  ),
                  const SizedBox(width: _leadingGap),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: resolvedTitleStyle,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: subtitleStyle ?? tokens.footnote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(value!, style: valueStyle ?? tokens.footnote),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
                if (showChevron) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: chevronColor ?? tokens.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
