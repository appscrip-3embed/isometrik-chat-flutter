import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Shared emoji / GIF / sticker panel for channel and thread composers.
///
/// Channel [EmojiBoard] and the thread panel both use this widget so styling
/// and Giphy wiring stay in one place. Pass the active
/// [TextEditingController] (channel input or thread reply field).
class IsmChatComposerEmojiBoard extends StatelessWidget {
  const IsmChatComposerEmojiBoard({
    required this.textController,
    required this.emojiBoardTab,
    required this.onTabChanged,
    this.showGiphyTabs,
    this.onBeforeGiphySend,
    this.onAfterGiphySend,
    super.key,
  });

  final TextEditingController textController;
  final IsmChatEmojiBoardTab emojiBoardTab;
  final ValueChanged<IsmChatEmojiBoardTab> onTabChanged;

  /// When null, uses [IsmChatPageProperties.giphyApiKey] + [IsmChatFeature.giphyPicker].
  final bool? showGiphyTabs;

  /// Called before [IsmChatPageController.sendGiphyItem] (e.g. thread
  /// [IsmChatThreadController.syncSendTarget]).
  final Future<void> Function()? onBeforeGiphySend;

  /// Called after a Giphy item is sent (e.g. close thread emoji panel).
  final VoidCallback? onAfterGiphySend;

  bool get _showGiphyPicker {
    if (showGiphyTabs == false) return false;
    final apiKey =
        IsmChatProperties.chatPageProperties.giphyApiKey?.trim() ?? '';
    return apiKey.isNotEmpty &&
        IsmChatProperties.chatPageProperties.features
            .contains(IsmChatFeature.giphyPicker);
  }

