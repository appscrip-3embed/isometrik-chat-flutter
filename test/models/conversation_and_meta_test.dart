import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatConversationModel', () {
    test('fromMap of conversationJson fills opponent and last message', () {
      final model = IsmChatConversationModel.fromMap(conversationJson());
      expect(model.conversationId, kDirectConversationId);
      expect(model.isGroup, isFalse);
      expect(model.opponentDetails?.userId, kOpponentId);
      expect(model.lastMessageDetails?.body, 'latest');
    });

    test('group conversationJson has no opponent', () {
      final model = IsmChatConversationModel.fromMap(
        conversationJson(isGroup: true, title: 'G'),
      );
      expect(model.isGroup, isTrue);
      expect(model.conversationTitle, 'G');
    });

    test('directConversation factory round-trips through json', () {
      final original = directConversation();
      final copy = IsmChatConversationModel.fromJson(original.toJson());
      expect(copy.conversationId, original.conversationId);
      expect(copy.members, hasLength(2));
      expect(copy.copyWith(conversationTitle: 'x').conversationTitle, 'x');
    });

    test('groupConversation factory keeps admin flag', () {
      final group = groupConversation();
      expect(group.isGroup, isTrue);
      expect(group.members!.first.isAdmin, isTrue);
      expect(group.members, hasLength(3));
    });
  });

  group('IsmChatMetaData', () {
    test('fromMap reads caption aliases, contacts and reply', () {
      final model = IsmChatMetaData.fromMap({
        'captionMessage': 'hi',
        'firstName': 'Ada',
        'lastName': 'L',
        'duration': 4,
        'contacts': [
          {
            'contactName': 'A',
            'contactIdentifier': '+1',
            'contactImageUrl': '',
            'contactId': '1',
          }
        ],
        'replyMessage': {
          'parentMessageBody': 'quoted',
          'parentMessageInitiator': true,
        },
        'about': 'bio',
        'isBroadCastMessage': true,
        'groupCastId': 'g',
      });
      expect(model.caption, 'hi');
      expect(model.firstName, 'Ada');
      expect(model.duration, const Duration(seconds: 4));
      expect(model.contacts, hasLength(1));
      expect(model.replyMessage?.parentMessageBody, 'quoted');
      expect(model.aboutText?.title, 'bio');
      expect(model.isBroadCastMessage, isTrue);
      expect(IsmChatMetaData.fromJson(null).caption, isNull);
      expect(IsmChatMetaData.fromJson('').firstName, isNull);
      expect(IsmChatMetaData.fromJson(model.toJson()).firstName, 'Ada');
      expect(model.copyWith(captionMessage: 'x').caption, 'x');
    });

    test('customType string is wrapped into a map', () {
      final model = IsmChatMetaData.fromMap({'customType': 'offer'});
      expect(model.customType, {'offer': 'offer'});
    });
  });

  group('LastMessageDetails', () {
    test('fromMap of conversationJson lastMessageDetails', () {
      final details = LastMessageDetails.fromMap(
        conversationJson()['lastMessageDetails'] as Map<String, dynamic>,
      );
      expect(details.body, 'latest');
      expect(details.senderId, kOpponentId);
      expect(details.copyWith(body: 'x').body, 'x');
    });
  });

  group('ConversationConfigModel', () {
    test('round trip', () {
      final config = ConversationConfigModel(
        typingEvents: true,
        readEvents: false,
        pushNotifications: true,
      );
      expect(ConversationConfigModel.fromJson(config.toJson()).readEvents,
          isFalse);
      expect(config.copyWith(readEvents: true).readEvents, isTrue);
    });
  });
}
