part of '../chat_page_controller.dart';

// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
/// Utility methods mixin for IsmChatPageController.
///
/// This mixin contains helper methods and utility functions used throughout
/// the chat page controller.
mixin IsmChatPageUtilityMethodsMixin on GetxController {
  /// Gets the controller instance.
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Gets or creates a noise widget for the specified timestamp.
  Widget getNoise(int sentAt, [bool sentByMe = true]) {
    if (!_controller.noises.keys.contains(sentAt)) {
      final props = IsmChatProperties.chatPageProperties;
      var color = sentByMe
          ? (props.voiceMessageWaveColorMe ?? Colors.white)
          : (props.voiceMessageWaveColorOpponent ?? Colors.grey);
      var noiseList = List.generate(27, (index) => $SingleNoise(color: color));
      var noise = Noises(noises: noiseList);
      _controller.noises[sentAt] = noise;
    }
    return _controller.noises[sentAt]!;
  }

  /// Gets or creates a global key for the specified timestamp.
  GlobalKey getGlobalKey(int sentAt) {
    if (!_controller.globalKeys.keys.contains(sentAt)) {
      _controller.globalKeys[sentAt] = GlobalKey();
    }
    return _controller.globalKeys[sentAt]!;
  }

  /// Gets or creates a memory image for the specified timestamp.
  MemoryImage getMemoryImage(int sentAt, Uint8List bytes) {
    if (!_controller.memoryImage.keys.contains(sentAt)) {
      _controller.memoryImage[sentAt] = MemoryImage(bytes);
    }
    return _controller.memoryImage[sentAt] ?? MemoryImage(Uint8List(0));
  }

  /// Sorts media messages into a list of maps grouped by date.
  List<Map<String, List<IsmChatMessageModel>>> sortMediaList(
      List<IsmChatMessageModel> messages) {
    var storeMediaImageList = <Map<String, List<IsmChatMessageModel>>>[];
    for (var x in messages) {
      if (x.customType == IsmChatCustomMessageType.date) {
        storeMediaImageList.add({x.body: <IsmChatMessageModel>[]});
        continue;
      }
      storeMediaImageList.last.forEach((key, value) {
        value.add(x);
      });
    }
    return storeMediaImageList;
  }

  // -------------------------------- threads --------------------------------
  // Local echoes composed inside a thread must never show up in the channel
  // list, but they still need the channel's upload-progress machinery. These
  // three helpers are the only place that knows which list owns an echo, so
  // the media / audio / document / location / contact pipelines stay the same
  // for channel sends (target == null, and always with threads off).

  /// Adds a freshly built outgoing [message] to whichever list should show it:
  /// the open thread panel for a thread reply, otherwise the channel list.
  void addLocalOutgoingRow(IsmChatMessageModel message) {
    if (IsmChatThreadCoordinator.isThreadTargetedEcho(message)) {
      final thread = IsmChatThreadController.instance;
      if (thread != null && thread.addLocalReply(message)) {
        return;
      }
      // Thread panel gone (closed mid-send): keep the row out of the channel,
      // the send itself continues and the reply is fetched on reopen.
      return;
    }
    _controller.messages.add(message);
  }

  /// The local row created at [sentAt], wherever it lives — the channel list or
  /// the open thread panel — or `null` when it is gone.
  ///
  /// Upload pipelines look the echo up by timestamp before they start, so this
  /// is what lets a media / voice / document send composed inside a thread use
  /// the very same pipeline.
  IsmChatMessageModel? localOutgoingRow(int sentAt, {bool onlyUnsent = false}) {
    bool matches(IsmChatMessageModel row) =>
        row.sentAt == sentAt &&
        (!onlyUnsent || row.messageId?.isEmpty == true);

    final index = _controller.messages.indexWhere(matches);
    if (index != -1) return _controller.messages[index];
    final replies = IsmChatThreadController.instance?.replies;
    if (replies == null) return null;
    final threadIndex = replies.indexWhere(matches);
    return threadIndex == -1 ? null : replies[threadIndex];
  }

  /// Applies [mutate] to the un-sent local row created at [sentAt], wherever it
  /// lives, and notifies the list that owns it.
  ///
  /// Returns `true` when a row was found and [mutate] reported a change. Used
  /// by the upload pipeline to swap in presigned URLs, clear the uploading
  /// flag, or mark a failure.
  bool mutateLocalRow(
    int sentAt,
    bool Function(IsmChatMessageModel row) mutate, {
    bool onlyUnsent = false,
  }) {
    bool matches(IsmChatMessageModel row) =>
        row.sentAt == sentAt &&
        (!onlyUnsent || row.messageId?.isEmpty == true);

    final index = _controller.messages.indexWhere(matches);
    if (index != -1) {
      final row = _controller.messages[index];
      if (!mutate(row)) return false;
      _controller.messages[index] = row;
      final list = _controller.messages;
      if (list is RxList<IsmChatMessageModel>) {
        list.refresh();
      }
      _controller.update();
      return true;
    }
    // Not in the channel list → it may be an echo inside the open thread.
    return IsmChatThreadController.instance?.mutateLocalReply(
          sentAt,
          mutate,
          onlyUnsent: onlyUnsent,
        ) ??
        false;
  }

  /// Updates the indexed message list mapping.
  ///
  /// This method is used by other mixins (e.g., get_message.dart) to update
  /// the indexed message list after messages are loaded.
  // ignore: unused_element
  void _generateIndexedMessageList() =>
      _controller.indexedMessageList = _controller.viewModel.generateIndexedMessageList(_controller.messages);
}

