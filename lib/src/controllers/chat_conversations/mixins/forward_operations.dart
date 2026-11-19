part of '../chat_conversations_controller.dart';

// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
/// Forward operations mixin for IsmChatConversationsController.
///
/// This mixin contains methods related to forwarding messages and managing
/// user selection for forwarding and creating conversations.
mixin IsmChatConversationsForwardOperationsMixin on GetxController {
  /// Gets the controller instance.
  IsmChatConversationsController get _controller =>
      this as IsmChatConversationsController;

  /// Select / unselect a user on forward, group, and broadcast pickers.
  ///
  /// Also refreshes GetX: [SelectedMembers.isUserSelected] is an internal [RxBool],
  /// so toggling it alone does not rebuild [GetX] builders.
  void onForwardUserTap(int index) {
    _controller.forwardedList[index].isUserSelected =
        !_controller.forwardedList[index].isUserSelected;
    _controller.forwardedList =
        List<SelectedMembers>.from(_controller.forwardedList);
    _controller.update();
  }

  /// This function will be used in [Forward Screen and New conversation screen] Adds or removes a user from the selected user list based on their selection state.
  ///
  ///  `userDetails`: The user to be selected or deselected.
  void isSelectedUser(UserDetails userDetails) {
    final updated = List<UserDetails>.from(_controller.selectedUserList);
    if (updated.any((e) => e.userId == userDetails.userId)) {
      updated.removeWhere((e) => e.userId == userDetails.userId);
    } else {
      updated.add(userDetails);
    }
    _controller.selectedUserList = updated;
    _controller.update();
  }

  /// Sends a forwarded message to specified users.
  ///
  ///  `userIds`: List of user IDs to send the message to.
  /// `body`: The body of the message.
  /// `attachments`: Optional attachments for the message.
  /// `customType`: Optional custom type for the message.
  /// `isLoading`: Indicates if loading should be shown.
  /// `metaData`: Optional metadata for the message.
  Future<void> sendForwardMessage({
    required List<String> userIds,
    required String body,
    List<Map<String, dynamic>>? attachments,
    String? customType,
    bool isLoading = false,
    IsmChatMetaData? metaData,
  }) async {
    final response = await _controller.viewModel.sendForwardMessage(
      userIds: userIds,
      showInConversation: true,
      messageType: IsmChatMessageType.forward.value,
      encrypted: true,
      deviceId: IsmChatConfig.communicationConfig.projectConfig.deviceId,
      body: body,
      notificationBody: body,
      notificationTitle:
          IsmChatConfig.communicationConfig.userConfig.userName ??
              _controller.userDetails?.userName ??
              '',
      isLoading: isLoading,
      searchableTags: [body],
      customType: customType,
      attachments: attachments,
      events: {'updateUnreadCount': true, 'sendPushNotification': true},
      metaData: metaData,
    );
    if (response?.hasError == false) {
      IsmChatRoute.goBack();
    }
  }

  /// Initializes the state for creating a new conversation.
  ///
  /// `isGroupConversation`: Indicates if the conversation is a group chat.
  Future<void> initCreateConversation([bool isGroupConversation = false]) async {
    _controller.callApiOrNot = true;
    _controller.profileImage = '';
    _controller.forwardedList.clear();
    _controller.selectedUserList.clear();
    _controller.addGrouNameController.clear();
    _controller.forwardedList.selectedUsers.clear();
    _controller.userSearchNameController.clear();
    _controller.isLoadResponse = false;
    await _controller.getNonBlockUserList(
      opponentId: IsmChatConfig.communicationConfig.userConfig.userId,
      isGroupConversation: isGroupConversation,
    );

    // No need for background loading - contacts will be fetched on-demand when alphabet is clicked
    if (!isGroupConversation) {
      await _controller.getContacts();
    }
  }
}

