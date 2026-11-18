import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatGroupEligibleUser extends StatelessWidget {
  const IsmChatGroupEligibleUser({super.key});

  @override
  Widget build(BuildContext context) => GetX<IsmChatPageController>(
        tag: IsmChat.i.chatPageTag,
        initState: (_) {
          var chatPageController = IsmChatUtility.chatPageController;
          chatPageController
            ..groupEligibleUser.clear()
            ..canCallCurrentApi = false
            ..participnatsEditingController.clear()
            ..getEligibleMembers(
                conversationId:
                    chatPageController.conversation?.conversationId ?? '',
                limit: 20);
        },
        builder: (controller) => Scaffold(
          backgroundColor: IsmChatColors.whiteColor,
          resizeToAvoidBottomInset: false,
          appBar: IsmChatAppBar(
            onBack: !IsmChatResponsive.isWeb(context)
                ? null
                : () => IsmChatUtility
                        .conversationController.isRenderChatPageaScreen =
                    IsRenderChatPageScreen.coversationInfoView,
            title: Text(
              'Add participants...  ${controller.groupEligibleUser.selectedUsers.isEmpty ? '' : controller.groupEligibleUser.selectedUsers.length}',
              style: IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
                  IsmChatStyles.w600White18,
            ),
          ),
          body: Column(
            children: [
              IsmChatUserListSearchBar(
                controller: controller.participnatsEditingController,
                hintText: 'Search user..',
                height: IsmChatDimens.fortyEight,
                padding: EdgeInsets.fromLTRB(
                  IsmChatDimens.ten,
                  IsmChatDimens.ten,
                  IsmChatDimens.ten,
                  IsmChatDimens.ten,
                ),
                onChanged: controller.addParticipantSearch,
                onClear: () => controller.addParticipantSearch(''),
              ),
              Expanded(
                child: controller.groupEligibleUser.isEmpty
                    ? controller.participnatsEditingController.text
                            .trim()
                            .isNotEmpty
                        ? Center(
                            child: Text(
                              'No user found',
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
                              controller.getEligibleMembers(
                                conversationId:
                                    controller.conversation?.conversationId ??
                                        '',
                                limit: 20,
                              );
                            }
                          }
                          return true;
                        },
                        child: AzListView(
                          data: controller.groupEligibleUser,
                          itemCount: controller.groupEligibleUser.length,
                          physics: const BouncingScrollPhysics(),
                          indexHintBuilder: (context, hint) => Container(
                            alignment: Alignment.center,
                            width: IsmChatDimens.eighty,
                            height: IsmChatDimens.eighty,
                            decoration: BoxDecoration(
                              color: IsmChatConfig.chatTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(hint,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 30.0)),
                          ),
                          indexBarData: SuspensionUtil.getTagIndexList(
                              controller.groupEligibleUser),
                          // const [
                          //   'A',
                          //   'B',
                          //   'C',
                          //   'D',
                          //   'E',
                          //   'F',
                          //   'G',
                          //   'H',
                          //   'I',
                          //   'J',
                          //   'K',
                          //   'L',
                          //   'M',
                          //   'N',
                          //   'O',
                          //   'P',
                          //   'Q',
                          //   'R',
                          //   'S',
                          //   'T',
                          //   'U',
                          //   'V',
                          //   'W',
                          //   'X',
                          //   'Y',
                          //   'Z'
                          // ],
                          indexBarMargin: IsmChatDimens.edgeInsets10,
                          indexBarHeight: IsmChatDimens.percentHeight(5),
                          indexBarWidth: IsmChatDimens.forty,
                          indexBarItemHeight: IsmChatDimens.twenty,

                          indexBarOptions: IndexBarOptions(
                            indexHintDecoration: const BoxDecoration(
                              color: IsmChatColors.whiteColor,
                            ),
                            indexHintChildAlignment: Alignment.center,
                            selectTextStyle: IsmChatStyles.w400White12,
                            selectItemDecoration: BoxDecoration(
                              color: IsmChatConfig.chatTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            needRebuild: true,
                            indexHintHeight: IsmChatDimens.percentHeight(.2),
                          ),
                          itemBuilder: (_, int index) {
                            var user = controller.groupEligibleUser[index];
                            var susTag = user.getSuspensionTag();
                            if (user.userDetails.userId ==
                                IsmChatConfig
                                    .communicationConfig.userConfig.userId) {
                              return const SizedBox.shrink();
                            }
                            return IsmChatTapHandler(
                              onTap: () =>
                                  controller.onGrouEligibleUserTap(index),
                              child: Column(
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
                                  Container(
                                    color: controller.groupEligibleUser[index]
                                            .isUserSelected
                                        ? IsmChatConfig.chatTheme.primaryColor!
                                            .applyIsmOpacity(.2)
                                        : null,
                                    child: Column(
                                      children: [
                                        ListTile(
                                          dense: true,
                                          leading: IsmChatImage.profile(
                                            user.userDetails.profileUrl,
                                            name: user.userDetails.userName
                                                    .capitalizeFirst ??
                                                '',
                                          ),
                                          title: Text(
                                            user.userDetails.userName
                                                    .capitalizeFirst ??
                                                '',
                                            style: IsmChatStyles.w600Black14,
                                          ),
                                          subtitle: Text(
                                            user.userDetails.userIdentifier,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: IsmChatStyles.w400Black12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
              if (controller.groupEligibleUser.selectedUsers.isNotEmpty)
                const _SelectedUsers(),
            ],
          ),
        ),
      );
}

class _SelectedUsers extends StatelessWidget {
  const _SelectedUsers();

  @override
  Widget build(BuildContext context) => GetX<IsmChatPageController>(
        tag: IsmChat.i.chatPageTag,
        builder: (controller) => SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: IsmChatConfig.chatTheme.backgroundColor,
            ),
            height: IsmChatDimens.ninty,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        controller.groupEligibleUser.selectedUsers.length,
                    separatorBuilder: (_, __) => IsmChatDimens.boxWidth8,
                    itemBuilder: (context, index) {
                      var conversation = controller
                          .groupEligibleUser.selectedUsers[index].userDetails;
                      return IsmChatTapHandler(
                        onTap: () => controller.onGrouEligibleUserTap(
                          controller.groupEligibleUser.indexOf(
                            controller.groupEligibleUser.selectedUsers[index],
                          ),
                        ),
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
                                      conversation.userProfileImageUrl,
                                      name: conversation.userName,
                                    ),
                                  ),
                                  Positioned(
                                    top: IsmChatDimens.twentySeven,
                                    left: IsmChatDimens.twentySeven,
                                    child: CircleAvatar(
                                      backgroundColor:
                                          IsmChatConfig.chatTheme.primaryColor,
                                      radius: IsmChatDimens.eight,
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: IsmChatColors.whiteColor,
                                        size: IsmChatDimens.twelve,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              SizedBox(
                                height: IsmChatDimens.twentyEight,
                                child: Text(
                                  conversation.userName,
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
                IsmChatDimens.boxWidth4,
                FloatingActionButton(
                  elevation: 0,
                  shape: const CircleBorder(),
                  backgroundColor: IsmChatConfig.chatTheme.primaryColor,
                  child: const Icon(
                    Icons.check,
                    color: IsmChatColors.whiteColor,
                  ),
                  onPressed: () async {
                    var memberIds = <String>[];
                    for (var x in controller.groupEligibleUser) {
                      if (x.isUserSelected == true) {
                        memberIds.add(x.userDetails.userId);
                      }
                    }
                    IsmChatRoute.goBack<void>();
                    await controller.addMembers(
                        isLoading: true, memberIds: memberIds);
                  },
                ),
                IsmChatDimens.boxWidth4,
              ],
            ),
          ),
        ),
      );
}
