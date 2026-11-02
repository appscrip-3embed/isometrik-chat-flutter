import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('BroadcastModel', () {
    test('fromMap / toJson / copyWith', () {
      final model = BroadcastModel.fromMap({
        'groupcastId': 'g1',
        'groupcastTitle': 'News',
        'customType': 'broadcast',
        'sendPushForNewConversationCreated': true,
        'hideNewConversationsForSender': false,
        'membersCount': 2,
        'createdAt': 1,
        'createdBy': kMeId,
        'searchableTags': ['a'],
      });
      expect(model.groupcastId, 'g1');
      expect(BroadcastModel.fromJson(model.toJson()).groupcastTitle, 'News');
      expect(model.copyWith(groupcastTitle: 'X').groupcastTitle, 'X');
    });
  });

  group('IsmChatMqttActionModel', () {
    test('fromMap reads action, members and sender', () {
      final model = IsmChatMqttActionModel.fromMap({
        'action': 'membersAdd',
        'conversationId': kGroupConversationId,
        'sentAt': 1,
        'memberId': 'u',
        'memberName': 'U',
        'userId': kOpponentId,
        'userName': kOpponentName,
        'initiatorId': kMeId,
        'initiatorName': kMeName,
        'messageId': 'm',
        'messageIds': ['m'],
        'body': 'x',
      });
      expect(model.action, IsmChatActionEvents.addMember);
      expect(model.conversationId, kGroupConversationId);
      expect(model.userDetails?.userId, kOpponentId);
      expect(model.messageId, 'm');
      expect(model.copyWith(memberName: 'Z').memberName, 'Z');
    });
  });

  group('IsmChatMqttUserModel', () {
    test('displayName and metaDataFromMap', () {
      final user = IsmChatMqttUserModel(
        userId: 'u',
        userName: 'nick',
        userIdentifier: 'u@t',
        profileImageUrl: '',
        metaData: IsmChatMetaData(firstName: 'Ada', lastName: 'L'),
      );
      expect(user.displayName, 'Ada L');
      expect(
        IsmChatMqttUserModel.metaDataFromMap({
          'firstName': 'A',
          'lastName': 'B',
        })?.firstName,
        'A',
      );
    });
  });

  group('IsmChatEvents / AboutText / LastRead / Mention', () {
    test('events round trip', () {
      final events = IsmChatEvents(
        typingEvents: true,
        readEvents: true,
        pushNotifications: false,
        updateUnreadCount: true,
        sendPushNotification: false,
      );
      expect(IsmChatEvents.fromJson(events.toJson()).typingEvents, isTrue);
      expect(events.copyWith(readEvents: false).readEvents, isFalse);
    });

    test('AboutTextModel and MentionModel', () {
      final about = AboutTextModel(title: 't', subTitle: 's');
      expect(AboutTextModel.fromJson(about.toJson()).title, 't');
      const mention = MentionModel(userId: 'u', wordCount: 1, order: 0);
      expect(MentionModel.fromJson(mention.toJson()), mention);
    });

    test('IsmChatLastReadAt from list and map', () {
      final fromMap = IsmChatLastReadAt.fromMap({
        'userId': kOpponentId,
        'timestamp': 5,
      });
      expect(fromMap.userId, kOpponentId);
      expect(
        IsmChatLastReadAt.fromNetworkMap({kOpponentId: 9}).first.readAt,
        9,
      );
    });
  });

  group('IsmChatBackgroundModel', () {
    test('fromMap / copyWith', () {
      final model = IsmChatBackgroundModel(
        color: '#fff',
        imageUrl: 'u',
        isImage: false,
      );
      expect(IsmChatBackgroundModel.fromJson(model.toJson()).color, '#fff');
      expect(model.copyWith(isImage: true).isImage, isTrue);
    });
  });

  group('MessageReactionModel', () {
    test('map / json', () {
      final model = MessageReactionModel(emojiKey: 'yes', userIds: [kMeId]);
      expect(MessageReactionModel.fromJson(model.toJson()), model);
      expect(model.copyWith(emojiKey: 'heart').emojiKey, 'heart');
    });
  });

  group('IsmChatUserOwnDetails', () {
    test('fromMap / json / copyWith / equality', () {
      final model = IsmChatUserOwnDetails(
        memberId: kMeId,
        isAdmin: true,
        isDeleted: false,
      );
      expect(IsmChatUserOwnDetails.fromJson(model.toJson()), model);
      expect(model.copyWith(isAdmin: false).isAdmin, isFalse);
      expect(model.hashCode, isA<int>());
      expect(model.toString(), contains(kMeId));
    });
  });

  group('PaidMediaSendResult', () {
    test('handled and send factories', () {
      expect(const PaidMediaSendResult.handled().handled, isTrue);
      expect(const PaidMediaSendResult.send({'k': 1}).handled, isFalse);
      expect(const PaidMediaSendResult.send({'k': 1}).metaData, {'k': 1});
    });
  });

  group('IsmChatHeader / IsmChatConversationAction / popup', () {
    test('constructors hold callbacks', () {
      final header = IsmChatHeader(backgroundColor: const Color(0xFF000000));
      expect(header.backgroundColor, const Color(0xFF000000));
      var tapped = false;
      final action = IsmChatConversationAction(
        icon: const SizedBox(),
        onTap: (_) => tapped = true,
        label: 'Pin',
      );
      action.onTap(directConversation());
      expect(tapped, isTrue);
      expect(action.label, 'Pin');

      final item = IsmChatPopupMenuItem(
        label: 'Info',
        icon: Icons.info,
        onTap: (_) {},
      );
      expect(item, item);
      expect(item.hashCode, isA<int>());
      expect(item.toString(), contains('Info'));
    });
  });

  group('BroadcastMemberModel', () {
    test('fromMap / json / copyWith', () {
      final model = BroadcastMemberModel.fromMap({
        'membersCount': 1,
        'members': [
          {
            'memberId': kOpponentId,
            'timestamp': 1,
            'newConversationTypingEvents': true,
            'newConversationReadEvents': true,
            'newConversationPushNotificationsEvents': false,
            'newConversationMetadata': <String, dynamic>{},
            'newConversationCustomType': '',
          }
        ],
      });
      expect(model.members, hasLength(1));
      expect(
        BroadcastMemberModel.fromJson(model.toJson()).membersCount,
        1,
      );
      expect(model.copyWith(membersCount: 2).membersCount, 2);
      expect(model.members.single.copyWith(memberId: 'x').memberId, 'x');
    });
  });

  group('ContactSync', () {
    test('fromJson / toJson / copyWith', () {
      final sync = ContactSync.fromJson({
        'data': [
          {
            'firstName': 'A',
            'lastName': 'B',
            'fullName': 'A B',
            'countryCode': '+1',
            'contactNo': '555',
            'userId': kOpponentId,
            'isRegisteredUser': true,
            'contactId': 'c1',
          }
        ],
        'totalCount': 1,
      });
      expect(sync.data, hasLength(1));
      expect(sync.data!.first.copyWith(firstName: 'Z').firstName, 'Z');
      // toJson writes `contacts` while fromJson reads `data`.
      expect(contactSyncToJson(sync), contains('contacts'));
    });
  });

  group('SelectedMembers / SelectedContact / typing', () {
    test('round-trip and selection helpers', () {
      final selected = SelectedMembers(
        isUserSelected: true,
        userDetails: user(),
        isBlocked: false,
        tagIndex: 'O',
      );
      expect(SelectedMembers.fromJson(selected.toJson()).tagIndex, 'O');
      expect(selected.copyWith(isBlocked: true).isBlocked, isTrue);
      expect(selected.getSuspensionTag(), 'O');
      selected.isUserSelected = false;
      expect(selected.isUserSelected, isFalse);

      final contact = SelectedContact(
        isConotactSelected: true,
        contact: Contact(id: 'c', displayName: 'Alice'),
        tagIndex: 'A',
      );
      expect(contact.copyWith(isConotactSelected: false).isConotactSelected,
          isFalse);
      expect(contact.getSuspensionTag(), 'A');

      final typing = IsmChatTypingModel(
        conversationId: kDirectConversationId,
        userName: kOpponentName,
      );
      expect(typing.copyWith(userName: 'x').userName, 'x');
      expect(typing, typing);
    });
  });

  group('IsmChatConfirmationRequest', () {
    test('actionById and every confirmation type exists', () {
      var pressed = false;
      final request = IsmChatConfirmationRequest(
        type: IsmChatConfirmationType.confirmBlock,
        title: 'Block?',
        actions: [
          IsmChatConfirmationAction(
            id: IsmChatConfirmationActionId.block,
            label: 'Block',
            onPressed: () => pressed = true,
          ),
        ],
      );
      request.actionById(IsmChatConfirmationActionId.block)?.onPressed();
      expect(pressed, isTrue);
      expect(request.actionById(IsmChatConfirmationActionId.dismiss), isNull);
      expect(IsmChatConfirmationType.values, isNotEmpty);
      expect(IsmChatConfirmationActionId.values, isNotEmpty);
    });
  });
}
