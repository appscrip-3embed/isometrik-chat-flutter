part of '../chat_page_controller.dart';
// coverage:ignore-file
// Dialogs, sheets and route pushes are UI glue; covered by key widget tests.

mixin IsmChatShowDialogMixin on GetxController {
  /// Gets the controller instance.
  ///
  /// This getter attempts to use the current instance (this) first,
  /// and falls back to GetX lookup if needed. This prevents errors
  /// when the controller is accessed before it's fully registered in GetX.
  IsmChatPageController get _controller {
    // If this is already an IsmChatPageController, use it directly
    // This prevents the "controller not found" error during initialization
    if (this is IsmChatPageController) {
      return this as IsmChatPageController;
    }
    // Fallback to GetX lookup for cases where mixin might be used elsewhere
    return IsmChatUtility.chatPageController;
  }

  BuildContext get _dialogHostContext =>
      IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;

  /// Single entry for chat-page alert dialogs — uses [IsmChatThemeResolver.dialogFromConfig].
  Future<void> _showThemedAlertDialog({
    required String title,
    List<String>? actionLabels,
    List<VoidCallback>? callbackActions,
    String? cancelLabel,
    VoidCallback? onCancel,
    Widget? content,
    bool barrierDismissible = true,
  }) =>
      IsmChatContextWidget.showThemedAlertDialog(
        context: _dialogHostContext,
        title: title,
        actionLabels: actionLabels,
        callbackActions: callbackActions,
        cancelLabel: cancelLabel ?? IsmChatStrings.cancel,
        onCancel: onCancel,
        content: content,
        barrierDismissible: barrierDismissible,
      );

  /// Text field styled from [IsmChatDialogTheme] (group title, etc.).
  Widget _themedDialogInput(TextEditingController controller) => Builder(
        builder: (context) {
          final theme = IsmChatThemeResolver.dialogFromConfig(context);
          return TextFormField(
            controller: controller,
            style: theme.inputTextStyle,
            cursorColor: theme.inputFocusedBorderColor,
            decoration: InputDecoration(
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(IsmChatDimens.eight),
                borderSide: BorderSide(color: theme.inputBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(IsmChatDimens.eight),
                borderSide: BorderSide(color: theme.inputFocusedBorderColor),
              ),
              hintStyle: theme.contentTextStyle,
            ),
          );
        },
      );

  Future<void> _presentChatConfirmation(
      IsmChatConfirmationRequest request) async {
    final presenter =
        IsmChatProperties.chatPageProperties.chatConfirmationPresenter;
    if (presenter != null) {
      final handled = await presenter(_dialogHostContext, request);
      if (handled) {
        return;
      }
    }
    await _showThemedAlertDialog(
      title: request.title,
      content: request.content ??
          (request.body == null
              ? null
              : Builder(
                  builder: (context) => IsmChatAlertDialogBox.themedBodyText(
                    context,
                    request.body!,
                  ),
                )),
      actionLabels: request.actions.isEmpty
          ? null
          : request.actions.map((a) => a.label).toList(),
      callbackActions: request.actions.isEmpty
          ? null
          : request.actions.map((a) => a.onPressed).toList(),
      cancelLabel: request.cancelLabel ?? IsmChatStrings.cancel,
      onCancel: request.onCancel,
    );
  }

  void _runBlockAction({required bool unblock}) {
    final opponentId = _controller.conversation?.opponentDetails?.userId ?? '';
    if (unblock) {
      _controller.unblockUser(
        opponentId: opponentId,
        isLoading: true,
        userBlockOrNot: true,
      );
    } else {
      _controller.blockUser(
        opponentId: opponentId,
        isLoading: true,
        userBlockOrNot: false,
      );
    }
  }

  void showDialogForClearChatAndDeleteGroup(
      {bool isGroupDelete = false}) async {
    final conversation = _controller.conversation;
    if (!isGroupDelete) {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.clearChatMessages,
          title: IsmChatStrings.clearAllMessages,
          conversation: conversation,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.clearChat,
              label: IsmChatStrings.clearChat,
              onPressed: () => _controller.clearAllMessages(
                conversation?.conversationId ?? '',
                fromServer:
                    IsmChatConfirmationHelper.shouldClearMessagesFromServer(
                  conversation,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.deleteGroup,
          title: IsmChatStrings.deleteThiGroup,
          conversation: conversation,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.deleteGroup,
              label: IsmChatStrings.deleteGroup,
              onPressed: () => _controller.conversationController.deleteChat(
                conversation?.conversationId ?? '',
                deleteFromServer: false,
              ),
            ),
          ],
        ),
      );
      IsmChatRoute.goBack();
    }
  }

  /// function to show dialog for changing the group title
  void showDialogForChangeGroupTitle() async {
    _controller.groupTitleController.text =
        _controller.conversation?.chatName ?? '';
    // Host can customize via chatConfirmationPresenter
    // ([IsmChatConfirmationType.changeGroupTitle]).
    await _presentChatConfirmation(
      IsmChatConfirmationRequest(
        type: IsmChatConfirmationType.changeGroupTitle,
        title: IsmChatStrings.enterNewGroupTitle,
        conversation: _controller.conversation,
        textController: _controller.groupTitleController,
        content: _themedDialogInput(_controller.groupTitleController),
        actions: [
          IsmChatConfirmationAction(
            id: IsmChatConfirmationActionId.changeGroupTitle,
            label: IsmChatStrings.okay,
            onPressed: () => _controller.changeGroupTitle(
              conversationTitle: _controller.groupTitleController.text,
              conversationId: _controller.conversation?.conversationId ?? '',
              isLoading: true,
            ),
          ),
        ],
      ),
    );
  }

  /// function to show dialog for changing the group profile
  Future<void> showDialogForChangeGroupProfile() async {
    if (kIsWeb) {
      final imageUrl = await _controller.conversationController
          .ismChangeImage(ImageSource.gallery);
      if (imageUrl == null || imageUrl.isEmpty) {
        return;
      }
      await _controller.changeGroupProfile(
          conversationImageUrl: imageUrl,
          conversationId: _controller.conversation?.conversationId ?? '',
          isLoading: true);
    } else {
      await IsmChatContextWidget.showBottomsheetContext(
        content: const ProfileChange(),
        isDismissible: true,
        elevation: 0,
        backgroundColor: IsmChatColors.transparent,
      );
    }
  }

  void showDialogForBlockUnBlockUser(
    bool userBlockOrNot, [
    bool includeMembers = false,
  ]) async {
    await _presentChatConfirmation(
      IsmChatConfirmationRequest(
        type: userBlockOrNot
            ? IsmChatConfirmationType.confirmUnblock
            : IsmChatConfirmationType.confirmBlock,
        title: userBlockOrNot
            ? IsmChatStrings.doWantUnBlckUser
            : IsmChatStrings.doWantBlckUser,
        conversation: _controller.conversation,
        actions: [
          IsmChatConfirmationAction(
            id: userBlockOrNot
                ? IsmChatConfirmationActionId.unblock
                : IsmChatConfirmationActionId.block,
            label:
                userBlockOrNot ? IsmChatStrings.unblock : IsmChatStrings.block,
            onPressed: () => _runBlockAction(unblock: userBlockOrNot),
          ),
        ],
      ),
    );
  }

  void showDialogCheckBlockUnBlock() async {
    if (_controller.conversation?.isSelfChat == true) {
      return;
    }
    if (_controller.conversation?.isBlockedByMe ?? false) {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.blockedByYouPromptUnblock,
          title: IsmChatStrings.youBlockUser,
          conversation: _controller.conversation,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.unblock,
              label: IsmChatStrings.unblock,
              onPressed: () => _runBlockAction(unblock: true),
            ),
          ],
        ),
      );
    } else {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.cannotBlockOpponent,
          title: IsmChatStrings.cannotBlock,
          cancelLabel: IsmChatStrings.okay,
          actions: [],
        ),
      );
    }
  }

  Future<void> showDialogForMessageDelete(IsmChatMessageModel message,
      {bool fromMediaPrivew = false}) async {
    // If user taps delete from the focus menu on a media tile (image/video),
    // delete must affect the whole grouped media grid, not only the first tile.
    final groupedMediaMessages = _getGroupedMediaMessagesForDeletion(message);

    final messageMap = _toUniqueMessageMap(groupedMediaMessages);

    if (message.sentByMe) {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.deleteMessageOwn,
          title: IsmChatStrings.deleteMessage,
          conversation: _controller.conversation,
          message: message,
          messages: groupedMediaMessages,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.deleteForEveryone,
              label: IsmChatStrings.deleteForEvery,
              onPressed: () => _controller.deleteMessageForEveryone(messageMap),
            ),
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.deleteForMe,
              label: IsmChatStrings.deleteForMe,
              onPressed: () => _controller.deleteMessageForMe(messageMap),
            ),
          ],
        ),
      );
      if (fromMediaPrivew) IsmChatRoute.goBack();
    } else {
      final senderFullName =
          '${message.senderInfo?.metaData?.firstName ?? ''} ${message.senderInfo?.metaData?.lastName ?? ''}'
              .trim();
      final senderDisplayName = senderFullName.isNotEmpty
          ? senderFullName
          : message.senderInfo?.userName ?? '';

      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.deleteMessageOther,
          title: '${IsmChatStrings.deleteFromUser} $senderDisplayName',
          conversation: _controller.conversation,
          message: message,
          messages: groupedMediaMessages,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.deleteForMe,
              label: IsmChatStrings.deleteForMe,
              onPressed: () => _controller.deleteMessageForMe(messageMap),
            ),
          ],
        ),
      );
      if (fromMediaPrivew) IsmChatRoute.goBack();
    }
  }

  /// Same rules as multi-select forward grouping: [IsmChatMediaGridGrouping].
  List<IsmChatMessageModel> _getGroupedMediaMessagesForDeletion(
    IsmChatMessageModel message,
  ) {
    final allMessages = _controller.messages
        .where((msg) => msg.customType != IsmChatCustomMessageType.date)
        .toList();
    return IsmChatMediaGridGrouping.collectActionableGroup(allMessages, message);
  }

  /// Converts a list of messages into a map with unique keys.
  /// Keys are only for map uniqueness; delete APIs use `messageId`.
  IsmChatMessages _toUniqueMessageMap(List<IsmChatMessageModel> messages) {
    final map = <String, IsmChatMessageModel>{};
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final messageId = msg.messageId ?? '';
      final uniqueKey = messageId.isNotEmpty ? messageId : '${msg.key}-$i';
      map[uniqueKey] = msg;
    }
    return map;
  }

  void showDialogForDeleteMultipleMessage(
    bool allSelectedFromMe,
    IsmChatMessages messages,
  ) async {
    final messageCount = messages.length;
    final titleText = messageCount > 1
        ? '${IsmChatStrings.delete} $messageCount ${IsmChatStrings.messages.toLowerCase()} ?'
        : IsmChatStrings.deleteMessage;
    final canDeleteForEveryone = allSelectedFromMe &&
        messages.values.any((m) => m.isEligibleForDeleteForEveryone);

    void onDeleteSelectionCancel() {
      IsmChatRoute.goBack<void>();
      _controller.selectedMessage.clear();
      _controller.isMessageSeleted = false;
    }

    if (canDeleteForEveryone) {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.deleteMultipleOwn,
          title: titleText,
          conversation: _controller.conversation,
          messageCount: messageCount,
          onCancel: onDeleteSelectionCancel,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.deleteForEveryone,
              label: IsmChatStrings.deleteForEvery,
              onPressed: () => _controller.deleteMessageForEveryone(messages),
            ),
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.deleteForMe,
              label: IsmChatStrings.deleteForMe,
              onPressed: () => _controller.deleteMessageForMe(messages),
            ),
          ],
        ),
      );
    } else {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.deleteMultipleOther,
          title: !allSelectedFromMe
              ? '${IsmChatStrings.deleteMessages}'
              : titleText,
          conversation: _controller.conversation,
          messageCount: messageCount,
          onCancel: onDeleteSelectionCancel,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.deleteForMe,
              label: IsmChatStrings.deleteForMe,
              onPressed: () => _controller.deleteMessageForMe(messages),
            ),
          ],
        ),
      );
    }
  }

  Future<void> handleBlockUnblock([bool includeMembers = false]) async {
    if (_controller.conversation?.isSelfChat == true) {
      return;
    }
    if (_controller.conversation?.isBlockedByMe ?? false) {
      // This means chatting is not allowed and user has blocked the opponent
      showDialogForBlockUnBlockUser(true, includeMembers);
      return;
    }

    // If chatting is not allowed but I didn't block them, it means they blocked me.
    // In that state the user can't block back.
    if (!(_controller.conversation?.isChattingAllowed ?? true)) {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.cannotBlockWhenTheyBlockedMe,
          title: IsmChatStrings.cannotBlockWhenAlreadyBlocked,
          cancelLabel: IsmChatStrings.okay,
          actions: [],
        ),
      );
      return;
    }

    // This means chatting is allowed i.e. no one is blocked.
    showDialogForBlockUnBlockUser(false, includeMembers);

    // if (_controller.conversation?.isChattingAllowed ?? false) {
    // This means chatting is allowed i.e. no one is blocked
    // showDialogForBlockUnBlockUser(false, includeMembers);
    // return;
    // }

    // This means chatting is not allowed and opponent has blocked the user
    // await IsmChatContextWidget.showDialogContext(
    //   content: const IsmChatAlertDialogBox(
    //     title: IsmChatStrings.cannotBlock,
    //     cancelLabel: 'Okay',
    //   ),
    // );
  }

  Future<void> showDialogExitButton([bool askToLeave = false]) async {
    var adminCount = _controller.groupMembers.where((e) => e.isAdmin).length;
    var isUserAdmin = _controller.groupMembers.any((e) =>
        e.userId == IsmChatConfig.communicationConfig.userConfig.userId &&
        e.isAdmin);
    final conversation = _controller.conversation;
    if (adminCount == 1 && !askToLeave && isUserAdmin) {
      // Only-admin warning — host can customize via chatConfirmationPresenter.
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.exitGroupOnlyAdmin,
          title: IsmChatStrings.areYouSure,
          body: IsmChatStrings.youAreOnlyAdmin,
          conversation: conversation,
          cancelLabel: IsmChatStrings.assignAdmin,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.exitGroup,
              label: IsmChatStrings.exit,
              onPressed: () => showDialogExitButton(true),
            ),
          ],
        ),
      );
    } else {
      await _presentChatConfirmation(
        IsmChatConfirmationRequest(
          type: IsmChatConfirmationType.exitGroup,
          title: 'Exit ${conversation?.chatName ?? ''}?',
          body: IsmChatStrings.exitGroupBody,
          conversation: conversation,
          actions: [
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.exitGroup,
              label: IsmChatStrings.leaveGroup,
              onPressed: () async => await _controller.leaveGroup(
                adminCount: adminCount,
                isUserAdmin: isUserAdmin,
                mode: IsmChatLeaveGroupMode.keepHistory,
              ),
            ),
            IsmChatConfirmationAction(
              id: IsmChatConfirmationActionId.leaveGroupAndDeleteForMe,
              label: IsmChatStrings.leaveAndDeleteForMe,
              onPressed: () async => await _controller.leaveGroup(
                adminCount: adminCount,
                isUserAdmin: isUserAdmin,
                mode: IsmChatLeaveGroupMode.deleteForMe,
              ),
            ),
          ],
        ),
      );
    }
  }
}
