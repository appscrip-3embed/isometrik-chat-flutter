import 'dart:typed_data';

import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import 'test_bootstrap.dart';

/// Shared model factories for tests.
///
/// **Reuse:** prefer these over hand-built models so a change to a model's
/// required fields only needs fixing here. Every factory takes the fields a
/// test usually varies as named parameters with sensible defaults.

/// Conversation id used by the default 1-to-1 fixture.
const kDirectConversationId = 'conv-direct';

/// Conversation id used by the default group fixture.
const kGroupConversationId = 'conv-group';

UserDetails user({
  String id = kOpponentId,
  String name = kOpponentName,
  bool isAdmin = false,
  String? firstName,
  String? lastName,
}) =>
    UserDetails(
      userProfileImageUrl: 'https://img.test/$id.png',
      userName: name,
      userIdentifier: '$id@test.com',
      userId: id,
      online: false,
      lastSeen: 0,
      isAdmin: isAdmin,
      metaData: IsmChatMetaData(firstName: firstName, lastName: lastName),
    );

/// The logged-in user as [UserDetails].
UserDetails me() => user(id: kMeId, name: kMeName);

/// A private 1-to-1 conversation between [kMeId] and [kOpponentId].
IsmChatConversationModel directConversation({
  String conversationId = kDirectConversationId,
  Map<String, IsmChatMessageModel>? messages,
  IsmChatMetaData? metaData,
  bool messagingDisabled = false,
}) =>
    IsmChatConversationModel(
      conversationId: conversationId,
      isGroup: false,
      privateOneToOne: true,
      opponentDetails: user(),
      membersCount: 2,
      conversationType: IsmChatConversationType.private,
      conversationTitle: '',
      conversationImageUrl: '',
      messages: messages ?? {},
      metaData: metaData ?? IsmChatMetaData(),
      messagingDisabled: messagingDisabled,
      userIds: const [kMeId, kOpponentId],
      members: [me(), user()],
      lastReadAt: const [],
      config: ConversationConfigModel(
        typingEvents: true,
        readEvents: true,
        pushNotifications: true,
      ),
    );

/// A group with [kMeId] as admin plus two members.
IsmChatConversationModel groupConversation({
  String conversationId = kGroupConversationId,
  String title = 'Test Group',
  Map<String, IsmChatMessageModel>? messages,
  bool meAdmin = true,
}) =>
    IsmChatConversationModel(
      conversationId: conversationId,
      isGroup: true,
      privateOneToOne: false,
      conversationTitle: title,
      conversationImageUrl: 'https://img.test/group.png',
      membersCount: 3,
      conversationType: IsmChatConversationType.private,
      messages: messages ?? {},
      metaData: IsmChatMetaData(),
      createdBy: kMeId,
      userIds: const [kMeId, kOpponentId, 'user-third'],
      members: [
        user(id: kMeId, name: kMeName, isAdmin: meAdmin),
        user(),
        user(id: 'user-third', name: 'Third'),
      ],
      lastReadAt: const [],
      config: ConversationConfigModel(
        typingEvents: true,
        readEvents: true,
        pushNotifications: true,
      ),
    );

/// A message of any [customType]. `sentByMe` defaults to true.
IsmChatMessageModel message({
  String body = 'hello',
  IsmChatCustomMessageType customType = IsmChatCustomMessageType.text,
  int sentAt = 1000,
  bool sentByMe = true,
  String? messageId,
  String conversationId = kDirectConversationId,
  List<AttachmentModel>? attachments,
  IsmChatMetaData? metaData,
  IsmChatMessageType messageType = IsmChatMessageType.normal,
  String? parentMessageId,
  bool isGroup = false,
  List<UserDetails>? mentionedUsers,
  List<MessageReactionModel>? reactions,
}) =>
    IsmChatMessageModel(
      body: body,
      customType: customType,
      sentAt: sentAt,
      sentByMe: sentByMe,
      messageId: messageId ?? 'msg-$sentAt',
      conversationId: conversationId,
      attachments: attachments,
      metaData: metaData ?? IsmChatMetaData(),
      messageType: messageType,
      parentMessageId: parentMessageId,
      isGroup: isGroup,
      senderInfo: sentByMe ? me() : user(),
      mentionedUsers: mentionedUsers,
      reactions: reactions,
      deliveredTo: const [],
      readBy: const [],
      lastReadAt: const [],
    );

