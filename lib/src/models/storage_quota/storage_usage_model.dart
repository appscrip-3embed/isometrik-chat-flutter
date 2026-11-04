import 'dart:convert';

/// Server-authoritative snapshot of a user's media storage quota.
///
/// Returned by `GET /chat/quota/storage/usage`. Usage is always read from the
/// server and never computed on-device — treat these numbers as the source of
/// truth and refresh them after every upload or delete.
///
/// When quota is turned off for the project ([quotaEnabled] is `false`),
/// [usedBytes], [quotaBytes], [remainingBytes] and [tier] are `null` and
/// [canUpload] is `true` (today's upload flow is unchanged).
///
/// See also:
/// - [IsmChatStorageQuotaTier] — the resolved allowance tier.
/// - `IsmChatQuotaMediaResponseModel` — the user's charged media list.
class IsmChatStorageUsageModel {
  const IsmChatStorageUsageModel({
    required this.quotaEnabled,
    required this.canUpload,
    this.usedBytes,
    this.quotaBytes,
    this.remainingBytes,
    this.tier,
  });

  factory IsmChatStorageUsageModel.fromJson(String source) =>
      IsmChatStorageUsageModel.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  factory IsmChatStorageUsageModel.fromMap(Map<String, dynamic> map) =>
      IsmChatStorageUsageModel(
        quotaEnabled: map['quotaEnabled'] as bool? ?? false,
        // Server omits/na-nulls `canUpload` only in error shapes; default true
        // so a missing value never wrongly blocks the composer.
        canUpload: map['canUpload'] as bool? ?? true,
        usedBytes: _asInt(map['usedBytes']),
        quotaBytes: _asInt(map['quotaBytes']),
        remainingBytes: _asInt(map['remainingBytes']),
        tier: IsmChatStorageQuotaTier.fromValue(map['tier'] as String?),
      );

  /// Parses a byte count that may arrive as `int`, `double`, `String` or null.
  ///
  /// Byte counts can exceed 2^32 (e.g. 100 GB) so we keep them as [int]
  /// (safe up to 2^53 on web).
  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Whether the project has media quotas switched on. When `false` the whole
  /// feature is dormant and the SDK behaves exactly as it does today.
  final bool quotaEnabled;

  /// Whether a new attachment upload is currently allowed. `false` when the
  /// user is at/over their allowance. Text messages are always allowed.
  final bool canUpload;

  /// Bytes currently charged to this user. `null` when quota is off.
  final int? usedBytes;

  /// The user's total allowance in bytes. `null` when quota is off.
  final int? quotaBytes;

  /// `quotaBytes - usedBytes`, never below `0`. `null` when quota is off.
  final int? remainingBytes;

  /// The resolved allowance tier (`paid` / `free`). `null` when quota is off.
  final IsmChatStorageQuotaTier? tier;

  /// Fraction of the allowance used, in `0.0..1.0`. Returns `0` when quota is
  /// off or the allowance is unknown/zero. Handy for a progress bar.
  double get usedFraction {
    final used = usedBytes;
    final quota = quotaBytes;
    if (used == null || quota == null || quota <= 0) return 0;
    final fraction = used / quota;
    if (fraction.isNaN) return 0;
    return fraction.clamp(0.0, 1.0);
  }

  /// `true` when the user is at or above their allowance (and so blocked from
  /// uploading new media). Always `false` when quota is off.
  bool get isOverLimit =>
      quotaEnabled && !canUpload;

  /// Whether usage has reached [threshold] of the allowance (e.g. `0.9` for 90%).
  ///
  /// Used by the conversation-list warning banner. Always `false` when quota is
  /// off or [quotaBytes] is zero/unknown.
  bool shouldWarnNearQuota({double threshold = 0.9}) =>
      quotaEnabled &&
      (quotaBytes ?? 0) > 0 &&
      usedFraction >= threshold;

  /// Whether a prospective upload of [size] bytes fits in the remaining
  /// allowance. Always `true` when quota is off. Mirrors the server rule:
  /// a file larger than [remainingBytes] is rejected on send.
  bool canUploadBytes(int size) {
    if (!quotaEnabled) return true;
    if (!canUpload) return false;
    final remaining = remainingBytes;
    if (remaining == null) return true;
    return size <= remaining;
  }

  IsmChatStorageUsageModel copyWith({
    bool? quotaEnabled,
    bool? canUpload,
    int? usedBytes,
    int? quotaBytes,
    int? remainingBytes,
    IsmChatStorageQuotaTier? tier,
  }) =>
      IsmChatStorageUsageModel(
        quotaEnabled: quotaEnabled ?? this.quotaEnabled,
        canUpload: canUpload ?? this.canUpload,
        usedBytes: usedBytes ?? this.usedBytes,
        quotaBytes: quotaBytes ?? this.quotaBytes,
        remainingBytes: remainingBytes ?? this.remainingBytes,
        tier: tier ?? this.tier,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'quotaEnabled': quotaEnabled,
        'canUpload': canUpload,
        'usedBytes': usedBytes,
        'quotaBytes': quotaBytes,
        'remainingBytes': remainingBytes,
        'tier': tier?.value,
      };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'IsmChatStorageUsageModel(quotaEnabled: $quotaEnabled, canUpload: $canUpload, usedBytes: $usedBytes, quotaBytes: $quotaBytes, remainingBytes: $remainingBytes, tier: $tier)';

  @override
  bool operator ==(covariant IsmChatStorageUsageModel other) {
    if (identical(this, other)) return true;
    return other.quotaEnabled == quotaEnabled &&
        other.canUpload == canUpload &&
        other.usedBytes == usedBytes &&
        other.quotaBytes == quotaBytes &&
        other.remainingBytes == remainingBytes &&
        other.tier == tier;
  }

  @override
  int get hashCode =>
      quotaEnabled.hashCode ^
      canUpload.hashCode ^
      usedBytes.hashCode ^
      quotaBytes.hashCode ^
      remainingBytes.hashCode ^
      tier.hashCode;
}

/// The resolved storage allowance tier for a user.
///
/// A missing/unknown tier resolves to [free], matching the server rule
/// ("Missing tier is free").
enum IsmChatStorageQuotaTier {
  free('free'),
  paid('paid');

  const IsmChatStorageQuotaTier(this.value);

  /// Maps the server string to a tier. `null`/unknown → [free].
  factory IsmChatStorageQuotaTier.fromValue(String? value) {
    switch (value) {
      case 'paid':
        return IsmChatStorageQuotaTier.paid;
      case 'free':
      default:
        return IsmChatStorageQuotaTier.free;
    }
  }

  final String value;

  bool get isPaid => this == IsmChatStorageQuotaTier.paid;
}
