import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Host-app customization for the built-in Manage Storage screen
/// ([IsmChatStorageView] / [IsmChat.openStorageManagement]).
///
/// Pass via [IsmChatProperties.storageManagementProperties].
/// Static strings apply when the matching builder is null. Typography defaults
/// come from [IsmChatThemeData.storageTheme] via [IsmChatThemeResolver].
///
/// Example:
/// ```dart
/// IsmChatProperties.storageManagementProperties =
///     IsmChatStorageManagementProperties(
///   title: 'My storage',
///   emptyTitle: 'Nothing stored yet',
///   selectAllTooltip: 'Select all items',
/// );
/// ```
class IsmChatStorageManagementProperties {
  const IsmChatStorageManagementProperties({
    this.title,
    this.selectionTitleBuilder,
    this.selectAllTooltip,
    this.sortLargestFirstTooltip,
    this.sortNewestFirstTooltip,
    this.closeIcon,
    this.selectAllIcon,
    this.sortIcon,
    this.sortByDateIcon,
    this.emptyPlaceholder,
    this.emptyIcon,
    this.emptyTitle,
    this.emptyTitleWhenQuotaOff,
    this.emptyTitleStyle,
    this.conversationScopeLabel,
    this.deleteAllLabel,
    this.filterAllLabel,
    this.deleteSelectedLabel,
    this.restrictedLabel,
    this.typeLabelBuilder,
    this.quotaDisabledMessage,
    this.usageCardTitle,
    this.overLimitMessage,
  });

  /// SDK default copy when the host omits overrides.
  static const IsmChatStorageManagementProperties defaults =
      IsmChatStorageManagementProperties();

  static const String defaultTitle = 'Storage';

  static const String defaultSelectAllTooltip = 'Select all';

  static const String defaultSortLargestFirstTooltip = 'Largest first';

  static const String defaultSortNewestFirstTooltip = 'Newest first';

  static const String defaultEmptyTitle = 'No media to show';

  static const String defaultEmptyTitleWhenQuotaOff =
      'No media uses your storage yet';

  static const String defaultConversationScopeLabel =
      'Showing one conversation';

  static const String defaultDeleteAllLabel = 'Delete all';

  static const String defaultFilterAllLabel = 'All';

  static const String defaultDeleteSelectedLabel = 'Delete';

  static const String defaultRestrictedLabel = 'Restricted';

  static const String defaultQuotaDisabledMessage =
      'Storage usage is not limited on this project.';

  static const String defaultUsageCardTitle = 'Storage';

  static const String defaultOverLimitMessage =
      'Storage is full. Delete media to upload again. '
      'You can still send and receive text.';

  /// App bar title (non-selection mode).
  final String? title;

  /// Selection app bar title. Takes precedence over default "$count selected".
  final StorageManagementSelectionTitleBuilder? selectionTitleBuilder;

  final String? selectAllTooltip;
  final String? sortLargestFirstTooltip;
  final String? sortNewestFirstTooltip;

  /// Header action icons. Null → Material defaults used today.
  final IconData? closeIcon;
  final IconData? selectAllIcon;
  final IconData? sortIcon;
  final IconData? sortByDateIcon;

  /// Replaces the entire empty list UI (pull-to-refresh still wraps the list).
  final Widget? emptyPlaceholder;

  /// Shown when [emptyPlaceholder] is null.
  final IconData? emptyIcon;

  final String? emptyTitle;
  final String? emptyTitleWhenQuotaOff;

  /// Overrides [IsmChatStorageTheme.emptyTextStyle] for empty list title.
  final TextStyle? emptyTitleStyle;

  final String? conversationScopeLabel;
  final String? deleteAllLabel;
  final String? filterAllLabel;
  final String? deleteSelectedLabel;
  final String? restrictedLabel;

  /// Type filter chips and tile subtitles. Null → SDK English defaults.
  final StorageManagementTypeLabelBuilder? typeLabelBuilder;

  final String? quotaDisabledMessage;
  final String? usageCardTitle;
  final String? overLimitMessage;

  String resolveTitle() => title ?? defaultTitle;

  String resolveSelectionTitle(BuildContext context, int count) =>
      selectionTitleBuilder?.call(context, count) ?? '$count selected';

  String resolveSelectAllTooltip() =>
      selectAllTooltip ?? defaultSelectAllTooltip;

  String resolveSortLargestFirstTooltip() =>
      sortLargestFirstTooltip ?? defaultSortLargestFirstTooltip;

  String resolveSortNewestFirstTooltip() =>
      sortNewestFirstTooltip ?? defaultSortNewestFirstTooltip;

  String resolveEmptyTitle({required bool quotaEnabled}) =>
      quotaEnabled
          ? (emptyTitle ?? defaultEmptyTitle)
          : (emptyTitleWhenQuotaOff ?? defaultEmptyTitleWhenQuotaOff);

  String resolveConversationScopeLabel() =>
      conversationScopeLabel ?? defaultConversationScopeLabel;

  String resolveDeleteAllLabel() => deleteAllLabel ?? defaultDeleteAllLabel;

  String resolveFilterAllLabel() => filterAllLabel ?? defaultFilterAllLabel;

  String resolveDeleteSelectedLabel() =>
      deleteSelectedLabel ?? defaultDeleteSelectedLabel;

  String resolveRestrictedLabel() => restrictedLabel ?? defaultRestrictedLabel;

  String resolveQuotaDisabledMessage() =>
      quotaDisabledMessage ?? defaultQuotaDisabledMessage;

  String resolveUsageCardTitle() => usageCardTitle ?? defaultUsageCardTitle;

  String resolveOverLimitMessage() => overLimitMessage ?? defaultOverLimitMessage;

  String resolveTypeLabel(IsmChatMediaType type) {
    final custom = typeLabelBuilder?.call(type);
    if (custom != null && custom.isNotEmpty) return custom;
    switch (type) {
      case IsmChatMediaType.image:
        return 'Images';
      case IsmChatMediaType.video:
        return 'Videos';
      case IsmChatMediaType.audio:
        return 'Audio';
      case IsmChatMediaType.file:
        return 'Documents';
      case IsmChatMediaType.gif:
        return 'GIFs';
      case IsmChatMediaType.sticker:
        return 'Stickers';
      case IsmChatMediaType.location:
        return 'Location';
      case IsmChatMediaType.adminMessage:
        return 'Files';
    }
  }

  /// Short label for a single media row (tile subtitle prefix).
  String resolveTypeLabelShort(IsmChatMediaType type) {
    final custom = typeLabelBuilder?.call(type);
    if (custom != null && custom.isNotEmpty) return custom;
    switch (type) {
      case IsmChatMediaType.image:
        return 'Image';
      case IsmChatMediaType.video:
        return 'Video';
      case IsmChatMediaType.audio:
        return 'Audio';
      case IsmChatMediaType.file:
        return 'Document';
      case IsmChatMediaType.gif:
        return 'GIF';
      case IsmChatMediaType.sticker:
        return 'Sticker';
      case IsmChatMediaType.location:
        return 'Location';
      case IsmChatMediaType.adminMessage:
        return 'File';
    }
  }
}