/// [Reaction] payload for repository / view-model tests and mocktail `any()`.
Reaction reaction({
  IsmChatEmoji reactionType = IsmChatEmoji.yes,
  String messageId = 'm',
  String conversationId = kDirectConversationId,
}) =>
    Reaction(
      reactionType: reactionType,
      messageId: messageId,
      conversationId: conversationId,
    );

/// One attachment per media type, matching what the send flows build.
AttachmentModel attachment(IsmChatMediaType type) => switch (type) {
      IsmChatMediaType.location => AttachmentModel(
          attachmentType: type,
          latitude: 12.97,
          longitude: 77.59,
          title: 'Office',
          address: 'MG Road',
        ),
      _ => AttachmentModel(
          attachmentType: type,
          mediaUrl: 'https://cdn.test/${type.name}.bin',
          thumbnailUrl: 'https://cdn.test/${type.name}_thumb.png',
          name: '${type.name}.bin',
          mimeType: 'application/octet-stream',
          extension: 'bin',
          size: 1024,
          mediaId: 'media-${type.name}',
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
    };

/// Message fixtures for every attachment-bearing custom type.
Map<IsmChatCustomMessageType, IsmChatMessageModel> attachmentMessages() => {
      IsmChatCustomMessageType.image: message(
        customType: IsmChatCustomMessageType.image,
        attachments: [attachment(IsmChatMediaType.image)],
        sentAt: 2001,
      ),
      IsmChatCustomMessageType.video: message(
        customType: IsmChatCustomMessageType.video,
        attachments: [attachment(IsmChatMediaType.video)],
        sentAt: 2002,
      ),
      IsmChatCustomMessageType.audio: message(
        customType: IsmChatCustomMessageType.audio,
        attachments: [attachment(IsmChatMediaType.audio)],
        sentAt: 2003,
      ),
      IsmChatCustomMessageType.file: message(
        customType: IsmChatCustomMessageType.file,
        attachments: [attachment(IsmChatMediaType.file)],
        sentAt: 2004,
      ),
      IsmChatCustomMessageType.location: message(
        customType: IsmChatCustomMessageType.location,
        attachments: [attachment(IsmChatMediaType.location)],
        sentAt: 2005,
      ),
      IsmChatCustomMessageType.contact: message(
        customType: IsmChatCustomMessageType.contact,
        sentAt: 2006,
        metaData: IsmChatMetaData(
          contacts: [
            IsmChatContactMetaDatModel(
              contactName: 'Alice',
              contactIdentifier: '+15550001',
              contactImageUrl: '',
            ),
          ],
        ),
      ),
    };

/// Raw API JSON for a message, as returned by `GET /chat/messages`.
Map<String, dynamic> messageJson({
  String messageId = 'msg-api-1',
  String body = 'from api',
  int sentAt = 5000,
  String conversationId = kDirectConversationId,
  String senderId = kOpponentId,
  String? customType = 'text',
  String? action,
  List<Map<String, dynamic>>? attachments,
}) =>
    {
      'messageId': messageId,
      'body': body,
      'sentAt': sentAt,
      'conversationId': conversationId,
      'customType': customType,
      if (action != null) 'action': action,
      'messageType': 0,
      'senderInfo': {
        'userId': senderId,
        'userName': senderId == kMeId ? kMeName : kOpponentName,
        'userIdentifier': '$senderId@test.com',
        'userProfileImageUrl': '',
      },
      'deliveredTo': <dynamic>[],
      'readBy': <dynamic>[],
      if (attachments != null) 'attachments': attachments,
    };

/// Raw API JSON for a conversation, as returned by `GET /chat/conversations`.
Map<String, dynamic> conversationJson({
  String conversationId = kDirectConversationId,
  bool isGroup = false,
  String title = '',
}) =>
    {
      'conversationId': conversationId,
      'isGroup': isGroup,
      'privateOneToOne': !isGroup,
      'conversationTitle': title,
      'conversationImageUrl': '',
      'membersCount': isGroup ? 3 : 2,
      'unreadMessagesCount': 1,
      'opponentDetails': isGroup
          ? null
          : {
              'userId': kOpponentId,
              'userName': kOpponentName,
              'userIdentifier': '$kOpponentId@test.com',
              'userProfileImageUrl': '',
            },
      'lastMessageDetails': {
        'messageId': 'msg-last',
        'body': 'latest',
        'sentAt': 9000,
        'conversationId': conversationId,
        'senderName': kOpponentName,
        'senderId': kOpponentId,
        'messageType': 0,
        'showInConversation': true,
        'customType': 'text',
        'action': 'conversationCreated',
      },
    };
