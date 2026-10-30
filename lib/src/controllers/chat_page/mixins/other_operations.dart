part of '../chat_page_controller.dart';

/// Other operations mixin for IsmChatPageController.
///
/// This mixin handles various miscellaneous operations like leaving groups,
/// location operations, reactions, user details, timers, and audio recording.
mixin IsmChatPageOtherOperationsMixin on GetxController {
  /// Gets the controller instance.
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Starts the recording timer.
  void startTimer() {
    _controller.forRecordTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      var seconds = _controller.myDuration.inSeconds + 1;
      _controller.myDuration = Duration(seconds: seconds);
    });
  }

  /// Leaves a group conversation.
  Future<void> leaveGroup({
    required int adminCount,
    required bool isUserAdmin,
  }) async {
    final conversationId = _controller.conversation?.conversationId ?? '';
    if (conversationId.isEmpty) return;
    if (adminCount == 1 && isUserAdmin) {
      final members =
          _controller.groupMembers.where((e) => !e.isAdmin).toList();
      final member = members[Random().nextInt(members.length)];
      await _controller.makeAdmin(member.userId, member.userName, false);
    }
    final didLeft = await _controller.leaveConversation(conversationId);
    if (didLeft) {
      // Clear BOTH conversation controllers. Leaving only
      // `currentConversation` null while keeping `conversation` set to the
      // exited group lets a late `getConverstaionDetails` response write that
      // old conversationId back as "current", so the next group opens with
      // the wrong ID in the conversation-details API.
      _controller.conversationController
        ..currentConversation = null
        ..currentConversationId = ''
        ..isRenderChatPageaScreen = IsRenderChatPageScreen.none;
      _controller
        ..conversation = null
        ..isActionAllowed = false
        ..isCoverationApiDetails = true
        ..canCallCurrentApi = false
        ..messages.clear()
        ..selectedMessage.clear()
        ..isMessageSeleted = false;
      IsmChatRoute.goBack(); // to Chat Page
      IsmChatRoute.goBack(); // to Conversation Page
      await Future.wait([
        IsmChatConfig.dbWrapper!.removeConversation(conversationId),
        _controller.conversationController.getChatConversations(),
      ]);
    }
  }

  /// Gets location predictions based on latitude, longitude, and search keyword.
  Future<void> getLocation(
      {required String latitude,
      required String longitude,
      String searchKeyword = ''}) async {
    _controller.predictionList.clear();
    _controller.isLocaionSearch = true;
    final response = await _controller.viewModel.getLocation(
      latitude: latitude,
      longitude: longitude,
      searchKeyword: searchKeyword,
    );
    _controller.isLocaionSearch = false;
    if (response == null || response.isEmpty) {
      return;
    }
    _controller.predictionList = response;
  }

  /// Deletes a reaction from a message.
  Future<void> deleteReacton({required Reaction reaction}) async {
    var response =
        await _controller.viewModel.deleteReacton(reaction: reaction);
    if (response != null && !response.hasError) {
      await _controller.conversationController.getChatConversations();
    }
  }

  /// Shows user details.
  Future<void> showUserDetails(UserDetails userDetails,
      {bool fromMessagePage = true}) async {
    final conversationId = _controller.conversationController.getConversationId(
      userDetails.userId,
    );
    final conversationUser =
        await IsmChatConfig.dbWrapper!.getConversation(conversationId);
    UserDetails? user;
    if (conversationUser != null) {
      user = conversationUser.opponentDetails;
    } else {
      user = userDetails;
    }
    _controller.conversationController.contactDetails = user;
    _controller.conversationController.userConversationId = conversationId;
    if (IsmChatResponsive.isWeb(
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context)) {
      _controller.conversationController.isRenderChatPageaScreen =
          IsRenderChatPageScreen.userInfoView;
    } else {
      await IsmChatRoute.goToRoute(
        IsmChatUserInfo(
          conversationId: conversationId,
          user: user!,
          fromMessagePage: fromMessagePage,
        ),
      );
    }
  }

  /// Handles @-mention taps in message bodies.
  ///
  /// Always opens the mentioned user's 1:1 chat (same rebind flow as
  /// [IsmChatUserInfo] → Message). Does not open contact info.
  Future<void> onMentionUserTapped(UserDetails userDetails) async {
    await openDirectChatWithUser(userDetails);
  }

  /// Resolves the user for [@mentionText] on [message] and opens their DM.
  Future<void> onMentionLinkTapped(
    IsmChatMessageModel message,
    String mentionText,
  ) async {
    if (!mentionText.startsWith('@')) return;
    final user = message.resolveMentionedUser(mentionText.substring(1));
    if (user == null) return;
    final userId = user.userId.trim().isNotEmpty
        ? user.userId.trim()
        : (user.memberId?.trim() ?? '');
    if (userId.isEmpty || isCurrentChatUser(userId)) return;
    await openDirectChatWithUser(
      user.userId.trim().isNotEmpty ? user : user.copyWith(userId: userId),
    );
  }

  /// Switches the open chat route to a 1:1 conversation with [userDetails].
  ///
  /// Same rebind flow as [IsmChatUserInfo] → Message: updates the shared chat
  /// route via [setRebindConversationId] + [startInit]. Does not call
  /// [IsmChatConversationProperties.onChatTap] (that often pushes another chat
  /// route and duplicates the screen with an empty history).
  Future<void> openDirectChatWithUser(UserDetails userDetails) async {
    final opponentId = userDetails.userId.trim().isNotEmpty
        ? userDetails.userId.trim()
        : (userDetails.memberId?.trim() ?? '');
    if (opponentId.isEmpty) return;
    final opponent = userDetails.userId.trim().isNotEmpty
        ? userDetails
        : userDetails.copyWith(userId: opponentId);

    final conversationController = _controller.conversationController;
    var targetConversationId =
        conversationController.getConversationId(opponentId);
    final currentConversationId =
        _controller.conversation?.conversationId ?? '';

    if (targetConversationId.isNotEmpty &&
        targetConversationId == currentConversationId) {
      return;
    }

    IsmChatUtility.showLoader();

    IsmChatConversationModel? conversationModel;
    if (targetConversationId.isNotEmpty) {
      conversationModel =
          await IsmChatConfig.dbWrapper?.getConversation(targetConversationId);
      conversationModel ??=
          conversationController.getConversation(targetConversationId);
    }

    if (targetConversationId.isEmpty || conversationModel == null) {
      final local = await IsmChatConfig.dbWrapper?.getAllConversations();
      for (final cached in local ?? const <IsmChatConversationModel>[]) {
        if (cached.isGroup == true) continue;
        if (cached.opponentDetails?.userId.trim() == opponentId) {
          targetConversationId = cached.conversationId?.trim() ?? '';
          conversationModel = cached;
          break;
        }
      }
    }

    conversationModel ??= IsmChatConversationModel(
      messagingDisabled: false,
      isGroup: false,
      opponentDetails: opponent,
      unreadMessagesCount: 0,
      lastMessageDetails: null,
      lastMessageSentAt: 0,
      membersCount: 1,
      conversationId: targetConversationId,
    );

    if (targetConversationId != currentConversationId) {
      await conversationController.updateLocalConversation(conversationModel);
      _controller
        ..setRebindConversationId(
          targetConversationId.isNotEmpty
              ? targetConversationId
              : conversationModel.conversationId ?? '',
        )
        ..isMessagesLoading = true;
    }

    _controller.closeOverlay();

    if (IsmChatResponsive.isWeb(
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context)) {
      conversationController.isRenderChatPageaScreen =
          IsRenderChatPageScreen.none;
    }

    IsmChatUtility.closeLoader();
    unawaited(Future.microtask(_controller.startInit));
  }

  /// Checks if an audio encoder is supported.
  Future<bool> isEncoderSupported(AudioEncoder encoder) async {
    final isSupported = await _controller.recordVoice.isEncoderSupported(
      encoder,
    );

    if (!isSupported) {
      await IsmChatContextWidget.showDialogContext(
        content: IsmChatAlertDialogBox(
          title: '${encoder.name} is not supported on this platform.',
          cancelLabel: IsmChatStrings.okay,
        ),
      );
    }
    return isSupported;
  }

  /// Deletes the current recording.
  void recordDelete() {
    _controller.isEnableRecordingAudio = false;
    _controller.showSendButton = false;
    _controller.forRecordTimer?.cancel();
    _controller.seconds = 0;
  }

  /// Plays or pauses voice recording.
  Future<void> recordPlayPauseVoice() async {
    if (await _controller.recordVoice.isPaused()) {
      await _controller.recordVoice.resume();
      _controller.isRecordPlay = true;
      _controller.forRecordTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        _controller.seconds++;
      });
    } else {
      await _controller.recordVoice.pause();
      _controller.isRecordPlay = false;
      _controller.forRecordTimer?.cancel();
    }
  }
}
