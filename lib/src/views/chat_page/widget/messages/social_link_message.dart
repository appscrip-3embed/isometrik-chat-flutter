import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatSocialMessage extends StatelessWidget {
  const IsmChatSocialMessage(this.message, {super.key});

  final IsmChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final data = IsmChatProperties.chatPageProperties.isShowMessageBlur
        ?.call(context, message);
    return Material(
      color: Colors.transparent,
      child: IntrinsicWidth(
        child: BlurFilter.widget(
          isBlured: data?.shouldBlured ?? false,
          sigmaX: data?.sigmaX ?? 3,
          sigmaY: data?.sigmaY ?? 3,
          child: Container(
            alignment:
                message.sentByMe ? Alignment.centerRight : Alignment.centerLeft,
            constraints: BoxConstraints(
              minHeight: (IsmChatResponsive.isWeb(context))
                  ? context.height * .04
                  : context.height * .05,
            ),
            padding: IsmChatDimens.edgeInsets4,
            child: IsmChatMentionRichText(
              body: message.body,
              style: message.style,
              message: message,
            ),
          ),
        ),
      ),
    );
  }
}