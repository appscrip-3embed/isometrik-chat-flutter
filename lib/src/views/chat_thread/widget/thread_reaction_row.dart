import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Outlined reaction chips for the thread panel (emoji + count, border only).
///
/// Reuses the channel's reaction data and tap targets ([ImsChatReaction]) but
/// omits filled chip backgrounds so rows match Slack-style thread chrome.
/// Border / label colors come from [IsmChatThreadTheme] via
/// [IsmChatThemeResolver.threadFromConfig].
class IsmChatThreadReactionRow extends StatefulWidget {
  const IsmChatThreadReactionRow({
    required this.message,
    super.key,
  });

  final IsmChatMessageModel message;

  IsmChatPageController get _controller => IsmChatUtility.chatPageController;

  @override
  State<IsmChatThreadReactionRow> createState() =>
      _IsmChatThreadReactionRowState();
}

class _IsmChatThreadReactionRowState extends State<IsmChatThreadReactionRow> {
  int reactionLength = 0;
  bool showCount = false;

  @override
  void initState() {
    _checkReactionCount();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant IsmChatThreadReactionRow oldWidget) {
    _checkReactionCount();
    super.didUpdateWidget(oldWidget);
  }

  void _checkReactionCount() {
    widget.message.reactions
        ?.removeWhere((e) => e.emojiKey.isNotEmpty && e.userIds.isEmpty);
    reactionLength = widget.message.reactions?.length ?? 0;
    if (reactionLength > 3) {
      showCount = true;
      reactionLength = reactionLength - 2;
    } else {
      showCount = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadTheme = IsmChatThemeResolver.threadFromConfig(context);
    final borderColor = threadTheme.reactionChipBorderColor;
    final countStyle = threadTheme.reactionCountStyle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        showCount ? 3 : widget.message.reactions?.length ?? 0,
        (index) => _outlineChip(
          context,
          index: index,
          borderColor: borderColor,
          countStyle: countStyle,
        ),
      ),
    );
  }

  Widget _outlineChip(
    BuildContext context, {
    required int index,
    required Color borderColor,
    required TextStyle countStyle,
  }) {
    final reactionName = widget.message.reactions?[index].emojiKey;
    final reactionValue =
        IsmChatEmoji.values.firstWhere((e) => e.value == reactionName);
    final reaction = widget._controller.reactions
        .firstWhere((e) => e.name == reactionValue.emojiKeyword);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget._controller.showReactionUser(
          message: widget.message,
          reactionType: reactionName ?? '',
          index: index,
        );
      },
      child: Container(
        margin: EdgeInsets.only(right: IsmChatDimens.six),
        padding: EdgeInsets.symmetric(
          horizontal: IsmChatDimens.eight,
          vertical: IsmChatDimens.four,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(IsmChatDimens.fifty),
          border: Border.all(color: borderColor),
        ),
        child: showCount && index == 2
            ? Text(
                '+ $reactionLength',
                style: countStyle,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiCell.fromConfig(
                    emojiBoxSize: IsmChatDimens.eighteen,
                    emoji: reaction,
                    emojiSize: IsmChatDimens.sixteen,
                    onEmojiSelected: (_, emoji) {
                      widget._controller.showReactionUser(
                        index: index,
                        message: widget.message,
                        reactionType: reactionName ?? '',
                      );
                    },
                    config: Config(
                      categoryViewConfig: CategoryViewConfig(
                        indicatorColor: IsmChatConfig.chatTheme.primaryColor!,
                      ),
                      emojiViewConfig: EmojiViewConfig(
                        emojiSizeMax: IsmChatDimens.twenty,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                  IsmChatDimens.boxWidth2,
                  Text(
                    '${widget.message.reactions?[index].userIds.length}',
                    style: countStyle,
                  ),
                ],
              ),
      ),
    );
  }
}