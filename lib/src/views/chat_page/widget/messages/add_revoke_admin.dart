import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatAddRevokeAdmin extends StatelessWidget {
  const IsmChatAddRevokeAdmin(
    this.message, {
    this.isAdded = true,
    super.key,
  });

  final IsmChatMessageModel message;
  final bool isAdded;

  String get _memberLabel =>
      message.memberId == IsmChatConfig.communicationConfig.userConfig.userId
          ? IsmChatStrings.you.toLowerCase()
          : (message.memberName ?? '');

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          decoration: BoxDecoration(
            color: IsmChatConfig.chatTheme.chatPageTheme?.centerMessageTheme
                    ?.backgroundColor ??
                IsmChatConfig.chatTheme.backgroundColor,
            borderRadius: BorderRadius.circular(IsmChatDimens.eight),
          ),
          padding: IsmChatDimens.edgeInsets8_4,
          child: Text(
            '${message.initiator} ${isAdded ? 'made' : 'removed'} $_memberLabel ${isAdded ? 'an' : 'from being an'} admin of this group'
                .trim(),
            textAlign: TextAlign.center,
            style: IsmChatConfig
                    .chatTheme.chatPageTheme?.centerMessageTheme?.textStyle ??
                IsmChatStyles.w500Black12.copyWith(
                  color: IsmChatConfig.chatTheme.primaryColor,
                ),
          ),
        ),
      );
}
