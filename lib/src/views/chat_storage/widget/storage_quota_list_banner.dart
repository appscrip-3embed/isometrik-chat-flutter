import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// WhatsApp-style warning at the top of the conversation list when media
/// storage usage crosses [IsmChatConversationProperties.storageQuotaWarningThreshold].
///
/// Copy and styling: [IsmChatConversationProperties.storageQuotaListBannerProperties].
/// Full widget override: [IsmChatConversationProperties.storageQuotaListBannerBuilder].
///
/// Wired automatically in the default conversation list. Host apps that replace the
/// chat list with [IsmChatConversationProperties.conversationScreenBuilder]
/// can embed this widget and refresh usage via `IsmChat.i.getStorageUsage()`.
class IsmChatStorageQuotaListBanner extends StatelessWidget {
  const IsmChatStorageQuotaListBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!IsmChatProperties
        .conversationProperties.enableStorageQuotaListBanner) {
      return IsmChatDimens.box0;
    }
    if (!Get.isRegistered<IsmChatStorageQuotaController>()) {
      return IsmChatDimens.box0;
    }

    final controller = Get.find<IsmChatStorageQuotaController>();
    final conversationProps = IsmChatProperties.conversationProperties;
    final threshold = conversationProps.storageQuotaWarningThreshold;
    final customBuilder = conversationProps.storageQuotaListBannerBuilder;
    final bannerProps = conversationProps.storageQuotaListBannerProperties;

    return Obx(() {
      final usage = controller.usage;
      if (usage == null ||
          controller.listBannerDismissed ||
          !usage.shouldWarnNearQuota(threshold: threshold)) {
        return IsmChatDimens.box0;
      }

      void onManageStorage() => IsmChat.i.openStorageManagement();
      void onDismiss() => controller.dismissStorageQuotaListBanner();

      if (customBuilder != null) {
        return customBuilder(context, usage, onManageStorage, onDismiss);
      }

      return _DefaultStorageQuotaListBanner(
        usage: usage,
        properties: bannerProps,
        onManageStorage: onManageStorage,
        onDismiss: onDismiss,
      );
    });
  }
}

class _DefaultStorageQuotaListBanner extends StatelessWidget {
  const _DefaultStorageQuotaListBanner({
    required this.usage,
    required this.properties,
    required this.onManageStorage,
    required this.onDismiss,
  });

  final IsmChatStorageUsageModel usage;
  final IsmChatStorageQuotaListBannerProperties properties;
  final VoidCallback onManageStorage;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final primary = properties.actionColor ??
        IsmChatConfig.chatTheme.primaryColor ??
        IsmChatColors.primaryColorLight;
    final surface = properties.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? IsmChatColors.greyColorLight.withValues(alpha: 0.12)
            : const Color(0xFFF5F5F5));
    final radius = properties.borderRadius ?? BorderRadius.circular(12);
    final margin =
        properties.margin ?? const EdgeInsets.fromLTRB(12, 8, 12, 4);
    final contentPadding = properties.contentPadding ??
        EdgeInsets.fromLTRB(14, 14, properties.showDismissButton ? 36 : 14, 14);

    final titleText = properties.resolveTitle(context, usage);
    final subtitleText = properties.resolveSubtitle(context, usage);
    final actionText = properties.resolveActionLabel(context, usage);

    final defaultTitleStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    final defaultSubtitleStyle = TextStyle(
      fontSize: 13.5,
      color: IsmChatColors.greyColor.withValues(alpha: 0.95),
    );
    final defaultActionStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: primary,
    );

    final leading = properties.leading ??
        const Icon(
          Icons.warning_amber_rounded,
          color: IsmChatColors.yellowColor,
          size: 22,
        );

    return Padding(
      padding: margin,
      child: Material(
        color: surface,
        borderRadius: radius,
        child: Stack(
          children: [
            Padding(
              padding: contentPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style:
                              properties.titleStyle ?? defaultTitleStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style: properties.subtitleStyle ??
                              defaultSubtitleStyle,
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onManageStorage,
                          child: Text(
                            actionText,
                            style:
                                properties.actionStyle ?? defaultActionStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (properties.showDismissButton)
              Positioned(
                top: 4,
                right: 4,
                child: properties.dismissIcon != null
                    ? GestureDetector(
                        onTap: onDismiss,
                        child: properties.dismissIcon,
                      )
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: IsmChatColors.greyColor.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        onPressed: onDismiss,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