  @override
  Widget build(BuildContext context) {
    final textFieldTheme = IsmChatThemeResolver.textFieldFromConfig(context);
    final tokens = IsmChatDesignTokens.of(context);
    final panelColor = textFieldTheme.emojiBoardBackgroundColor ??
        textFieldTheme.backgroundColor ??
        IsmChatColors.whiteColor;
    // Unselected category / search icons: theme override or design-token secondary.
    final categoryIconColor =
        textFieldTheme.emojiBoardCategoryIconColor ?? tokens.textSecondary;
    final actionIconColor =
        textFieldTheme.emojiBoardActionIconColor ?? IsmChatColors.blackColor;
    // Selected category icons always use host primary (not hardcoded purple).
    final primaryColor = IsmChatConfig.chatTheme.primaryColor ??
        IsmChatColors.primaryColorLight;
    final isDark = IsmChatThemeResolver.brightness(context) == Brightness.dark;
    final showGiphy = _showGiphyPicker;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final panelBodyHeight =
        IsmChatUtility.composerEmojiPanelBodyHeight(context);

    return ColoredBox(
      color: panelColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: panelBodyHeight,
          child: Column(
            children: [
              if (showGiphy) ...[
                Row(
                  children: [
                    IsmChatComposerEmojiBoardTab(
                      label: 'Emoji',
                      selected: emojiBoardTab == IsmChatEmojiBoardTab.emoji,
                      onTap: () => onTabChanged(IsmChatEmojiBoardTab.emoji),
                      primaryColor: primaryColor,
                      textStyle: textFieldTheme.inputTextStyle,
                    ),
                    IsmChatComposerEmojiBoardTab(
                      label: IsmChatStrings.gif,
                      selected: emojiBoardTab == IsmChatEmojiBoardTab.gif,
                      onTap: () => onTabChanged(IsmChatEmojiBoardTab.gif),
                      primaryColor: primaryColor,
                      textStyle: textFieldTheme.inputTextStyle,
                    ),
                    IsmChatComposerEmojiBoardTab(
                      label: IsmChatStrings.sticker,
                      selected: emojiBoardTab == IsmChatEmojiBoardTab.sticker,
                      onTap: () => onTabChanged(IsmChatEmojiBoardTab.sticker),
                      primaryColor: primaryColor,
                      textStyle: textFieldTheme.inputTextStyle,
                    ),
                  ],
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: showGiphy
                    ? _giphyTabBody(
                        textFieldTheme,
                        panelColor,
                        categoryIconColor,
                        actionIconColor,
                        primaryColor,
                        tokens.textPrimary,
                        isDark,
                      )
                    : IsmChatComposerEmojiPicker(
                        textController: textController,
                        panelColor: panelColor,
                        categoryIconColor: categoryIconColor,
                        actionIconColor: actionIconColor,
                        primaryColor: primaryColor,
                        textPrimaryColor: tokens.textPrimary,
                        isDark: isDark,
                        textFieldTheme: textFieldTheme,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _giphyTabBody(
    IsmChatTextFiledTheme textFieldTheme,
    Color panelColor,
    Color categoryIconColor,
    Color actionIconColor,
    Color primaryColor,
    Color textPrimaryColor,
    bool isDark,
  ) {
    switch (emojiBoardTab) {
      case IsmChatEmojiBoardTab.gif:
        return GiphyPickerPanel(
          key: const ValueKey('ism_giphy_gif_panel'),
          stickers: false,
          onBeforeSend: onBeforeGiphySend,
          onAfterSend: onAfterGiphySend,
        );
      case IsmChatEmojiBoardTab.sticker:
        return GiphyPickerPanel(
          key: const ValueKey('ism_giphy_sticker_panel'),
          stickers: true,
          onBeforeSend: onBeforeGiphySend,
          onAfterSend: onAfterGiphySend,
        );
      case IsmChatEmojiBoardTab.emoji:
        return IsmChatComposerEmojiPicker(
          key: const ValueKey('ism_emoji_panel'),
          textController: textController,
          panelColor: panelColor,
          categoryIconColor: categoryIconColor,
          actionIconColor: actionIconColor,
          primaryColor: primaryColor,
          textPrimaryColor: textPrimaryColor,
          isDark: isDark,
          textFieldTheme: textFieldTheme,
        );
    }
  }
}

/// Tab row shared by [IsmChatComposerEmojiBoard].
class IsmChatComposerEmojiBoardTab extends StatelessWidget {
  const IsmChatComposerEmojiBoardTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primaryColor,
    required this.textStyle,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primaryColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Expanded(
        child: IsmChatTapHandler(
          onTap: onTap,
          child: Container(
            padding: IsmChatDimens.edgeInsets12,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              style: textStyle?.copyWith(
                color: selected ? primaryColor : IsmChatColors.greyColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
}

/// Emoji grid wired to any composer [TextEditingController].
///
/// Category-tab colors (reuse this wiring elsewhere):
/// - Selected → [primaryColor] (host [IsmChatThemeData.primaryColor])
/// - Unselected / search → [categoryIconColor]
///   ([IsmChatTextFiledTheme.emojiBoardCategoryIconColor] or
///   [IsmChatDesignTokens.textSecondary])
///
/// Recents tab is off ([RecentTabBehavior.NONE]); opens on smileys.
/// Search / empty placeholders use [textPrimaryColor] so dark mode stays
/// readable (package default `Colors.black26` is invisible on dark panels).
///
/// [IsmChatTextFiledTheme.emojiColor] styles the composer smile button only.
class IsmChatComposerEmojiPicker extends StatelessWidget {
  const IsmChatComposerEmojiPicker({
    required this.textController,
    required this.panelColor,
    required this.categoryIconColor,
    required this.actionIconColor,
    required this.primaryColor,
    required this.textPrimaryColor,
    required this.isDark,
    required this.textFieldTheme,
    super.key,
  });

  final TextEditingController textController;
  final Color panelColor;
  final Color categoryIconColor;
  final Color actionIconColor;
  final Color primaryColor;

  /// [IsmChatDesignTokens.textPrimary] — search hint / empty-state copy.
  final Color textPrimaryColor;
  final bool isDark;
  final IsmChatTextFiledTheme textFieldTheme;

  @override
  Widget build(BuildContext context) {
    final hintStyle = (textFieldTheme.hintTextStyle ??
            textFieldTheme.inputTextStyle ??
            const TextStyle())
        .copyWith(
      color: textPrimaryColor,
      fontSize: IsmChatDimens.twelve,
    );
    final inputStyle = (textFieldTheme.inputTextStyle ?? const TextStyle())
        .copyWith(
      color: textPrimaryColor,
      fontSize: IsmChatDimens.twelve,
    );

    return EmojiPicker(
      textEditingController: textController,
      onEmojiSelected: (category, emoji) {
        IsmChatLog.error(emoji.toJson());
      },
      config: Config(
        bottomActionBarConfig: BottomActionBarConfig(
          showBackspaceButton: true,
          enabled: true,
          buttonIconColor: actionIconColor,
          buttonColor: panelColor,
          backgroundColor: panelColor,
        ),
        categoryViewConfig: CategoryViewConfig(
          // Skip Recents — start on smileys so hosts never land on empty state.
          initCategory: Category.SMILEYS,
          recentTabBehavior: RecentTabBehavior.NONE,
          backgroundColor: panelColor,
          indicatorColor: primaryColor,
          iconColor: categoryIconColor,
          iconColorSelected: primaryColor,
          backspaceColor: primaryColor,
          dividerColor:
              isDark ? IsmChatColors.greyColor : IsmChatColors.greyColorLight,
        ),
        searchViewConfig: SearchViewConfig(
          backgroundColor: panelColor,
          buttonIconColor: categoryIconColor,
          hintTextStyle: hintStyle,
          inputTextStyle: inputStyle,
        ),
        skinToneConfig: SkinToneConfig(
          dialogBackgroundColor: panelColor,
          indicatorColor: primaryColor,
        ),
        emojiViewConfig: EmojiViewConfig(
          emojiSizeMax: IsmChatDimens.twenty,
          columns: 8,
          backgroundColor: panelColor,
          // Fallback if Recents is re-enabled; readable in light and dark.
          noRecents: Text(
            'No Recents',
            style: TextStyle(
              fontSize: IsmChatDimens.twelve,
              color: textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      onBackspacePressed: () {
        final value = textController.text;
        if (value.isEmpty) return;
        textController.text = value.substring(0, value.length - 1);
      },
    );
  }
}