import 'dart:convert';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Unsent composer state for one conversation (text and optional reply).
///
/// Attachments are never part of a draft. `@mentions` are kept as plain text
/// in [text]; they are resolved again from group members on send.
class IsmChatDraftModel {
  const IsmChatDraftModel({
    required this.text,
    this.replyMessage,
    this.updatedAt = 0,
  });

  factory IsmChatDraftModel.fromMap(Map<String, dynamic> map) {
    final reply = map['replyMessage'];
    return IsmChatDraftModel(
      text: map['text'] as String? ?? '',
      replyMessage: reply is Map
          ? IsmChatMessageModel.fromMap(Map<String, dynamic>.from(reply))
          : null,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }

  factory IsmChatDraftModel.fromJson(String source) =>
      IsmChatDraftModel.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Raw composer text, including `@mention` labels.
  final String text;

  /// Message being replied to, if the reply bar was open.
  final IsmChatMessageModel? replyMessage;

  /// Last edit time in milliseconds since epoch.
  final int updatedAt;

  /// Nothing worth keeping: blank text and no reply.
  bool get isEmpty => text.trim().isEmpty && replyMessage == null;

  bool sameContentAs(IsmChatDraftModel? other) =>
      other != null &&
      other.text == text &&
      other.replyMessage?.messageId == replyMessage?.messageId &&
      other.replyMessage?.sentAt == replyMessage?.sentAt;

  Map<String, dynamic> toMap() => {
        'text': text,
        if (replyMessage != null) 'replyMessage': replyMessage!.toMap(),
        'updatedAt': updatedAt,
      };

  String toJson() => json.encode(toMap());
}
