import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// App-overridable icons and profile widgets for conversation info screens
/// ([IsmChatConverstaionInfoView], [IsmChatUserInfo]).
///
/// Kept separate from [IsmChatPageProperties] and list
/// [IsmChatCardProperties] so chat-page and conversation-list settings stay lean.
/// Configure via [IsmChatProperties.conversationInfoAssets].
///
/// Example:
/// ```dart
/// IsmChatProperties.conversationInfoAssets = IsmChatConversationInfoAssets(
///   profileImageBuilder: (context, conversation, url) => MyHeroAvatar(...),
///   groupMemberProfileImageBuilder: (context, member) => MyMemberAvatar(...),
///   clearChatIcon: SvgPicture.asset('assets/icons/clear_chat.svg'),
///   exitGroupIcon: SvgPicture.asset('assets/icons/exit_group.svg'),
///   deleteChatIcon: SvgPicture.asset('assets/icons/delete_chat.svg'),
///   blockUserIcon: SvgPicture.asset('assets/icons/block.svg'),
///   unblockUserIcon: SvgPicture.asset('assets/icons/unblock.svg'),
///   conversationMediaIcon: SvgPicture.asset('assets/icons/gallery.svg'),
///   groupProfileEditIcon: Icon(Icons.camera_alt_outlined, size: 18),
/// );
/// ```
class IsmChatConversationInfoAssets {
  IsmChatConversationInfoAssets({
    this.profileImageBuilder,
    this.profileImageUrl,
    this.groupMemberProfileImageBuilder,
    this.groupMemberProfileImageUrl,
    this.groupProfileEditIcon,
    this.conversationMediaIcon,
    this.clearChatIcon,
    this.deleteChatIcon,
    this.exitGroupIcon,
    this.blockUserIcon,
    this.unblockUserIcon,
    this.changeGroupTitleIcon,
    this.changeGroupImageIcon,
  });

  /// Hero profile on group/conversation info and [IsmChatUserInfo].
  ///
  /// Size your widget for context (~100 group info, ~150 contact info).
  /// If null, SDK uses [IsmChatImage.profile] with [profileImageUrl] when set.
  final ConversationWidgetCallback? profileImageBuilder;

  /// Optional URL override for the hero avatar default image.
  final ConversationStringCallback? profileImageUrl;

  /// Avatar for each row in the group participants list.
  ///
  /// If null, SDK uses [IsmChatImage.profile] with [groupMemberProfileImageUrl]
  /// when set.
  final UserDetailsWidgetCallback? groupMemberProfileImageBuilder;

  /// Optional URL override for group member list default avatars.
  final UserDetailsStringCallback? groupMemberProfileImageUrl;

  /// Edit badge on the group profile photo.
  ///
  /// If null, SDK uses `Icons.edit_outlined`.
  final Widget? groupProfileEditIcon;

  /// Leading icon for the Media / Links / Docs row.
  ///
  /// Reused by group info and 1:1 [IsmChatUserInfo].
  /// If null, SDK uses [IsmChatAssets.gallarySvg].
  final Widget? conversationMediaIcon;

  /// Clear chat action (group + 1:1).
  ///
  /// If null, SDK defaults:
  /// - Group: `Icons.clear_all_rounded`
  /// - 1:1: `Icons.clear_all_outlined` (red)
  final Widget? clearChatIcon;

  /// Delete chat action (1:1).
  ///
  /// If null, SDK uses `Icons.delete_forever_outlined` (red).
  final Widget? deleteChatIcon;

  /// Exit group action.
  ///
  /// If null, SDK uses `Icons.logout_rounded` (red).
  final Widget? exitGroupIcon;

  /// Block action when the opponent is not blocked.
  ///
  /// Pair with [unblockUserIcon]. If null, SDK uses `Icons.block_outlined` (red).
  final Widget? blockUserIcon;

  /// Unblock action when the opponent is blocked.
  ///
  /// If null, falls back to [blockUserIcon], then SDK `Icons.block_outlined` (red).
  final Widget? unblockUserIcon;

//Menu icons
  final Widget? changeGroupTitleIcon;

  final Widget? changeGroupImageIcon;
}
