part of '../chat_page_controller.dart';

// coverage:ignore-file

/// Text edit (PATCH `/chat/message`) for the channel composer.
mixin IsmChatPageEditMessageMixin on GetxController {
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Enters edit mode: loads body into the channel composer.
  void beginEditMessage(IsmChatMessageModel message) {
    if (!message.canShowEditInFocusMenu) return;
    _controller
      ..isreplying = false
      ..replayMessage = null
      ..editingMessage = message
      ..isEditing = true
      ..chatInputController.text = message.body
      ..showSendButton = true;
    _controller.messageFocusNode.requestFocus();
    _controller.update();
  }

  void cancelEditMessage() {
    _controller
      ..isEditing = false
      ..editingMessage = null
      ..chatInputController.clear()
      ..showSendButton = false;
    _controller.update();
  }

  static List<String> textEditSearchableTags(String plainBody) => [
        IsmChatConstants.textMessageSearchTag,
        plainBody,
      ];

  String _encryptionIdForEdit(IsmChatMessageModel message) {
    final convId = message.conversationId ?? '';
    final groupCastId = message.metaData?.groupCastId?.trim() ?? '';
    if (message.metaData?.isBroadCastMessage == true && groupCastId.isNotEmpty) {
      return groupCastId;
    }
    return convId;
  }

  /// Submits composer text as an edit when [isEditing] is true.
  ///
  /// Returns `false` when not editing or validation fails; `true` on success.
  Future<bool> trySubmitEditFromComposer({String? text}) async {
    if (!_controller.isEditing || _controller.editingMessage == null) {
      return false;
    }
    if (text != null) {
      _controller.chatInputController.text = text;
    }
    final ok = await submitTextEditForMessage(
      _controller.editingMessage!,
      _controller.chatInputController.text.trim(),
    );
    if (ok) cancelEditMessage();
    return ok;
  }

  /// PATCHes new text for [original]. Shared by channel and thread composers.
  Future<bool> submitTextEditForMessage(
    IsmChatMessageModel original,
    String plainBody,
  ) async {
    if (plainBody.isEmpty || _controller.isMessageSent) {
      return false;
    }
    if (!original.canShowEditInFocusMenu) {
      return false;
    }
    if (plainBody == original.body.trim()) {
      return false;
    }

    final messageId = original.messageId?.trim() ?? '';
    final conversationId = original.conversationId?.trim() ?? '';
    if (messageId.isEmpty || conversationId.isEmpty) return false;

    _controller.isMessageSent = true;
    final encrypted = IsmChatConfig.messageEncrypted ?? false;
    final encryptionId = _encryptionIdForEdit(original);
    final apiBody = encrypted
        ? IsmChatUtility.encryptMessage(plainBody, encryptionId)
        : plainBody;
    final tags = textEditSearchableTags(plainBody);

    try {
      final ok = await _controller.viewModel.editMessageText(
        messageId: messageId,
        conversationId: conversationId,
        body: apiBody,
        searchableTags: tags,
        isLoading: true,
      );
      if (!ok) {
        IsmChatUtility.showToast(IsmChatStrings.editMessageFailed);
        return false;
      }

      final updated = original.copyWith(
        body: plainBody,
        searchableTags: tags,
        messageUpdated: true,
        metaData: original.metaData?.copyWith(
          isOnelyEmoji: IsmChatUtility.isOnlyEmoji(plainBody),
        ),
      );
      await _applyLocalMessageEdit(updated);
      return true;
    } finally {
      _controller.isMessageSent = false;
    }
  }

  /// Updates channel list, DB, conversation preview, and open thread rows.
  Future<void> _applyLocalMessageEdit(IsmChatMessageModel updated) async {
    final messageId = updated.messageId ?? '';
    final conversationId = updated.conversationId ?? '';
    if (messageId.isEmpty || conversationId.isEmpty) return;

    final key = updated.key;
    for (var i = 0; i < _controller.messages.length; i++) {
      if (_controller.messages[i].key == key ||
          _controller.messages[i].messageId == messageId) {
        _controller.messages[i] = updated;
        break;
      }
    }
    _controller.update();

    await IsmChatConfig.dbWrapper?.updateConversation(
      conversationId: conversationId,
      update: (latest) {
        if (latest == null) return null;
        final messages = Map<String, IsmChatMessageModel>.from(
          latest.messages ?? {},
        );
        for (final entry in messages.entries) {
          if (entry.value.messageId == messageId) {
            messages[entry.key] = updated;
            break;
          }
        }
        var next = latest.copyWith(messages: messages);
        if (next.lastMessageDetails?.messageId == messageId) {
          next = next.copyWith(
            lastMessageDetails: next.lastMessageDetails?.copyWith(
              body: updated.body,
            ),
          );
        }
        return next;
      },
    );

    IsmChatThreadController.applyMessageDetailsUpdate(updated);
    unawaited(_controller.getMessagesFromDB(conversationId));
    if (IsmChatUtility.conversationControllerRegistered) {
      unawaited(
        IsmChatUtility.conversationController.getConversationsFromDB(),
      );
    }
  }

  /// Applies a remote edit (MQTT or host). Reuse from MQTT mixin.
  Future<void> applyMessageEditFromRemote(IsmChatMessageModel updated) async {
    await _applyLocalMessageEdit(updated);
  }
}