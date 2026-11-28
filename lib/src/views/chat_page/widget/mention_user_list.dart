import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Channel composer `@` picker bound to [IsmChatPageController].
class MentionUserList extends StatelessWidget {
  const MentionUserList({super.key});

  @override
  Widget build(BuildContext context) => GetX<IsmChatPageController>(
        tag: IsmChat.i.chatPageTag,
        builder: (controller) {
          final alreadyMentioned = mentionUserIdsInComposerText(
            controller.chatInputController.text,
            controller.groupMembers,
          );
          final suggestions = controller.mentionSuggestions
              .where((m) => !isCurrentChatUser(m.userId))
              .where((m) => !alreadyMentioned.contains(m.userId.trim()))
              .toList();
          return IsmChatMentionSuggestionList(
            suggestions: suggestions,
            onSelect: (member) => controller.updateMentionUser(member.userName),
          );
        },
      );
}

/// `@` picker list shared by the channel and thread composers.
///
/// Shows up to four rows at a time (scrolls for more) and collapses to zero
/// height when [suggestions] is empty.
class IsmChatMentionSuggestionList extends StatelessWidget {
  const IsmChatMentionSuggestionList({
    required this.suggestions,
    required this.onSelect,
    super.key,
  });

  final List<UserDetails> suggestions;
  final ValueChanged<UserDetails> onSelect;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
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
            : suggestions.take(4).length * IsmChatDimens.percentHeight(0.07),
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
                  final member = suggestions[index];
                  return IsmChatTapHandler(
                    onTap: () => onSelect(member),
                    child: ListTile(
                      mouseCursor: SystemMouseCursors.click,
                      dense: true,
                      horizontalTitleGap: IsmChatDimens.ten,
                      title: Text(
                        IsmChatProperties.chatPageProperties.mentionUserName
                                ?.call(context, member) ??
                            member.userName.capitalizeFirst ??
                            '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IsmChatStyles.w600Black13,
                      ),
                      leading: IsmChatImage.profile(
                        IsmChatProperties
                                .chatPageProperties.mentionUserProfileUrl
                                ?.call(context, member) ??
                            member.profileUrl,
                        dimensions: IsmChatDimens.thirtyTwo,
                      ),
                    ),
                  );
                },
              ),
      );
}

/// `@` picker above a media caption field (gallery, camera, web preview).
///
/// Reads [IsmChatPageController.captionMentionSuggestions]; feed it with
/// [IsmChatPageController.refreshCaptionMentions] from the field's
/// `onChanged`. A pick is written into [field] and the new caption is handed
/// to [onCaptionChanged] so the caller can store it on the picked media.
class IsmChatCaptionMentionList extends StatelessWidget {
  const IsmChatCaptionMentionList({
    required this.field,
    required this.onCaptionChanged,
    super.key,
  });

  final TextEditingController field;
  final ValueChanged<String> onCaptionChanged;

  @override
  Widget build(BuildContext context) => Obx(() {
        final controller = IsmChatUtility.chatPageController;
        final suggestions = controller.captionMentionSuggestions.toList();
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: IsmChatDimens.edgeInsetsBottom10,
            child: IsmChatMentionSuggestionList(
              suggestions: suggestions,
              onSelect: (member) => onCaptionChanged(
                controller.selectCaptionMention(field, member),
              ),
            ),
          ),
        );
      });
}
