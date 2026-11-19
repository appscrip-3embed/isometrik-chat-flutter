import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// [IsmChatThreadCoordinator] is the only place that decides what threading
/// does, so these tests pin both states of the feature flag: **off** must be a
/// no-op (the classic chat experience) and **on** must filter, count and route.
void main() {
  setUp(() {
    configureChatSdk();
    IsmChatConfig.threadsEnabled = false;
    IsmChatProperties.chatPageProperties = IsmChatPageProperties();
  });
  tearDown(() async {
    IsmChatConfig.threadsEnabled = false;
    IsmChatProperties.chatPageProperties = IsmChatPageProperties();
    await resetChatSdk();
  });

  group('feature flag', () {
    test('is off by default and sends no feedType', () {
      expect(IsmChatThreadCoordinator.isEnabled, isFalse);
      expect(IsmChatThreadCoordinator.timelineFeedType, isNull);
    });

    test('on → channel timeline asks for feedType=main', () {
      IsmChatConfig.threadsEnabled = true;
      expect(IsmChatThreadCoordinator.timelineFeedType, IsmChatFeedType.main);
      expect(IsmChatFeedType.main.queryValue, 'main');
      expect(IsmChatFeedType.thread.queryValue, 'thread');
      expect(IsmChatFeedType.all.queryValue, 'all');
    });

    test('UI gate also honours IsmChatFeature.threadReply', () {
      IsmChatConfig.threadsEnabled = true;
      expect(IsmChatThreadCoordinator.isUiEnabled, isTrue);

      IsmChatProperties.chatPageProperties = IsmChatPageProperties(
        features: IsmChatFeature.values
            .where((e) => e != IsmChatFeature.threadReply)
            .toList(),
      );
      // Data rules stay on so fetch/realtime cannot drift…
      expect(IsmChatThreadCoordinator.isEnabled, isTrue);
      // …but the entry points are hidden.
      expect(IsmChatThreadCoordinator.isUiEnabled, isFalse);
      expect(
        IsmChatThreadCoordinator.shouldShowFooter(threadRoot()),
        isFalse,
      );
    });
  });

  group('classification', () {
    test('needs both messageType 2 and a threadRootId', () {
      IsmChatConfig.threadsEnabled = true;
      expect(IsmChatThreadCoordinator.isThreadReply(threadReply()), isTrue);
      // Legacy inline quote: reply type, no threadRootId.
      expect(
        IsmChatThreadCoordinator.isThreadReply(
          message(messageType: IsmChatMessageType.reply, parentMessageId: 'p'),
        ),
        isFalse,
      );
      expect(IsmChatThreadCoordinator.isThreadReply(message()), isFalse);
      expect(IsmChatThreadCoordinator.isThreadReply(null), isFalse);
    });

    test('"also sent to channel" replies are not thread-only', () {
      IsmChatConfig.threadsEnabled = true;
      final shared = threadReply(alsoSentToChannel: true);
      expect(IsmChatThreadCoordinator.isThreadReply(shared), isTrue);
      expect(IsmChatThreadCoordinator.isThreadOnlyReply(shared), isFalse);
      expect(IsmChatThreadCoordinator.shouldHideFromTimeline(shared), isFalse);
    });

    test('also-sent replies gate channel echo UI', () {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      final shared = threadReply(alsoSentToChannel: true);
      final threadOnly = threadReply();
      expect(IsmChatThreadCoordinator.isAlsoSentThreadReply(shared), isTrue);
      expect(IsmChatThreadCoordinator.isAlsoSentThreadReply(threadOnly), isFalse);
      expect(
        IsmChatThreadCoordinator.shouldUseViewThreadMenuLabel(shared),
        isTrue,
      );
      expect(
        IsmChatThreadCoordinator.shouldShowChannelThreadContext(shared),
        isTrue,
      );
    });

    test('thread-only replies are hidden from the timeline only when on', () {
      final reply = threadReply();
      expect(IsmChatThreadCoordinator.shouldHideFromTimeline(reply), isFalse);

      IsmChatConfig.threadsEnabled = true;
      expect(IsmChatThreadCoordinator.shouldHideFromTimeline(reply), isTrue);
    });
  });

  group('resolveThreadPanelRoot', () {
    setUp(() => IsmChatConfig.threadsEnabled = true);

    test('returns the channel root for an also-sent reply', () {
      final root = threadRoot(messageId: 'root-1');
      final shared = threadReply(
        messageId: 'r-shared',
        threadRootId: 'root-1',
        alsoSentToChannel: true,
      );
      final resolved = IsmChatThreadCoordinator.resolveThreadPanelRoot(
        shared,
        [root, shared],
      );
      expect(resolved.messageId, 'root-1');
      expect(IsmChatThreadCoordinator.isThreadReply(resolved), isFalse);
    });

    test('uses parentMessageId when threadRootId is missing', () {
      final root = threadRoot(messageId: 'root-1');
      final reply = message(
        messageId: 'r1',
        messageType: IsmChatMessageType.reply,
        parentMessageId: 'root-1',
        showInConversation: true,
      );
      final resolved = IsmChatThreadCoordinator.resolveThreadPanelRoot(
        reply,
        [root],
      );
      expect(resolved.messageId, 'root-1');
    });

    test('plain channel messages are unchanged', () {
      final plain = message(messageId: 'plain-1');
      expect(
        IsmChatThreadCoordinator.resolveThreadPanelRoot(plain, [plain]),
        plain,
      );
    });
  });

  group('channel thread context', () {
    setUp(() => IsmChatConfig.threadsEnabled = true);
    tearDown(() => IsmChatConfig.threadsEnabled = false);

    test('resolveParentInTimeline prefers parentMessageId then root', () {
      final root = threadRoot(messageId: 'root-1');
      final img = message(
        messageId: 'img-1',
        body: '',
        customType: IsmChatCustomMessageType.image,
        attachments: [
          attachment(IsmChatMediaType.image).copyWith(name: 'image (1).png'),
        ],
      );
      final shared = threadReply(
        messageId: 'r1',
        alsoSentToChannel: true,
        parentMessageId: 'img-1',
      );
      final timeline = [root, img, shared];
      expect(
        IsmChatThreadCoordinator.resolveParentInTimeline(shared, timeline),
        img,
      );
      final nested = threadReply(
        messageId: 'r2',
        alsoSentToChannel: true,
        parentMessageId: 'missing',
        threadRootId: 'root-1',
      );
      expect(
        IsmChatThreadCoordinator.resolveParentInTimeline(nested, timeline),
        root,
      );
    });

    test('threadReplyContextSubject uses media type labels and text', () {
      final named = message(
        customType: IsmChatCustomMessageType.image,
        attachments: [
          attachment(IsmChatMediaType.image).copyWith(name: 'image (1).png'),
        ],
      );
      expect(
        IsmChatThreadCoordinator.threadReplyContextSubject(named),
        IsmChatStrings.image,
      );
      expect(
        IsmChatThreadCoordinator.threadReplyContextSubject(
          message(body: 'hello thread'),
        ),
        'hello thre...',
      );
      expect(
        IsmChatThreadCoordinator.threadReplyContextSubject(null),
        IsmChatStrings.threadContextSubjectFallback,
      );
    });
  });

  group('timeline filtering', () {
    final timeline = [
      threadRoot(),
      threadReply(messageId: 'r1', sentAt: 1100),
      threadReply(messageId: 'r2', sentAt: 1200, alsoSentToChannel: true),
      message(messageId: 'plain', sentAt: 1300),
    ];

    test('off → list and map are untouched', () {
      expect(IsmChatThreadCoordinator.filterTimeline(timeline), hasLength(4));
      final map = {for (final m in timeline) m.messageId!: m};
      expect(IsmChatThreadCoordinator.filterTimelineMap(map), hasLength(4));
    });

    test('on → drops thread-only replies, keeps shared ones', () {
      IsmChatConfig.threadsEnabled = true;
      final filtered = IsmChatThreadCoordinator.filterTimeline(timeline);
      expect(filtered.map((e) => e.messageId), ['root-1', 'r2', 'plain']);

      final map = {for (final m in timeline) m.messageId!: m};
      expect(
        IsmChatThreadCoordinator.filterTimelineMap(map).keys,
        containsAll(['root-1', 'r2', 'plain']),
      );
      expect(
        IsmChatThreadCoordinator.filterTimelineMap(map).containsKey('r1'),
        isFalse,
      );
    });

    test('filtering never mutates the caller\'s collection', () {
      IsmChatConfig.threadsEnabled = true;
      final source = List<IsmChatMessageModel>.from(timeline);
      IsmChatThreadCoordinator.filterTimeline(source);
      expect(source, hasLength(4));
    });
  });

  group('thread ids', () {
    test('a reply reports its root, a root reports itself', () {
      expect(
        IsmChatThreadCoordinator.threadIdOf(threadReply(threadRootId: 'root-9')),
        'root-9',
      );
      expect(
        IsmChatThreadCoordinator.threadIdOf(threadRoot(messageId: 'root-9')),
        'root-9',
      );
      expect(IsmChatThreadCoordinator.threadIdOf(null), '');
    });

    test('resolveThreadRootId mirrors the server for nested replies', () {
      // Replying to a reply keeps the same thread.
      final nestedParent = threadReply(messageId: 'r1', threadRootId: 'root-1');
      expect(
        IsmChatThreadCoordinator.resolveThreadRootId(nestedParent),
        'root-1',
      );
      // Replying to a root starts that root's thread.
      expect(
        IsmChatThreadCoordinator.resolveThreadRootId(
          threadRoot(messageId: 'root-2'),
        ),
        'root-2',
      );
    });

    test('canOpenThread requires the flag, a server id and a real row', () {
      final root = threadRoot();
      expect(IsmChatThreadCoordinator.canOpenThread(root), isFalse);

      IsmChatConfig.threadsEnabled = true;
      expect(IsmChatThreadCoordinator.canOpenThread(root), isTrue);
      // Not yet sent.
      expect(
        IsmChatThreadCoordinator.canOpenThread(message(messageId: '')),
        isFalse,
      );
      // System / deleted rows.
      for (final type in const [
        IsmChatCustomMessageType.deletedForEveryone,
        IsmChatCustomMessageType.date,
        IsmChatCustomMessageType.conversationCreated,
        IsmChatCustomMessageType.block,
      ]) {
        expect(
          IsmChatThreadCoordinator.canOpenThread(message(customType: type)),
          isFalse,
          reason: '$type must not open a thread',
        );
      }
    });
  });

  group('reply counts', () {
    test('null replyCount reads as zero', () {
      expect(IsmChatThreadCoordinator.replyCountOf(message()), 0);
      expect(IsmChatThreadCoordinator.hasThreadReplies(message()), isFalse);
      expect(
        IsmChatThreadCoordinator.hasThreadReplies(threadRoot(replyCount: 1)),
        isTrue,
      );
    });

    test('applyReplyToRoot increments and moves lastThreadReplyAt forward', () {
      final root = threadRoot(replyCount: 2, lastThreadReplyAt: 5000);
      final updated = IsmChatThreadCoordinator.applyReplyToRoot(
        root,
        threadReply(sentAt: 6000),
      );
      expect(updated.replyCount, 3);
      expect(updated.lastThreadReplyAt, 6000);
    });

    test('an out-of-order reply cannot rewind lastThreadReplyAt', () {
      final root = threadRoot(replyCount: 2, lastThreadReplyAt: 9000);
      final updated = IsmChatThreadCoordinator.applyReplyToRoot(
        root,
        threadReply(sentAt: 4000),
      );
      expect(updated.replyCount, 3);
      expect(updated.lastThreadReplyAt, 9000);
    });

    test('removal decrements but never goes negative', () {
      expect(
        IsmChatThreadCoordinator.applyReplyRemovalToRoot(
          threadRoot(replyCount: 1),
        ).replyCount,
        0,
      );
      expect(
        IsmChatThreadCoordinator.applyReplyRemovalToRoot(
          threadRoot(replyCount: 0),
        ).replyCount,
        0,
      );
    });

    test('applyReplyToRootInMap bumps the matching root only', () {
      final map = {
        'a': threadRoot(messageId: 'root-1', replyCount: 1),
        'b': threadRoot(messageId: 'root-2', replyCount: 7),
      };
      final next = IsmChatThreadCoordinator.applyReplyToRootInMap(
        map,
        threadReply(threadRootId: 'root-1', sentAt: 8000),
      );
      expect(next['a']!.replyCount, 2);
      expect(next['b']!.replyCount, 7);
      // Original map untouched.
      expect(map['a']!.replyCount, 1);
    });

    test('applyReplyToRootInMap ignores a reply with no root id', () {
      final map = {'a': threadRoot(messageId: 'root-1', replyCount: 1)};
      // A legacy reply (no threadRootId) must not touch any root.
      final next = IsmChatThreadCoordinator.applyReplyToRootInMap(
        map,
        message(messageType: IsmChatMessageType.reply, parentMessageId: 'x'),
      );
      expect(next['a']!.replyCount, 1);
      expect(
        IsmChatThreadCoordinator.applyReplyToRootInList(
          [threadRoot(messageId: 'root-1', replyCount: 1)],
          message(messageType: IsmChatMessageType.reply),
        ).single.replyCount,
        1,
      );
    });

    test('applyReplyToRootInMap is a no-op for an uncached root', () {
      final map = {'a': threadRoot(messageId: 'root-1', replyCount: 1)};
      final next = IsmChatThreadCoordinator.applyReplyToRootInMap(
        map,
        threadReply(threadRootId: 'root-404'),
      );
      expect(next['a']!.replyCount, 1);
    });

    test('applyReplyToRootInList bumps the root in place', () {
      final list = [
        message(messageId: 'plain'),
        threadRoot(messageId: 'root-1', replyCount: 0),
      ];
      final next = IsmChatThreadCoordinator.applyReplyToRootInList(
        list,
        threadReply(threadRootId: 'root-1', sentAt: 7000),
      );
      expect(next[1].replyCount, 1);
      expect(next[1].lastThreadReplyAt, 7000);
      expect(list[1].replyCount, 0);
    });

    test('mediaGalleryItemsFromThreadReplies resolves reply wire type', () {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      final replies = [
        message(
          body: IsmChatStrings.image,
          customType: IsmChatCustomMessageType.reply,
          messageType: IsmChatMessageType.reply,
          threadRootId: 'root-1',
          messageId: 'img-reply',
          attachments: [attachment(IsmChatMediaType.image)],
        ),
        threadReply(body: 'text only'),
      ];
      final gallery =
          IsmChatThreadCoordinator.mediaGalleryItemsFromThreadReplies(replies);
      expect(gallery, hasLength(1));
      expect(gallery.single.messageId, 'img-reply');
      expect(gallery.single.customType, IsmChatCustomMessageType.image);
    });

    test('mergeMediaGalleryItems dedupes channel + thread rows', () {
      final channel = message(
        messageId: 'shared',
        customType: IsmChatCustomMessageType.image,
        attachments: [attachment(IsmChatMediaType.image)],
      );
      final threadRow = channel.copyWith(
        customType: IsmChatCustomMessageType.reply,
        messageType: IsmChatMessageType.reply,
      );
      final merged = IsmChatThreadCoordinator.mergeMediaGalleryItems(
        [channel],
        [threadRow.copyWith(customType: IsmChatCustomMessageType.image)],
      );
      expect(merged, hasLength(1));
    });

    test('mergeThreadRootBadgesInList keeps higher in-memory reply counts', () {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      final fromDb = [
        threadRoot(messageId: 'root-1', replyCount: 0),
        message(messageId: 'other'),
      ];
      final previous = [
        threadRoot(messageId: 'root-1', replyCount: 2, lastThreadReplyAt: 9000),
      ];
      final merged = IsmChatThreadCoordinator.mergeThreadRootBadgesInList(
        fromDb,
        previous,
      );
      expect(merged[0].replyCount, 2);
      expect(merged[0].lastThreadReplyAt, 9000);
      expect(merged[1].messageId, 'other');
    });
  });

  group('send target', () {
    IsmChatMessageModel mediaEcho() => message(
          body: '',
          customType: IsmChatCustomMessageType.image,
          messageId: '',
          sentAt: 7000,
        );

    test('forThread resolves the root and the immediate parent', () {
      final root = threadRoot(messageId: 'root-1');
      final target = IsmChatThreadSendTarget.forThread(root: root);
      expect(target.threadRootId, 'root-1');
      expect(target.parentMessageId, 'root-1');
      expect(target.showInConversation, isFalse);
      expect(target.isValid, isTrue);

      // Nested: same thread, different parent.
      final nested = IsmChatThreadSendTarget.forThread(
        root: root,
        replyTo: threadReply(messageId: 'r1'),
        alsoSendToChannel: true,
      );
      expect(nested.threadRootId, 'root-1');
      expect(nested.parentMessageId, 'r1');
      expect(nested.showInConversation, isTrue);

      // A root with no server id cannot be targeted.
      expect(
        IsmChatThreadSendTarget.forThread(root: message(messageId: '')).isValid,
        isFalse,
      );
    });

    test('targets compare by value', () {
      const a = IsmChatThreadSendTarget(
        threadRootId: 'root-1',
        parentMessageId: 'root-1',
      );
      const b = IsmChatThreadSendTarget(
        threadRootId: 'root-1',
        parentMessageId: 'root-1',
      );
      const c = IsmChatThreadSendTarget(
        threadRootId: 'root-1',
        parentMessageId: 'r1',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('root-1'));
    });

    test('stampThreadTarget turns a channel echo into a thread reply', () {
      IsmChatConfig.threadsEnabled = true;
      final echo = mediaEcho();
      final stamped = IsmChatThreadCoordinator.stampThreadTarget(
        echo,
        IsmChatThreadSendTarget.forThread(root: threadRoot()),
      );

      // Stamped in place: the row in the list, the queued copy and the request
      // all read the same object.
      expect(identical(stamped, echo), isTrue);
      expect(echo.messageType, IsmChatMessageType.reply);
      expect(echo.parentMessageId, 'root-1');
      expect(echo.threadRootId, 'root-1');
      expect(echo.showInConversation, isFalse);
      // The payload itself is untouched.
      expect(echo.customType, IsmChatCustomMessageType.image);
      expect(IsmChatThreadCoordinator.isThreadTargetedEcho(echo), isTrue);
    });

    test('"also send to channel" keeps the echo visible in the channel', () {
      IsmChatConfig.threadsEnabled = true;
      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(),
        IsmChatThreadSendTarget.forThread(
          root: threadRoot(),
          alsoSendToChannel: true,
        ),
      );
      expect(echo.showInConversation, isTrue);
      // Shared replies belong in both places, so they are not thread-only.
      expect(IsmChatThreadCoordinator.isThreadTargetedEcho(echo), isFalse);
      expect(IsmChatThreadCoordinator.shouldHideFromTimeline(echo), isFalse);
    });

    test('is a no-op with no target, an invalid target, or threads off', () {
      IsmChatConfig.threadsEnabled = true;
      final noTarget = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(),
        null,
      );
      expect(noTarget.messageType, IsmChatMessageType.normal);
      expect(noTarget.threadRootId, isNull);

      final invalid = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(),
        const IsmChatThreadSendTarget(
          threadRootId: '',
          parentMessageId: '',
        ),
      );
      expect(invalid.threadRootId, isNull);

      IsmChatConfig.threadsEnabled = false;
      final whenOff = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(),
        IsmChatThreadSendTarget.forThread(root: threadRoot()),
      );
      expect(whenOff.messageType, IsmChatMessageType.normal);
      expect(whenOff.threadRootId, isNull);
      expect(whenOff.showInConversation, isNull);
      expect(IsmChatThreadCoordinator.isThreadTargetedEcho(whenOff), isFalse);
    });
  });

  group('send + delete rules', () {
    test('alsoSendToChannel maps to showInConversation', () {
      expect(
        IsmChatThreadCoordinator.showInConversationForReply(
          alsoSendToChannel: false,
        ),
        isFalse,
      );
      expect(
        IsmChatThreadCoordinator.showInConversationForReply(
          alsoSendToChannel: true,
        ),
        isTrue,
      );
    });

    test('errorCode 4 is recognised as "root has replies"', () {
      const blocked = IsmChatResponseModel(
        data: '{"errorCode": 4, "error": "Cannot delete message: thread has '
            'replies."}',
        hasError: true,
        errorCode: 400,
      );
      expect(IsmChatThreadCoordinator.isRootDeleteBlocked(blocked), isTrue);
      expect(IsmChatThreadCoordinator.rootHasRepliesErrorCode, 4);
    });

    test('other failures and successes are not delete-blocked', () {
      expect(
        IsmChatThreadCoordinator.isRootDeleteBlocked(
          const IsmChatResponseModel(
            data: '{"errorCode": 6}',
            hasError: true,
            errorCode: 403,
          ),
        ),
        isFalse,
      );
      expect(
        IsmChatThreadCoordinator.isRootDeleteBlocked(
          const IsmChatResponseModel(
            data: '{"errorCode": 4}',
            hasError: false,
            errorCode: 200,
          ),
        ),
        isFalse,
      );
      expect(IsmChatThreadCoordinator.isRootDeleteBlocked(null), isFalse);
    });
  });

  group('message model getters', () {
    test('classify regardless of the flag; only the UI gate follows it', () {
      final reply = threadReply();
      // Classification describes the message, so it does not depend on the
      // flag — that is what lets a host inspect data before switching on.
      expect(reply.isThreadReply, isTrue);
      expect(reply.isThreadOnlyReply, isTrue);
      expect(reply.threadId, 'root-1');
      expect(threadRoot(replyCount: 4).threadReplyCount, 4);
      // The UI gate stays shut while threads are off.
      expect(reply.showThreadFooter, isFalse);
      expect(threadRoot(replyCount: 4).showThreadFooter, isFalse);

      IsmChatConfig.threadsEnabled = true;
      expect(threadRoot(replyCount: 4).showThreadFooter, isTrue);
      expect(threadRoot(replyCount: 0).showThreadFooter, isFalse);
    });

  });
}
