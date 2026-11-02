import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatMessageType', () {
    test('fromValue covers every case and default', () {
      expect(IsmChatMessageType.fromValue(0), IsmChatMessageType.normal);
      expect(IsmChatMessageType.fromValue(1), IsmChatMessageType.forward);
      expect(IsmChatMessageType.fromValue(2), IsmChatMessageType.reply);
      expect(IsmChatMessageType.fromValue(3), IsmChatMessageType.admin);
      expect(IsmChatMessageType.fromValue(99), IsmChatMessageType.normal);
      expect(IsmChatMessageType.reply.toString(), 'Reply');
    });
  });

  group('IsmChatCustomMessageType', () {
    test('fromString / fromMap / value round-trip for core types', () {
      expect(IsmChatCustomMessageType.fromString('text'),
          IsmChatCustomMessageType.text);
      expect(IsmChatCustomMessageType.fromString('AttachmentMessage:Image'),
          IsmChatCustomMessageType.image);
      expect(IsmChatCustomMessageType.fromString('unknown-xyz'),
          IsmChatCustomMessageType.text);
      expect(IsmChatCustomMessageType.fromMap(4), IsmChatCustomMessageType.image);
      expect(IsmChatCustomMessageType.fromMap('location'),
          IsmChatCustomMessageType.location);
      expect(IsmChatCustomMessageType.fromMap(true),
          IsmChatCustomMessageType.text);
      expect(IsmChatCustomMessageType.text.value, 'AttachmentMessage:Text');
      expect(IsmChatCustomMessageType.fromValue(1), IsmChatCustomMessageType.text);
      for (final type in IsmChatCustomMessageType.values) {
        expect(IsmChatCustomMessageType.fromValue(type.number), type);
        expect(type.value, isNotEmpty);
        expect(
          IsmChatCustomMessageType.fromString(type.value),
          isA<IsmChatCustomMessageType>(),
        );
      }
    });
  });

  group('IsmChatMediaType', () {
    test('fromMap and values', () {
      for (final type in IsmChatMediaType.values) {
        expect(IsmChatMediaType.fromMap(type.value), type);
      }
    });
  });

  group('IsmChatActionEvents', () {
    test('fromName known and fallback', () {
      expect(IsmChatActionEvents.fromName('typingEvent'),
          IsmChatActionEvents.typingEvent);
      expect(IsmChatActionEvents.fromName('conversationCreated'),
          IsmChatActionEvents.conversationCreated);
      expect(IsmChatActionEvents.fromName('not-a-real-action'),
          isA<IsmChatActionEvents>());
    });

    test('fromName covers every published action string', () {
      const names = [
        'typingEvent',
        'conversationCreated',
        'messageDelivered',
        'messageRead',
        'messagesDeleteForAll',
        'multipleMessagesRead',
        'userBlock',
        'userBlockConversation',
        'userUnblock',
        'userUnblockConversation',
        'clearConversation',
        'deleteConversationLocally',
        'membersRemove',
        'membersAdd',
        'removeAdmin',
        'addAdmin',
        'memberLeave',
        'reactionAdd',
        'reactionRemove',
        'conversationDetailsUpdated',
        'conversationTitleUpdated',
        'conversationImageUpdated',
        'broadcast',
        'memberJoin',
        'observerJoin',
        'observerLeave',
        'userUpdate',
        'meetingEndedByHost',
        'meetingCreated',
        'meetingEndedDueToRejectionByAll',
        'meetingEndedDueToNoUserPublishing',
        'joinRequestAccept',
        'messageDetailsUpdated',
      ];
      for (final name in names) {
        final event = IsmChatActionEvents.fromName(name);
        expect(event, isA<IsmChatActionEvents>(), reason: name);
        expect(event.toString(), isNotEmpty);
      }
    });
  });

  group('remaining enums', () {
    test('conversation, connection, status, attachment, db, features', () {
      expect(IsmChatConversationType.fromValue(0),
          IsmChatConversationType.private);
      expect(IsmChatConversationType.fromValue(1),
          IsmChatConversationType.public);
      expect(IsmChatConversationType.fromValue(2), IsmChatConversationType.open);
      expect(IsmChatConversationType.fromValue(99),
          IsmChatConversationType.private);
      expect(IsmChatConnectionState.connected, isA<IsmChatConnectionState>());
      expect(IsmChatMessageStatus.read, isA<IsmChatMessageStatus>());
      for (final t in IsmChatAttachmentType.values) {
        expect(t, isA<IsmChatAttachmentType>());
      }
      expect(IsmChatDbBox.main, isA<IsmChatDbBox>());
      expect(IsmChatFeature.audioMessage, isA<IsmChatFeature>());
      expect(IsmChatEmojiBoardTab.gif, isA<IsmChatEmojiBoardTab>());
      expect(IsmChatConversationPosition.menu, isA<IsmChatConversationPosition>());
      expect(SendMessageType.pendingMessage, isA<SendMessageType>());
      expect(ApiCallOrigin.referesh, isA<ApiCallOrigin>());
      expect(ApiCallOrigin.loadMore, isA<ApiCallOrigin>());
      for (final menu in IsmChatFocusMenuType.values) {
        expect(menu.label, isNotEmpty);
      }
      expect(IsRenderConversationScreen.none, isA<IsRenderConversationScreen>());
      expect(IsRenderChatPageScreen.none, isA<IsRenderChatPageScreen>());
    });
  });

  group('IsmChatEmoji', () {
    test('fromMap and values', () {
      expect(IsmChatEmoji.fromMap('yes'), IsmChatEmoji.yes);
      expect(IsmChatEmoji.heart.value, 'heart');
      for (final emoji in IsmChatEmoji.values) {
        expect(IsmChatEmoji.fromMap(emoji.value), emoji);
        expect(emoji.emojiKeyword, isNotEmpty);
      }
    });
  });

  group('string extensions', () {
    test('null/empty, url, alphabet, color, maps link', () {
      String? n;
      expect(n.isNullOrEmpty, isTrue);
      expect('  '.isNullOrEmpty, isTrue);
      expect('Hello'.didMatch('ell'), isTrue);
      expect('example.com'.convertToValidUrl, 'https://example.com');
      expect('https://x.com'.isValidUrl, isTrue);
      expect('https://x.com'.isForceValidUrl, isTrue);
      expect('www.x.com'.isForceValidUrl, isTrue);
      expect('Abc'.isAlphabet, isTrue);
      expect('A1'.isAlphabet, isFalse);
      expect('#ffffff'.toColor, isNotNull);
      expect('#000000'.getColor(), isNotNull);
      expect(
        'https://www.google.com/maps/search/?api=1&query=12.0%2C77.0&rest=1'
            .position,
        const LatLng(12.0, 77.0),
      );
      expect(
        () => 'https://example.com'.position,
        throwsA(isA<IsmChatInvalidMapUrlException>()),
      );
    });

    test('size() accepts KB and small MB', () {
      expect('12 KB'.size(), isTrue);
      expect('10 MB'.size(), isTrue);
      expect('200 MB'.size(), isFalse);
      expect('[1, 2, 3]'.strigToUnit8List.length, 3);
      expect(''.strigToUnit8List, isEmpty);
    });
  });

  group('int pagination and timer', () {
    test('pagination and getTimerRecord', () {
      expect(0.pagination(), 0);
      expect(5.pagination(), 20);
      expect(25.pagination(), 40);
      expect(90.getTimerRecord, '01:30');
    });
  });

  group('duration and list extensions', () {
    test('formatDuration / formatFullDuration / waveSamples', () {
      expect(const Duration(seconds: 90).formatDuration, '01:30');
      expect(const Duration(hours: 1, minutes: 2, seconds: 3).formatDuration,
          '01:02:03');
      expect(const Duration(minutes: 2, seconds: 5).formatFullDuration,
          contains('Mins'));
      expect(const Duration(seconds: 3).waveSamples, isNotEmpty);
    });

    test('list unique, merge, unreadCount, selected helpers', () {
      expect(<int>[1, 1, 2].unique(), [1, 2]);
      expect(
        <List<int>>[
          [1, 2],
          [3]
        ].merge(),
        [1, 2, 3],
      );
      expect(
        <List<String>>[
          ['a'],
          ['b']
        ].mergeWithSeprator('|'),
        ['a', '|', 'b'],
      );
      List<int>? empty;
      expect(empty.isNullOrEmpty, isTrue);
      expect(
        <IsmChatConversationModel>[
          directConversation(),
          directConversation(conversationId: 'c2'),
        ].unreadCount,
        isA<int>(),
      );
      expect(
        [
          SelectedMembers(
            isUserSelected: true,
            userDetails: user(),
            isBlocked: false,
          ),
          SelectedMembers(
            isUserSelected: false,
            userDetails: user(id: 'x'),
            isBlocked: false,
          ),
        ].selectedUsers,
        hasLength(1),
      );
    });
  });

  group('IsmChatDebounce', () {
    test('run executes after duration and resets', () async {
      final debounce = IsmChatDebounce();
      var count = 0;
      debounce.run(() => count++, duration: const Duration(milliseconds: 20));
      debounce.run(() => count++, duration: const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(count, 1);

      final action = IsmChatActionDebounce();
      var n = 0;
      action.run(() => n++, duration: const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(n, 1);
    });
  });
}
