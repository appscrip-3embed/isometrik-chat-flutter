import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Gallery/camera → crop → upload; only hits change-group-profile when upload succeeds.
Future<void> _pickGroupPhotoAndUpdate(ImageSource source) async {
  final conversationsController = Get.find<IsmChatConversationsController>(
    tag: IsmChat.i.chatListPageTag,
  );
  final chatPageController = Get.find<IsmChatPageController>(
    tag: IsmChat.i.chatPageTag,
  );
  final imageUrl = await conversationsController.ismChangeImage(source);
  if (imageUrl == null || imageUrl.isEmpty) {
    return;
  }
  await chatPageController.changeGroupProfile(
    conversationImageUrl: imageUrl,
    conversationId: chatPageController.conversation?.conversationId ?? '',
    isLoading: true,
  );
}

class ProfileChange extends StatelessWidget {
  const ProfileChange({super.key});

  @override
  Widget build(BuildContext context) {
    final dialogTheme = IsmChatThemeResolver.dialogFromConfig(context);
    return GetBuilder<IsmChatConversationsController>(
        tag: IsmChat.i.chatListPageTag,
        builder: (controller) => CupertinoActionSheet(
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () async {
                    IsmChatRoute.goBack();
                    // Let the action sheet finish dismissing before presenting UIImagePicker.
                    await WidgetsBinding.instance.endOfFrame;
                    await _pickGroupPhotoAndUpdate(ImageSource.camera);
                  },
                  child: Padding(
                    padding: IsmChatDimens.edgeInsets10_0,
                    child: Row(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent,
                          ),
                          width: IsmChatDimens.forty,
                          height: IsmChatDimens.forty,
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: IsmChatColors.whiteColor,
                          ),
                        ),
                        IsmChatDimens.boxWidth8,
                        Text(
                          IsmChatStrings.camera,
                          style: dialogTheme.titleTextStyle,
                        )
                      ],
                    ),
                  ),
                ),
                CupertinoActionSheetAction(
                  onPressed: () async {
                    IsmChatRoute.goBack();
                    await WidgetsBinding.instance.endOfFrame;
                    await _pickGroupPhotoAndUpdate(ImageSource.gallery);
                  },
                  child: Padding(
                    padding: IsmChatDimens.edgeInsets10_0,
                    child: Row(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purpleAccent,
                          ),
                          width: IsmChatDimens.forty,
                          height: IsmChatDimens.forty,
                          child: const Icon(
                            Icons.photo_rounded,
                            color: IsmChatColors.whiteColor,
                          ),
                        ),
                        IsmChatDimens.boxWidth8,
                        Text(
                          IsmChatStrings.gallery,
                          style: dialogTheme.titleTextStyle,
                        )
                      ],
                    ),
                  ),
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: IsmChatRoute.goBack,
                isDestructiveAction: true,
                child: Text(
                  IsmChatStrings.cancel,
                  style: dialogTheme.actionTextStyle,
                ),
              ),
            ));
  }
}
