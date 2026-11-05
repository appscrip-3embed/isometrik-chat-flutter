import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Theme for the Manage Storage screen ([IsmChatStorageView]).
///
/// Omit [IsmChatThemeData.storageTheme] for SDK light/dark defaults
/// ([IsmChatThemeResolver.storageFromConfig]).
class IsmChatStorageTheme {
  const IsmChatStorageTheme({
    required this.scaffoldBackgroundColor,
    required this.usageCardBackgroundColor,
    required this.usageCardBorderColor,
    required this.usageTitleStyle,
    required this.usageSubtitleStyle,
    required this.usageMutedTextStyle,
    required this.overLimitBannerTextStyle,
    required this.mediaTitleStyle,
    required this.mediaSubtitleStyle,
    required this.restrictedChipTextStyle,
    required this.restrictedChipBackgroundColor,
    required this.dividerColor,
    required this.filterChipLabelStyle,
    required this.selectionSummaryStyle,
    required this.deleteButtonBackgroundColor,
    required this.deleteButtonForegroundColor,
    required this.deleteButtonTextStyle,
    required this.scopeHintStyle,
    required this.emptyIconColor,
    required this.emptyTextStyle,
  });

  factory IsmChatStorageTheme.light() => IsmChatStorageTheme(
        scaffoldBackgroundColor: IsmChatColors.backgroundColorLight,
        usageCardBackgroundColor: IsmChatColors.whiteColor,
        usageCardBorderColor:
            IsmChatColors.greyColorLight.withValues(alpha: 0.4),
        usageTitleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        usageSubtitleStyle: const TextStyle(fontSize: 13),
        usageMutedTextStyle: TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.greyColorLight.withValues(alpha: 0.95),
        ),
        overLimitBannerTextStyle: TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.redColor.withValues(alpha: 0.9),
        ),
        mediaTitleStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        mediaSubtitleStyle: const TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.greyColor,
        ),
        restrictedChipTextStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: IsmChatColors.redColor,
        ),
        restrictedChipBackgroundColor:
            IsmChatColors.redColor.withValues(alpha: 0.12),
        dividerColor: IsmChatColors.greyColorLight.withValues(alpha: 0.4),
        filterChipLabelStyle: const TextStyle(fontSize: 12.5),
        selectionSummaryStyle: const TextStyle(fontWeight: FontWeight.w500),
        deleteButtonBackgroundColor: IsmChatColors.redColor,
        deleteButtonForegroundColor: IsmChatColors.whiteColor,
        deleteButtonTextStyle: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        scopeHintStyle: const TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.greyColor,
        ),
        emptyIconColor: IsmChatColors.greyColorLight,
        emptyTextStyle: const TextStyle(color: IsmChatColors.greyColor),
      );

  factory IsmChatStorageTheme.dark() => IsmChatStorageTheme(
        scaffoldBackgroundColor: IsmChatColors.backgroundColorDark,
        usageCardBackgroundColor: const Color(0xFF353535),
        usageCardBorderColor:
            IsmChatColors.greyColorLight.withValues(alpha: 0.4),
        usageTitleStyle: IsmChatStyles.w400White16.copyWith(
          fontWeight: FontWeight.w600,
        ),
        usageSubtitleStyle: IsmChatStyles.w400White14,
        usageMutedTextStyle: IsmChatStyles.w400White12.copyWith(
          color: IsmChatColors.greyColorLight,
        ),
        overLimitBannerTextStyle: TextStyle(
          fontSize: 12.5,
          color: IsmChatColors.redColor.withValues(alpha: 0.9),
        ),
        mediaTitleStyle: IsmChatStyles.w500White16.copyWith(fontSize: 14.5),
        mediaSubtitleStyle: IsmChatStyles.w400White12.copyWith(
          color: IsmChatColors.greyColorLight,
        ),
        restrictedChipTextStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: IsmChatColors.redColor,
        ),
        restrictedChipBackgroundColor:
            IsmChatColors.redColor.withValues(alpha: 0.12),
        dividerColor: IsmChatColors.greyColorLight.withValues(alpha: 0.4),
        filterChipLabelStyle: IsmChatStyles.w400White12.copyWith(fontSize: 12.5),
        selectionSummaryStyle: IsmChatStyles.w500White16,
        deleteButtonBackgroundColor: IsmChatColors.redColor,
        deleteButtonForegroundColor: IsmChatColors.whiteColor,
        deleteButtonTextStyle: IsmChatStyles.w500White16,
        scopeHintStyle: IsmChatStyles.w400White12.copyWith(
          color: IsmChatColors.greyColorLight,
        ),
        emptyIconColor: IsmChatColors.greyColorLight,
        emptyTextStyle: IsmChatStyles.w400White14.copyWith(
          color: IsmChatColors.greyColorLight,
        ),
      );

  final Color scaffoldBackgroundColor;
  final Color usageCardBackgroundColor;
  final Color usageCardBorderColor;
  final TextStyle usageTitleStyle;
  final TextStyle usageSubtitleStyle;
  final TextStyle usageMutedTextStyle;
  final TextStyle overLimitBannerTextStyle;
  final TextStyle mediaTitleStyle;
  final TextStyle mediaSubtitleStyle;
  final TextStyle restrictedChipTextStyle;
  final Color restrictedChipBackgroundColor;
  final Color dividerColor;
  final TextStyle filterChipLabelStyle;
  final TextStyle selectionSummaryStyle;
  final Color deleteButtonBackgroundColor;
  final Color deleteButtonForegroundColor;
  final TextStyle deleteButtonTextStyle;
  final TextStyle scopeHintStyle;
  final Color emptyIconColor;
  final TextStyle emptyTextStyle;
}
