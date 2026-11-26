part of '../chat_page_controller.dart';

// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
/// Contact and group operations mixin for IsmChatPageController.
///
/// This mixin handles contact search, selection, group member operations,
/// and mention functionality.
mixin IsmChatPageContactGroupOperationsMixin on GetxController {
  /// Gets the controller instance.
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Searches contacts based on the provided query.
  void onContactSearch(String query) {
    if (query.trim().isEmpty) {
      _controller.contactList = _controller.searchContactList;
      _controller.isLoadingContact = false;
    } else {
      _controller.contactList = _controller.searchContactList
          .where(
            (e) {
              // displayName is nullable in flutter_contacts 2.x.
              final name = e.contact.safeDisplayName;
              final number = e.contact.phones.isEmpty
                  ? ''
                  : e.contact.phones.first.number;
              return name.didMatch(query) || number.didMatch(query);
            },
          )
          .toList();
      if (_controller.contactList.isEmpty) {
        _controller.isLoadingContact = true;
      }
    }

    _controller.commonController
        .handleSorSelectedContact(_controller.contactList);
  }

  /// Handles contact selection/deselection in the contact screen.
  void onSelectedContactTap(int index, SelectedContact contact) {
    _controller.contactList[index].isConotactSelected =
        !_controller.contactList[index].isConotactSelected;
    final checkContact = _controller.contactSelectedList
        .any((e) => e.contact.id == contact.contact.id);
    if (checkContact) {
      _controller.contactSelectedList
          .removeWhere((e) => e.contact.id == contact.contact.id);
    } else {
      _controller.contactSelectedList.add(contact);
    }
  }

  /// Sets contact list with selected contacts marked.
  void setContatWithSelectedContact() {
    var temContactList = <SelectedContact>[];
    for (final contact in _controller.searchContactList) {
      final checkContact = _controller.contactSelectedList
          .any((e) => e.contact.id == contact.contact.id);
      contact.isConotactSelected = checkContact;
      temContactList.add(contact);
    }
    _controller.contactList.clear();
    _controller.contactList = temContactList;
  }

  /// Handles group eligible user selection/deselection.
  void onGrouEligibleUserTap(int index) {
    _controller.groupEligibleUser[index].isUserSelected =
        !_controller.groupEligibleUser[index].isUserSelected;
  }

  /// Searches group members based on the provided query.
  /// Ensures the current user always appears first in the list.
  void onGroupSearch(String query) {
    // Get current user ID to ensure they appear first in the list
    final currentUserId = IsmChatConfig.communicationConfig.userConfig.userId;

    if (query.trim().isEmpty) {
      _controller.groupMembers = List.from(_controller.conversation!.members!);
    } else {
      _controller.groupMembers = _controller.conversation!.members!
          .where(
            (e) => [
              e.userName,
              e.userIdentifier,
            ].any(
              (e) => e.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            ),
          )
          .toList();
    }

    // Sort members: current user first, then others alphabetically
    _controller.groupMembers.sort((a, b) {
      // If one is the current user, it should come first
      if (a.userId == currentUserId) return -1;
      if (b.userId == currentUserId) return 1;
      // Otherwise, sort alphabetically by username
      return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
    });
  }

  /// Searches for participants to add to a group.
  void addParticipantSearch(String query) {
    if (query.trim().isEmpty) {
      // Reset to all eligible users when search is cleared
      _controller.groupEligibleUser = _controller.groupEligibleUserDuplicate;
      return;
    }

    // Use debounce to delay API call until user stops typing (matches 1-to-1 chat behavior)
    _controller.ismChatDebounce.run(() {
      // Call API with search query to get filtered results from server
      _controller.getEligibleMembers(
        conversationId: _controller.conversation?.conversationId ?? '',
        limit: 20,
        searchTag: query.trim(),
        isLoading: false,
      );
    });
  }

  /// Shows or hides the mention user list based on the input value.
  void showMentionsUserList(String value) async {
    if (!_controller.conversation!.isGroup!) {
      return;
    }
    _controller.showMentionUserList = value.split(' ').last.contains('@');
    if (!_controller.showMentionUserList) {
      _controller.mentionSuggestions.clear();
      return;
    }
    var query = value.split('@').last;
    final currentUserId =
        IsmChatConfig.communicationConfig.userConfig.userId.trim();
    final alreadyMentioned = mentionUserIdsInComposerText(
      value,
      _controller.groupMembers,
    );
    _controller.mentionSuggestions = _controller.groupMembers
        .where((e) => e.userId.trim() != currentUserId)
        .where((e) => !alreadyMentioned.contains(e.userId.trim()))
        .where((e) {
          final q = query.toLowerCase();
          final label = mentionLabelForUser(e).toLowerCase();
          return e.userName.toLowerCase().contains(q) || label.contains(q);
        })
        .toList();
  }

  /// Updates the mention user in the input field.
  void updateMentionUser(String value) {
    final member = _controller.groupMembers.firstWhereOrNull(
      (e) => e.userName == value,
    );
    final currentUserId =
        IsmChatConfig.communicationConfig.userConfig.userId.trim();
    if (member != null && member.userId.trim() == currentUserId) {
      _controller.showMentionUserList = false;
      return;
    }
    final tempList = _controller.chatInputController.text.split('@');
    final remainingText = tempList.sublist(0, tempList.length - 1).join('@');
    final mentionLabel = member != null
        ? mentionLabelForUser(member)
        : value.capitalizeFirst!;
    final updatedText = '$remainingText@$mentionLabel ';
    _controller.showMentionUserList = false;
    _controller.chatInputController.value =
        _controller.chatInputController.value.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(
        offset: updatedText.length,
      ),
    );
  }

  /// Gets the list of mentioned users from the message data.
  ///
  /// Matches each `@` segment against [mentionLabelForUser], [UserDetails.displayName],
  /// and [UserDetails.userName]. [MentionModel.wordCount] follows the label actually
  /// inserted in the composer, not [UserDetails.userName] alone.
  Future<void> getMentionedUserList(String data) async {
    _controller.userMentionedList.clear();
    final mentionedList = (data.split('@').toList())
      ..removeWhere((e) => e.trim().isEmpty);

    final seenUserIds = <String>{};

    // Longest display names first so "@Rasika Flutter User" beats a "@Rasika" alias.
    final membersByLabelLength = List<UserDetails>.from(_controller.groupMembers)
      ..sort(
        (a, b) =>
            mentionLabelForUser(b).length.compareTo(mentionLabelForUser(a).length),
      );

    for (var mentionIndex = 0; mentionIndex < mentionedList.length;
        mentionIndex++) {
      final seg = mentionedList[mentionIndex].trimLeft();
      UserDetails? matchedMember;
      int? bestMatchEnd;

      for (final member in membersByLabelLength) {
        if (isCurrentChatUser(member.userId)) continue;
        final userName = member.userName.trim();
        if (userName.isEmpty) continue;

        final label = mentionLabelForUser(member);
        final displayName = member.displayName.trim();
        final matches = mentionSegmentMatchesMemberName(seg, label) ||
            (displayName.isNotEmpty &&
                mentionSegmentMatchesMemberName(seg, displayName)) ||
            mentionSegmentMatchesMemberName(seg, userName);
        if (!matches) continue;

        final matchEnd = longestMentionNameEndInBody('@$seg', 0, member);
        if (matchEnd == null || matchEnd <= 1) continue;
        if (bestMatchEnd == null || matchEnd > bestMatchEnd) {
          bestMatchEnd = matchEnd;
          matchedMember = member;
        }
      }

      if (matchedMember == null) continue;
      if (!seenUserIds.add(matchedMember.userId.trim())) continue;

      final label = mentionLabelForUser(matchedMember);
      final wordCount =
          label.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      _controller.userMentionedList.add(
        MentionModel(
          wordCount: wordCount,
          userId: matchedMember.userId,
          order: mentionIndex,
        ),
      );
    }
  }
}
