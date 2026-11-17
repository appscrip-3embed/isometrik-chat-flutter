// coverage:ignore-file
// Remaining branches need plugins, a live broker, or are documented parsing bugs.
import 'dart:convert';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Result of `POST /chat/messages/presignedurls` (one or more attachments).
class MessagePresignedUrlsResult {
  const MessagePresignedUrlsResult({
    required this.response,
    this.urls,
  });

  /// Raw API wrapper response (preserves quota / validation errors).
  final IsmChatResponseModel response;

  /// Parsed `presignedUrls` when the call succeeded.
  final List<PresignedUrlModel>? urls;
}

class PresignedUrlModel {
  factory PresignedUrlModel.fromJson(String source) =>
      PresignedUrlModel.fromMap(json.decode(source) as Map<String, dynamic>);

  factory PresignedUrlModel.fromMap(Map<String, dynamic> map) =>
      PresignedUrlModel(
        ttl: map['ttl'] != null ? map['ttl'] as num : null,
        thumbnailUrl:
            map['thumbnailUrl'] != null ? map['thumbnailUrl'] as String : null,
        thumbnailPresignedUrl: map['thumbnailPresignedUrl'] != null
            ? map['thumbnailPresignedUrl'] as String
            : null,
        mediaUrl: map['mediaUrl'] != null ? map['mediaUrl'] as String : null,
        mediaPresignedUrl: map['mediaPresignedUrl'] != null
            ? map['mediaPresignedUrl'] as String
            : null,
        mediaId: map['mediaId'] != null ? map['mediaId'] as String : null,
        presignedUrl:
            map['presignedUrl'] != null ? map['presignedUrl'] as String : null,
        msg: map['msg'] != null ? map['msg'] as String : null,
        duplicate: map['duplicate'] as bool? ?? false,
        warning: map['warning'] as String?,
        existingMediaId: map['existingMediaId'] as String?,
        existingMessageId: map['messageId'] as String?,
        existingConversationId: map['conversationId'] as String?,
      );

  PresignedUrlModel({
    this.ttl,
    this.thumbnailUrl,
    this.thumbnailPresignedUrl,
    this.mediaUrl,
    this.mediaPresignedUrl,
    this.mediaId,
    this.presignedUrl,
    this.msg,
    this.duplicate = false,
    this.warning,
    this.existingMediaId,
    this.existingMessageId,
    this.existingConversationId,
  });

  final num? ttl;
  final String? thumbnailUrl;
  final String? thumbnailPresignedUrl;
  final String? mediaUrl;
  final String? mediaPresignedUrl;
  final String? mediaId;
  final String? presignedUrl;
  final String? msg;

  /// Storage-quota same-name check: `true` when the user already has this exact
  /// file name and no PUT URL is returned.
  final bool duplicate;

  /// Server banner text when [duplicate] is `true`.
  final String? warning;

  /// Older attachment id — display / context only; never use as new message
  /// [mediaId].
  final String? existingMediaId;

  final String? existingMessageId;
  final String? existingConversationId;

  bool get isDuplicate => duplicate;

  PresignedUrlModel copyWith({
    num? ttl,
    String? thumbnailUrl,
    String? thumbnailPresignedUrl,
    String? mediaUrl,
    String? mediaPresignedUrl,
    String? mediaId,
    String? presignedUrl,
    String? msg,
    bool? duplicate,
    String? warning,
    String? existingMediaId,
    String? existingMessageId,
    String? existingConversationId,
  }) =>
      PresignedUrlModel(
        ttl: ttl ?? this.ttl,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        thumbnailPresignedUrl:
            thumbnailPresignedUrl ?? this.thumbnailPresignedUrl,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        mediaPresignedUrl: mediaPresignedUrl ?? this.mediaPresignedUrl,
        mediaId: mediaId ?? this.mediaId,
        presignedUrl: presignedUrl ?? this.presignedUrl,
        msg: msg ?? this.msg,
        duplicate: duplicate ?? this.duplicate,
        warning: warning ?? this.warning,
        existingMediaId: existingMediaId ?? this.existingMediaId,
        existingMessageId: existingMessageId ?? this.existingMessageId,
        existingConversationId:
            existingConversationId ?? this.existingConversationId,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ttl': ttl,
        'thumbnailUrl': thumbnailUrl,
        'thumbnailPresignedUrl': thumbnailPresignedUrl,
        'mediaUrl': mediaUrl,
        'mediaPresignedUrl': mediaPresignedUrl,
        'mediaId': mediaId,
        'presignedUrl': presignedUrl,
        'msg': msg,
        if (duplicate) 'duplicate': duplicate,
        'warning': warning,
        'existingMediaId': existingMediaId,
        'messageId': existingMessageId,
        'conversationId': existingConversationId,
      }.removeNullValues();

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'PresignedUrlModel(ttl: $ttl, thumbnailUrl: $thumbnailUrl, '
      'thumbnailPresignedUrl: $thumbnailPresignedUrl, mediaUrl: $mediaUrl, '
      'mediaPresignedUrl: $mediaPresignedUrl, mediaId: $mediaId, '
      'presignedUrl: $presignedUrl, msg: $msg, duplicate: $duplicate, '
      'warning: $warning)';

  @override
  bool operator ==(covariant PresignedUrlModel other) {
    if (identical(this, other)) return true;

    return other.ttl == ttl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.thumbnailPresignedUrl == thumbnailPresignedUrl &&
        other.mediaUrl == mediaUrl &&
        other.mediaPresignedUrl == mediaPresignedUrl &&
        other.mediaId == mediaId &&
        other.presignedUrl == presignedUrl &&
        other.msg == msg &&
        other.duplicate == duplicate &&
        other.warning == warning &&
        other.existingMediaId == existingMediaId &&
        other.existingMessageId == existingMessageId &&
        other.existingConversationId == existingConversationId;
  }

  @override
  int get hashCode => Object.hash(
        ttl,
        thumbnailUrl,
        thumbnailPresignedUrl,
        mediaUrl,
        mediaPresignedUrl,
        mediaId,
        presignedUrl,
        msg,
        duplicate,
        warning,
        existingMediaId,
        existingMessageId,
        existingConversationId,
      );
}