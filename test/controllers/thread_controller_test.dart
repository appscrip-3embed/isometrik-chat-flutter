import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// [IsmChatThreadController] owns everything the thread panel shows, so these
/// tests cover opening, paging, optimistic sending, realtime merges and the
/// root badge — all against a [FakeChatApi], no widgets involved.
void main() {
  late FakeChatApi api;
  late IsmChatThreadController controller;

  IsmChatThreadController buildController() => IsmChatThreadController(
        IsmChatThreadViewModel(
          IsmChatThreadRepository(apiWrapper: api.wrapper()),
        ),
      );

  setUp(() {
    configureChatSdk();
    IsmChatConfig.threadsEnabled = true;
    api = FakeChatApi();
    controller = Get.put(buildController());
  });

  tearDown(() async {
    IsmChatConfig.threadsEnabled = false;
    await resetChatSdk();
  });

  void stubThread(List<Map<String, dynamic>> replies) => api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({'messages': replies}),
      );

  void stubSend({String messageId = 'server-reply'}) => api.on(
        'POST',
        '/chat/message',
        FakeResponse.json({'messageId': messageId}),
      );

  group('openThread', () {
    test('loads replies oldest-first and keeps the root', () async {
      stubThread([
        threadReplyJson(messageId: 'r2', sentAt: 3000),
        threadReplyJson(messageId: 'r1', sentAt: 2000),
      ]);

      await controller.openThread(
        root: threadRoot(replyCount: 2),
        conversation: directConversation(),
      );

      expect(controller.root?.messageId, 'root-1');
      expect(controller.threadRootId, 'root-1');
      expect(controller.replies.map((e) => e.messageId), ['r1', 'r2']);
      expect(controller.replyCount, 2);
      expect(controller.isLoading, isFalse);
      expect(controller.loadErrorMessage, isEmpty);
    });

    test('does nothing while threads are off', () async {
      IsmChatConfig.threadsEnabled = false;
      stubThread([threadReplyJson()]);

      await controller.openThread(root: threadRoot());

      expect(controller.root, isNull);
      expect(api.requests, isEmpty);
    });

    test('ignores a message that cannot root a thread', () async {
      await controller.openThread(root: message(messageId: ''));
      expect(controller.root, isNull);
      expect(api.requests, isEmpty);
    });

    test('re-opening a different thread drops the previous replies', () async {
      stubThread([threadReplyJson(messageId: 'r1')]);
      await controller.openThread(root: threadRoot(messageId: 'root-1'));
      expect(controller.replies, hasLength(1));

      stubThread([
        threadReplyJson(messageId: 'other-1', threadRootId: 'root-2'),
      ]);
      await controller.openThread(
        root: threadRoot(messageId: 'root-2', replyCount: 1),
      );
      expect(controller.threadRootId, 'root-2');
      expect(controller.replies.map((e) => e.messageId), ['other-1']);
    });

    test('opening from an also-sent row loads that thread, not the last panel',
        () async {
      final pageApi = FakeChatApi();
      final ctrls = registerChatControllers(pageApi);
      final page = ctrls.page;
      final rootA = threadRoot(messageId: 'root-a', replyCount: 1);
      final rootB = threadRoot(messageId: 'root-b', replyCount: 0);
      final alsoSent = threadReply(
        messageId: 'also-1',
        threadRootId: 'root-a',
        alsoSentToChannel: true,
        body: 'broadcast',
      );
      page.messages = [rootA, alsoSent, rootB];

      pageApi.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [
            threadReplyJson(messageId: 'b-1', threadRootId: 'root-b'),
          ],
        }),
      );
      final threadCtrl = IsmChatThreadController(
        IsmChatThreadViewModel(
          IsmChatThreadRepository(apiWrapper: pageApi.wrapper()),
        ),
      );
      Get.put(threadCtrl);
      final conversation = directConversation();

      await threadCtrl.openThread(root: rootB, conversation: conversation);
      expect(threadCtrl.threadRootId, 'root-b');
      expect(threadCtrl.replies.single.messageId, 'b-1');

      pageApi.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [
            threadReplyJson(messageId: 'a-1', threadRootId: 'root-a'),
          ],
        }),
      );
      await threadCtrl.openThread(root: alsoSent, conversation: conversation);
      expect(threadCtrl.threadRootId, 'root-a');
      expect(threadCtrl.root?.messageId, 'root-a');
      expect(threadCtrl.replies.single.messageId, 'a-1');
    });

    test('a failed load surfaces a retry message and keeps the panel', () async {
      api.on('GET', '/chat/messages', const FakeResponse('{}', status: 500));
      await controller.openThread(root: threadRoot());
      expect(controller.replies, isEmpty);
      expect(controller.loadErrorMessage, IsmChatStrings.threadLoadFailed);
    });

    test('HTTP 404 on first load is an empty thread, not a failure', () async {
      api.on(
        'GET',
        '/chat/messages',
        const FakeResponse('{"error":"Not found"}', status: 404),
      );
      await controller.openThread(root: threadRoot(replyCount: 0));
      expect(controller.replies, isEmpty);
      expect(controller.loadErrorMessage, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('system rows from the API are filtered out of the thread', () async {
      stubThread([
        threadReplyJson(messageId: 'r1', sentAt: 2000),
        threadReplyJson(
          messageId: 'noise',
          sentAt: 2500,
          action: 'reactionAdd',
        ),
      ]);
      await controller.openThread(root: threadRoot());
      expect(controller.replies.map((e) => e.messageId), ['r1']);
    });

    test('toggleEmojiBoard is isolated from the channel composer', () async {
      await controller.openThread(root: threadRoot());
      expect(controller.showEmojiBoard, isFalse);
      controller.toggleEmojiBoard(true);
      expect(controller.showEmojiBoard, isTrue);
      controller.closeEmojiBoard();
      expect(controller.showEmojiBoard, isFalse);
    });

    test('closeThread clears every bit of panel state', () async {
      stubThread([threadReplyJson()]);
      await controller.openThread(root: threadRoot());
      controller
        ..alsoSendToChannel = true
        ..replyTo = threadReply()
        ..closeThread();

      expect(controller.root, isNull);
      expect(controller.replies, isEmpty);
      expect(controller.alsoSendToChannel, isFalse);
      expect(controller.replyTo, isNull);
      expect(controller.replyCount, 0);
    });
  });

  group('paging', () {
    test('loadMoreReplies appends the next page and stops at the end',
        () async {
      // First page is full → more may exist.
      stubThread(
        List.generate(
          IsmChatThreadController.pageLimit,
          (i) => threadReplyJson(messageId: 'r$i', sentAt: 2000 + i),
        ),
      );
      await controller.openThread(
        root: threadRoot(replyCount: IsmChatThreadController.pageLimit),
      );
      expect(controller.hasMore, isTrue);
      expect(controller.replies, hasLength(IsmChatThreadController.pageLimit));

      stubThread([threadReplyJson(messageId: 'tail', sentAt: 9000)]);
      await controller.loadMoreReplies();

      expect(
        controller.replies.last.messageId,
        'tail',
        reason: 'older page merges in sentAt order',
      );
      expect(controller.hasMore, isFalse, reason: 'short page ends paging');

      // Skip is sent so the server does not resend page one.
      final query = api.requestsTo('/chat/messages').last.url.queryParameters;
      expect(query['skip'], '${IsmChatThreadController.pageLimit}');
    });

    test('a failed older page surfaces the retry message', () async {
      stubThread(
        List.generate(
          IsmChatThreadController.pageLimit,
          (i) => threadReplyJson(messageId: 'r$i', sentAt: 2000 + i),
        ),
      );
      await controller.openThread(root: threadRoot());

      api.on('GET', '/chat/messages', const FakeResponse('{}', status: 500));
      await controller.loadMoreReplies();

      expect(controller.loadErrorMessage, IsmChatStrings.threadLoadFailed);
      // The page already loaded is kept.
      expect(controller.replies, hasLength(IsmChatThreadController.pageLimit));
    });

    test('an empty page ends paging without an error', () async {
      stubThread(
        List.generate(
          IsmChatThreadController.pageLimit,
          (i) => threadReplyJson(messageId: 'r$i', sentAt: 2000 + i),
        ),
      );
      await controller.openThread(root: threadRoot());

      stubThread([]);
      await controller.loadMoreReplies();
      expect(controller.hasMore, isFalse);
      expect(controller.loadErrorMessage, isEmpty);
    });

    test('loadMoreReplies is a no-op once the thread is fully loaded',
        () async {
      stubThread([threadReplyJson()]);
      await controller.openThread(root: threadRoot());
      expect(controller.hasMore, isFalse);

      final before = api.requests.length;
      await controller.loadMoreReplies();
      expect(api.requests.length, before);
    });

    test('refreshReplyCount writes the server count onto the root', () async {
      stubThread([threadReplyJson()]);
      await controller.openThread(root: threadRoot(replyCount: 1));

      api.on(
        'GET',
        '/chat/messages/count',
        FakeResponse.json(const {'messagesCount': 12}),
      );
      await controller.refreshReplyCount();
      expect(controller.root?.replyCount, 12);
      expect(controller.replyCount, 12);
    });
  });

  group('sendReply', () {
    setUp(() {
      stubThread([]);
      stubSend();
    });

    test('shows the reply immediately and confirms it with the server id',
        () async {
      await controller.openThread(root: threadRoot(replyCount: 0));
      controller.replyController.text = 'on it';

      final sent = await controller.sendReply();

      expect(sent, isTrue);
      expect(controller.replies, hasLength(1));
      final reply = controller.replies.single;
      expect(reply.messageId, 'server-reply');
      expect(reply.body, 'on it');
      expect(reply.messageType, IsmChatMessageType.reply);
      expect(reply.threadRootId, 'root-1');
      expect(reply.parentMessageId, 'root-1');
      expect(reply.showInConversation, isFalse);
      expect(reply.sentByMe, isTrue);
      // Composer cleared, badge bumped.
      expect(controller.replyController.text, isEmpty);
      expect(controller.root?.replyCount, 1);
      expect(controller.isSending, isFalse);
    });

    test('"also send to channel" posts showInConversation: true', () async {
      await controller.openThread(root: threadRoot(replyCount: 0));
      controller
        ..alsoSendToChannel = true
        ..replyController.text = 'everyone should see this';

      await controller.sendReply();

      final body = api.requestsForPath('/chat/message', method: 'POST').last.json
          as Map<String, dynamic>;
      expect(body['showInConversation'], isTrue);
      expect(controller.replies.single.showInConversation, isTrue);
    });

    test('also-send text is mirrored onto the live chat page', () async {
      final pageApi = FakeChatApi();
      final ctrls = registerChatControllers(pageApi);
      final page = ctrls.page;
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      final conversation = directConversation();
      page
        ..conversation = conversation
        ..messages = [root];
      pageApi.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({'messages': []}),
      );
      pageApi.on(
        'POST',
        '/chat/message',
        FakeResponse.json({'messageId': 'also-sent-id'}),
      );
      final threadCtrl = IsmChatThreadController(
        IsmChatThreadViewModel(
          IsmChatThreadRepository(apiWrapper: pageApi.wrapper()),
        ),
      );
      Get.put(threadCtrl);

      await threadCtrl.openThread(root: root, conversation: conversation);
      threadCtrl
        ..alsoSendToChannel = true
        ..replyController.text = 'seen in channel';

      expect(await threadCtrl.sendReply(), isTrue);
      expect(
        page.messages.map((e) => e.body),
        contains('seen in channel'),
      );
      final channelRow = page.messages
          .firstWhere((e) => (e.messageId ?? '') == 'also-sent-id');
      expect(channelRow.threadRootId, 'root-1');
      expect(channelRow.showInConversation, isTrue);
    });

    test('a nested reply targets the reply, not the root', () async {
      await controller.openThread(root: threadRoot(replyCount: 0));
      controller
        ..replyTo = threadReply(messageId: 'r1', threadRootId: 'root-1')
        ..replyController.text = 'answering r1';

      await controller.sendReply();

      final body = api.requestsForPath('/chat/message', method: 'POST').last.json
          as Map<String, dynamic>;
      expect(body['parentMessageId'], 'r1');
      // Same thread: threadRootId comes from the parent's root.
      expect(controller.replies.single.threadRootId, 'root-1');
      // Target cleared after sending.
      expect(controller.replyTo, isNull);
    });

    test('rolls the optimistic row back and reports the server error',
        () async {
      await controller.openThread(root: threadRoot(replyCount: 0));
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(
          const {'errorCode': 1, 'error': 'Parent message not found.'},
          status: 404,
        ),
      );
      controller.replyController.text = 'doomed';

      final sent = await controller.sendReply();

      expect(sent, isFalse);
      expect(controller.replies, isEmpty);
      expect(controller.sendErrorMessage, 'Parent message not found.');
      expect(controller.root?.replyCount, 0);
    });

    test('a send that never reached the server stays queued, not lost',
        () async {
      await controller.openThread(root: threadRoot(replyCount: 0));
      api.throwOn('POST', '/chat/message', Exception('offline'));
      controller.replyController.text = 'offline draft';

      expect(await controller.sendReply(), isFalse);
      // The row stays on screen and the user is told it will be retried.
      expect(controller.replies.single.body, 'offline draft');
      expect(controller.sendErrorMessage, IsmChatStrings.threadReplyQueued);
    });

    test('a server rejection drops the row and shows the reason', () async {
      await controller.openThread(root: threadRoot(replyCount: 0));
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(
          const {'errorCode': 1, 'error': 'Parent message not found.'},
          status: 404,
        ),
      );
      controller.replyController.text = 'doomed';

      expect(await controller.sendReply(), isFalse);
      expect(controller.replies, isEmpty);
      expect(controller.sendErrorMessage, 'Parent message not found.');
    });

    test('keeps the confirmed reply even if the panel was cleared mid-send',
        () async {
      await controller.openThread(root: threadRoot(replyCount: 0));
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(
          const {'messageId': 'server-reply'},
          delay: const Duration(milliseconds: 20),
        ),
      );
      controller.replyController.text = 'slow send';

      final pendingSend = controller.sendReply();
      // Something else drops the optimistic row while the POST is in flight.
      controller.replies.clear();
      expect(await pendingSend, isTrue);
      expect(controller.replies.single.messageId, 'server-reply');
    });

    test('clearReplyTo drops the nested-reply target', () async {
      await controller.openThread(root: threadRoot());
      controller.replyTo = threadReply(messageId: 'r1');
      expect(controller.replyTo, isNotNull);
      controller.clearReplyTo();
      expect(controller.replyTo, isNull);
    });

    test('ignores empty text and a missing root', () async {
      await controller.openThread(root: threadRoot());
      controller.replyController.text = '   ';
      expect(await controller.sendReply(), isFalse);

      controller.closeThread();
      expect(await controller.sendReply(text: 'no root'), isFalse);
      expect(api.requestsForPath('/chat/message', method: 'POST'), isEmpty);
    });
  });

  group('realtime', () {
    test('an incoming reply for this thread is merged and bumps the badge',
        () async {
      stubThread([threadReplyJson(messageId: 'r1', sentAt: 2000)]);
      await controller.openThread(root: threadRoot(replyCount: 1));

      final applied = controller.applyIncomingReply(
        threadReply(messageId: 'r2', sentAt: 3000),
      );

      expect(applied, isTrue);
      expect(controller.replies.map((e) => e.messageId), ['r1', 'r2']);
      expect(controller.root?.replyCount, 2);
      expect(controller.root?.lastThreadReplyAt, 3000);
    });

    test('a reply for another thread is ignored', () async {
      stubThread([]);
      await controller.openThread(root: threadRoot());

      final applied = controller.applyIncomingReply(
        threadReply(messageId: 'x', threadRootId: 'root-999'),
      );
      expect(applied, isFalse);
      expect(controller.replies, isEmpty);
    });

    test('an echo of our own reply replaces it instead of duplicating',
        () async {
      stubThread([]);
      stubSend(messageId: 'server-reply');
      await controller.openThread(root: threadRoot(replyCount: 0));
      controller.replyController.text = 'hello';
      await controller.sendReply();
      expect(controller.replies, hasLength(1));

      controller.applyIncomingReply(
        threadReply(messageId: 'server-reply', body: 'hello', sentAt: 4000),
      );
      expect(controller.replies, hasLength(1));
      expect(controller.replies.single.messageId, 'server-reply');
    });

    test('a server echo with a new id replaces our pending row', () async {
      stubThread([]);
      await controller.openThread(root: threadRoot(replyCount: 0));
      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(
          const {'messageId': 'server-reply'},
          delay: const Duration(milliseconds: 40),
        ),
      );
      controller.replyController.text = 'racing';
      final pendingSend = controller.sendReply();

      // The realtime echo of this very reply can beat the HTTP response; it
      // carries the same server id.
      controller.applyIncomingReply(
        threadReply(messageId: 'server-reply', body: 'racing', sentAt: 7000),
      );
      await pendingSend;

      expect(
        controller.replies.where((e) => e.body == 'racing'),
        hasLength(1),
        reason: 'the pending row is replaced, not duplicated',
      );
      expect(controller.replies.single.messageId, 'server-reply');
      // The badge counts the reply once, not twice.
      expect(controller.root?.replyCount, 1);
    });

    test('out-of-order arrivals are inserted by sentAt', () async {
      stubThread([threadReplyJson(messageId: 'r1', sentAt: 2000)]);
      await controller.openThread(root: threadRoot());

      controller
        ..applyIncomingReply(threadReply(messageId: 'r3', sentAt: 4000))
        ..applyIncomingReply(threadReply(messageId: 'r2', sentAt: 3000));

      expect(controller.replies.map((e) => e.messageId), ['r1', 'r2', 'r3']);
    });

    test('deliverIncomingReply routes through the registered controller',
        () async {
      stubThread([]);
      await controller.openThread(root: threadRoot(replyCount: 0));

      expect(
        IsmChatThreadController.deliverIncomingReply(
          threadReply(messageId: 'live', sentAt: 5000),
        ),
        isTrue,
      );
      expect(controller.replies.single.messageId, 'live');

      // With threads off nothing is routed, even with a live controller.
      IsmChatConfig.threadsEnabled = false;
      expect(
        IsmChatThreadController.deliverIncomingReply(
          threadReply(messageId: 'live-2', sentAt: 6000),
        ),
        isFalse,
      );
      expect(controller.replies, hasLength(1));
    });

    test('a deleted reply leaves the thread and lowers the badge', () async {
      stubThread([
        threadReplyJson(messageId: 'r1', sentAt: 2000),
        threadReplyJson(messageId: 'r2', sentAt: 3000),
      ]);
      await controller.openThread(root: threadRoot(replyCount: 2));

      controller.applyReplyDeleted('r1');

      expect(controller.replies.map((e) => e.messageId), ['r2']);
      expect(controller.root?.replyCount, 1);

      // Unknown ids change nothing.
      controller.applyReplyDeleted('nope');
      expect(controller.replies, hasLength(1));
      expect(controller.root?.replyCount, 1);
    });
  });

  group('cached badge', () {
    late IsmChatDBWrapper db;

    setUp(() async {
      // Real Hive in a temp directory: plain `test()` runs on the real event
      // loop, so no pumping is needed for file IO.
      db = await openTestDatabase();
    });

    test('an own reply persists the root badge so a reload keeps it', () async {
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await db.saveConversation(
        conversation: directConversation(messages: {'1000': root}),
      );
      stubThread([]);
      stubSend();

      await controller.openThread(
        root: root,
        conversation: directConversation(),
      );
      controller.replyController.text = 'persist me';
      expect(await controller.sendReply(), isTrue);
      await pumpEventQueue();

      final stored = await db.getConversation(kDirectConversationId);
      final storedRoot = stored?.messages?.values
          .firstWhere((e) => e.messageId == 'root-1');
      expect(storedRoot?.replyCount, 1);
      expect(storedRoot?.lastThreadReplyAt, isNotNull);
      // The reply itself is never written to the conversation.
      expect(
        stored?.messages?.values.map((e) => e.messageId),
        isNot(contains('server-reply')),
      );
    });

    test('an offline reply is queued, kept in the panel, and dequeued on send',
        () async {
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await db.saveConversation(
        conversation: directConversation(messages: {'1000': root}),
      );
      stubThread([]);
      await controller.openThread(
        root: root,
        conversation: directConversation(),
      );

      // 1. Offline: the POST never reaches the server.
      api.throwOn('POST', '/chat/message', Exception('offline'));
      controller.replyController.text = 'queued reply';
      expect(await controller.sendReply(), isFalse);

      final queued = await db.getMessage(
        kDirectConversationId,
        IsmChatDbBox.pending,
      );
      expect(
        queued?.values.map((e) => e.body),
        contains('queued reply'),
        reason: 'the reply waits in the pending box for the retry sender',
      );
      final queuedReply = queued!.values.firstWhere(
        (e) => e.body == 'queued reply',
      );
      // Stored as a thread reply, so the retry re-sends it as one.
      expect(queuedReply.threadRootId, 'root-1');
      expect(queuedReply.showInConversation, isFalse);
      expect(queuedReply.messageType, IsmChatMessageType.reply);

      // 2. Reopening the thread still shows it (the server does not have it).
      await controller.openThread(
        root: root,
        conversation: directConversation(),
      );
      expect(controller.replies.map((e) => e.body), contains('queued reply'));

      // 3. Back online: the same text sends and the queue is cleared.
      stubSend(messageId: 'server-reply');
      controller.replyController.text = 'now online';
      expect(await controller.sendReply(), isTrue);
      final afterSend = await db.getMessage(
        kDirectConversationId,
        IsmChatDbBox.pending,
      );
      expect(
        afterSend?.values.map((e) => e.body) ?? const <String>[],
        isNot(contains('now online')),
      );
    });

    test('a rejected reply is dequeued so it is not retried forever', () async {
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await db.saveConversation(
        conversation: directConversation(messages: {'1000': root}),
      );
      stubThread([]);
      await controller.openThread(
        root: root,
        conversation: directConversation(),
      );

      api.on(
        'POST',
        '/chat/message',
        FakeResponse.json(
          const {'errorCode': 1, 'error': 'Parent message not found.'},
          status: 404,
        ),
      );
      controller.replyController.text = 'rejected reply';
      expect(await controller.sendReply(), isFalse);

      final queued = await db.getMessage(
        kDirectConversationId,
        IsmChatDbBox.pending,
      );
      expect(
        queued?.values.map((e) => e.body) ?? const <String>[],
        isNot(contains('rejected reply')),
      );
    });

    test('a realtime reply does not write the database (the MQTT handler does)',
        () async {
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await db.saveConversation(
        conversation: directConversation(messages: {'1000': root}),
      );
      stubThread([]);
      await controller.openThread(
        root: root,
        conversation: directConversation(),
      );

      controller.applyIncomingReply(
        threadReply(messageId: 'live', sentAt: 5000),
      );
      await pumpEventQueue();

      final stored = await db.getConversation(kDirectConversationId);
      expect(
        stored?.messages?.values
            .firstWhere((e) => e.messageId == 'root-1')
            .replyCount,
        0,
        reason: 'the cached badge is owned by the MQTT handler for this path',
      );
      // …while the panel shows it immediately.
      expect(controller.root?.replyCount, 1);
    });
  });

  group('attachment sends (local echoes)', () {
    IsmChatMessageModel mediaEcho({int sentAt = 7000}) => message(
          body: '',
          customType: IsmChatCustomMessageType.image,
          messageId: '',
          sentAt: sentAt,
          attachments: [attachment(IsmChatMediaType.image)],
        );

    test('sendTarget tracks the root, the nested target and the switch',
        () async {
      expect(controller.sendTarget, isNull, reason: 'no thread open');

      stubThread([]);
      await controller.openThread(root: threadRoot(messageId: 'root-1'));
      expect(controller.sendTarget?.threadRootId, 'root-1');
      expect(controller.sendTarget?.parentMessageId, 'root-1');
      expect(controller.sendTarget?.showInConversation, isFalse);

      controller.replyTo = threadReply(messageId: 'r1');
      expect(controller.sendTarget?.parentMessageId, 'r1');

      controller.alsoSendToChannel = true;
      expect(controller.sendTarget?.showInConversation, isTrue);

      controller.closeThread();
      expect(controller.sendTarget, isNull);
    });

    test('a stamped echo is shown in the panel and can be updated and confirmed',
        () async {
      stubThread([]);
      await controller.openThread(root: threadRoot(replyCount: 0));

      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(),
        controller.sendTarget,
      );
      expect(controller.addLocalReply(echo), isTrue);
      expect(controller.replies.single.sentAt, 7000);

      // Upload progress lands on the panel row.
      final mutated = controller.mutateLocalReply(
        7000,
        (row) {
          row.isUploading = false;
          return true;
        },
        onlyUnsent: true,
      );
      expect(mutated, isTrue);
      expect(controller.replies.single.isUploading, isFalse);

      // The send response promotes it to a real message and moves the badge.
      controller.confirmLocalReply(sentAt: 7000, messageId: 'server-media');
      expect(controller.replies.single.messageId, 'server-media');
      expect(controller.root?.replyCount, 1);
    });

    test('an echo for another thread is refused', () async {
      stubThread([]);
      await controller.openThread(root: threadRoot(messageId: 'root-1'));
      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(),
        IsmChatThreadSendTarget.forThread(
          root: threadRoot(messageId: 'root-other'),
        ),
      );
      expect(controller.addLocalReply(echo), isFalse);
      expect(controller.replies, isEmpty);
    });

    test('mutate / confirm / remove are no-ops for unknown rows', () async {
      stubThread([]);
      await controller.openThread(root: threadRoot(replyCount: 0));
      expect(
        controller.mutateLocalReply(1, (_) => true),
        isFalse,
      );
      controller
        ..confirmLocalReply(sentAt: 1, messageId: 'x')
        ..confirmLocalReply(sentAt: 1, messageId: '')
        ..removeLocalReply(1);
      expect(controller.replies, isEmpty);
      expect(controller.root?.replyCount, 0);
    });

    test('a failed upload row can be dropped from the panel', () async {
      stubThread([]);
      await controller.openThread(root: threadRoot(replyCount: 0));
      controller.addLocalReply(
        IsmChatThreadCoordinator.stampThreadTarget(
          mediaEcho(),
          controller.sendTarget,
        ),
      );
      expect(controller.replies, hasLength(1));

      controller.removeLocalReply(7000);
      expect(controller.replies, isEmpty);
    });
  });

  group('IsmChatThreadViewModel.sanitize', () {
    test('drops action rows and block banners, sorts by sentAt', () {
      final sanitized = IsmChatThreadViewModel.sanitize([
        threadReply(messageId: 'late', sentAt: 5000),
        threadReply(messageId: 'early', sentAt: 1000),
        message(
          messageId: 'banner',
          customType: IsmChatCustomMessageType.block,
          sentAt: 2000,
        ),
      ]);
      expect(sanitized.map((e) => e.messageId), ['early', 'late']);
    });
  });

  group('buildLocalReply', () {
    test('mirrors what the server will store', () {
      final pending = controller.buildLocalReply(
        body: 'draft',
        parent: threadReply(messageId: 'r1', threadRootId: 'root-1'),
        conversationId: kDirectConversationId,
        alsoSendToChannel: true,
      );
      expect(pending.messageId, isEmpty);
      expect(pending.messageType, IsmChatMessageType.reply);
      expect(pending.parentMessageId, 'r1');
      expect(pending.threadRootId, 'root-1');
      expect(pending.showInConversation, isTrue);
      expect(pending.sentByMe, isTrue);
      expect(pending.customType, IsmChatCustomMessageType.text);
    });
  });
}
