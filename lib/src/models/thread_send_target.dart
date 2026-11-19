import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Where a send should land when it is composed inside a thread.
///
/// The channel composer sends with no target (`null`), which is the behaviour
/// the SDK has always had. The thread panel sets a target before it triggers a
/// send — attachment sheet, camera, voice note, location, contact — so the
/// existing send pipelines post the message as a **thread reply**
/// (`messageType: 2`, `parentMessageId`, `showInConversation`) instead of a
/// channel message.
///
/// The target is captured into the local echo at build time
/// ([IsmChatThreadCoordinator.stampThreadTarget]) and the API call then reads
/// its fields back off that echo, so a target that changes mid-upload (user
/// closes the thread and sends in the channel) can never mislabel a message
/// already in flight.
///
/// See `docs/THREADS.md`.
class IsmChatThreadSendTarget {
  const IsmChatThreadSendTarget({
    required this.threadRootId,
    required this.parentMessageId,
    this.alsoSendToChannel = false,
  });

  /// Builds the target for replying inside [root]'s thread.
  ///
  /// [replyTo] is the message being answered (a reply, for a nested reply);
  /// omit it to answer the root, which is Slack's default.
  factory IsmChatThreadSendTarget.forThread({
    required IsmChatMessageModel root,
    IsmChatMessageModel? replyTo,
    bool alsoSendToChannel = false,
  }) {
    final parent = replyTo ?? root;
    return IsmChatThreadSendTarget(
      threadRootId: IsmChatThreadCoordinator.threadIdOf(root),
      parentMessageId: (parent.messageId ?? '').trim(),
      alsoSendToChannel: alsoSendToChannel,
    );
  }

  /// Root of the thread the message belongs to (server `threadRootId`).
  final String threadRootId;

  /// Immediate parent: the root, or the reply being answered.
  final String parentMessageId;

  /// Slack's "Also send to channel" — the reply is posted with
  /// `showInConversation: true` so it shows in the channel as well.
  final bool alsoSendToChannel;

  /// `showInConversation` to send for this target.
  bool get showInConversation => alsoSendToChannel;

  /// Whether this target can actually be used (ids resolved).
  bool get isValid => threadRootId.isNotEmpty && parentMessageId.isNotEmpty;

  @override
  String toString() => 'IsmChatThreadSendTarget(threadRootId: $threadRootId, '
      'parentMessageId: $parentMessageId, '
      'alsoSendToChannel: $alsoSendToChannel)';

  @override
  bool operator ==(Object other) =>
      other is IsmChatThreadSendTarget &&
      other.threadRootId == threadRootId &&
      other.parentMessageId == parentMessageId &&
      other.alsoSendToChannel == alsoSendToChannel;

  @override
  int get hashCode =>
      threadRootId.hashCode ^
      parentMessageId.hashCode ^
      alsoSendToChannel.hashCode;
}
