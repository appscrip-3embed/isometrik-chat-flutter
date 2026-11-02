part of '../chat_page_controller.dart';

// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
mixin IsmChatGroupAdminMixin on GetxController {
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

  /// This variable use for get all method and varibles from IsmChatCommonController
  IsmChatCommonController get _commonController =>
      Get.find<IsmChatCommonController>();

  /// Add members to a conversation
  Future<void> addMembers(
      {required List<String> memberIds, bool isLoading = false}) async {
    final conversationId = _controller.conversation?.conversationId ?? '';
    final response = await _controller.viewModel.addMembers(
        memberList: memberIds,
        conversationId: conversationId,
        isLoading: isLoading);
    if (response?.hasError ?? true) {
      return;
    }
    await _controller.getConverstaionDetails(
      isLoading: false,
    );
    await _controller.getMessagesFromAPI();
  }

  /// change group title
  Future<void> changeGroupTitle({
    required String conversationTitle,
    required String conversationId,
    required bool isLoading,
  }) async {
    final response = await _controller.viewModel.changeGroupTitle(
      conversationTitle: conversationTitle,
      conversationId: conversationId,
      isLoading: isLoading,
    );
    if (response?.hasError ?? true) {
      return;
    } else {
      _controller.conversation = _controller.conversation
          ?.copyWith(conversationTitle: conversationTitle);
      _controller.update();
      await _controller.getMessagesFromAPI(
          lastMessageTimestamp: _controller.messages.last.sentAt);
      unawaited(_controller.conversationController.getChatConversations());
      IsmChatUtility.showToast('Group title changed successfully!');
    }
  }

  /// change group profile
  Future<void> changeGroupProfile({
    required String conversationImageUrl,
    required String conversationId,
    required bool isLoading,
  }) async {
    final response = await _controller.viewModel.changeGroupProfile(
        conversationImageUrl: conversationImageUrl,
        conversationId: conversationId,
        isLoading: isLoading);
    if (response?.hasError ?? true) {
      return;
    } else {
      _controller.conversation = _controller.conversation
          ?.copyWith(conversationImageUrl: conversationImageUrl);
      _controller.update();
      await _controller.getMessagesFromAPI(
          lastMessageTimestamp: _controller.messages.last.sentAt);
      unawaited(_controller.conversationController.getChatConversations());
      IsmChatUtility.showToast('Group profile changed successfully!');
    }
  }

  /// Resolves a participant row for admin-then-remove sequencing in [removeMember].
  UserDetails? _findGroupMember(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    for (final member in _controller.groupMembers) {
      if (member.matchesConversationMember(needle)) return member;
    }
    final members = _controller.conversation?.members;
    if (members != null) {
      for (final member in members) {
        if (member.matchesConversationMember(needle)) return member;
      }
    }
    return null;
  }

  ///Remove members from conversation
  Future<void> removeMember(String userId) async {
    final apiMemberId = userId.trim();
    if (apiMemberId.isEmpty) return;

    final conversationId = _controller.conversation?.conversationId ?? '';
    if (conversationId.isEmpty) return;

    final member = _findGroupMember(apiMemberId);
    if (member?.isAdmin == true) {
      final adminResponse = await _controller.viewModel.removeAdmin(
        conversationId: conversationId,
        memberId: member!.conversationMemberIdForApi,
      );
      if (adminResponse?.hasError ?? true) {
        IsmChatUtility.showToast(
          'Could not remove admin role for ${member.userName}.',
          timeOutInSec: 2,
        );
        return;
      }
    }

    final response = await _controller.viewModel.removeMember(
      conversationId: conversationId,
      userId: apiMemberId,
    );

    if (response?.hasError ?? true) {
      return;
    }
    await _controller.getConverstaionDetails(
      isLoading: false,
    );
    await _controller.getMessagesFromAPI();
  }

  ///Remove members from conversation
  Future<void> getEligibleMembers(
      {required String conversationId,
      bool isLoading = false,
      int limit = 20,
      int skip = 0,
      String? searchTag}) async {
    // Allow search calls even if previous call is in progress
    // Only block pagination calls (when searchTag is empty)
    if (searchTag.isNullOrEmpty && _controller.canCallCurrentApi) return;

    // For search, we want to make the call immediately, so don't block
    if (searchTag.isNullOrEmpty) {
      _controller.canCallCurrentApi = true;
    }

    final response = await _controller.viewModel.getEligibleMembers(
        conversationId: conversationId,
        isLoading: isLoading,
        limit: limit,
        skip: searchTag.isNullOrEmpty
            ? _controller.groupEligibleUser.length.pagination()
            : 0,
        searchTag: searchTag);
    if (response == null) {
      if (searchTag.isNullOrEmpty) {
        _controller.canCallCurrentApi = false;
      }
      return;
    }
    final users = response;

    if (searchTag.isNullOrEmpty) {
      // Add to existing list when not searching
      _controller.groupEligibleUser.addAll(List.from(users)
          .map((e) => SelectedMembers(
                isUserSelected: false,
                userDetails: e as UserDetails,
                isBlocked: false,
              ))
          .toList());
      _controller.groupEligibleUser.sort((a, b) => a.userDetails.userName
          .toLowerCase()
          .compareTo(b.userDetails.userName.toLowerCase()));
      _controller.groupEligibleUserDuplicate =
          List.from(_controller.groupEligibleUser);
      _controller.canCallCurrentApi = false;
    } else {
      // Replace list when searching
      _controller.groupEligibleUser.clear();
      _controller.groupEligibleUser.addAll(List.from(users)
          .map((e) => SelectedMembers(
                isUserSelected: false,
                userDetails: e as UserDetails,
                isBlocked: false,
              ))
          .toList());
      _controller.groupEligibleUser.sort((a, b) => a.userDetails.userName
          .toLowerCase()
          .compareTo(b.userDetails.userName.toLowerCase()));
    }

    _commonController.handleSorSelectedMembers(_controller.groupEligibleUser);
  }

  /// Remove members from conversation
  Future<bool> leaveConversation(String conversationId) async {
    final response =
        await _controller.viewModel.leaveConversation(conversationId, true);

    if (response?.hasError ?? true) {
      return false;
    }
    return true;
  }

  void _syncMemberAdminLocally(String memberId, {required bool isAdmin}) {
    final id = memberId.trim();
    if (id.isEmpty) return;

    final conv = _controller.conversation;
    if (conv?.members != null) {
      final updatedMembers = conv!.members!
          .map(
            (m) =>
                m.matchesConversationMember(id) ? m.copyWith(isAdmin: isAdmin) : m,
          )
          .toList();
      _controller.conversation = conv.copyWith(members: updatedMembers);
    }
    if (_controller.groupMembers.isNotEmpty) {
      _controller.groupMembers = _controller.groupMembers
          .map(
            (m) =>
                m.matchesConversationMember(id) ? m.copyWith(isAdmin: isAdmin) : m,
          )
          .toList();
    }
    _controller.update();
  }

  Future<void> _refreshConversationDetailsAfterAdminChange() async {
    await _controller.getConverstaionDetails(isLoading: false);
    // Group info often triggers a details fetch on open; if one is in flight,
    // the call above is a no-op — retry once so admin badge updates.
    if (!_controller.isCoverationApiDetails) {
      await Future.delayed(const Duration(milliseconds: 400));
      await _controller.getConverstaionDetails(isLoading: false);
    }
  }

  /// make admin
  Future<void> makeAdmin(
    String memberId,
    String userName, [
    bool updateConversation = true,
  ]) async {
    final apiMemberId = memberId.trim();
    if (apiMemberId.isEmpty) {
      IsmChatUtility.showToast('Unable to update admin role.', timeOutInSec: 2);
      return;
    }
    final response = await _controller.viewModel.makeAdmin(
        memberId: apiMemberId,
        conversationId: _controller.conversation?.conversationId ?? '');
    if (response?.hasError ?? true) {
      IsmChatUtility.showToast('Could not make $userName an admin.',
          timeOutInSec: 2);
      return;
    }
    if (updateConversation) {
      _syncMemberAdminLocally(apiMemberId, isAdmin: true);
      IsmChatUtility.showToast('You made $userName an admin of this group',
          timeOutInSec: 2);
      await _refreshConversationDetailsAfterAdminChange();
      await _controller.getMessagesFromAPI(
        lastMessageTimestamp: _controller.messages.isNotEmpty
            ? _controller.messages.last.sentAt
            : _controller.conversation?.lastMessageSentAt,
      );
    }
  }

  ///Remove member as admin from conversation
  Future<void> removeAdmin(String memberId, String userName) async {
    final apiMemberId = memberId.trim();
    if (apiMemberId.isEmpty) {
      IsmChatUtility.showToast('Unable to update admin role.', timeOutInSec: 2);
      return;
    }
    final response = await _controller.viewModel.removeAdmin(
      conversationId: _controller.conversation?.conversationId ?? '',
      memberId: apiMemberId,
    );

    if (response?.hasError ?? true) {
      IsmChatUtility.showToast('Could not remove admin role for $userName.',
          timeOutInSec: 2);
      return;
    }
    _syncMemberAdminLocally(apiMemberId, isAdmin: false);
    IsmChatUtility.showToast(
        'You removed $userName from being an admin of this group',
        timeOutInSec: 2);
    await _refreshConversationDetailsAfterAdminChange();
    await _controller.getMessagesFromAPI(
      lastMessageTimestamp: _controller.messages.isNotEmpty
          ? _controller.messages.last.sentAt
          : _controller.conversation?.lastMessageSentAt,
    );
  }
}
