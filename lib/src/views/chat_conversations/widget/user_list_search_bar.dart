import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Permanent search field for member / conversation picker screens.
///
/// Styling matches [IsmChatSearchConversation] (themed body field, not header
/// [IsmChatInputField]). Use this above user lists on create conversation,
/// broadcast, forward, public/open lists, etc. For the main chat conversation
/// list, use [IsmChatSearchConversation] instead.
///
/// Pair scrollable lists with [dismissKeyboardOnPickerScroll] in a
/// [NotificationListener] so the keyboard hides when the user scrolls.
class IsmChatUserListSearchBar extends StatelessWidget {
  const IsmChatUserListSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.hintText,
    this.height,
    this.border,
    this.backgroundColor,
    this.hintStyle,
    this.inputStyle,
    this.searchIconSize,
    this.cursorColor,
    this.padding,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Called after the field is cleared (suffix close). Use to restore lists.
  final VoidCallback? onClear;

  /// Placeholder. Null uses [IsmChatStrings.searchUser].
  final String? hintText;

  final double? height;
  final InputBorder? border;
  final Color? backgroundColor;
  final TextStyle? hintStyle;
  final TextStyle? inputStyle;
  final double? searchIconSize;
  final Color? cursorColor;

  /// Outer padding around the field. Null uses [IsmChatDimens.edgeInsets10_4].
  final EdgeInsetsGeometry? padding;

  void _handleClear() {
    controller.clear();
    onChanged('');
    onClear?.call();
    IsmChatUtility.hideKeyboard();
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

    return Padding(
      padding: padding ?? IsmChatDimens.edgeInsets10_4,
      child: SizedBox(
        height: resolvedHeight,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            autofocus: false,
            enableSuggestions: false,
            autocorrect: false,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            cursorColor: cursorColor ?? textFieldTheme.cursorColor,
            style: resolvedInputStyle,
            onTapOutside: (_) => IsmChatUtility.hideKeyboard(),
            onSubmitted: (_) => IsmChatUtility.hideKeyboard(),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText ?? IsmChatStrings.searchUser,
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
                      onPressed: _handleClear,
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
    );
  }
}

/// Hides the keyboard when the user starts scrolling a picker list.
///
/// Return `false` so other [ScrollNotification] listeners can still run
/// when nested; return `true` if this is the only listener and you want to
/// absorb the notification.
bool dismissKeyboardOnPickerScroll(
  ScrollNotification notification, {
  bool absorb = false,
}) {
  if (notification is ScrollStartNotification ||
      notification is UserScrollNotification) {
    IsmChatUtility.hideKeyboard();
  }
  return absorb;
}
