import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class MentionUserList extends StatelessWidget {
  const MentionUserList({super.key});

  @override
  Widget build(BuildContext context) => GetX<IsmChatPageController>(
        tag: IsmChat.i.chatPageTag,
        builder: (controller) {
          final currentUserId =
              IsmChatConfig.communicationConfig.userConfig.userId.trim();
          final suggestions = controller.mentionSuggestions
              .where((m) => m.userId.trim() != currentUserId)
              .toList();
          return AnimatedContainer(
          curve: Curves.easeInOut,
          duration: IsmChatConfig.animationDuration,
          margin: IsmChatDimens.edgeInsetsLeft10,
          decoration: BoxDecoration(
            border: Border.all(color: IsmChatConfig.chatTheme.primaryColor!),
            borderRadius: BorderRadius.circular(IsmChatDimens.sixteen),
            color: IsmChatColors.whiteColor,
          ),
          height: suggestions.isEmpty
              ? IsmChatDimens.zero
              // ? IsmChatDimens.percentHeight(0.08)
              : suggestions.take(4).length *
                  IsmChatDimens.percentHeight(0.07),
          width: IsmChatResponsive.isWeb(context)
              ? IsmChatDimens.percentWidth(.4)
              : IsmChatDimens.percentWidth(.8),
          child: suggestions.isEmpty
              ? const SizedBox.shrink()
              : ListView.separated(
                  shrinkWrap: true,
                  padding: IsmChatDimens.edgeInsets0_4,
                  separatorBuilder: (_, index) => IsmChatDimens.box0,
                  itemCount: suggestions.length,
                  itemBuilder: (_, index) {
                    var member = suggestions[index];
                    return IsmChatTapHandler(
                      onTap: () {
                        controller.updateMentionUser(member.userName);
                      },
                      child: ListTile(
                        mouseCursor: SystemMouseCursors.click,
                        dense: true,
                        horizontalTitleGap: IsmChatDimens.ten,
                        title: Text(
                          IsmChatProperties.chatPageProperties.mentionUserName
                                  ?.call(
                                context,
                                member,
                              ) ??
                              member.userName.capitalizeFirst ??
                              '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IsmChatStyles.w600Black13,
                        ),
                        leading: IsmChatImage.profile(
                          IsmChatProperties
                                  .chatPageProperties.mentionUserProfileUrl
                                  ?.call(
                                context,
                                member,
                              ) ??
                              member.profileUrl,
                          dimensions: IsmChatDimens.thirtyTwo,
                        ),
                      ),
                    );
                  },
                ),
        );
        },
      );
}
