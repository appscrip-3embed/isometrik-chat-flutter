import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Hero avatar for conversation / contact info screens.
///
/// Honors [IsmChatConversationInfoAssets.profileImageBuilder] and
/// [IsmChatConversationInfoAssets.profileImageUrl] on
/// [IsmChatProperties.conversationInfoAssets]. Not used for conversation list
/// cards (see [IsmChatCardProperties]).
class IsmChatConversationCardProfileImage extends StatelessWidget {
  const IsmChatConversationCardProfileImage({
    super.key,
    required this.conversation,
    required this.dimensions,
    this.fallbackUrl = '',
    this.displayName,
  });

  final IsmChatConversationModel? conversation;
  final double dimensions;

  /// Used when [conversation]?.profileUrl is empty.
  final String fallbackUrl;

  /// Initials fallback when [conversation]?.chatName is empty (e.g. [IsmChatUserInfo]).
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final assets = IsmChatProperties.conversationInfoAssets;
    final resolvedUrl = conversation?.profileUrl ?? fallbackUrl;

    return assets.profileImageBuilder?.call(
          context,
          conversation,
          resolvedUrl,
        ) ??
        IsmChatImage.profile(
          assets.profileImageUrl?.call(
                context,
                conversation,
                resolvedUrl,
              ) ??
              resolvedUrl,
          name: conversation?.chatName ?? displayName,
          dimensions: dimensions,
        );
  }
}
