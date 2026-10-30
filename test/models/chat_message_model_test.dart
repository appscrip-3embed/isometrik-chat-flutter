import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatMessageModel.fromMap', () {
    test('parses a text message and resolveSentByMe uses senderInfo', () {
      final model = IsmChatMessageModel.fromMap(messageJson(
        senderId: kMeId,
        body: 'hi',
      ));
      expect(model.body, 'hi');
      expect(model.customType, IsmChatCustomMessageType.text);
      expect(model.sentByMe, isTrue);
      expect(model.senderInfo?.userId, kMeId);
    });

    test('sentByMe is false when opponent sent it', () {
      final model = IsmChatMessageModel.fromMap(messageJson());
      expect(model.sentByMe, isFalse);
    });

    test('falls back to senderId fields when senderInfo is missing', () {
      final model = IsmChatMessageModel.fromMap({
        'body': 'x',
        'sentAt': 1,
        'senderId': kOpponentId,
        'senderName': kOpponentName,
        'senderIdentifier': 'x@test.com',
        'senderProfileImageUrl': '',
        'conversationId': kDirectConversationId,
      });
      expect(model.senderInfo?.userId, kOpponentId);
      expect(model.sentByMe, isFalse);
    });

    test('parses attachments, mentions, reactions map and events', () {
      final model = IsmChatMessageModel.fromMap({
        ...messageJson(),
        'attachments': [attachment(IsmChatMediaType.image).toMap()],
        'mentionedUsers': [user().toMap()],
        'reactions': {
          'yes': [kMeId, kOpponentId],
        },
        'events': {
          'updateUnreadCount': true,
          'sendPushNotification': false,
        },
        'deliveredTo': [
          {'userId': kOpponentId, 'timestamp': 1},
        ],
        'readBy': [
          {'userId': kOpponentId, 'timestamp': 2},
        ],
        'metaData': {
          'caption': 'cap',
          'contacts': [
            {
              'contactName': 'Alice',
              'contactIdentifier': '+1',
              'contactImageUrl': '',
              'contactId': 'c',
            }
          ],
        },
      });
      expect(model.attachments, hasLength(1));
      expect(model.mentionedUsers, hasLength(1));
      expect(model.reactions, isNotEmpty);
      expect(model.metaData?.caption, 'cap');
      expect(model.events?.updateUnreadCount, isTrue);
    });

    test('action-only customType comes from action string', () {
      final model = IsmChatMessageModel.fromMap({
        'body': '',
        'sentAt': 1,
        'action': 'conversationCreated',
        'conversationId': kDirectConversationId,
      });
      expect(model.customType, IsmChatCustomMessageType.conversationCreated);
    });

    test('broadcast meta uses groupCastId for decryption id', () {
      final model = IsmChatMessageModel.fromMap({
        'body': 'hello',
        'sentAt': 1,
        'conversationId': 'c',
        'customType': 'text',
        'metaData': {
          'isBroadCastMessage': true,
          'groupCastId': 'gcast',
        },
      });
      expect(model.body, 'hello');
      expect(model.metaData?.isBroadCastMessage, isTrue);
    });
  });

  group('IsmChatMessageModel.resolveSentByMe', () {
    test('uses initiator / userId / createdBy fallbacks', () {
      expect(
        IsmChatMessageModel.resolveSentByMe(
          IsmChatMessageModel(
            body: '',
            customType: IsmChatCustomMessageType.text,
            sentAt: 1,
            sentByMe: false,
            initiatorId: kMeId,
          ),
        ),
        isTrue,
      );
      expect(
        IsmChatMessageModel.resolveSentByMe(
          IsmChatMessageModel(
            body: '',
            customType: IsmChatCustomMessageType.text,
            sentAt: 1,
            sentByMe: false,
            userId: kOpponentId,
          ),
        ),
        isFalse,
      );
      expect(
        IsmChatMessageModel.resolveSentByMe(
          IsmChatMessageModel(
            body: '',
            customType: IsmChatCustomMessageType.text,
            sentAt: 1,
            sentByMe: false,
            createdBy: kMeId,
          ),
        ),
        isTrue,
      );
    });
  });

  group('fixtures', () {
    test('every attachment message has the matching custom type', () {
      attachmentMessages().forEach((type, msg) {
        expect(msg.customType, type);
        if (type != IsmChatCustomMessageType.contact) {
          expect(msg.attachments, isNotEmpty);
        }
      });
    });

    test('copyWith and toMap keep conversation id', () {
      final original = message(body: 'keep');
      final copy = original.copyWith(body: 'changed');
      expect(copy.body, 'changed');
      expect(copy.conversationId, original.conversationId);
      expect(original.toMap()['conversationId'], kDirectConversationId);
    });
  });
}
