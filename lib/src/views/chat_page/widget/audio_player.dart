import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Inline audio player for [AudioPreview] (not a nested [Dialog]).
class IsmChatAudioPlayer extends StatelessWidget {
  const IsmChatAudioPlayer({super.key, required this.message});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final mediaTheme = IsmChatThemeResolver.mediaFromConfig(context);
    final closeColor = IsmChatThemeResolver.hasCustomMediaTheme
        ? mediaTheme.appBarIconColor
        : IsmChatDesignTokens.of(context).textSecondary;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: mediaTheme.tabBarContainerColor,
        borderRadius: BorderRadius.circular(IsmChatDesignTokens.cardRadius),
      ),
      padding: IsmChatDimens.edgeInsets8,
      constraints: BoxConstraints(minHeight: IsmChatDimens.eighty),
      child: Row(
        children: [
          Expanded(
            child: IsmChatAudioMessage(message),
          ),
          IconButton(
            onPressed: IsmChatRoute.goBack,
            icon: Icon(
              Icons.close,
              color: closeColor,
            ),
          ),
        ],
      ),
    );
  }
}
