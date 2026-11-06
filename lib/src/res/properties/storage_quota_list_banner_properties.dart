import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Host-app customization for [IsmChatStorageQuotaListBanner].
///
/// Pass via [IsmChatConversationProperties.storageQuotaListBannerProperties].
/// Static strings apply when the matching `*Builder` is null. Builders run when
/// the banner is visible and receive the current [IsmChatStorageUsageModel].
///
/// Example:
/// ```dart
/// IsmChatConversationProperties(
///   storageQuotaListBannerProperties: IsmChatStorageQuotaListBannerProperties(
///     title: 'Storage almost full',
///     subtitle: 'Delete old media to keep chatting.',
///     actionLabel: 'Free up space',
///     backgroundColor: Color(0xFFFFF3E0),
///   ),
/// )
/// ```
class IsmChatStorageQuotaListBannerProperties {
  const IsmChatStorageQuotaListBannerProperties({
    this.title,
    this.subtitle,
    this.actionLabel,
    this.titleBuilder,
    this.subtitleBuilder,
    this.actionLabelBuilder,
    this.menuLabel,
    this.menuIcon,
    this.leading,
    this.showDismissButton = true,
    this.dismissIcon,
    this.margin,
    this.contentPadding,
    this.borderRadius,
    this.backgroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.actionStyle,
    this.actionColor,
  });

  /// SDK default copy when the host omits overrides.
  static const IsmChatStorageQuotaListBannerProperties defaults =
      IsmChatStorageQuotaListBannerProperties();

  static const String defaultTitle = 'Media storage almost full';

  static const String defaultSubtitle =
      'Free up space to keep sending photos and videos.';

  static const String defaultActionLabel = 'Manage storage';

  /// Headline. Ignored when [titleBuilder] returns non-null.
  final String? title;

  /// Body text. Ignored when [subtitleBuilder] returns non-null.
  final String? subtitle;

  /// Action link label. Ignored when [actionLabelBuilder] returns non-null.
  final String? actionLabel;

  /// Dynamic headline (e.g. include formatted usage). Takes precedence over [title].
  final StorageQuotaListBannerTextBuilder? titleBuilder;

  /// Dynamic body. Takes precedence over [subtitle].
  final StorageQuotaListBannerTextBuilder? subtitleBuilder;

  /// Dynamic action label. Takes precedence over [actionLabel].
  final StorageQuotaListBannerTextBuilder? actionLabelBuilder;

  /// Overflow-menu label when usage is below the banner threshold. Falls back
  /// to [actionLabel], then [defaultActionLabel].
  final String? menuLabel;

  /// Icon for the chat-list ⋮ menu entry. Default `Icons.sd_storage_outlined`.
  final IconData? menuIcon;

  /// Replaces the default warning icon. `null` → amber warning icon.
  final Widget? leading;

  /// Whether the top-right dismiss control is shown.
  final bool showDismissButton;

  /// Custom close control. `null` → default [Icons.close].
  final Widget? dismissIcon;

  /// Outer padding around the banner card.
  final EdgeInsetsGeometry? margin;

  /// Inner padding of the card content (excluding dismiss button).
  final EdgeInsetsGeometry? contentPadding;

  /// Card corner radius. Default `12`.
  final BorderRadius? borderRadius;

  /// Card background. `null` → light grey / dark subtle surface.
  final Color? backgroundColor;

  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? actionStyle;

  /// Action link color. `null` → chat theme primary color.
  final Color? actionColor;

  String resolveTitle(
    BuildContext context,
    IsmChatStorageUsageModel usage,
  ) =>
      titleBuilder?.call(context, usage) ??
      title ??
      defaultTitle;

  String resolveSubtitle(
    BuildContext context,
    IsmChatStorageUsageModel usage,
  ) =>
      subtitleBuilder?.call(context, usage) ??
      subtitle ??
      defaultSubtitle;

  String resolveActionLabel(
    BuildContext context,
    IsmChatStorageUsageModel usage,
  ) =>
      actionLabelBuilder?.call(context, usage) ??
      actionLabel ??
      defaultActionLabel;

  String resolveMenuLabel(
    BuildContext context,
    IsmChatStorageUsageModel? usage,
  ) {
    if (usage != null) {
      final fromBuilder = actionLabelBuilder?.call(context, usage);
      if (fromBuilder != null && fromBuilder.isNotEmpty) {
        return fromBuilder;
      }
    }
    return menuLabel ?? actionLabel ?? defaultActionLabel;
  }
}
