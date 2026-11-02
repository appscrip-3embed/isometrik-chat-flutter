import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// Real Hive (temp directory) tests for [IsmChatDBWrapper].
///
/// Plain `test()` is used on purpose: Hive file IO runs on the real event
/// loop here, so no `settle()` is needed.
void main() {
  late IsmChatDBWrapper db;

  setUp(() async {
    configureChatSdk(useDatabase: true);
    db = await openTestDatabase();
  });
  tearDown(resetChatSdk);

  test('create() without a path uses path_provider and the default name',
      () async {
    final defaultDb = await IsmChatDBWrapper.create();
    expect(await defaultDb.getAllConversations(), isA<List>());
  });

  group('conversations', () {
    test('getAllConversations is empty for a new database', () async {
      expect(await db.getAllConversations(), isEmpty);
    });

    test('save + getConversation round-trips a 1-to-1 chat', () async {
      expect(await db.saveConversation(conversation: directConversation()),
          isTrue);
      final stored = await db.getConversation(kDirectConversationId);
      expect(stored?.isGroup, isFalse);
      expect(stored?.opponentDetails?.userId, kOpponentId);
      expect(await db.getAllConversations(), hasLength(1));
    });

    test('save + get round-trips a group chat with members', () async {
      await db.saveConversation(conversation: groupConversation());
      final stored = await db.getConversation(kGroupConversationId);
      expect(stored?.isGroup, isTrue);
      expect(stored?.members, hasLength(3));
      expect(stored?.conversationTitle, 'Test Group');
    });

    test('saveConversation rejects empty or null ids', () async {
      expect(
        await db.saveConversation(
            conversation: IsmChatConversationModel(conversationId: '  ')),
        isFalse,
      );
      expect(
        await db.saveConversation(conversation: IsmChatConversationModel()),
        isFalse,
      );
    });

    test('getConversation returns null for empty / unknown ids', () async {
      expect(await db.getConversation(''), isNull);
      expect(await db.getConversation('missing'), isNull);
      expect(
        await db.getConversation('missing', dbBox: IsmChatDbBox.pending),
        isNull,
      );
    });

    test('createAndUpdateConversation inserts first then merges', () async {
      await db.createAndUpdateConversation(directConversation());
      expect(await db.getConversation(kDirectConversationId), isNotNull);

      // Second conversation goes through the "not found → save" path.
      await db.createAndUpdateConversation(groupConversation());
      expect(await db.getAllConversations(), hasLength(2));

      // Existing conversation is merged, keeping stored messages.
      await db.saveMessage(message(sentAt: 11));
      await db.createAndUpdateConversation(
        groupConversation(title: 'Renamed').copyWith(
          conversationId: kDirectConversationId,
          isGroup: false,
        ),
      );
      final merged = await db.getConversation(kDirectConversationId);
      expect(merged?.conversationTitle, 'Renamed');
      expect(merged?.messages?.keys, contains('11'));
    });

    test('removeConversation deletes from main and pending boxes', () async {
      await db.saveConversation(conversation: directConversation());
      await db.saveMessage(message(sentAt: 1), IsmChatDbBox.pending);
      await db.removeConversation(kDirectConversationId);
      await db.removeConversation(
          kDirectConversationId, IsmChatDbBox.pending);
      expect(await db.getConversation(kDirectConversationId), isNull);
      expect(
        await db.getConversation(kDirectConversationId,
            dbBox: IsmChatDbBox.pending),
        isNull,
      );
      // Removing unknown ids is a no-op.
      await db.removeConversation('missing');
      await db.removeConversation('missing', IsmChatDbBox.pending);
    });

    test('clearChatLocalDb / deleteChatLocalDb wipe every box', () async {
      await db.saveConversation(conversation: directConversation());
      await db.clearChatLocalDb();
      expect(await db.getAllConversations(), isEmpty);
      await db.saveConversation(conversation: directConversation());
      await db.deleteChatLocalDb();
      expect(await db.getAllConversations(), isEmpty);
    });
  });

  group('messages', () {
    test('saveMessage ignores messages without ids', () async {
      await db.saveConversation(conversation: directConversation());
      await db.saveMessage(IsmChatMessageModel(
          body: 'x',
          customType: IsmChatCustomMessageType.text,
          sentAt: 1,
          sentByMe: true));
      await db.saveMessage(IsmChatMessageModel(
          body: 'x',
          customType: IsmChatCustomMessageType.text,
          sentAt: 1,
          sentByMe: true,
          messageId: ' ',
          conversationId: ' '));
      expect(await db.getMessage(kDirectConversationId), isEmpty);
    });

    test('saveMessage to main box requires an existing conversation',
        () async {
      await db.saveMessage(message(sentAt: 1));
      expect(await db.getMessage(kDirectConversationId), isNull);

      await db.saveConversation(conversation: directConversation());
      await db.saveMessage(message(sentAt: 1));
      await db.saveMessage(message(sentAt: 2, body: 'second'));
      final messages = await db.getMessage(kDirectConversationId);
      expect(messages?.keys, containsAll(['1', '2']));
    });

    test('pending box creates and appends to the pending conversation',
        () async {
      await db.saveMessage(message(sentAt: 1), IsmChatDbBox.pending);
      await db.saveMessage(message(sentAt: 2), IsmChatDbBox.pending);
      final pending =
          await db.getMessage(kDirectConversationId, IsmChatDbBox.pending);
      expect(pending, hasLength(2));
      final all = await db.getAllPendingMessages();
      expect(all, hasLength(2));
    });

    test('getAllPendingMessages is empty when nothing is queued', () async {
      expect(await db.getAllPendingMessages(), isEmpty);
    });

    test('getMessage returns null for empty id / missing conversation',
        () async {
      expect(await db.getMessage(''), isNull);
      expect(await db.getMessage('missing'), isNull);
      expect(await db.getMessage('missing', IsmChatDbBox.pending), isNull);
    });

    test('removePendingMessage removes matching sentAt from both boxes',
        () async {
      await db.saveMessage(message(sentAt: 1), IsmChatDbBox.pending);
      await db.saveMessage(message(sentAt: 2), IsmChatDbBox.pending);
      await db.removePendingMessage(
          kDirectConversationId, {'1': message(sentAt: 1)});
      expect(
        (await db.getMessage(kDirectConversationId, IsmChatDbBox.pending))
            ?.keys,
        ['2'],
      );

      await db.saveConversation(
        conversation:
            directConversation(messages: {'5': message(sentAt: 5)}),
      );
      await db.removePendingMessage(
        kDirectConversationId,
        {'5': message(sentAt: 5)},
        IsmChatDbBox.main,
      );
      expect(await db.getMessage(kDirectConversationId), isNotNull);

      // Unknown ids are ignored for both boxes.
      await db.removePendingMessage('missing', {});
      await db.removePendingMessage('missing', {}, IsmChatDbBox.main);
    });

    test('clearAllMessage empties messages and blocked banner', () async {
      await db.saveConversation(
        conversation: directConversation(
          messages: {'1': message(sentAt: 1)},
          metaData: IsmChatMetaData(blockedMessage: message(sentAt: 9)),
        ),
      );
      await db.clearAllMessage(conversationId: kDirectConversationId);
      final cleared = await db.getConversation(kDirectConversationId);
      expect(cleared?.messages, isEmpty);
      // Unknown conversation is a no-op.
      await db.clearAllMessage(conversationId: 'missing');
    });
  });

  group('purgeBlockUnblockAndRefreshLastMessage', () {
    test('no-ops for blank, missing and message-less conversations',
        () async {
      await db.purgeBlockUnblockAndRefreshLastMessage(' ');
      await db.purgeBlockUnblockAndRefreshLastMessage('missing');
      await db.saveConversation(conversation: directConversation());
      await db.purgeBlockUnblockAndRefreshLastMessage(kDirectConversationId);
      expect(
          (await db.getConversation(kDirectConversationId))?.messages,
          isEmpty);
    });

    test('removes banners and rebuilds last message from scratch', () async {
      await db.saveConversation(
        conversation: directConversation(messages: {
          '1': message(sentAt: 1, body: 'real'),
          '2': message(
              sentAt: 2, customType: IsmChatCustomMessageType.block),
          '3': message(
              sentAt: 3, customType: IsmChatCustomMessageType.unblock),
          '4': message(
              sentAt: 4, customType: IsmChatCustomMessageType.date),
        }),
      );
      await db.purgeBlockUnblockAndRefreshLastMessage(kDirectConversationId);
      final c = await db.getConversation(kDirectConversationId);
      expect(c?.messages?.keys, unorderedEquals(['1', '4']));
      expect(c?.lastMessageDetails?.body, 'real');
      expect(c?.lastMessageSentAt, 1);
    });

    test('updates an existing lastMessageDetails via copyWith', () async {
      await db.saveConversation(
        conversation: directConversation(messages: {
          '1': message(sentAt: 1, body: 'kept'),
          '2': message(
              sentAt: 2, customType: IsmChatCustomMessageType.block),
        }).copyWith(
          lastMessageDetails: LastMessageDetails(
            showInConversation: true,
            sentAt: 2,
            senderName: 'x',
            messageType: 0,
            messageId: 'old',
            conversationId: kDirectConversationId,
            body: 'You blocked',
            sentByMe: true,
          ),
        ),
      );
      await db.purgeBlockUnblockAndRefreshLastMessage(kDirectConversationId);
      final c = await db.getConversation(kDirectConversationId);
      expect(c?.lastMessageDetails?.body, 'kept');
      expect(c?.lastMessageDetails?.messageId, 'msg-1');
    });

    test('keeps old last message when only banners remain', () async {
      await db.saveConversation(
        conversation: directConversation(messages: {
          '2': message(
              sentAt: 2, customType: IsmChatCustomMessageType.block),
          '3': message(
              sentAt: 3,
              customType: IsmChatCustomMessageType.conversationCreated),
        }),
      );
      await db.purgeBlockUnblockAndRefreshLastMessage(kDirectConversationId);
      final c = await db.getConversation(kDirectConversationId);
      expect(c?.messages?.keys, ['3']);
      expect(c?.lastMessageDetails, isNull);
    });
  });

  group('upsertCallMessage', () {
    IsmChatMessageModel call(String action, int sentAt,
            {List<CallDuration>? durations}) =>
        IsmChatMessageModel(
          body: '',
          sentAt: sentAt,
          customType: IsmChatCustomMessageType.audioCall,
          sentByMe: false,
          meetingId: 'meet-1',
          action: action,
          messageId: 'call-$sentAt',
          conversationId: kDirectConversationId,
          callDurations: durations,
        );

    test('ignores messages without a conversation or stored chat', () async {
      await db.upsertCallMessage(IsmChatMessageModel(
          body: '',
          sentAt: 1,
          customType: IsmChatCustomMessageType.audioCall,
          sentByMe: true));
      await db.upsertCallMessage(call('meetingCreated', 1));
      expect(await db.getAllConversations(), isEmpty);
    });

    test('keeps one row per meeting and syncs last message preview',
        () async {
      await db.saveConversation(
        conversation: directConversation().copyWith(
          lastMessageDetails: LastMessageDetails(
            showInConversation: true,
            sentAt: 10,
            senderName: '',
            messageType: 0,
            messageId: 'call-10',
            conversationId: kDirectConversationId,
            body: '',
            sentByMe: false,
            customType: IsmChatCustomMessageType.audioCall,
          ),
        ),
      );
      await db.upsertCallMessage(call('meetingCreated', 10));
      await db.upsertCallMessage(call(
        'meetingEndedDueToNoUserPublishing',
        20,
        durations: [
          CallDuration(memberId: kMeId, durationInMilliseconds: 5000),
        ],
      ));
      final c = await db.getConversation(kDirectConversationId);
      expect(c?.messages, hasLength(1));
      expect(c?.messages?.values.single.sentAt, 10);
      expect(c?.lastMessageDetails?.action,
          'meetingEndedDueToNoUserPublishing');
      expect(c?.lastMessageDetails?.meetingId, 'meet-1');
    });

    test('pending box upsert works the same way', () async {
      await db.saveMessage(message(sentAt: 1), IsmChatDbBox.pending);
      await db.upsertCallMessage(call('meetingCreated', 5),
          IsmChatDbBox.pending);
      final pending =
          await db.getMessage(kDirectConversationId, IsmChatDbBox.pending);
      expect(pending?.keys, containsAll(['1', '5']));
    });
  });
}
