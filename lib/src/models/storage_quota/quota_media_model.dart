import 'dart:convert';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// A single charged media row from `GET /chat/quota/storage/media`.
///
/// One row is one *send*: sending the same video twice produces two rows even
/// though it is charged once. Rows arrive newest-charged-first.
///
/// When [restricted] is `true` the file is past the user's current allowance:
/// [mediaUrl] and [thumbnailUrl] are `null`, so show the row (with its size)
/// in the storage list so the user can delete it, but do not open the media.
/// Files inside the allowance become readable again on the next fetch once the
/// earliest remaining files fit.
class IsmChatQuotaMediaModel {
  const IsmChatQuotaMediaModel({
    required this.mediaId,
    required this.messageId,
    required this.conversationId,
    required this.attachmentType,
    required this.name,
    required this.size,
    this.mediaUrl,
    this.thumbnailUrl,
    this.restricted = false,
  });

  factory IsmChatQuotaMediaModel.fromJson(String source) =>
      IsmChatQuotaMediaModel.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  factory IsmChatQuotaMediaModel.fromMap(Map<String, dynamic> map) =>
      IsmChatQuotaMediaModel(
        mediaId: map['mediaId'] as String? ?? '',
        messageId: map['messageId'] as String? ?? '',
        conversationId: map['conversationId'] as String? ?? '',
        attachmentType:
            IsmChatMediaType.fromMap(_asInt(map['attachmentType']) ?? 0),
        name: map['name'] as String? ?? '',
        size: _asInt(map['size']) ?? 0,
        mediaUrl: _nullIfEmpty(map['mediaUrl']),
        thumbnailUrl: _nullIfEmpty(map['thumbnailUrl']),
        restricted: map['restricted'] as bool? ?? false,
      );

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Treats `null` / empty / whitespace as `null`; otherwise the trimmed value.
  /// Restricted rows send `mediaUrl`/`thumbnailUrl` as `null`.
  static String? _nullIfEmpty(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Stable id of this media row. Pass to `DELETE /chat/quota/media`.
  final String mediaId;

  /// The message this media belongs to. Deleting the media removes this whole
  /// message for everyone in the conversation.
  final String messageId;

  /// The conversation the media was sent in.
  final String conversationId;

  /// The attachment kind (image/video/audio/document/custom...). The server's
  /// numeric `attachmentType` maps onto [IsmChatMediaType].
  final IsmChatMediaType attachmentType;

  /// File name (with extension), e.g. `clip.mp4`.
  final String name;

  /// Size in bytes charged for this send.
  final int size;

  /// Signed URL to the media, or `null` when [restricted] / unavailable.
  final String? mediaUrl;

  /// Signed URL to the thumbnail, or `null` when [restricted] / unavailable.
  final String? thumbnailUrl;

  /// `true` when the file is past the current allowance (hidden on fetch).
  final bool restricted;

  /// Whether this row can be previewed (has a usable media URL and is not
  /// restricted).
  bool get isViewable => !restricted && (mediaUrl?.isNotEmpty ?? false);

  IsmChatQuotaMediaModel copyWith({
    String? mediaId,
    String? messageId,
    String? conversationId,
    IsmChatMediaType? attachmentType,
    String? name,
    int? size,
    String? mediaUrl,
    String? thumbnailUrl,
    bool? restricted,
  }) =>
      IsmChatQuotaMediaModel(
        mediaId: mediaId ?? this.mediaId,
        messageId: messageId ?? this.messageId,
        conversationId: conversationId ?? this.conversationId,
        attachmentType: attachmentType ?? this.attachmentType,
        name: name ?? this.name,
        size: size ?? this.size,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        restricted: restricted ?? this.restricted,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'mediaId': mediaId,
        'messageId': messageId,
        'conversationId': conversationId,
        'attachmentType': attachmentType.value,
        'name': name,
        'size': size,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'restricted': restricted,
      };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'IsmChatQuotaMediaModel(mediaId: $mediaId, messageId: $messageId, conversationId: $conversationId, attachmentType: $attachmentType, name: $name, size: $size, restricted: $restricted)';

  @override
  bool operator ==(covariant IsmChatQuotaMediaModel other) {
    if (identical(this, other)) return true;
    return other.mediaId == mediaId &&
        other.messageId == messageId &&
        other.conversationId == conversationId &&
        other.attachmentType == attachmentType &&
        other.name == name &&
        other.size == size &&
        other.mediaUrl == mediaUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.restricted == restricted;
  }

  @override
  int get hashCode =>
      mediaId.hashCode ^
      messageId.hashCode ^
      conversationId.hashCode ^
      attachmentType.hashCode ^
      name.hashCode ^
      size.hashCode ^
      mediaUrl.hashCode ^
      thumbnailUrl.hashCode ^
      restricted.hashCode;
}

/// Response shape of `GET /chat/quota/storage/media`.
///
/// [media] is empty when the user has no charged media (including when quota is
/// off). Stop paging when [media] is empty or shorter than the requested
/// `limit`.
class IsmChatQuotaMediaResponseModel {
  const IsmChatQuotaMediaResponseModel({
    required this.quotaEnabled,
    required this.media,
    this.msg,
  });

  factory IsmChatQuotaMediaResponseModel.fromJson(String source) =>
      IsmChatQuotaMediaResponseModel.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  factory IsmChatQuotaMediaResponseModel.fromMap(Map<String, dynamic> map) =>
      IsmChatQuotaMediaResponseModel(
        quotaEnabled: map['quotaEnabled'] as bool? ?? false,
        msg: map['msg'] as String?,
        media: (map['media'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(IsmChatQuotaMediaModel.fromMap)
                .toList() ??
            const [],
      );

  final bool quotaEnabled;
  final String? msg;
  final List<IsmChatQuotaMediaModel> media;

  @override
  String toString() =>
      'IsmChatQuotaMediaResponseModel(quotaEnabled: $quotaEnabled, msg: $msg, media: ${media.length})';
}
