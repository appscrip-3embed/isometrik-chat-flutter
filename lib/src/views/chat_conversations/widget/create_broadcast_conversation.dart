import 'dart:async';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatCreateBroadCastView extends StatelessWidget {
  const IsmChatCreateBroadCastView({
    super.key,
  });

  @override
  Widget build(BuildContext context) => GetX<IsmChatConversationsController>(
        tag: IsmChat.i.chatListPageTag,
        initState: (_) {
          IsmChatUtility.doLater(() async {
            if (!Get.isRegistered<IsmChatConversationsController>(
                tag: IsmChat.i.chatListPageTag)) {
              return;
            }
            final conversationsController =
                Get.find<IsmChatConversationsController>(
              tag: IsmChat.i.chatListPageTag,
            );
            await conversationsController.initCreateConversation(true);
          });
        },
        builder: (controller) => Scaffold(
          backgroundColor: IsmChatColors.whiteColor,
          appBar: IsmChatAppBar(
            height: IsmChatDimens.fiftyFive,
            title: Text(
              'Broadcast message to...  ${controller.selectedUserList.isEmpty ? '' : controller.selectedUserList.length}',
              style: IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
                  IsmChatStyles.w600White18,
            ),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.max,
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
                onChanged: (value) =>
                    _onBroadcastSearchChanged(controller, value),
                onClear: () => _onBroadcastSearchClear(controller),
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
                          if (controller.userSearchNameController.text
                                  .isEmpty &&
                              !controller.isLoadResponse) {
                            if (scrollNotification is ScrollEndNotification) {
                              if (scrollNotification.metrics.pixels >
                                  scrollNotification.metrics.maxScrollExtent *
                                      0.7) {
                                unawaited(controller.getNonBlockUserList(
                                  isGroupConversation: true,
                                  opponentId: IsmChatConfig
                                      .communicationConfig.userConfig.userId,
                                ));
                              }
                            }
                          }
                          return true;
                        },
                        child: AzListView(
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
                                indexBarData: const []
                                // SuspensionUtil.getTagIndexList(
                                //     controller.forwardedList)

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
                                          onTap: () {
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
                                            IsmChatProperties
                                                    .conversationProperties
                                                    .opponentSubTitle
                                                    ?.call(context,
                                                        user.userDetails) ??
                                                user.userDetails.userIdentifier,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: IsmChatStyles.w400Black12,
                                          ),
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
                  height: IsmChatDimens.eighty,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: controller.selectedUserList.length,
                          separatorBuilder: (_, __) => IsmChatDimens.boxWidth8,
                          itemBuilder: (context, index) {
                            var user = controller.selectedUserList[index];
                            return InkWell(
                              onTap: () {
                                controller
                                  ..isSelectedUser(user)
                                  ..onForwardUserTap(
                                    controller.forwardedList.indexOf(
                                      controller
                                          .forwardedList.selectedUsers[index],
                                    ),
                                  );
                              },
                              child: SizedBox(
                                width: IsmChatDimens.fifty,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        SizedBox(
                                          width: IsmChatDimens.forty,
                                          height: IsmChatDimens.forty,
                                          child: IsmChatImage.profile(
                                            user.userProfileImageUrl,
                                            name: user.userName,
                                          ),
                                        ),
                                        Positioned(
                                          top: IsmChatDimens.twentySeven,
                                          left: IsmChatDimens.twentySeven,
                                          child: CircleAvatar(
                                            backgroundColor: IsmChatConfig
                                                .chatTheme.backgroundColor,
                                            radius: IsmChatDimens.eight,
                                            child: Icon(
                                              Icons.close_rounded,
                                              color: IsmChatConfig
                                                  .chatTheme.primaryColor,
                                              size: IsmChatDimens.twelve,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                    SizedBox(
                                      height: IsmChatDimens.twentyEight,
                                      child: Text(
                                        user.userName,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        style: IsmChatStyles.w600Black10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      IsmChatDimens.boxWidth8,
                      FloatingActionButton(
                        elevation: 0,
                        shape: const CircleBorder(),
                        backgroundColor: IsmChatConfig.chatTheme.primaryColor,
                        onPressed: () async {
                          if (controller.selectedUserList.length >= 2) {
                            // Pop picker so back from chat returns to conversation list
                            // (same as group create in create_conversation_view.dart).
                            IsmChatRoute.goBack<void>();
                            await controller.goToBroadcastMessage(
                              controller.selectedUserList,
                              '',
                            );
                          } else {
                            await IsmChatContextWidget.showDialogContext(
                              content: IsmChatAlertDialogBox(
                                title: IsmChatStrings.broadcastAlert,
                                cancelLabel: 'Okay',
                              ),
                            );
                          }
                        },
                        child: const Icon(
                          Icons.done_rounded,
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

  static void _onBroadcastSearchChanged(
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
      if (controller.isLoadResponse) {
        controller.isLoadResponse = false;
      }
      return;
    }
    controller.debounce.run(() {
      controller
        ..isLoadResponse = false
        ..getNonBlockUserList(
          searchTag: value,
          opponentId:
              IsmChatConfig.communicationConfig.userConfig.userId,
        );
    });
  }

  static void _onBroadcastSearchClear(
    IsmChatConversationsController controller,
  ) {
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
