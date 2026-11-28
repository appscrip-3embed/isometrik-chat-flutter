part of '../chat_page_controller.dart';

// coverage:ignore-file
// Unreachable under VM tests: needs the chat page, Hive and text input.
/// Keeps unsent composer text and the open reply per conversation.
///
/// The composer is shared by every chat (the controller is reused across
/// routes and web tabs), so [_draftTracker] is bound to the chat the composer
/// currently belongs to. It is detached while a chat is being switched, so
/// clearing the field for the next chat never wipes the previous chat's draft.
///
/// Attachments are never drafted. While a message is being edited nothing is
/// saved, so the edited body never replaces the real draft.
mixin IsmChatPageDraftMessageMixin on GetxController {
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Tracks the chat the composer currently belongs to; its key is the
  /// conversation id.
  late final IsmChatDraftTracker _draftTracker = IsmChatDraftTracker(
    save: (conversationId, draft) async {
      // Memory first: reopening the chat reads it before the Hive write lands.
      _notifyDraftChanged(conversationId, draft);
      await IsmChatConfig.dbWrapper?.saveDraft(conversationId, draft);
    },
  );
  bool _draftListenersAdded = false;
  final List<Worker> _draftWorkers = [];

  void _ensureDraftListeners() {
    if (_draftListenersAdded) return;
    _draftListenersAdded = true;
    _controller.chatInputController.addListener(_onComposerChanged);
    _draftWorkers
      ..add(ever<bool>(_controller._isreplying, (_) => _onComposerChanged()))
      ..add(ever<IsmChatMessageModel?>(
        _controller._replayMessage,
        (_) => _onComposerChanged(),
      ));
  }

  void _onComposerChanged() {
    if (_controller.isEditing) return;
    _draftTracker.onChanged(
      IsmChatDraftModel(
        text: _controller.chatInputController.text,
        replyMessage: _controller.isreplying ? _controller.replayMessage : null,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Lets the conversation list show the draft without reading Hive per row.
  void _notifyDraftChanged(String conversationId, IsmChatDraftModel draft) {
    if (!IsmChatUtility.conversationControllerRegistered) return;
    final drafts = IsmChatUtility.conversationController.conversationDrafts;
    if (draft.isEmpty) {
      drafts.remove(conversationId);
    } else {
      drafts[conversationId] = draft;
    }
  }

  /// Writes any unsaved composer change for the current chat right away.
  ///
  /// Call before leaving the chat (back, app paused, controller close).
  Future<void> flushComposerDraft() => _draftTracker.flush();

  /// Saves the current chat's draft and stops tracking it, before the
  /// composer is cleared for another chat.
  void _detachComposerDraft() {
    _ensureDraftListeners();
    _draftTracker.detach();
  }

  /// Loads the saved draft of [_controller.conversation] into the composer and
  /// starts tracking that chat.
  ///
  /// Returns false when a newer chat open ([openGeneration]) took over.
  Future<bool> _restoreComposerDraft({int? openGeneration}) async {
    _ensureDraftListeners();
    final conversation = _controller.conversation;
    final conversationId = conversation?.conversationId ?? '';
    IsmChatDraftModel? draft;
    // Text/media handed in from outside the chat is sent on open; a restored
    // reply would be attached to it.
    if (conversationId.isNotEmpty && conversation?.outSideMessage == null) {
      await _draftTracker.idle;
      final drafts = IsmChatUtility.conversationControllerRegistered
          ? IsmChatUtility.conversationController.conversationDrafts
          : null;
      draft = drafts != null && drafts.containsKey(conversationId)
          ? drafts[conversationId]
          : await IsmChatConfig.dbWrapper?.getDraft(conversationId);
    }
    if (openGeneration != null &&
        openGeneration != _controller.chatOpenGeneration) {
      return false;
    }
    if (_controller.conversation?.conversationId !=
        conversation?.conversationId) {
      return false;
    }
    // Still detached here, so these writes do not save anything.
    _controller
      ..isreplying = draft?.replyMessage != null
      ..replayMessage = draft?.replyMessage;
    final text = draft?.text ?? '';
    if (_controller.chatInputController.text != text) {
      _controller.chatInputController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (IsmChatProperties.chatPageProperties.features
        .contains(IsmChatFeature.audioMessage)) {
      _controller.showSendButton = text.isNotEmpty;
    }
    _draftTracker.attach(conversationId, draft);
    return true;
  }

  /// Re-attaches the composer when this page is shown again for a different
  /// chat without a full [startInit] (stacked chat routes popping back).
  Future<void> syncComposerDraftWithConversation() async {
    final currentId = _controller.conversation?.conversationId ?? '';
    // Same chat, or a new 1:1 with no id yet: keep whatever is typed.
    if (currentId == (_draftTracker.key ?? '')) return;
    _detachComposerDraft();
    await _restoreComposerDraft();
  }

  void _disposeComposerDraft() {
    _draftTracker.detach();
    for (final worker in _draftWorkers) {
      worker.dispose();
    }
    _draftWorkers.clear();
    if (_draftListenersAdded) {
      try {
        _controller.chatInputController.removeListener(_onComposerChanged);
      } catch (_) {}
    }
    _draftListenersAdded = false;
  }
}
