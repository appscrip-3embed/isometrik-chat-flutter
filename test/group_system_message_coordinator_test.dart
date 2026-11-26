import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  group('IsmChatGroupSystemMessageCoordinator', () {
    test('buildFromMqttAction sets initiator fields for addMember banner copy',
        () {
      final action = IsmChatMqttActionModel(
        conversationId: 'conv-1',
        sentAt: 1000,
        action: IsmChatActionEvents.addMember,
        userDetails: IsmChatMqttUserModel(
          userId: 'admin-1',
          userName: 'Admin One',
        ),
        members: [
          UserDetails(
            userProfileImageUrl: '',
            userIdentifier: '',
            userId: 'user-2',
            userName: 'Member Two',
            memberId: 'm2',
            memberName: 'Member Two',
            online: false,
            lastSeen: 0,
          ),
        ],
      );

      final row = IsmChatGroupSystemMessageCoordinator.buildFromMqttAction(
        action,
        sentByMe: true,
      );

      expect(row.customType, IsmChatCustomMessageType.addMember);
      expect(row.userId, 'admin-1');
      expect(row.userName, 'Admin One');
      expect(row.sentByMe, isTrue);
    });

    test('replaceMemberLeaveRowsForSubject keeps one row per leaving user', () {
      final oldRow = IsmChatMessageModel(
        body: '',
        customType: IsmChatCustomMessageType.memberLeave,
        sentAt: 1000,
        sentByMe: true,
        userId: 'user-3',
        userName: 'Leaver',
      );
      final map = <String, IsmChatMessageModel>{'1000': oldRow};
      final newRow = oldRow.copyWith(sentAt: 2000);
      IsmChatGroupSystemMessageCoordinator.replaceMemberLeaveRowsForSubject(
        map,
        newRow,
      );
      map['2000'] = newRow;
      expect(map.length, 1);
      expect(map.values.first.sentAt, 2000);
    });

    test('dedupeMemberLeaveTimelineRows collapses duplicate leave banners', () {
      final rows = [
        IsmChatMessageModel(
          body: '',
          customType: IsmChatCustomMessageType.memberLeave,
          sentAt: 1000,
          sentByMe: true,
          userId: 'user-3',
        ),
        IsmChatMessageModel(
          body: '',
          customType: IsmChatCustomMessageType.memberLeave,
          sentAt: 2000,
          sentByMe: true,
          userId: 'user-3',
        ),
      ];
      IsmChatGroupSystemMessageCoordinator.dedupeMemberLeaveTimelineRows(rows);
      expect(rows.length, 1);
      expect(rows.single.sentAt, 2000);
    });

    test('isCurrentUserAmongAddedMembers matches members and memberId', () {
      IsmChatConfig.communicationConfig = IsmChatCommunicationConfig(
        userConfig: const IsmChatUserConfig(
          userToken: 'token',
          userId: 'user-me',
        ),
        mqttConfig: const IsmChatMqttConfig(hostName: '', port: 0),
        projectConfig: const IsmChatProjectConfig(
          accountId: '',
          appSecret: '',
          userSecret: '',
          keySetId: '',
          licenseKey: '',
          projectId: '',
          deviceId: '',
        ),
      );
      final amongMembers = IsmChatMqttActionModel(
        conversationId: 'conv-1',
        sentAt: 1,
        action: IsmChatActionEvents.addMember,
        members: [
          UserDetails(
            userProfileImageUrl: '',
            userIdentifier: '',
            userId: 'user-me',
            userName: 'Me',
            online: false,
            lastSeen: 0,
          ),
        ],
      );
      expect(
        IsmChatGroupSystemMessageCoordinator.isCurrentUserAmongAddedMembers(
          amongMembers,
        ),
        isTrue,
      );

      final byMemberId = IsmChatMqttActionModel(
        conversationId: 'conv-1',
        sentAt: 1,
        action: IsmChatActionEvents.addMember,
        memberId: 'user-me',
      );
      expect(
        IsmChatGroupSystemMessageCoordinator.isCurrentUserAmongAddedMembers(
          byMemberId,
        ),
        isTrue,
      );

      final otherUser = IsmChatMqttActionModel(
        conversationId: 'conv-1',
        sentAt: 1,
        action: IsmChatActionEvents.addMember,
        members: [
          UserDetails(
            userProfileImageUrl: '',
            userIdentifier: '',
            userId: 'someone-else',
            userName: 'Other',
            online: false,
            lastSeen: 0,
          ),
        ],
      );
      expect(
        IsmChatGroupSystemMessageCoordinator.isCurrentUserAmongAddedMembers(
          otherUser,
        ),
        isFalse,
      );
    });

    test('bootstrapConversationFromIncomingMessage builds group row', () {
      final message = IsmChatMessageModel(
        body: 'Hello group',
        customType: IsmChatCustomMessageType.text,
        conversationId: 'group-conv-1',
        conversationTitle: 'Project Team',
        isGroup: true,
        sentAt: 5000,
        messageId: 'msg-1',
        sentByMe: false,
        senderInfo: UserDetails(
          userProfileImageUrl: '',
          userIdentifier: '',
          userId: 'user-sender',
          userName: 'Alice',
          online: false,
          lastSeen: 0,
        ),
      );

      final row =
          IsmChatGroupSystemMessageCoordinator
              .bootstrapConversationFromIncomingMessage(
        message,
        sentByMe: false,
      );

      expect(row, isNotNull);
      expect(row!.conversationId, 'group-conv-1');
      expect(row.isGroup, isTrue);
      expect(row.conversationTitle, 'Project Team');
      expect(row.lastMessageDetails?.body, 'Hello group');
      expect(row.unreadMessagesCount, 1);
    });

    test('bootstrapConversationFromIncomingMessage returns null without id', () {
      final message = IsmChatMessageModel(
        body: 'Hi',
        customType: IsmChatCustomMessageType.text,
        conversationId: '',
        sentAt: 1,
        sentByMe: false,
      );
      expect(
        IsmChatGroupSystemMessageCoordinator
            .bootstrapConversationFromIncomingMessage(
          message,
          sentByMe: false,
        ),
        isNull,
      );
    });

    test('buildFromMqttAction uses subject userName for memberLeave', () {
      final action = IsmChatMqttActionModel(
        conversationId: 'conv-1',
        sentAt: 2000,
        action: IsmChatActionEvents.memberLeave,
        userDetails: IsmChatMqttUserModel(
          userId: 'user-3',
          userName: 'Leaver',
        ),
      );

      final row = IsmChatGroupSystemMessageCoordinator.buildFromMqttAction(
        action,
        sentByMe: false,
      );

      expect(row.customType, IsmChatCustomMessageType.memberLeave);
      expect(row.userName, 'Leaver');
    });
  });

  group('MemberLeaveVisibility', () {
    test('memberLeave is visible for all members', () {
      final message = IsmChatMessageModel(
        body: '',
        customType: IsmChatCustomMessageType.memberLeave,
        sentAt: 1,
        sentByMe: false,
        userName: 'Someone',
      );
      expect(
        message.isVisibleInGroupChat(
          IsmChatConversationModel(
            conversationId: 'g1',
            isGroup: true,
            members: const [],
          ),
        ),
        isTrue,
      );
    });
  });
}
