import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatSearchMessgae extends StatefulWidget {
  const IsmChatSearchMessgae({super.key});

  @override
  State<IsmChatSearchMessgae> createState() => _IsmChatSearchMessgaeState();
}

class _IsmChatSearchMessgaeState extends State<IsmChatSearchMessgae> {
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  IsmChatPageController get _controller => IsmChatUtility.chatPageController;

  @override
  void initState() {
    super.initState();
    _controller
      ..searchMessages.clear()
      ..textEditingController.clear()
      ..canCallCurrentApi = false
      ..isSearchMessagesLoading = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    if (value.trim().isEmpty) {
      _controller
        ..searchMessages.clear()
        ..isSearchMessagesLoading = false;
      return;
    }
    _controller.ismChatDebounce.run(
      () => _controller.searchedMessages(value),
    );
  }

  /// Dismisses keyboard when the user scrolls results or taps outside the field.
  /// Same behavior as [IsmChatSearchConversation].
  Widget _wrapKeyboardDismissBehavior(Widget child) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            IsmChatUtility.hideKeyboard();
          }
          return false;
        },
        child: GestureDetector(
          onTap: IsmChatUtility.hideKeyboard,
          behavior: HitTestBehavior.translucent,
          child: child,
        ),
      );

  TextStyle _emptyStateTextStyle(BuildContext context) {
    final theme = IsmChatThemeResolver.searchTextFieldFromConfig(context);
    final base = theme.inputTextStyle ?? IsmChatStyles.w600Black20;
    return base.copyWith(
      fontSize: IsmChatDimens.twenty,
      fontWeight: FontWeight.w600,
    );
  }

  Widget _buildBody(BuildContext context) => Obx(
        () {
          final messages = _controller.searchMessages;
          final isLoading = _controller.isSearchMessagesLoading;
          final emptyStyle = _emptyStateTextStyle(context);

          if (_query.trim().isEmpty) {
            return _wrapKeyboardDismissBehavior(
              Center(
                child: SizedBox(
                  width: IsmChatDimens.percentWidth(.7),
                  child: Text(
                    IsmChatStrings.noSearch,
                    style: emptyStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (isLoading && messages.isEmpty) {
            return _wrapKeyboardDismissBehavior(
              const Center(child: IsmChatLoadingDialog()),
            );
          }
          if (messages.isEmpty) {
            return _wrapKeyboardDismissBehavior(
              Center(
                child: Text(
                  IsmChatStrings.noMessageFound,
                  style: emptyStyle,
                ),
              ),
            );
          }
          return _wrapKeyboardDismissBehavior(
            SafeArea(
              child: SizedBox(
                height: IsmChatDimens.percentHeight(1),
                width: IsmChatDimens.percentWidth(1),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ListView.builder(
                        controller: _controller.searchMessageScrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        scrollDirection: Axis.vertical,
                        shrinkWrap: true,
                        reverse: true,
                        padding: IsmChatDimens.edgeInsets4_8,
                        addAutomaticKeepAlives: true,
                        itemCount: messages.length,
                        itemBuilder: (_, index) => IsmChatMessage(
                          index,
                          messages[index],
                          isFromSearchMessage: true,
                          isIgnorTap: true,
                        ),
                      ),
                    ),
                    if (isLoading)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: IsmChatDimens.edgeInsets8,
                          child: const IsmChatLoadingDialog(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final searchFieldTheme =
        IsmChatThemeResolver.searchTextFieldFromConfig(context);
    final inputStyle = searchFieldTheme.inputTextStyle ??
        IsmChatStyles.w600White16;
    final hintStyle = searchFieldTheme.hintTextStyle ?? inputStyle;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          IsmChatConfig.chatTheme.chatPageTheme?.backgroundColor ??
              IsmChatColors.whiteColor,
      appBar: IsmChatAppBar(
        height: IsmChatDimens.fiftyFive,
        onBack: !IsmChatResponsive.isWeb(context)
            ? null
            : () {
                Get.find<IsmChatConversationsController>(
                        tag: IsmChat.i.chatListPageTag)
                    .isRenderChatPageaScreen = IsRenderChatPageScreen.none;
              },
        backIcon: Icons.close_rounded,
        title: IsmChatInputField(
          fillColor: searchFieldTheme.backgroundColor ??
              IsmChatConfig.chatTheme.primaryColor,
          autofocus: false,
          focusNode: _searchFocusNode,
          hint: 'Search message..',
          hintStyle: hintStyle,
          cursorColor: searchFieldTheme.cursorColor ??
              IsmChatColors.whiteColor,
          style: inputStyle,
          controller: _controller.textEditingController,
          onChanged: _onSearchChanged,
          onTapOutside: (_) => IsmChatUtility.hideKeyboard(),
          onFieldSubmitted: (_) => IsmChatUtility.hideKeyboard(),
        ),
      ),
      body: _buildBody(context),
    );
  }
}
