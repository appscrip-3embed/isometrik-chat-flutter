import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatForwardView extends StatelessWidget {
  IsmChatForwardView({
    super.key,
    required this.message,
    required this.conversation,
  });

  final IsmChatMessageModel message;

  final IsmChatConversationModel conversation;

  final converstaionController = IsmChatUtility.conversationController;

  @override
  Widget build(BuildContext context) => GetX<IsmChatConversationsController>(
        tag: IsmChat.i.chatListPageTag,
        initState: (_) {
          converstaionController.callApiOrNot = true;
          converstaionController.forwardedList.clear();
          converstaionController.selectedUserList.clear();

          converstaionController.userSearchNameController.clear();
          converstaionController.isLoadResponse = false;
          converstaionController.getNonBlockUserList(
            opponentId: conversation.opponentDetails?.userId,
          );
        },
        builder: (controller) => Scaffold(
          backgroundColor: IsmChatColors.whiteColor,
          appBar: IsmChatAppBar(
            title: Text(
              'Forward to...  ${controller.selectedUserList.isEmpty ? '' : controller.selectedUserList.length}',
              style: IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
                  IsmChatStyles.w600White18,
            ),
          ),
          body: Column(
            children: [
              IsmChatUserListSearchBar(
                controller: controller.userSearchNameController,
                height: IsmChatDimens.fortyEight,
                padding: EdgeInsets.fromLTRB(
                  IsmChatDimens.ten,
                  IsmChatDimens.ten,
                  IsmChatDimens.ten,
                  IsmChatDimens.ten,
                ),
                onChanged: (value) => _onForwardSearchChanged(controller, value),
                onClear: () => _onForwardSearchClear(controller),
              ),
              Expanded(
                child: controller.forwardedList.isEmpty
                    ? controller.isLoadResponse
                        ? Center(
                            child: Text(
                              IsmChatStrings.noUserFound,
                              style: IsmChatStyles.w600Black16,
                            ),
                          )
                        : const IsmChatLoadingDialog()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scrollNotification) {
                          dismissKeyboardOnPickerScroll(scrollNotification);
                          if (scrollNotification is ScrollEndNotification) {
                            if (scrollNotification.metrics.pixels >
                                scrollNotification.metrics.maxScrollExtent *
                                    0.7) {
                              controller.getNonBlockUserList(
                                  opponentId: IsmChatConfig
                                      .communicationConfig.userConfig.userId);
                            }
                          }
                          return true;
                        },
                        child: controller.isLoadResponse
                            ? Center(
                                child: Text(
                                  IsmChatStrings.noUserFound,
                                  style: IsmChatStyles.w600Black16,
                                ),
                              )
                            : AzListView(
                                data: controller.forwardedList,
                                itemCount: controller.forwardedList.length,
                                indexHintBuilder: (context, hint) => Container(
                                  alignment: Alignment.center,
                                  width: IsmChatDimens.eighty,
                                  height: IsmChatDimens.eighty,
                                  decoration: BoxDecoration(
                                    color: IsmChatConfig.chatTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(hint,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: IsmChatDimens.thirty)),
                                ),
                                indexBarMargin: IsmChatDimens.edgeInsets10,
                                indexBarData: SuspensionUtil.getTagIndexList(
                                    controller.forwardedList)
                                // [
                                //     'A',
                                //     'B',
                                //     'C',
                                //     'D',
                                //     'E',
                                //     'F',
                                //     'G',
                                //     'H',
                                //     'I',
                                //     'J',
                                //     'K',
                                //     'L',
                                //     'M',
                                //     'N',
                                //     'O',
                                //     'P',
                                //     'Q',
                                //     'R',
                                //     'S',
                                //     'T',
                                //     'U',
                                //     'V',
                                //     'W',
                                //     'X',
                                //     'Y',
                                //     'Z'
                                //   ],
                                ,
                                indexBarHeight: IsmChatDimens.percentHeight(5),
                                indexBarWidth: IsmChatDimens.forty,
                                indexBarItemHeight: IsmChatDimens.twenty,
                                indexBarOptions: IndexBarOptions(
                                  indexHintDecoration: const BoxDecoration(
                                      color: IsmChatColors.whiteColor),
                                  indexHintChildAlignment: Alignment.center,
                                  selectTextStyle: IsmChatStyles.w400White12,
                                  selectItemDecoration: BoxDecoration(
                                    color: IsmChatConfig.chatTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  needRebuild: true,
                                  indexHintHeight:
                                      IsmChatDimens.percentHeight(.2),
                                ),
                                itemBuilder: (_, int index) {
                                  var user = controller.forwardedList[index];
                                  var susTag = user.getSuspensionTag();
                                  if (user.userDetails.userId ==
                                      IsmChatConfig.communicationConfig
                                          .userConfig.userId) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Offstage(
                                        offstage: user.isShowSuspension !=
                                                true ||
                                            index == 0,
                                        child: IsmChatUtility.buildSusWidget(
                                          susTag,
                                          showTrailingDivider: index != 0,
                                        ),
                                      ),
                                      ListTile(
                                          onTap: !user.isUserSelected &&
                                                  controller
                                                          .forwardedList
                                                          .selectedUsers
                                                          .length >
                                                      4
                                              ? () {
                                                  IsmChatContextWidget
                                                      .showDialogContext(
                                                    content: const AlertDialog(
                                                      title: Text(
                                                          'Alert message...'),
                                                      content: Text(
                                                          'You can only share with up to 5 chats'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed:
                                                              IsmChatRoute
                                                                  .goBack,
                                                          child: Text(
                                                            'Okay',
                                                            style: TextStyle(
                                                                fontSize: 15),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  );
                                                }
                                              : () async {
                                                  controller
                                                    ..onForwardUserTap(index)
                                                    ..isSelectedUser(
                                                        user.userDetails);
                                                },
                                          dense: true,
                                          mouseCursor: SystemMouseCursors.click,
                                          tileColor: user.isUserSelected
                                              ? IsmChatConfig
                                                  .chatTheme.primaryColor!
                                                  .applyIsmOpacity(.2)
                                              : null,
                                          leading: IsmChatImage.profile(
                                            user.userDetails
                                                .userProfileImageUrl,
                                            name: user.userDetails.userName,
                                          ),
                                          title: Text(
                                            user.userDetails.userName,
                                            style: IsmChatStyles.w600Black14,
                                          ),
                                          subtitle: Text(
                                            user.userDetails.userIdentifier,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: IsmChatStyles.w400Black12,
                                          ),
                                          autofocus: true,
                                        ),
                                    ],
                                  );
                                },
                              ),
                      ),
              ),
              if (controller.selectedUserList.isNotEmpty)
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                        ),
                        height: IsmChatDimens.sixty,
                        padding: IsmChatDimens.edgeInsets10_0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: IsmChatDimens.edgeInsets10,
                                child: Text(
                                  controller.selectedUserList
                                      .map((e) => e.userName)
                                      .join(', '),
                                  maxLines: 1,
                                  style: IsmChatStyles.w600Black12,
                                ),
                              ),
                            ),
                            IsmChatDimens.boxWidth8,
                            FloatingActionButton(
                              onPressed: () async {
                                if (IsmChatProperties
                                        .chatPageProperties.onForwardTap !=
                                    null) {
                                  IsmChatProperties
                                      .chatPageProperties.onForwardTap!
                                      .call(context,
                                          controller.currentConversation!);
                                }

                                // messageAllowedConfig is optional. Prefer `?.`
                                // + `?? true` (same contract as the
                                // MessageAllowedConfig? extension): no filter
                                // configured → allow. Never `?? false` — that
                                // would block every forward in hosts that do
                                // not set a safety filter.
                                final allowed = await IsmChatProperties
                                        .chatPageProperties
                                        .messageAllowedConfig
                                        ?.shouldAllowOutboundSend(
                                      context: IsmChatConfig.kNavigatorKey
                                              .currentContext ??
                                          IsmChatConfig.context,
                                      conversation: conversation,
                                      customType:
                                          IsmChatCustomMessageType.forward,
                                      messageText: message.body,
                                    ) ??
                                    true;
                                if (allowed) {
                                  await controller.sendForwardMessage(
                                    customType: message.customType?.name ?? '',
                                    userIds: controller.selectedUserList
                                        .map((e) => e.userId)
                                        .toList(),
                                    body: message.body,
                                    metaData: message.metaData,
                                    attachments: message.attachments
                                        ?.map((e) => e.toMap())
                                        .toList(),
                                    isLoading: true,
                                  );
                                }
                              },
                              elevation: 0,
                              shape: const CircleBorder(),
                              backgroundColor:
                                  IsmChatConfig.chatTheme.primaryColor,
                              child: const Icon(
                                Icons.send_rounded,
                                color: IsmChatColors.whiteColor,
                              ),
                            ),
                          ],
                        ),
                      ),
            ],
          ),
        ),
      );

  static void _onForwardSearchChanged(
    IsmChatConversationsController controller,
    String value,
  ) {
    if (value.trim().isEmpty) {
      controller.forwardedList = controller.forwardedListDuplicat
          .map((e) => SelectedMembers(
                isUserSelected: controller.selectedUserList
                    .any((d) => d.userId == e.userDetails.userId),
                userDetails: e.userDetails,
                isBlocked: e.isBlocked,
                tagIndex: e.tagIndex,
              ))
          .toList();
      controller.commonController.handleSorSelectedMembers(
        controller.forwardedList,
      );
      return;
    }
    controller.debounce.run(() {
      controller
        ..isLoadResponse = false
        ..getNonBlockUserList(
          searchTag: value,
          opponentId: IsmChatConfig.communicationConfig.userConfig.userId,
        );
    });
  }

  static void _onForwardSearchClear(IsmChatConversationsController controller) {
    if (controller.forwardedListDuplicat.isNotEmpty) {
      controller.forwardedList = controller.forwardedListDuplicat
          .map(
            (e) => SelectedMembers(
              isUserSelected: controller.selectedUserList
                  .any((d) => d.userId == e.userDetails.userId),
              userDetails: e.userDetails,
              isBlocked: e.isBlocked,
              tagIndex: e.tagIndex,
            ),
          )
          .toList();
      controller.commonController.handleSorSelectedMembers(
        controller.forwardedList,
      );
    }
    if (controller.isLoadResponse) {
      controller.isLoadResponse = false;
    }
  }
}
