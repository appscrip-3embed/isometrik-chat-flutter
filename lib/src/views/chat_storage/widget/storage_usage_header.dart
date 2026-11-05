import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Usage summary card at the top of the "Manage Storage" screen.
///
/// Renders three states from an [IsmChatStorageUsageModel]:
/// - quota off → a neutral "not limited" note,
/// - within quota → a progress meter with used / free figures,
/// - over limit → the meter plus a non-blocking "storage full" banner.
///
/// Copy from [IsmChatProperties.storageManagementProperties]; styling from
/// [IsmChatThemeResolver.storageFromConfig]. Figures come from the server.
class IsmChatStorageUsageHeader extends StatelessWidget {
  const IsmChatStorageUsageHeader({
    required this.usage,
    this.isLoading = false,
    super.key,
  });

  final IsmChatStorageUsageModel? usage;
  final bool isLoading;

  IsmChatStorageManagementProperties get _props =>
      IsmChatProperties.storageManagementProperties;

  @override
  Widget build(BuildContext context) {
    final theme = IsmChatThemeResolver.storageFromConfig(context);
    final primary =
        IsmChatConfig.chatTheme.primaryColor ?? IsmChatColors.primaryColorLight;
    final data = usage;

    if (data == null) {
      return SizedBox(
        height: IsmChatDimens.eighty,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    if (!data.quotaEnabled) {
      return _card(
        theme,
        child: Row(
          children: [
            Icon(Icons.cloud_done_outlined, color: primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _props.resolveQuotaDisabledMessage(),
                style: theme.usageSubtitleStyle,
              ),
            ),
          ],
        ),
      );
    }

    final used = data.usedBytes ?? 0;
    final quota = data.quotaBytes ?? 0;
    final remaining = data.remainingBytes ?? 0;
    final overLimit = data.isOverLimit;
    final barColor = overLimit ? IsmChatColors.redColor : primary;

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _props.resolveUsageCardTitle(),
                  style: theme.usageTitleStyle,
                ),
              ),
              _tierChip(data.tier, primary),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: data.usedFraction,
              minHeight: 8,
              backgroundColor: primary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${IsmChatUtility.formatBytesDecimal(used)} of ${IsmChatUtility.formatBytesDecimal(quota)} used',
                style: theme.usageSubtitleStyle,
              ),
              Text(
                '${IsmChatUtility.formatBytesDecimal(remaining)} free',
                style: theme.usageSubtitleStyle.copyWith(
                  color: overLimit ? IsmChatColors.redColor : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (overLimit) ...[
            const SizedBox(height: 12),
            _overLimitBanner(theme),
          ],
        ],
      ),
    );
  }

  Widget _card(IsmChatStorageTheme theme, {required Widget child}) => Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.usageCardBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.usageCardBorderColor),
        ),
        child: child,
      );

  Widget _tierChip(IsmChatStorageQuotaTier? tier, Color primary) {
    final isPaid = tier?.isPaid ?? false;
    final label = isPaid ? 'PAID' : 'FREE';
    final color = isPaid ? IsmChatColors.greenColor : primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _overLimitBanner(IsmChatStorageTheme theme) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: IsmChatColors.redColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: IsmChatColors.redColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _props.resolveOverLimitMessage(),
                style: theme.overLimitBannerTextStyle,
              ),
            ),
          ],
        ),
      );
}
