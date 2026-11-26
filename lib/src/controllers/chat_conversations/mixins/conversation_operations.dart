part of '../chat_conversations_controller.dart';

// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
/// Conversation operations mixin for IsmChatConversationsController.
///
/// This mixin contains methods related to conversation management including
/// fetching, updating, deleting, and searching conversations.
mixin IsmChatConversationsConversationOperationsMixin on GetxController {
  /// Gets the controller instance.
  IsmChatConversationsController get _controller =>
      this as IsmChatConversationsController;

  /// Hides self-chat rows when [IsmChatConversationProperties.enableSelfChat] is off.
  List<IsmChatConversationModel> _visibleConversations(
    Iterable<IsmChatConversationModel> source,
  ) {
    final list = source.toList();
    if (IsmChatProperties.conversationProperties.enableSelfChat) {
      return list;
    }
    return list.where((c) => !c.isSelfChat).toList();
  }

  /// Retrieves conversations from the local database and updates the observable list.
  ///
  /// `searchTag`: Optional search term for filtering conversations.
  Future<void> getConversationsFromDB({
    String? searchTag,
  }) async {
    final dbConversations =
        await IsmChatConfig.dbWrapper?.getAllConversations() ?? [];

    _controller.conversations.clear();
    if (dbConversations.isEmpty == true) {
      IsmChatProperties.conversationProperties.conversationListEmptyOrNot
          ?.call(dbConversations.isEmpty);
      return;
    }

    // Recompute lastMessageDetails from stored messages when needed.
    // This fixes cases after app restart where conversation.lastMessageDetails
    // falls back to "Conversation created" even though real messages exist in DB.
    final updatedConversations = <IsmChatConversationModel>[];
    for (final conv in dbConversations) {
      final messagesMap = conv.messages;
      final lastPreview = conv.lastMessageDetails;
      var needsRecompute = (lastPreview == null) ||
          (lastPreview?.customType ==
              IsmChatCustomMessageType.conversationCreated) ||
          (lastPreview?.customType == IsmChatCustomMessageType.block) ||
          (lastPreview?.customType == IsmChatCustomMessageType.unblock) ||
          (lastPreview?.action ==
                  IsmChatActionEvents.messageDetailsUpdated.name &&
              lastPreview!.body.trim().isEmpty);

      if (!needsRecompute &&
          lastPreview != null &&
          messagesMap != null &&
          messagesMap.isNotEmpty) {
        final previewId = lastPreview.messageId.trim();
        if (previewId.isNotEmpty) {
          for (final row in messagesMap.values) {
            if ((row.messageId ?? '').trim() != previewId) continue;
            if (row.body.trim() != lastPreview.body.trim()) {
              needsRecompute = true;
            }
            break;
          }
        }
      }

      // Empty [messages] is normal for chats not opened yet — keep API/DB preview.
      // Cleared chats null [lastMessageDetails] via [withClearedMessageHistory].
      if (!needsRecompute ||
          messagesMap == null ||
          messagesMap.isEmpty ||
          (conv.conversationId ?? '').isEmpty) {
        updatedConversations.add(conv);
        continue;
      }

      final messages = messagesMap.values.toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

      IsmChatMessageModel? lastReal;
      for (var i = messages.length - 1; i >= 0; i--) {
        final m = messages[i];
        if (m.customType == IsmChatCustomMessageType.date ||
            m.customType == IsmChatCustomMessageType.conversationCreated ||
            m.customType == IsmChatCustomMessageType.block ||
            m.customType == IsmChatCustomMessageType.unblock ||
            !m.isVisibleInGroupChat(conv)) {
          continue;
        }
        lastReal = m;
        break;
      }

      if (lastReal == null) {
        updatedConversations.add(conv);
        continue;
      }

      final base = conv.lastMessageDetails;
      final rebuilt = base != null
          ? base.copyWith(
              sentByMe: lastReal.sentByMe,
              senderId:
                  lastReal.senderInfo?.userId ?? lastReal.initiatorId ?? '',
              senderName: lastReal.senderInfo?.userName ??
                  lastReal.userName ??
                  lastReal.initiatorName ??
                  '',
              showInConversation: true,
              sentAt: lastReal.sentAt,
              messageType: lastReal.messageType?.value ?? 0,
              messageId: lastReal.messageId ?? '',
              conversationId:
                  lastReal.conversationId ?? conv.conversationId ?? '',
              body: lastReal.body,
              customType: lastReal.customType,
              action: lastReal.action,
              deliverCount: lastReal.deliveredTo?.length ?? 0,
              deliveredTo: lastReal.deliveredTo ?? const <MessageStatus>[],
              readCount: lastReal.readBy?.length ?? 0,
              readBy: lastReal.readBy ?? const <MessageStatus>[],
              initiatorId: lastReal.initiatorId,
              members:
                  lastReal.members?.map((e) => e.memberName ?? '').toList() ??
                      const <String>[],
              metaData: lastReal.metaData,
              audioOnly: lastReal.audioOnly,
              callDurations: lastReal.callDurations,
              meetingId: lastReal.meetingId,
              meetingType: lastReal.meetingType,
              isInvalidMessage: lastReal.isInvalidMessage,
            )
          : LastMessageDetails(
              showInConversation: true,
              sentAt: lastReal.sentAt,
              senderName: lastReal.senderInfo?.userName ??
                  lastReal.userName ??
                  lastReal.initiatorName ??
                  '',
              senderId:
                  lastReal.senderInfo?.userId ?? lastReal.initiatorId ?? '',
              messageType: lastReal.messageType?.value ?? 0,
              messageId: lastReal.messageId ?? '',
              conversationId:
                  lastReal.conversationId ?? conv.conversationId ?? '',
              body: lastReal.body,
              deliverCount: lastReal.deliveredTo?.length ?? 0,
              readCount: lastReal.readBy?.length ?? 0,
              sentByMe: lastReal.sentByMe,
              customType: lastReal.customType,
              members:
                  lastReal.members?.map((e) => e.memberName ?? '').toList() ??
                      const <String>[],
              action: lastReal.action,
              userId: lastReal.userId,
              initiatorId: lastReal.initiatorId,
              deliveredTo: lastReal.deliveredTo ?? const <MessageStatus>[],
              readBy: lastReal.readBy ?? const <MessageStatus>[],
              metaData: lastReal.metaData,
              audioOnly: lastReal.audioOnly,
              callDurations: lastReal.callDurations,
              meetingId: lastReal.meetingId,
              meetingType: lastReal.meetingType,
              isInvalidMessage: lastReal.isInvalidMessage,
            );

      final patched = conv.copyWith(
        lastMessageDetails: rebuilt,
        lastMessageSentAt: lastReal.sentAt,
      );
      updatedConversations.add(patched);
      // Persist so next restart also shows correct preview.
      await IsmChatConfig.dbWrapper?.saveConversation(conversation: patched);
    }

    _controller.conversations = _visibleConversations(
      updatedConversations
          .map((conversation) => conversation.normalizeOpponentDetails()),
    );
    _controller.isConversationsLoading = false;

    if (_controller.conversations.length > 1) {
      _controller.conversations.sort((a, b) {
        int sortKey(IsmChatConversationModel c) =>
            c.lastMessageDetails?.sentAt ?? c.lastMessageSentAt ?? 0;
        return sortKey(b).compareTo(sortKey(a));
      });
      final opponentEmptyData = <IsmChatConversationModel>[];
      final opponentData = <IsmChatConversationModel>[];
      for (var x in _controller.conversations) {
        if (x.isGroup == false &&
            !x.isSelfChat &&
            x.opponentDetails?.userId.isEmpty == true) {
          opponentEmptyData.add(x);
        } else {
          opponentData.add(x);
        }
      }
      opponentData.addAll(opponentEmptyData);
      _controller.conversations = opponentData;
    }

    // Always apply search filter — previously skipped when length <= 1, so a
    // single non-matching chat never showed [searchPlaceholder].
    if (searchTag?.isNotEmpty == true) {
      final rawSearchText = (searchTag ?? '').trim().toLowerCase();
      final normalizedSearchText =
          rawSearchText.replaceAll(RegExp(r'\s+'), ' ');
      _controller.conversations = _controller.conversations.where((e) {
        if (e.isGroup == true) {
          return (e.conversationTitle ?? '').toLowerCase().contains(
                    normalizedSearchText,
                  ) ||
              (e.searchableTags?.cast<String>().any(
                        (x) => x.toLowerCase().contains(normalizedSearchText),
                      ) ??
                  false);
        }
        if (e.isSelfChat) {
          final label = e.selfChatDisplayName.toLowerCase();
          final yourself = IsmChatStrings.messageYourself.toLowerCase();
          return label.contains(normalizedSearchText) ||
              yourself.contains(normalizedSearchText) ||
              normalizedSearchText.contains(yourself);
        }
        final userName = (e.opponentDetails?.userName ?? '').toLowerCase();
        final firstName =
            (e.opponentDetails?.metaData?.firstName ?? '').toLowerCase();
        final lastName =
            (e.opponentDetails?.metaData?.lastName ?? '').toLowerCase();
        final identifier =
            (e.opponentDetails?.userIdentifier ?? '').toLowerCase();
        final fullName = '$firstName $lastName'.trim();
        final fullNameRev = '$lastName $firstName'.trim();
        final normalizedFullName =
            fullName.replaceAll(RegExp(r'\s+'), ' ').trim();
        final normalizedFullNameRev =
            fullNameRev.replaceAll(RegExp(r'\s+'), ' ').trim();

        return userName.contains(normalizedSearchText) ||
            identifier.contains(normalizedSearchText) ||
            firstName.contains(normalizedSearchText) ||
            lastName.contains(normalizedSearchText) ||
            normalizedFullName.contains(normalizedSearchText) ||
            normalizedFullNameRev.contains(normalizedSearchText);
      }).toList();
    }

    if (IsmChatConfig.sortConversationWithIdentifier != null) {
      var target = IsmChatConfig.sortConversationWithIdentifier?.call();
      _controller.conversations.sort((a, b) {
        if (a.opponentDetails?.userIdentifier == target) {
          return -1;
        }
        if (b.opponentDetails?.userIdentifier == target) {
          return 1;
        }
        return -1;
      });
    }

    IsmChatProperties.conversationProperties.conversationListEmptyOrNot
        ?.call(_controller.conversations.isEmpty);
  }

  /// Fetches chat conversations from the server and updates the local
  ///
  /// `skip`: Number of conversations to skip.
  /// `origin`: The origin of the API call (e.g., refresh, load more).
  /// `searchTag`: Optional search term for filtering conversations.
  /// Returns the page fetched from the server (used by [IsmChatPullToRefresh]
  /// to decide load-complete vs no-more-data).
  Future<List<IsmChatConversationModel>> getChatConversations({
    int skip = 0,
    ApiCallOrigin? origin,
    String? searchTag,
  }) async {
    // Keep reactive search flag in sync so empty-state shows searchPlaceholder.
    // - Explicit [searchTag] updates the query (including '' to clear).
    // - Pull-to-refresh clears search.
    // - Load-more keeps the current query and re-applies it locally.
    if (searchTag != null) {
      final trimmedSearch = searchTag.trim();
      _controller.searchConversationQuery = trimmedSearch;
      _controller.searchConversationTEC.value = TextEditingValue(
        text: trimmedSearch,
        selection: TextSelection.collapsed(offset: trimmedSearch.length),
      );
    } else if (origin == ApiCallOrigin.referesh) {
      _controller.searchConversationQuery = '';
      _controller.searchConversationTEC.clear();
    }

    final resolvedSearch = () {
      if (searchTag != null) {
        final t = searchTag.trim();
        return t.isEmpty ? null : t;
      }
      if (origin == ApiCallOrigin.loadMore &&
          _controller.searchConversationQuery.trim().isNotEmpty) {
        return _controller.searchConversationQuery.trim();
      }
      return null;
    }();

    if (_controller.conversations.isEmpty) {
      _controller.isConversationsLoading = true;
    }
    var chats = await _controller.viewModel.getChatConversations(
      skip: skip,
      searchTag: resolvedSearch,
    );

    if (IsmChatProperties.conversationModifier != null) {
      chats = await Future.wait(
        chats.map(
          (e) async => await IsmChatProperties.conversationModifier!(e),
        ),
      );
      await Future.wait(
        chats.map(
          (e) async =>
              await IsmChatConfig.dbWrapper?.createAndUpdateConversation(e),
        ),
      );
    }

    // List pull-to-refresh completes via [IsmChatPullToRefresh] — do not call
    // [refreshController] here (detached controllers can confuse scroll physics).
    if (origin == ApiCallOrigin.loadMore) {
      if (chats.isEmpty) {
        _controller.refreshController.loadNoData();
        _controller.refreshControllerOnEmptyList.loadNoData();
      } else {
        _controller.refreshController.loadComplete();
        _controller.refreshControllerOnEmptyList.loadComplete();
      }
    }

    // Always fallback to local filtering.
    //
    // Reason:
    // - Server-side search may not support searching by full name (first + last)
    //   even though UI displays it.
    // - If API returns empty for queries like "liam theo", we should still be able
    //   to match cached conversations locally.
    await _controller.getConversationsFromDB(
      searchTag: resolvedSearch,
    );

    if (_controller.conversations.isEmpty) {
      _controller.isConversationsLoading = false;
    }
    return chats;
  }

  /// Fetches search results for chat conversations.
  ///
  /// `skip`: Number of conversations to skip.
  /// `origin`: The origin of the API call (e.g., refresh, load more).
  /// `chatLimit`: Maximum number of chat results to return.
  /// Returns the search page fetched from the server (used by
  /// [IsmChatPullToRefresh] to decide load-complete vs no-more-data).
  Future<List<IsmChatConversationModel>> getChatSearchConversations({
    int skip = 0,
    ApiCallOrigin? origin,
    int chatLimit = 20,
  }) async {
    if (_controller.searchConversationList.isEmpty) {
      _controller.isConversationsLoading = true;
    }

    final response = await _controller.viewModel.getChatConversations(
      skip: skip,
      chatLimit: chatLimit,
    );

    _controller.searchConversationList = response;

    if (origin == ApiCallOrigin.referesh) {
      _controller.searchConversationrefreshController.refreshCompleted(
        resetFooterState: true,
      );
    } else if (origin == ApiCallOrigin.loadMore) {
      _controller.searchConversationrefreshController.loadComplete();
    }
    _controller.isConversationsLoading = false;
    return response;
  }

  /// Retrieves the conversation ID for a given user ID.
  ///
  /// `userId`: The ID of the user to find the conversation for.
  String getConversationId(String userId) {
    // Groups do not have a unique opponentDetails.userId — matching only on
    // userId would return the first group that shares a member, which breaks
    // when multiple groups contain the same person.
    final conversation = _controller.conversations.firstWhere(
      (element) =>
          element.isGroup != true && element.opponentDetails?.userId == userId,
      orElse: IsmChatConversationModel.new,
    );

    if (conversation.conversationId == null) {
      return '';
    }
    return conversation.conversationId ?? '';
  }

  /// Retrieves a conversation model based on the conversation ID.
  ///
  /// `conversationId`: The ID of the conversation to retrieve.
  IsmChatConversationModel? getConversation(String conversationId) {
    final conversation = _controller.conversations.firstWhere(
        (element) => element.conversationId == conversationId,
        orElse: IsmChatConversationModel.new);

    if (conversation.conversationId == null) {
      return null;
    }
    return conversation;
  }

  /// Deletes a chat based on the conversation ID
  ///
  /// `conversationId`: The ID of the conversation to delete.
  /// `deleteFromServer`: Indicates if the chat should be deleted from the server.
  /// `shouldUpdateLocal`: Indicates if the local database should be updated.
  Future<void> deleteChat(
    String? conversationId, {
    bool deleteFromServer = true,
    bool shouldUpdateLocal = true,
  }) async {
    if (conversationId.isNullOrEmpty) return;

    if (deleteFromServer) {
      final response =
          await _controller.viewModel.deleteChat(conversationId ?? '');
      if (response?.hasError ?? true) return;
    }
    if (shouldUpdateLocal) {
      final isCurrentConversation =
          _controller.currentConversationId == conversationId;
      if (isCurrentConversation) {
        _controller.currentConversation = null;
        _controller.currentConversationId = '';
        _controller.isRenderChatPageaScreen = IsRenderChatPageScreen.none;
        if (IsmChatUtility.chatPageControllerRegistered) {
          final chatPageController = IsmChatUtility.chatPageController;
          chatPageController
            ..messages.clear()
            ..conversation = null
            ..isMessageSeleted = false
            ..selectedMessage.clear()
            ..closeOverlay();
        }
      }
      await IsmChatConfig.dbWrapper?.removeConversation(conversationId ?? '');
      await _controller.getConversationsFromDB();
      if (deleteFromServer) {
        await _controller.getChatConversations();
      }
    }
  }

  /// Clears all messages in a conversation.
  ///
  /// `conversationId`: The ID of the conversation to clear messages from.
  ///  `fromServer`: Indicates if the clear action should be performed on the server.
  Future<void> clearAllMessages(String? conversationId,
      {bool fromServer = true}) async {
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }
    return _controller.viewModel
        .clearAllMessages(conversationId, fromServer: fromServer);
  }

  /// Updates the current conversation with new details.
  ///
  /// `conversation`: The conversation model to update.
  ///
  /// Reusability note:
  /// - Used both when **switching** chats and when **patching** the open chat
  ///   (e.g. unblock clears `messagingDisabled`).
  /// - Only clear the in-memory message list when the conversation id changes.
  ///   Clearing on same-id metadata updates caused a brief empty-state flash
  ///   ("This is the beginning of your chat history...") after unblock.
  Future<void> updateLocalConversation(
      IsmChatConversationModel conversation) async {
    final normalizedConversation = conversation.normalizeOpponentDetails();
    final previousConversationId = _controller.currentConversationId;
    final nextConversationId = normalizedConversation.conversationId ?? '';
    final isSwitchingConversation =
        previousConversationId != nextConversationId;

    _controller.currentConversation = normalizedConversation;
    _controller.currentConversationId = nextConversationId;

    // The chat page controller is often reused (especially on web). Point it
    // at the newly selected conversation *immediately* so any in-flight
    // `getConverstaionDetails` for a previously exited group cannot win the
    // race and keep using the old conversationId.
    if (IsmChatUtility.chatPageControllerRegistered) {
      final chatPage = IsmChatUtility.chatPageController;
      if (isSwitchingConversation) {
        chatPage
          ..conversation = normalizedConversation
          ..isActionAllowed = false
          ..isCoverationApiDetails = true
          ..canCallCurrentApi = false
          ..messages.clear();
      } else {
        // Same open chat: keep the visible message list; only refresh metadata.
        chatPage.conversation = normalizedConversation.copyWith(
          messages: normalizedConversation.messages ??
              chatPage.conversation?.messages,
        );
      }
    }

    // Persist metadata, but never wipe Hive messages on a metadata-only update
    // that omitted the messages map (common for unblock / list-driven patches).
    var toSave = normalizedConversation;
    if (!isSwitchingConversation &&
        (toSave.messages == null || toSave.messages!.isEmpty) &&
        nextConversationId.isNotEmpty) {
      final existing =
          await IsmChatConfig.dbWrapper?.getConversation(nextConversationId);
      if (existing?.messages?.isNotEmpty == true) {
        toSave = toSave.copyWith(messages: existing!.messages);
      }
    }
    await IsmChatConfig.dbWrapper?.saveConversation(
      conversation: toSave,
    );
  }

  /// Updates a conversation's metadata on the server.
  ///
  /// `conversationId`: The ID of the conversation to update.
  /// `metaData`: The new metadata for the conversation.
  /// `isLoading`: Indicates if loading should be shown.
  Future<void> updateConversation({
    required String conversationId,
    required IsmChatMetaData metaData,
    bool includeNullBlockedMessage = false,
    bool isLoading = false,
  }) async {
    final response = await _controller.viewModel.updateConversation(
      conversationId: conversationId,
      metaData: metaData,
      includeNullBlockedMessage: includeNullBlockedMessage,
      isLoading: isLoading,
    );
    if (response?.hasError == false) {
      await _controller.getChatConversations();
    }
  }

  /// Updates the settings of a conversation.
  ///
  /// `conversationId`: The ID of the conversation to update.
  /// `events`: The events to update in the conversation.
  /// `isLoading`: Indicates if loading should be shown.
  Future<void> updateConversationSetting({
    required String conversationId,
    required IsmChatEvents events,
    bool isLoading = false,
  }) async {
    await _controller.viewModel.updateConversationSetting(
      conversationId: conversationId,
      events: events,
      isLoading: isLoading,
    );
  }

  /// Updates push-notification (mute) settings for a conversation.
  ///
  /// `pushNotification`: `true` to enable notifications, `false` to mute.
  Future<bool> updateConversationNotifications({
    required String conversationId,
    required bool pushNotification,
    bool isLoading = false,
  }) async {
    final response =
        await _controller.viewModel.updateConversationNotifications(
      conversationId: conversationId,
      pushNotification: pushNotification,
      isLoading: isLoading,
    );
    if (response == null || response.hasError) {
      return false;
    }
    await _syncLocalPushNotifications(
      conversationId: conversationId,
      pushNotifications: pushNotification,
    );
    return true;
  }

  /// Persists mute / push-notification setting across DB, list, and open chat.
  Future<void> _syncLocalPushNotifications({
    required String conversationId,
    required bool pushNotifications,
  }) async {
    var conversation =
        await IsmChatConfig.dbWrapper?.getConversation(conversationId);
    conversation ??= getConversation(conversationId);
    if (conversation == null &&
        IsmChatUtility.chatPageControllerRegistered &&
        IsmChatUtility.chatPageController.conversation?.conversationId ==
            conversationId) {
      conversation = IsmChatUtility.chatPageController.conversation;
    }
    if (conversation == null) return;

    final currentUserId =
        IsmChatConfig.communicationConfig.userConfig.userId.trim();
    final updatedMembers = (conversation.members ?? const <UserDetails>[])
        .map(
          (member) => member.userId.trim() == currentUserId
              ? member.copyWith(pushNotification: pushNotifications)
              : member,
        )
        .toList();

    final updated = conversation.copyWith(
      pushNotifications: pushNotifications,
      members: updatedMembers.isEmpty ? conversation.members : updatedMembers,
      config: (conversation.config ??
              ConversationConfigModel(
                typingEvents: true,
                readEvents: true,
                pushNotifications: pushNotifications,
              ))
          .copyWith(pushNotifications: pushNotifications),
    );

    await IsmChatConfig.dbWrapper?.saveConversation(conversation: updated);

    final index = _controller.conversations
        .indexWhere((e) => e.conversationId == conversationId);
    if (index != -1) {
      final list =
          List<IsmChatConversationModel>.from(_controller.conversations);
      list[index] = updated;
      _controller.conversations = list;
    }

    if (_controller.currentConversationId == conversationId) {
      _controller.currentConversation = updated;
    }

    if (IsmChatUtility.chatPageControllerRegistered) {
      final chatController = IsmChatUtility.chatPageController;
      if (chatController.conversation?.conversationId == conversationId) {
        chatController.conversation = updated;
      }
    }
  }

  int _groupAdminCount(IsmChatConversationModel conversation) {
    final count =
        (conversation.members ?? []).where((member) => member.isAdmin).length;
    if (count == 0 && _isCurrentUserGroupAdmin(conversation)) {
      return 1;
    }
    return count;
  }

  bool _isCurrentUserGroupAdmin(IsmChatConversationModel conversation) =>
      conversation.usersOwnDetails?.isAdmin ??
      (conversation.members ?? []).any(
        (member) =>
            member.userId ==
                IsmChatConfig.communicationConfig.userConfig.userId &&
            member.isAdmin,
      );

  Future<void> showExitGroupDialog(
    IsmChatConversationModel conversation, [
    bool askToLeave = false,
  ]) async {
    final adminCount = _groupAdminCount(conversation);
    final isUserAdmin = _isCurrentUserGroupAdmin(conversation);
    if (adminCount == 1 && !askToLeave && isUserAdmin) {
      // Only-admin warning — same presenter path as Group Info exit.
      await IsmChatConfirmationHelper.present(
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
              onPressed: () => showExitGroupDialog(conversation, true),
            ),
          ],
        ),
      );
      return;
    }

    await IsmChatConfirmationHelper.present(
      IsmChatConfirmationRequest(
        type: IsmChatConfirmationType.exitGroup,
        title: 'Exit ${conversation.chatName}?',
        body: IsmChatStrings.exitGroupBody,
        conversation: conversation,
        actions: [
          IsmChatConfirmationAction(
            id: IsmChatConfirmationActionId.exitGroup,
            label: IsmChatStrings.exitGroup,
            onPressed: () async => leaveGroup(
              conversation: conversation,
              adminCount: adminCount,
              isUserAdmin: isUserAdmin,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> leaveGroup({
    required IsmChatConversationModel conversation,
    required int adminCount,
    required bool isUserAdmin,
  }) async {
    final conversationId = conversation.conversationId ?? '';
    if (conversationId.isEmpty) {
      return;
    }

    if (IsmChatUtility.chatPageControllerRegistered &&
        IsmChatUtility.chatPageController.conversation?.conversationId ==
            conversationId) {
      await IsmChatUtility.chatPageController.leaveGroup(
        adminCount: adminCount,
        isUserAdmin: isUserAdmin,
      );
      return;
    }

    if (adminCount == 1 && isUserAdmin) {
      final members = (conversation.members ?? [])
          .where((member) => !member.isAdmin)
          .toList();
      if (members.isNotEmpty) {
        final member = members[Random().nextInt(members.length)];
        final didPromote = await _controller.viewModel.makeAdmin(
          memberId: member.userId,
          conversationId: conversationId,
          isLoading: true,
        );
        if (!didPromote) {
          return;
        }
      }
    }

    final didLeft = await _controller.viewModel.leaveConversation(
      conversationId,
      isLoading: true,
    );
    if (!didLeft) {
      return;
    }

    final isCurrentConversation =
        _controller.currentConversationId == conversationId;
    if (isCurrentConversation) {
      _controller.currentConversation = null;
      _controller.currentConversationId = '';
      _controller.isRenderChatPageaScreen = IsRenderChatPageScreen.none;
      if (IsmChatUtility.chatPageControllerRegistered) {
        final chatPageController = IsmChatUtility.chatPageController;
        chatPageController
          ..messages.clear()
          ..conversation = null
          ..isMessageSeleted = false
          ..selectedMessage.clear()
          ..closeOverlay();
      }
    }

    await Future.wait([
      IsmChatConfig.dbWrapper!.removeConversation(conversationId),
      _controller.getChatConversations(),
    ]);
  }

  /// Filters suggestions based on the search query.
  ///
  /// `query`: The search query to filter suggestions.
  void onSearch(String query) {
    if (query.trim().isEmpty) {
      _controller.suggestions = _controller.conversations;
    } else {
      _controller.suggestions = _controller.conversations
          .where(
            (e) =>
                e.chatName.didMatch(query) ||
                (e.isSelfChat &&
                    IsmChatStrings.messageYourself.didMatch(query)) ||
                e.lastMessageDetails!.body.didMatch(query),
          )
          .toList();
    }
  }

  IsmChatConversationModel? _findSelfChatInList(
    Iterable<IsmChatConversationModel> list,
  ) {
    for (final c in list) {
      if (c.isSelfChat && (c.conversationId ?? '').isNotEmpty) {
        return c;
      }
    }
    return null;
  }

  /// Calls `POST /chat/conversation` with `selfChat: true`. No-op when the
  /// feature flag is off.
  Future<IsmChatConversationModel?> createSelfChat({
    bool isLoading = true,
  }) async {
    if (!IsmChatProperties.conversationProperties.enableSelfChat) {
      return null;
    }
    return _controller.commonController.createSelfChat(isLoading: isLoading);
  }

  /// Opens the user's self chat. Reuses an existing row when present;
  /// otherwise navigates with [IsmChatConversationModel.selfChatPlaceholder]
  /// and creates on the API at first send (see send path `createConversation`).
  Future<void> openSelfChat({bool isLoading = true}) async {
    if (!IsmChatProperties.conversationProperties.enableSelfChat) {
      return;
    }

    var conversation =
        _findSelfChatInList(_controller.conversations) ??
            _findSelfChatInList(
              await IsmChatConfig.dbWrapper?.getAllConversations() ??
                  const [],
            );

    if (conversation == null) {
      final cached = _controller.userDetails;
      final configName =
          IsmChatConfig.communicationConfig.userConfig.userName?.trim() ?? '';
      final hasDisplayName = cached != null &&
          (cached.displayName.trim().isNotEmpty || cached.profileUrl.isNotEmpty);
      if (!hasDisplayName && configName.isEmpty) {
        await _controller.getUserData();
      }
      conversation = IsmChatConversationModel.selfChatPlaceholder();
    }

    await _controller.updateLocalConversation(
      conversation.normalizeOpponentDetails(),
    );
    await _controller.goToChatPage();
  }
}
