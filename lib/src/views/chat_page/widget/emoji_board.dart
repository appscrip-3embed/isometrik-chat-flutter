import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Emoji, GIF, and sticker panel shown above the message composer.
///
/// Delegates to [IsmChatComposerEmojiBoard] so thread and channel share one UI.
class EmojiBoard extends StatelessWidget {
  const EmojiBoard({super.key});

  @override
  Widget build(BuildContext context) => GetBuilder<IsmChatPageController>(
        tag: IsmChat.i.chatPageTag,
        builder: (controller) => Obx(
          () => IsmChatComposerEmojiBoard(
            textController: controller.chatInputController,
            emojiBoardTab: controller.emojiBoardTab,
            onTabChanged: (tab) => controller.emojiBoardTab = tab,
            onAfterGiphySend: () => controller.toggleEmojiBoard(false, false),
          ),
        ),
      );
}