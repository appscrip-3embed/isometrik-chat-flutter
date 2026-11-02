import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Admin actions for a group member (view info, make/revoke admin, remove).
///
/// Uses plain [ListTile] actions — not [PopupMenuItem] — so taps work reliably
/// inside a [Dialog] (PopupMenuItem tries to [Navigator.pop] the dialog route).
class IsmChatGroupAdminDialog extends StatelessWidget {
  const IsmChatGroupAdminDialog(
      {super.key, required this.user, this.isAdmin = false, this.groupName});

  final UserDetails user;
  final bool isAdmin;
  final String? groupName;

  Future<void> _closeDialogThen(Future<void> Function() action) async {
    IsmChatRoute.goBack();
    // Let the dialog route finish popping before running async controller work.
    await Future.delayed(const Duration(milliseconds: 100));
    await action();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: IsmChatDimens.edgeInsets0_10,
          child: GetBuilder<IsmChatPageController>(
            tag: IsmChat.i.chatPageTag,
            builder: (controller) => ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: IsmChatResponsive.isWeb(context)
                    ? IsmChatDimens.percentWidth(.15)
                    : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('View info'),
                    onTap: () async {
                      await _closeDialogThen(() => controller.showUserDetails(
                            user,
                            fromMessagePage: false,
                          ));
                    },
                  ),
                  ListTile(
                    title: Text(isAdmin ? 'Revoke Admin' : 'Make Admin'),
                    onTap: () async {
                      final memberId = user.conversationMemberIdForApi;
                      await _closeDialogThen(() async {
                        if (isAdmin) {
                          await controller.removeAdmin(
                            memberId,
                            user.userName,
                          );
                        } else {
                          await controller.makeAdmin(
                            memberId,
                            user.userName,
                          );
                        }
                      });
                    },
                  ),
                  ListTile(
                    title: const Text('Remove from group'),
                    onTap: () async {
                      await _closeDialogThen(() async {
                        await IsmChatContextWidget.showDialogContext(
                          content: IsmChatAlertDialogBox(
                            title:
                                'Remove "${user.userName.capitalizeFirst}" from $groupName?',
                            actionLabels: [IsmChatStrings.okay],
                            callbackActions: [
                              () => controller.removeMember(
                                    user.conversationMemberIdForApi,
                                  ),
                            ],
                          ),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
