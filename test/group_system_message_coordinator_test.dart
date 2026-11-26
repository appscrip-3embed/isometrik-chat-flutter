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
