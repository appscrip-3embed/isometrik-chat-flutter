import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Conversation list search field.
///
/// Uses [TextField] directly instead of [IsmChatInputField] so this screen
/// can keep a search icon, an end clear action, and keyboard dismiss on a
/// tap outside the field. Reuse [IsmChatInputField] for other inputs that
/// do not need those three behaviors.
///
/// Colors follow light/dark via [IsmChatThemeResolver.textFieldFromConfig]
/// (same source as [IsmChatMessageField] / `chatPageTheme.textFiledTheme`).
/// Pass [height], [border], [backgroundColor], [hintText], [hintStyle],
/// [inputStyle], or [searchIconSize] to override one piece. Each null value
/// keeps that default, so hosts can restyle the bar without copying this
/// widget.
///
/// The clear icon listens to
/// [IsmChatConversationsController.searchConversationTEC] because text
/// controller changes do not rebuild GetX on their own.
class IsmChatSearchConversation extends StatelessWidget {
  const IsmChatSearchConversation({
    super.key,
    this.height,
    this.border,
    this.backgroundColor,
    this.hintText,
    this.hintStyle,
    this.inputStyle,
    this.searchIconSize,
    this.cursorColor,
  });

  /// Painted height of the field. Null uses 52.
  ///
  /// The [TextField] expands to fill this height. It is not only a max cap.
  final double? height;

  /// Border for every state. Null uses the themed outline
  /// ([IsmChatTextFiledTheme.borderColor], radius [IsmChatDimens.fifteen]).
  final InputBorder? border;

  /// Fill color. Null uses [IsmChatTextFiledTheme.backgroundColor].
  final Color? backgroundColor;

  /// Placeholder. Null uses [IsmChatStrings.searchChat].
  final String? hintText;

  /// Placeholder style. Null uses the themed hint at 14.
  final TextStyle? hintStyle;

  /// Typed text style. Null uses the themed input style at 14.
  final TextStyle? inputStyle;

  /// Search icon size. Null uses [IsmChatDimens.twenty].
  final double? searchIconSize;
  final Color? cursorColor;

  void _clearSearch(IsmChatConversationsController controller) {
    controller.searchConversationTEC.clear();
    controller
      ..searchConversationQuery = ''
      ..getConversationsFromDB()
      ..update();
  }

  @override
  Widget build(BuildContext context) {
    final textFieldTheme = IsmChatThemeResolver.textFieldFromConfig(context);
    final resolvedInputStyle = inputStyle ??
        (textFieldTheme.inputTextStyle ?? IsmChatStyles.w400Black18)
            .copyWith(fontSize: IsmChatDimens.forteen);
    final resolvedHintStyle = hintStyle ??
        (textFieldTheme.hintTextStyle ?? resolvedInputStyle)
            .copyWith(fontSize: IsmChatDimens.forteen);
    final borderColor = textFieldTheme.borderColor ??
        IsmChatConfig.chatTheme.borderColor ??
        IsmChatColors.greyColor.applyIsmOpacity(.5);
    final iconColor = resolvedHintStyle.color ?? resolvedInputStyle.color;
    final resolvedHeight = height ?? 52;
    final resolvedSearchIconSize = searchIconSize ?? IsmChatDimens.twenty;
    final iconSlot = resolvedSearchIconSize * 2 > resolvedHeight
        ? resolvedHeight
        : resolvedSearchIconSize * 2;
    final resolvedBorder = border ??
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(IsmChatDimens.fifteen),
          borderSide: BorderSide(color: borderColor),
        );

    return GetBuilder<IsmChatConversationsController>(
      tag: IsmChat.i.chatListPageTag,
      builder: (controller) => Padding(
        padding: IsmChatDimens.edgeInsets10_4,
        child: SizedBox(
          height: resolvedHeight,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.searchConversationTEC,
            builder: (context, value, _) => TextField(
              controller: controller.searchConversationTEC,
              autofocus: false,
              enableSuggestions: false,
              autocorrect: false,
              // Fill [resolvedHeight]. maxLines must be null when expands is true.
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              cursorColor: cursorColor ?? textFieldTheme.cursorColor,
              style: resolvedInputStyle,
              onTapOutside: (_) => IsmChatUtility.hideKeyboard(),
              onSubmitted: (_) => IsmChatUtility.hideKeyboard(),
              onChanged: (value) async {
                controller.debounce.run(() async {
                  switch (value.trim().isNotEmpty) {
                    case true:
                      await controller.getChatConversations(
                        searchTag: value,
                      );
                      break;
                    default:
                      controller.searchConversationQuery = '';
                      await controller.getConversationsFromDB();
                  }
                });
                controller.update();
              },
              decoration: InputDecoration(
                hintText: hintText ?? IsmChatStrings.searchChat,
                hintStyle: resolvedHintStyle,
                isDense: true,
                filled: true,
                fillColor: backgroundColor ?? textFieldTheme.backgroundColor,
                contentPadding: IsmChatDimens.edgeInsets10_0,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: iconColor,
                  size: resolvedSearchIconSize,
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: iconSlot,
                  minHeight: iconSlot,
                  maxHeight: resolvedHeight,
                ),
                suffixIconConstraints: BoxConstraints(
                  minWidth: iconSlot,
                  minHeight: iconSlot,
                  maxHeight: resolvedHeight,
                ),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: iconSlot,
                          minHeight: iconSlot,
                          maxHeight: resolvedHeight,
                        ),
                        highlightColor: IsmChatColors.transparent,
                        disabledColor: IsmChatColors.transparent,
                        hoverColor: IsmChatColors.transparent,
                        splashColor: IsmChatColors.transparent,
                        focusColor: IsmChatColors.transparent,
                        onPressed: () => _clearSearch(controller),
                        icon: Icon(
                          Icons.close_outlined,
                          color: resolvedInputStyle.color,
                          size: IsmChatDimens.twenty,
                        ),
                      )
                    : null,
                border: resolvedBorder,
                enabledBorder: resolvedBorder,
                focusedBorder: resolvedBorder,
                errorBorder: resolvedBorder,
                focusedErrorBorder: resolvedBorder,
                disabledBorder: resolvedBorder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
