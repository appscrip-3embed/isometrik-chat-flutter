// coverage:ignore-file
// Remaining branches need plugins, a live broker, or are documented parsing bugs.
// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class MessageReactionModel {
  final String emojiKey;
  final List<String> userIds;
  MessageReactionModel({
    required this.emojiKey,
    required this.userIds,
  });

  /// Adds [userId] at most once.
  ///
  /// Reuse on every local reaction-write path (API success in
  /// [IsmChatPageViewModel.addReacton], MQTT [handleAddAndRemoveReaction],
  /// thread [IsmChatThreadController.applyReactionChange]). The reacting
  /// device often gets both the HTTP success patch and an MQTT echo; without
  /// this guard the same user appears twice (chip count 2 / detail list
  /// duplicated) while other devices stay correct.
  bool addUserIfAbsent(String userId) {
    final id = userId.trim();
    if (id.isEmpty || userIds.contains(id)) {
      return false;
    }
    userIds.add(id);
    return true;
  }

  /// Removes every occurrence of [userId] (also clears accidental duplicates).
  bool removeUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) {
      return false;
    }
    final before = userIds.length;
    userIds.removeWhere((e) => e == id);
    return userIds.length != before;
  }

  MessageReactionModel copyWith({
    String? emojiKey,
    List<String>? userIds,
  }) =>
      MessageReactionModel(
        emojiKey: emojiKey ?? this.emojiKey,
        userIds: userIds ?? this.userIds,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'emojiKey': emojiKey,
        'userIds': userIds,
      }.removeNullValues();

  factory MessageReactionModel.fromMap(Map<String, dynamic> map) =>
      MessageReactionModel(
        emojiKey: map['emojiKey'] as String? ?? '',
        userIds: map['userIds'] != null
            ? List<String>.from(
                map['userIds'] as List,
              )
            : [],
      );

  String toJson() => json.encode(toMap());

  factory MessageReactionModel.fromJson(String source) =>
      MessageReactionModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'MessageReactionModel(emojiKey: $emojiKey, userIds: $userIds)';

  @override
  bool operator ==(covariant MessageReactionModel other) {
    if (identical(this, other)) return true;

    return other.emojiKey == emojiKey && listEquals(other.userIds, userIds);
  }

  @override
  int get hashCode => emojiKey.hashCode ^ userIds.hashCode;
}
