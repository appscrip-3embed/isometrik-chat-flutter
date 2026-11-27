part of '../chat_page_controller.dart';

// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
mixin IsmChatPageGetMessageMixin on GetxController {
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

  /// Max immediate re-reads when a save lands during the Hive read.
  static const int _maxStaleReadRetries = 3;

  Future<void> getMessagesFromDB(String conversationId,
      [IsmChatDbBox dbBox = IsmChatDbBox.main, int staleRetry = 0]) async {
    _controller.closeOverlay();
    final requestedConversationId = conversationId;

    await IsmChatBlockUnblockCoordinator.pruneBlockBannersIfChatAllowed(
      conversationId,
    );

    // Option A: ensure banner row exists only while chat is actually blocked.
    final conv = _controller.conversation;
    if (conv != null &&
        IsmChatBlockUnblockCoordinator.isConversationBlocked(conv)) {
      final cachedBeforeEnsure =
          await IsmChatConfig.dbWrapper?.getConversation(conversationId);
      final hasBlockBanner = cachedBeforeEnsure?.messages?.values.any(
            (m) => m.customType == IsmChatCustomMessageType.block,
          ) ??
          false;
      if (!hasBlockBanner) {
        await IsmChatBlockUnblockCoordinator.ensureBlockBannerForDisabledChat(
          conv,
        );
      }
      final refreshed =
          await IsmChatConfig.dbWrapper?.getConversation(conversationId);
      if (refreshed != null) {
        _controller.conversation = _controller.conversation?.copyWith(
              messagingDisabled: refreshed.messagingDisabled,
            ) ??
            refreshed;
      }
    }

    // Captured immediately before the Hive read. A message insert or queued
    // save during the awaits below bumps [messagesGeneration]; applying this
    // older list would hide those rows.
    final generation = _controller.messagesGeneration;
    final messages =
        await IsmChatConfig.dbWrapper?.getMessage(conversationId, dbBox);
    // Guard against race conditions: if user switched chat while this async DB
    // read was running, ignore this result so messages from old chat don't show.
    if ((_controller.conversation?.conversationId ?? '') !=
        requestedConversationId) {
      _controller.isMessagesLoading = false;
      return;
    }
    if (generation != _controller.messagesGeneration) {
      return _retryStaleMessagesRead(conversationId, dbBox, staleRetry);
    }
    // If local cache is empty, continue with an empty map so we can still
    // render the base conversation-created row and let API sync fill messages.
    final safeMessages = messages ?? <String, IsmChatMessageModel>{};

    if (IsmChatConfig.shouldPendingMessageSend) {
      var pendingmessages = await IsmChatConfig.dbWrapper
          ?.getMessage(conversationId, IsmChatDbBox.pending);
      if (pendingmessages != null) {
        safeMessages.addAll(pendingmessages);
      }
    } else {
      await IsmChatConfig.dbWrapper
          ?.removeConversation(conversationId, IsmChatDbBox.pending);
    }
    var localMessages = safeMessages.values.toList();
    if (!IsmChatBlockUnblockCoordinator.isConversationBlocked(
      _controller.conversation,
    )) {
      IsmChatBlockUnblockCoordinator.removeBannerRowsFromList(localMessages);
    }
    if (localMessages.isNotEmpty) {
      localMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    }
    if (localMessages.isEmpty) {
      localMessages = insertEndtoEndMessage(
        timeStamp: DateTime.now().millisecondsSinceEpoch,
        messages: localMessages,
      );
    } else if (localMessages.first.customType !=
        IsmChatCustomMessageType.conversationCreated) {
      localMessages = insertEndtoEndMessage(
        timeStamp: localMessages.first.sentAt - 5,
        messages: localMessages,
      );
    }
    if ((_controller.conversation?.conversationId ?? '') !=
        requestedConversationId) {
      _controller.isMessagesLoading = false;
      return;
    }
    if (generation != _controller.messagesGeneration) {
      return _retryStaleMessagesRead(conversationId, dbBox, staleRetry);
    }
    final merged = IsmChatThreadCoordinator.mergeThreadRootBadgesInList(
      localMessages,
      _controller.messages,
    );
    _controller.messages = _controller.commonController
        .sortMessages(filterMessages(merged));
    IsmChatThreadController.instance?.syncReactionsFromCache(safeMessages.values);
    IsmChatThreadController.instance
        ?.syncOpenThreadFromChannel(_controller.messages);
    _controller.isMessagesLoading = false;
    _controller._generateIndexedMessageList();
    update();
  }

  /// A save landed while Hive was being read, so that snapshot may be missing
  /// rows. Dropping it used to leave the list empty after chat open (it is
  /// cleared first), showing "No messages" with nothing to retry. Re-read
  /// now; after a few tries fall back to a debounced reload.
  Future<void> _retryStaleMessagesRead(
    String conversationId,
    IsmChatDbBox dbBox,
    int staleRetry,
  ) async {
    if (staleRetry < _maxStaleReadRetries) {
      return getMessagesFromDB(conversationId, dbBox, staleRetry + 1);
    }
    // Keep the loader while empty; the scheduled reload will fill the list.
    if (_controller.messages.isNotEmpty) {
      _controller.isMessagesLoading = false;
    }
    scheduleMessagesReload(conversationId);
  }

  /// Reloads [conversationId] once a short burst of MQTT messages settles.
  ///
  /// Each incoming group message used to start its own [getMessagesFromDB].
  /// Those reads overlapped and the oldest one painted last, removing rows
  /// that a newer event had already shown. Later calls replace the pending
  /// reload instead of stacking another one.
  void scheduleMessagesReload(String conversationId) {
    if (conversationId.isEmpty) return;
    _controller._pendingMessagesReloadId = conversationId;
    _controller._messagesReloadTimer?.cancel();
    _controller._messagesReloadTimer = Timer(
      const Duration(milliseconds: 50),
      () {
        final id = _controller._pendingMessagesReloadId;
        _controller._pendingMessagesReloadId = null;
        _controller._messagesReloadTimer = null;
        if (id == null || id.isEmpty) return;
        if ((_controller.conversation?.conversationId ?? '') != id) return;
        unawaited(getMessagesFromDB(id));
      },
    );
  }

  List<IsmChatMessageModel> insertEndtoEndMessage(
      {required int timeStamp, required List<IsmChatMessageModel> messages}) {
    messages.insert(
      0,
      IsmChatMessageModel(
        body: '',
        customType: IsmChatCustomMessageType.conversationCreated,
        sentAt: timeStamp,
        sentByMe: true,
      ),
    );
    return messages;
  }

  List<IsmChatMessageModel> filterMessages(List<IsmChatMessageModel> messages) {
    var filterMessage = IsmChatMessageModel(
        body: '', sentAt: 0, customType: null, sentByMe: false);
    var dummymessages = List<IsmChatMessageModel>.from(messages);
    for (var x in dummymessages) {
      if (!x.isSdkCallBubbleMessage) {
        continue;
      }
      if (x.meetingId != filterMessage.meetingId) {
        filterMessage = x;
        continue;
      }
      if (x.action == IsmChatActionEvents.meetingCreated.name) {
        filterMessage = filterMessage.copyWith(meetingType: x.meetingType);
      } else {
        // Keep the first row's sentAt so the bubble stays in place when updated.
        final anchorSentAt = filterMessage.sentAt;
        filterMessage = x.copyWith(
          meetingType: filterMessage.meetingType ?? x.meetingType,
          sentAt: anchorSentAt,
        );
      }
      messages.removeWhere((e) =>
          e.action == IsmChatActionEvents.meetingCreated.name &&
          e.meetingId == x.meetingId);

      var fliterIndex = messages.indexWhere((e) => e.meetingId == x.meetingId);
      if (fliterIndex != -1) {
        // Merged row may pick [sentByMe] from a follow-up event (e.g. hang-up)
        // with wrong flags; normalize from initiator/sender like [fromMap].
        messages[fliterIndex] = filterMessage.copyWith(
          sentByMe: IsmChatMessageModel.resolveSentByMe(filterMessage),
        );
      }
    }
    messages.removeWhere(
      (m) => !m.isVisibleInGroupChat(_controller.conversation),
    );
    IsmChatGroupSystemMessageCoordinator.dedupeMemberLeaveTimelineRows(messages);
    // Slack-style threads: replies that live only in a thread never belong in
    // the channel list. No-op while IsmChatConfig.threadsEnabled is false, so
    // cached inline replies keep rendering as they do today.
    messages.removeWhere(IsmChatThreadCoordinator.shouldHideFromTimeline);
    return messages;
  }

  /// Whether [message] is a row the server also has (counts toward `skip`).
  ///
  /// Excludes UI-only date / conversation-created rows, local block banners,
  /// and pending sends (no `messageId` yet) — none of those occupy a server
  /// offset, so counting them would skip real older messages.
  bool _isServerBackedRow(IsmChatMessageModel message) =>
      message.customType != IsmChatCustomMessageType.date &&
      message.customType != IsmChatCustomMessageType.conversationCreated &&
      !IsmChatBlockUnblockCoordinator.isBannerMessage(message) &&
      (message.messageId ?? '').isNotEmpty;

  /// Count of server-backed chat rows (see [_isServerBackedRow]).
  int _realMessageCount(List<IsmChatMessageModel> messages) =>
      messages.where(_isServerBackedRow).length;

  /// `skip` for the next older page.
  ///
  /// Once a fetch has happened this is the raw server offset reached so far,
  /// plus rows that arrived after it was recorded (they push older rows
  /// further down on the server). Before any fetch, falls back to the local
  /// row count.
  int _olderPagingSkip(List<IsmChatMessageModel> messages) {
    final rawSkip = _controller.olderPagingRawSkip;
    if (rawSkip == null) return _realMessageCount(messages);
    final anchor = _controller.olderPagingAnchorSentAt;
    final arrivedSince = messages
        .where((m) => _isServerBackedRow(m) && m.sentAt > anchor)
        .length;
    return rawSkip + arrivedSince;
  }

  /// Records how far into server history we are after a chat-messages fetch.
  void _recordOlderPaging({
    required ({int skip, int? lastMessageTimestamp}) paging,
    required bool forPagination,
    required List<IsmChatMessageModel> before,
    required List<IsmChatMessageModel> fetched,
    required int? rawCount,
  }) {
    if (rawCount == null) return; // request failed: keep the old cursor
    const limit = IsmChatPageController.messagesApiPageLimit;
    final skipBefore = _olderPagingSkip(before);
    int nextSkip;
    if (forPagination) {
      nextSkip = paging.skip + rawCount;
      if (rawCount < limit) _controller.hasReachedOldestMessage = true;
    } else if (paging.lastMessageTimestamp == null) {
      // Latest page from the newest message.
      nextSkip = skipBefore > rawCount ? skipBefore : rawCount;
      if (rawCount < limit) _controller.hasReachedOldestMessage = true;
    } else if (rawCount >= limit) {
      // Forward sync filled a whole page: there may be more new rows between
      // this page and our cache (API sorts newest first, so we got the newest
      // [limit]). Only this page is known to be contiguous from the newest
      // message — page down from here so the gap is fetched, not skipped.
      nextSkip = rawCount;
    } else {
      // Forward sync got every new row: they sit above what we counted.
      nextSkip = skipBefore + rawCount;
    }
    var anchor = _newestRealMessageTimestamp(before) ?? 0;
    for (final m in fetched) {
      if (m.sentAt > anchor) anchor = m.sentAt;
    }
    _controller
      ..olderPagingRawSkip = nextSkip
      ..olderPagingAnchorSentAt = anchor;
  }

  /// Newest real message [sentAt] (list is sorted oldest → newest).
  int? _newestRealMessageTimestamp(List<IsmChatMessageModel> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.customType == IsmChatCustomMessageType.date ||
          message.customType == IsmChatCustomMessageType.conversationCreated) {
        continue;
      }
      return message.sentAt;
    }
    return null;
  }

  /// Resolves API `skip` + optional `lastMessageTimestamp`.
  ///
  /// | Case | skip | lastMessageTimestamp |
  /// |------|------|----------------------|
  /// | Scroll-up pagination | raw server rows reached + newer arrivals | omitted |
  /// | Empty DB / no real msgs | 0 | omitted |
  /// | Thin local cache (< [messagesApiPageLimit]) | 0 | omitted |
  /// | Full local cache (sync latest) | 0 | newest sentAt |
  ({int skip, int? lastMessageTimestamp}) _resolveMessagesApiPaging({
    required bool forPagination,
    required List<IsmChatMessageModel> messages,
    int? lastMessageTimestamp,
  }) {
    final realCount = _realMessageCount(messages);

    // Scroll up → older history via skip only (no timestamp).
    if (forPagination) {
      return (skip: _olderPagingSkip(messages), lastMessageTimestamp: null);
    }

    // Explicit caller timestamp (e.g. after group update).
    if (lastMessageTimestamp != null && lastMessageTimestamp > 0) {
      return (skip: 0, lastMessageTimestamp: lastMessageTimestamp);
    }

    // No local history yet → first page only.
    final newest = _newestRealMessageTimestamp(messages);
    if (newest == null) {
      return (skip: 0, lastMessageTimestamp: null);
    }

    // List/MQTT often leave only the latest row in Hive. Forward-only sync
    // (`lastMessageTimestamp`) would return nothing older; fetch a full window.
    if (realCount < IsmChatPageController.messagesApiPageLimit) {
      return (skip: 0, lastMessageTimestamp: null);
    }

    // Full local window → fetch anything newer than what we already have.
    return (skip: 0, lastMessageTimestamp: newest);
  }

  /// Real chat rows for pagination (shared with scroll/lifecycle mixins).
  int realMessageCountForPaging([List<IsmChatMessageModel>? messages]) =>
      _realMessageCount(messages ?? _controller.messages);

  /// Older pages fetched back-to-back when a page brings only rows we
  /// already have (re-walking cached history after a gap reset).
  static const int _maxDuplicatePageHops = 5;

  /// Fetches chat messages: an open/sync page, or with [forPagination] the
  /// next older page.
  ///
  /// [duplicateHops] is internal: how many all-duplicate older pages this
  /// scroll trigger already followed.
  Future<void> getMessagesFromAPI({
    bool forPagination = false,
    int? lastMessageTimestamp,
    bool isBroadcast = false,
    int duplicateHops = 0,
  }) async {
    if (IsmChatUtility.chatPageControllerRegistered) {
      final conversationID = _controller.conversation?.conversationId ?? '';
      if (conversationID.isEmpty) return;

      if (forPagination && _controller.hasReachedOldestMessage) return;
      if (_controller.canCallCurrentApi) return;
      _controller.canCallCurrentApi = true;
      final requestedConversationId = conversationID;
      var fetchNextOlderPage = false;

      try {
        if (_controller.messages.isEmpty) {
          _controller.isMessagesLoading = true;
        }
        final messagesList = List<IsmChatMessageModel>.from(_controller.messages);
        final paging = _resolveMessagesApiPaging(
          forPagination: forPagination,
          messages: messagesList,
          lastMessageTimestamp: lastMessageTimestamp,
        );

        final page = await _controller.viewModel.getChatMessagesPage(
          skip: paging.skip,
          limit: IsmChatPageController.messagesApiPageLimit,
          conversationId: conversationID,
          lastMessageTimestamp: paging.lastMessageTimestamp,
          isBroadcast: isBroadcast,
        );
        final data = page.messages;
        // Guard against race conditions: do not apply API results if active chat
        // changed before response came back.
        if ((_controller.conversation?.conversationId ?? '') !=
            requestedConversationId) {
          if (_controller.messages.isEmpty) {
            _controller.isMessagesLoading = false;
          }
          return;
        }

        _recordOlderPaging(
          paging: paging,
          forPagination: forPagination,
          before: messagesList,
          fetched: data,
          rawCount: page.rawCount,
        );

        // An older page made only of rows we already hold adds nothing to
        // the list, so no further scroll event would arrive — keep going.
        if (forPagination &&
            !_controller.hasReachedOldestMessage &&
            (page.rawCount ?? 0) > 0 &&
            duplicateHops < _maxDuplicatePageHops) {
          final knownIds = {
            for (final m in messagesList)
              if ((m.messageId ?? '').isNotEmpty) m.messageId,
          };
          fetchNextOlderPage =
              data.every((m) => knownIds.contains(m.messageId));
        }

        if (_controller.messages.isEmpty) {
          _controller.isMessagesLoading = false;
        }

        if (data.isNotEmpty && !_controller.isBroadcast) {
          await getMessagesFromDB(conversationID);
        } else if (data.isNotEmpty) {
          _controller.messages.addAll(data);
        } else if (_controller.messages.isEmpty ||
            (_controller.messages.length == 1 &&
                _controller.messages.first.customType ==
                    IsmChatCustomMessageType.conversationCreated)) {
          // API returned nothing — still show the local placeholder row.
          _controller.messages = _controller.commonController.sortMessages(
            filterMessages(
              insertEndtoEndMessage(
                timeStamp: DateTime.now().millisecondsSinceEpoch,
                messages: List<IsmChatMessageModel>.from(_controller.messages),
              ),
            ),
          );
          _controller.isMessagesLoading = false;
        }
      } finally {
        // Always unlock so stacked-chat / failed requests cannot permanently
        // block older-message pagination (scroll-up load more).
        _controller.canCallCurrentApi = false;
      }
      if (fetchNextOlderPage) {
        await getMessagesFromAPI(
          forPagination: true,
          isBroadcast: isBroadcast,
          duplicateHops: duplicateHops + 1,
        );
      }
    }
  }

  Future<void> getBroadcastMessages({
    String groupcastId = '',
    int? lastMessageTimestamp,
    bool isLoading = false,
    String? searchText,
    bool isBroadcast = false,
    bool forPagination = false,
  }) async {
    if (IsmChatUtility.chatPageControllerRegistered) {
      if (_controller.canCallCurrentApi) return;
      _controller.canCallCurrentApi = true;
      if (_controller.messages.isEmpty) {
        _controller.isMessagesLoading = true;
      }
      final messagesList = List<IsmChatMessageModel>.from(_controller.messages);
      final paging = _resolveMessagesApiPaging(
        forPagination: forPagination,
        messages: messagesList,
        lastMessageTimestamp: lastMessageTimestamp,
      );
      final groupcastID = groupcastId.isNotEmpty
          ? groupcastId
          : _controller.conversation?.conversationId ?? '';
      final requestedConversationId = groupcastID;
      final data = await _controller.viewModel.getBroadcastMessages(
        skip: paging.skip,
        groupcastId: groupcastID,
        lastMessageTimestamp: paging.lastMessageTimestamp,
        isBroadcast: isBroadcast,
      );
      // Same chat-isolation guard for broadcast messages.
      if ((_controller.conversation?.conversationId ?? '') !=
          requestedConversationId) {
        _controller.canCallCurrentApi = false;
        return;
      }
      if (_controller.messages.isEmpty) {
        _controller.isMessagesLoading = false;
      }
      _controller.messages.addAll(data);
      _controller.canCallCurrentApi = false;
    }
  }

  void searchedMessages(String query, {bool fromScrolling = false}) async {
    if (query.trim().isEmpty) {
      _controller.searchMessages.clear();
      _controller.isSearchMessagesLoading = false;
      return;
    }
    if (_controller.canCallCurrentApi) return;
    _controller.canCallCurrentApi = true;
    _controller.isSearchMessagesLoading = true;

    try {
      final messages = await _controller.viewModel.getChatMessages(
        skip:
            !fromScrolling ? 0 : _controller.searchMessages.length.pagination(),
        conversationId: _controller.conversation?.conversationId ?? '',
        searchText: query,
        isLoading: false,
      );

      if (messages.isNotEmpty) {
        if (fromScrolling) {
          _controller.searchMessages.addAll(messages);
        } else {
          _controller.searchMessages = messages;
        }
      } else if (!fromScrolling) {
        _controller.searchMessages.clear();
      }
    } finally {
      _controller.isSearchMessagesLoading = false;
      _controller.canCallCurrentApi = false;
    }
  }

  Future<void> getMessageDeliverTime(IsmChatMessageModel message) async {
    _controller.deliverdMessageMembers.clear();
    final response = await _controller.viewModel.getMessageDeliverTime(
      conversationId: message.conversationId ?? '',
      messageId: message.messageId ?? '',
    );

    if (response == null || response.isEmpty) {
      return;
    }
    _controller.deliverdMessageMembers = response;
    _syncMessageStatusFlags(message);
  }

  Future<void> getMessageReadTime(IsmChatMessageModel message) async {
    _controller.readMessageMembers.clear();
    final response = await _controller.viewModel.getMessageReadTime(
      conversationId: message.conversationId ?? '',
      messageId: message.messageId ?? '',
    );

    if (response == null || response.isEmpty) {
      return;
    }
    _controller.readMessageMembers = response;
    _syncMessageStatusFlags(message);
  }

  void _syncMessageStatusFlags(IsmChatMessageModel message) {
    final isGroup = _controller.conversation?.isGroup ?? false;
    final membersCount = _controller.conversation?.membersCount ?? 0;
    final expectedRecipients =
        isGroup ? (membersCount > 0 ? membersCount - 1 : 0) : 1;
    final deliveredCount = _controller.deliverdMessageMembers.length;
    final readCount = _controller.readMessageMembers.length;

    var deliveredToAll = message.deliveredToAll ?? false;
    var readByAll = message.readByAll ?? false;

    if (isGroup) {
      if (expectedRecipients > 0 && deliveredCount > 0) {
        deliveredToAll = deliveredCount >= expectedRecipients;
      }
      if (expectedRecipients > 0 && readCount > 0) {
        readByAll = readCount >= expectedRecipients;
        if (readByAll) {
          deliveredToAll = true;
        }
      }
    } else {
      if (deliveredCount > 0) {
        deliveredToAll = true;
      }
      if (readCount > 0) {
        readByAll = true;
        deliveredToAll = true;
      }
    }

    if (deliveredToAll == (message.deliveredToAll ?? false) &&
        readByAll == (message.readByAll ?? false)) {
      return;
    }

    final index = _controller.messages
        .indexWhere((m) => m.messageId == message.messageId);
    if (index == -1) {
      return;
    }

    _controller.messages[index] = _controller.messages[index].copyWith(
      deliveredToAll: deliveredToAll,
      readByAll: readByAll,
    );
  }

  Future<IsmChatConversationModel?> getConverstaionDetails(
      {bool? isLoading}) async {
    if (IsmChatUtility.chatPageControllerRegistered) {
      if (!_controller.isCoverationApiDetails) {
        return null;
      }
      _controller.isCoverationApiDetails = false;
      // Snapshot the ID at request time. After await, the user may have left
      // this group or opened a different chat — never apply a stale response.
      final conversationId = _controller.conversation?.conversationId ?? '';
      if (conversationId.isEmpty) {
        _controller.isCoverationApiDetails = true;
        return null;
      }
      final data = await _controller.viewModel.getConverstaionDetails(
        conversationId: conversationId,
        // Always include members so per-member `pushNotification` (mute) is available
        // for both group and 1:1 conversations.
        includeMembers: true,
        isLoading: isLoading,
      );

      // Active chat changed while this request was in flight (leave group /
      // open another conversation). Drop the response entirely so we never
      // push the exited group's conversationId back into currentConversation.
      final stillSameChat =
          _controller.conversation?.conversationId == conversationId;
      if (!stillSameChat) {
        _controller.isCoverationApiDetails = true;
        return null;
      }

      if (data.data != null) {
        final responeData = data.data as IsmChatConversationModel;
        // If we can successfully fetch conversation details, it generally means
        // the current user still has access to this conversation. We explicitly
        // clear the "removed" state so the UI banner/input restriction does not
        // remain stuck after the user is added back.
        _controller.isActionAllowed = false;
        final messageMap = {
          for (var message in _controller.messages) message.key: message,
        };
        final cached =
            await IsmChatConfig.dbWrapper?.getConversation(conversationId);
        // Re-check after the async DB read — user may have switched chats.
        if (_controller.conversation?.conversationId != conversationId) {
          _controller.isCoverationApiDetails = true;
          return null;
        }
        // Prefer local DB for block flag so a just-completed unblock is not
        // overwritten by stale conversation-details API data.
        final messagingDisabled = cached?.messagingDisabled ??
            responeData.messagingDisabled ??
            false;

        final resolvedMembers =
            (responeData.members != null && responeData.members!.isNotEmpty)
                ? responeData.members
                : (_controller.conversation?.members ?? cached?.members);

        _controller.conversation = responeData
            .copyWith(
              conversationId: conversationId,
              messagingDisabled: messagingDisabled,
              members: resolvedMembers,
              metaData: responeData.metaData?.copyWith(blockedMessage: null),
              outSideMessage: _controller.conversation?.outSideMessage,
              messages: messageMap,
            )
            .normalizeOpponentDetails();
        IsmChatProperties.chatPageProperties.onCoverstaionStatus?.call(
            IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context,
            _controller.conversation);

        syncConversationMediaTabLists(
          _controller.conversationController,
          _controller.messages,
        );

        if (responeData.members != null) {
          _controller.groupMembers = responeData.members ?? [];
          _controller.groupMembers.removeWhere((e) => e.userId.isEmpty);

          // Get current user ID to ensure they appear first in the list
          final currentUserId =
              IsmChatConfig.communicationConfig.userConfig.userId;

          // Sort members: current user first, then others alphabetically
          _controller.groupMembers.sort((a, b) {
            // If one is the current user, it should come first
            if (a.userId == currentUserId) return -1;
            if (b.userId == currentUserId) return 1;
            // Otherwise, sort alphabetically by username
            return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
          });
        }

        IsmChatLog.success('Updated conversation');
        if (IsmChatBlockUnblockCoordinator.isConversationBlocked(
          _controller.conversation,
        )) {
          unawaited(_controller.conversationController.getBlockUser());
          final conv = _controller.conversation;
          if (conv != null) {
            await IsmChatBlockUnblockCoordinator.ensureBlockBannerForDisabledChat(
              conv,
            );
          }
        } else {
          await IsmChatBlockUnblockCoordinator.pruneBlockBannersIfChatAllowed(
            conversationId,
          );
        }
      }
      // Only mark as removed when this response is still for the open chat.
      if (data.statusCode == 400 && conversationId.isNotEmpty) {
        _controller.isActionAllowed = true;
      }
      _controller.isCoverationApiDetails = true;
      // Sync list controller only when this response still matches the open chat.
      // Previously this always ran and could restore an exited group's ID after leave.
      if (_controller.conversation?.conversationId == conversationId) {
        _controller.conversationController.currentConversation =
            _controller.conversation;
      }
      return _controller.conversation;
    }
    return null;
  }

  Future<void> getReacton({required Reaction reaction}) async {
    final response = await _controller.viewModel.getReacton(reaction: reaction);
    _controller.userReactionList = response ?? [];
  }

  void updateLastMessagOnCurrentTime(IsmChatMessageModel message) async {
    // Slack-style threads: a reply that lives only in a thread is not the
    // conversation's latest message, so it must not move the preview or the
    // sort time. No-op while threads are off.
    if (IsmChatThreadCoordinator.isThreadOnlyReply(message)) {
      return;
    }
    final conversationController = IsmChatUtility.conversationController;
    var conversation = await IsmChatConfig.dbWrapper
        ?.getConversation(message.conversationId ?? '');

    if (conversation == null) {
      return;
    }

    if (!_controller.didReactedLast) {
      if (message.customType != IsmChatCustomMessageType.removeMember) {
        conversation = conversation.copyWith(
          lastMessageDetails: conversation.lastMessageDetails?.copyWith(
            sentByMe: message.sentByMe,
            showInConversation: true,
            sentAt: conversation.lastMessageDetails?.reactionType?.isNotEmpty ==
                    true
                ? conversation.lastMessageDetails?.sentAt
                : message.sentAt,
            senderName: [
              IsmChatCustomMessageType.removeAdmin,
              IsmChatCustomMessageType.addAdmin
            ].contains(message.customType)
                ? message.initiatorName ?? ''
                : message.chatName,
            messageType: message.messageType?.value ?? 0,
            messageId: message.messageId ?? '',
            conversationId: message.conversationId ?? '',
            body: IsmChatUtility.lastMessageBodyForConversationSync(message),
            senderId: message.senderInfo?.userId,
            customType: message.customType,
            readBy: [],
            deliveredTo: [],
            readCount: conversation.isGroup == true
                ? message.readByAll == true
                    ? conversation.membersCount ?? 0
                    : message.lastReadAt?.length
                : message.readByAll == true
                    ? 1
                    : 0,
            deliverCount: conversation.isGroup == true
                ? message.deliveredToAll == true
                    ? conversation.membersCount ?? 0
                    : 0
                : message.deliveredToAll == true
                    ? 1
                    : 0,
            members:
                message.members?.map((e) => e.memberName ?? '').toList() ?? [],
            action: '',
            metaData: message.metaData,
            // Propagate local-only / failed sends so conversation list shows error.
            isInvalidMessage: message.isInvalidMessage,
          ),
          unreadMessagesCount: 0,
        );
        await IsmChatConfig.dbWrapper
            ?.saveConversation(conversation: conversation);
        await conversationController.getConversationsFromDB();
      }
    } else {
      await conversationController.getChatConversations();
    }
  }

  UserDetails getUser() => UserDetails(
        userProfileImageUrl:
            IsmChatProperties.chatPageProperties.header?.profileImageUrl?.call(
                    IsmChatConfig.kNavigatorKey.currentContext ??
                        IsmChatConfig.context,
                    _controller.conversation,
                    _controller.conversation?.profileUrl ?? '') ??
                _controller.conversation?.profileUrl ??
                '',
        userName: IsmChatProperties.chatPageProperties.header?.title?.call(
                IsmChatConfig.kNavigatorKey.currentContext ??
                    IsmChatConfig.context,
                _controller.conversation,
                _controller.conversation?.chatName ?? '') ??
            _controller.conversation?.chatName ??
            '',
        userIdentifier:
            _controller.conversation?.opponentDetails?.userIdentifier ?? '',
        userId: _controller.conversation?.opponentDetails?.userId ?? '',
      );

  Future<void> updateMessage({
    required String messageId,
    required String conversationId,
    bool isOpponentMessage = false,
    IsmChatMetaData? metaData,
  }) async {
    if (!isOpponentMessage) {
      final response = await _controller.viewModel.updateMessage(
        metaData: {'isDownloaded': true},
        messageId: messageId,
        conversationId: conversationId,
        isLoading: true,
      );
      if (response) {
        await _controller.getMessagesFromDB(conversationId);
      }
    } else {
      var conversation =
          await IsmChatConfig.dbWrapper?.getConversation(conversationId);
      final allMessages = conversation?.messages;
      if (allMessages == null) return;
      final message = allMessages.values
          .cast<IsmChatMessageModel?>()
          .firstWhere((e) => e?.messageId == messageId, orElse: () => null);
      if (message != null) {
        if (metaData != null) {
          message.metaData = metaData;
        } else {
          message.metaData = message.metaData?.copyWith(
            isDownloaded: true,
          );
        }
        allMessages[message.key] = message;

        if (conversation != null) {
          conversation = conversation.copyWith(messages: allMessages);
          await IsmChatConfig.dbWrapper
              ?.saveConversation(conversation: conversation);
        }
        await getMessagesFromDB(conversationId);
      }
    }
  }

  Future<void> getMessageForStatus() async {
    final messageIds = <String>[];
    final conversationId = _controller.conversation?.conversationId ?? '';
    for (final message in _controller.messages) {
      if (((message.deliveredToAll == false) || (message.readByAll == false)) &&
          !message.messageId.isNullOrEmpty) {
        messageIds.add(message.messageId ?? '');
      }
    }
    if (messageIds.isNotEmpty) {
      messageIds.removeWhere((e) => e.isNullOrEmpty);
      final response = await _controller.viewModel.getMessageForStatus(
        conversationId: conversationId,
        messageIds: messageIds,
        isLoading: false,
      );
      if (response != null) {
        final saved = await IsmChatConfig.dbWrapper?.updateConversation(
          conversationId: conversationId,
          update: (conversation) {
            if (conversation == null) return null;
            final messages = Map<String, IsmChatMessageModel>.from(
              conversation.messages ?? {},
            );
            var changed = false;
            for (final entry in messages.entries) {
              final dbmessage = entry.value;
              final messageStatus =
                  response.cast<MessageStatusModel?>().firstWhere(
                        (e) => e?.messageId == dbmessage.messageId,
                        orElse: () => null,
                      );
              if (dbmessage.messageId != messageStatus?.messageId) continue;
              if (messageStatus?.deliveredToAll ?? false) {
                dbmessage.deliveredTo?.add(
                  MessageStatus(
                    userId: conversation.opponentDetails?.userId ?? '',
                    timestamp: int.tryParse(entry.key),
                  ),
                );
              }
              if (messageStatus?.readByAll ?? false) {
                dbmessage.readBy?.add(
                  MessageStatus(
                    userId: conversation.opponentDetails?.userId ?? '',
                    timestamp: int.tryParse(entry.key),
                  ),
                );
              }
              dbmessage
                ..readByAll = messageStatus?.readByAll ?? false
                ..deliveredToAll = messageStatus?.deliveredToAll ?? false;
              // If readByAll is true, deliveredToAll must also be true
              // (you can't read a message that hasn't been delivered)
              if (dbmessage.readByAll == true) {
                dbmessage.deliveredToAll = true;
              }
              messages[entry.key] = dbmessage;
              changed = true;
            }
            if (!changed) return null;
            return conversation.copyWith(messages: messages);
          },
        );
        if (saved != null &&
            (_controller.conversation?.conversationId ?? '') ==
                conversationId) {
          await getMessagesFromDB(conversationId);
        }
      }
    }
  }
}
