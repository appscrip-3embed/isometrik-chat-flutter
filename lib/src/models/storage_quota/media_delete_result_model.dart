import 'dart:convert';

/// Result of a quota media delete.
///
/// Returned by `DELETE /chat/quota/media`,
/// `DELETE /chat/quota/storage/conversation/{id}/media`, and by
/// `DELETE /chat/message` when quota is on.
///
/// [freedBytes] can be `0` when a video/audio/document still has another charged
/// copy with the same name and size (the message is still removed). After a
/// successful delete, refresh usage: if [usedBytes] is back under [quotaBytes],
/// uploads become allowed again.
class IsmChatMediaDeleteResultModel {
  const IsmChatMediaDeleteResultModel({
    required this.freedBytes,
    this.usedBytes,
    this.quotaBytes,
    this.msg,
  });

  factory IsmChatMediaDeleteResultModel.fromJson(String source) =>
      IsmChatMediaDeleteResultModel.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  factory IsmChatMediaDeleteResultModel.fromMap(Map<String, dynamic> map) =>
      IsmChatMediaDeleteResultModel(
        freedBytes: _asInt(map['freedBytes']) ?? 0,
        usedBytes: _asInt(map['usedBytes']),
        quotaBytes: _asInt(map['quotaBytes']),
        msg: map['msg'] as String?,
      );

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Bytes freed by this delete. May be `0`.
  final int freedBytes;

  /// The user's usage after the delete, in bytes. `null` if not reported.
  final int? usedBytes;

  /// The user's allowance in bytes. `null` if not reported.
  final int? quotaBytes;

  /// Server message, e.g. `Media deleted successfully.`
  final String? msg;

  /// Whether usage is now below the allowance (so uploads are allowed again).
  /// Returns `null` when the server did not report both figures.
  bool? get isUnderQuota {
    final used = usedBytes;
    final quota = quotaBytes;
    if (used == null || quota == null) return null;
    return used < quota;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'freedBytes': freedBytes,
        'usedBytes': usedBytes,
        'quotaBytes': quotaBytes,
        'msg': msg,
      };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'IsmChatMediaDeleteResultModel(freedBytes: $freedBytes, usedBytes: $usedBytes, quotaBytes: $quotaBytes, msg: $msg)';
}
