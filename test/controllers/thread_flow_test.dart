import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

/// End-to-end threading behaviour on the real chat page + database + MQTT.
///
/// The point of these tests is the **off** case as much as the on case: with
/// [IsmChatConfig.threadsEnabled] false the SDK must fetch and render exactly
/// what it did before threading existed.
///
/// **Harness note:** read the local database back with [drive], not
/// `tester.runAsync` — once the fake-async zone has driven Hive work, a read
/// started with `runAsync` never completes.
void main() {
  /// Last-message preview on the seeded conversation, so a test can prove the
  /// preview did **not** change when a thread reply arrived.
  LastMessageDetails channelPreview() => LastMessageDetails.fromMap({
        'messageId': 'root-1',
        'body': 'root message',
        'sentAt': 1000,
        'conversationId': kDirectConversationId,
        'senderId': kMeId,
        'senderName': kMeName,
        'showInConversation': true,
        'messageType': 0,
        'customType': 'text',
      });

  Future<void> seedConversation(
    ChatTestContext ctx, {
    Map<String, IsmChatMessageModel>? messages,
    LastMessageDetails? lastMessageDetails,
  }) async {
    final conversation = directConversation(messages: messages)
        .copyWith(lastMessageDetails: lastMessageDetails);
    await ctx.db!.saveConversation(conversation: conversation);
    ctx.page
      ..conversation = conversation
      ..currentUser = me();
  }

  /// Reads the cached conversation through the fake-async zone.
  Future<IsmChatConversationModel?> readConversation(
    WidgetTester tester,
    ChatTestContext ctx,
  ) =>
      drive(tester, () => ctx.db!.getConversation(kDirectConversationId));

  /// Registers the thread controller against the test API.
  ///
  /// [IsmChatThreadBinding] is idempotent, so the `IsmChat.i` thread methods
  /// reuse this instance instead of building one on the real HTTP client.
  IsmChatThreadController putThreadController(ChatTestContext ctx) => Get.put(
        IsmChatThreadController(
          IsmChatThreadViewModel(
            IsmChatThreadRepository(apiWrapper: ctx.api.wrapper()),
          ),
        ),
      );

  IsmChatMqttController putMqtt(ChatTestContext ctx) => Get.put(
        IsmChatMqttController(
          IsmChatMqttViewModel(
            IsmChatMqttRepository(apiWrapper: ctx.api.wrapper()),
          ),
        ),
      );

  group('channel fetch', () {
    chatTestWidgets('threads off → no feedType param (legacy request)',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = false;
      await tester.runAsync(() => seedConversation(ctx));
      ctx.api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({'messages': [messageJson()]}),
      );

      await drive(tester, ctx.page.getMessagesFromAPI);

      final query =
          ctx.api.requestsTo('/chat/messages').last.url.queryParameters;
      expect(query.containsKey('feedType'), isFalse);
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets('threads on → asks the server for feedType=main',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      await tester.runAsync(() => seedConversation(ctx));
      ctx.api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({'messages': [messageJson()]}),
      );

      await drive(tester, ctx.page.getMessagesFromAPI);

      final query =
          ctx.api.requestsTo('/chat/messages').last.url.queryParameters;
      expect(query['feedType'], 'main');
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets(
        'threads on → a thread-only reply in the response never reaches the '
        'timeline or the database', (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      await tester.runAsync(() => seedConversation(ctx));
      ctx.api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [
            messageJson(messageId: 'channel-1', sentAt: 1000),
            threadReplyJson(messageId: 'thread-1', sentAt: 2000),
            threadReplyJson(
              messageId: 'shared-1',
              sentAt: 2500,
              alsoSentToChannel: true,
            ),
          ],
        }),
      );

      await drive(tester, ctx.page.getMessagesFromAPI);
      await settle(tester);

      final ids = ctx.page.messages.map((e) => e.messageId).toList();
      expect(ids, contains('channel-1'));
      // "Also sent to channel" belongs in both places…
      expect(ids, contains('shared-1'));
      // …a thread-only reply belongs only in the thread.
      expect(ids, isNot(contains('thread-1')));

      final stored = await readConversation(tester, ctx);
      final storedIds =
          stored?.messages?.values.map((e) => e.messageId).toList() ?? [];
      expect(storedIds, isNot(contains('thread-1')));
      expect(storedIds, contains('channel-1'));
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets(
        'threads off → the same reply still renders inline (unchanged '
        'behaviour)', (tester, ctx) async {
      IsmChatConfig.threadsEnabled = false;
      await tester.runAsync(() => seedConversation(ctx));
      ctx.api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({
          'messages': [threadReplyJson(messageId: 'thread-1', sentAt: 2000)],
        }),
      );

      await drive(tester, ctx.page.getMessagesFromAPI);
      await settle(tester);

      expect(
        ctx.page.messages.map((e) => e.messageId),
        contains('thread-1'),
      );
    }, setUpApi: (api) => api.registerSendDefaults());
  });

  group('realtime routing', () {
    chatTestWidgets(
        'threads on → an incoming thread reply bumps the root badge, stays '
        'out of the channel, and lands in the open panel', (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);

      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await tester.runAsync(
        () => seedConversation(ctx, messages: {'root-1': root}),
      );
      ctx.page.messages = [root];

      // A thread panel is open on this thread.
      final thread = putThreadController(ctx);
      ctx.api.on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      await drive(
        tester,
        () => thread.openThread(root: root, conversation: ctx.page.conversation),
      );

      putMqtt(ctx).onMqttEvent(
        event: EventModel(
          topic: 'msg',
          payload: {
            ...threadReplyJson(
              messageId: 'live-reply',
              threadRootId: 'root-1',
              sentAt: 4000,
            ),
            'action': 'chatMessageSent',
          },
        ),
      );

      await pumpUntil(
        tester,
        () => thread.replies.any((e) => e.messageId == 'live-reply'),
      );

      // Panel shows it, channel does not.
      expect(thread.replies.single.messageId, 'live-reply');
      expect(
        ctx.page.messages.map((e) => e.messageId),
        isNot(contains('live-reply')),
      );
      // Badge moved on the channel row and in the panel.
      final channelRoot = ctx.page.messages
          .firstWhere((e) => e.messageId == 'root-1');
      expect(channelRoot.replyCount, 1);
      expect(thread.root?.replyCount, 1);
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets(
        'threads on → the conversation preview keeps the last channel message',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);

      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await tester.runAsync(
        () => seedConversation(
          ctx,
          messages: {'root-1': root},
          lastMessageDetails: channelPreview(),
        ),
      );
      final before = await readConversation(tester, ctx);
      final previewBefore = before?.lastMessageDetails?.messageId;
      expect(previewBefore, 'root-1');

      putMqtt(ctx).onMqttEvent(
        event: EventModel(
          topic: 'msg',
          payload: {
            ...threadReplyJson(
              messageId: 'live-reply',
              threadRootId: 'root-1',
              sentAt: 4000,
            ),
            'action': 'chatMessageSent',
          },
        ),
      );
      await settle(tester);

      final after = await readConversation(tester, ctx);
      expect(after?.lastMessageDetails?.messageId, previewBefore);
      // The root's badge is persisted, so it survives a chat reload.
      expect(
        after?.messages?.values
            .firstWhere((e) => e.messageId == 'root-1')
            .replyCount,
        1,
      );
      // The reply is not stored as a channel row either.
      expect(
        after?.messages?.values.map((e) => e.messageId),
        isNot(contains('live-reply')),
      );
      // Unread still counts thread activity (matches the backend).
      expect(
        (after?.unreadMessagesCount ?? 0) >= (before?.unreadMessagesCount ?? 0),
        isTrue,
      );
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets(
        'threads off → an incoming reply is appended to the channel as before',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = false;
      await tester.runAsync(() => seedConversation(ctx));

      putMqtt(ctx).onMqttEvent(
        event: EventModel(
          topic: 'msg',
          payload: {
            ...threadReplyJson(messageId: 'live-reply', sentAt: 4000),
            'action': 'chatMessageSent',
          },
        ),
      );

      await pumpUntil(
        tester,
        () => ctx.page.messages.any((e) => e.messageId == 'live-reply'),
      );
      expect(
        ctx.page.messages.map((e) => e.messageId),
        contains('live-reply'),
      );
    }, setUpApi: (api) => api.registerSendDefaults());
  });

  group('attachments composed in a thread', () {
    IsmChatMessageModel mediaEcho({int sentAt = 7000}) => message(
          body: '',
          customType: IsmChatCustomMessageType.image,
          messageId: '',
          sentAt: sentAt,
          attachments: [attachment(IsmChatMediaType.image)],
        );

    chatTestWidgets(
        'the echo goes to the panel, not the channel, and posts as a reply',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await tester.runAsync(
        () => seedConversation(ctx, messages: {'1000': root}),
      );
      ctx.page.messages = [root];
      ctx.api.on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      final thread = putThreadController(ctx);
      await drive(
        tester,
        () => thread.openThread(root: root, conversation: ctx.page.conversation),
      );

      // Opening the panel publishes the target the media pipelines read.
      expect(ctx.page.threadSendTarget?.threadRootId, 'root-1');

      // What every media / audio / document pipeline does: stamp, then show.
      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(),
        ctx.page.threadSendTarget,
      );
      ctx.page.addLocalOutgoingRow(echo);

      expect(thread.replies.single.sentAt, 7000);
      expect(
        ctx.page.messages.map((e) => e.sentAt),
        isNot(contains(7000)),
        reason: 'an attachment composed in a thread is not a channel row',
      );

      // Upload progress reaches the panel row through the shared helper.
      expect(
        ctx.page.mutateLocalRow(7000, (row) {
          row.isUploading = false;
          return true;
        }),
        isTrue,
      );
      expect(thread.replies.single.isUploading, isFalse);
      // …and so does the pipeline's "find my row" lookup.
      expect(ctx.page.localOutgoingRow(7000)?.sentAt, 7000);

      // The send itself posts a thread reply.
      await drive(
        tester,
        () => ctx.page.sendMessage(
          body: '',
          conversationId: kDirectConversationId,
          createdAt: 7000,
          deviceId: 'device-1',
          messageType: echo.messageType?.value ?? 0,
          notificationBody: 'Photo',
          notificationTitle: kMeName,
          customType: IsmChatCustomMessageType.image.value,
          attachments: [attachment(IsmChatMediaType.image).toMap()],
          parentMessageId: echo.parentMessageId,
          localEcho: echo,
        ),
      );

      final body = ctx.api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['messageType'], 2);
      expect(body['parentMessageId'], 'root-1');
      expect(body['showInConversation'], isFalse);
      expect(body['attachments'], isNotEmpty);
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets('"also send to channel" posts the attachment to both',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await tester.runAsync(
        () => seedConversation(ctx, messages: {'1000': root}),
      );
      ctx.api.on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      final thread = putThreadController(ctx);
      await drive(
        tester,
        () => thread.openThread(root: root, conversation: ctx.page.conversation),
      );
      thread.alsoSendToChannel = true;

      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(sentAt: 7100),
        ctx.page.threadSendTarget,
      );
      ctx.page.addLocalOutgoingRow(echo);

      // Shared replies belong in the channel list too.
      expect(ctx.page.messages.map((e) => e.sentAt), contains(7100));

      await drive(
        tester,
        () => ctx.page.sendMessage(
          body: '',
          conversationId: kDirectConversationId,
          createdAt: 7100,
          deviceId: 'device-1',
          messageType: echo.messageType?.value ?? 0,
          notificationBody: 'Photo',
          notificationTitle: kMeName,
          customType: IsmChatCustomMessageType.image.value,
          parentMessageId: echo.parentMessageId,
          localEcho: echo,
        ),
      );
      final body = ctx.api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['messageType'], 2);
      expect(body['showInConversation'], isTrue);
    }, setUpApi: (api) => api.registerSendDefaults());

    IsmChatMessageModel audioEcho({int sentAt = 7200}) => message(
          body: 'Audio',
          customType: IsmChatCustomMessageType.audio,
          messageId: '',
          sentAt: sentAt,
          attachments: [attachment(IsmChatMediaType.audio)],
        );

    chatTestWidgets('audio composed in a thread stays in the panel',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await tester.runAsync(
        () => seedConversation(ctx, messages: {'1000': root}),
      );
      ctx.page.messages = [root];
      ctx.api.on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      final thread = putThreadController(ctx);
      await drive(
        tester,
        () => thread.openThread(root: root, conversation: ctx.page.conversation),
      );

      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        audioEcho(),
        ctx.page.threadSendTarget,
      );
      ctx.page.addLocalOutgoingRow(echo);

      expect(thread.replies.single.sentAt, 7200);
      expect(
        ctx.page.messages.map((e) => e.sentAt),
        isNot(contains(7200)),
      );
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets('threads off → an attachment send is unchanged',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = false;
      await tester.runAsync(() => seedConversation(ctx));

      // No target exists, and a stamp cannot create one.
      expect(ctx.page.threadSendTarget, isNull);
      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(sentAt: 7200),
        IsmChatThreadSendTarget.forThread(root: threadRoot()),
      );
      ctx.page.addLocalOutgoingRow(echo);
      expect(ctx.page.messages.map((e) => e.sentAt), contains(7200));

      await drive(
        tester,
        () => ctx.page.sendMessage(
          body: '',
          conversationId: kDirectConversationId,
          createdAt: 7200,
          deviceId: 'device-1',
          messageType: 0,
          notificationBody: 'Photo',
          notificationTitle: kMeName,
          customType: IsmChatCustomMessageType.image.value,
          localEcho: echo,
        ),
      );
      final body = ctx.api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['messageType'], 0);
      expect(body['showInConversation'], isTrue);
      expect(body.containsKey('parentMessageId'), isFalse);
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets('closing the panel stops routing sends into the thread',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      await tester.runAsync(() => seedConversation(ctx));
      ctx.api.on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      final thread = putThreadController(ctx);
      await drive(
        tester,
        () => thread.openThread(
          root: threadRoot(),
          conversation: ctx.page.conversation,
        ),
      );
      expect(ctx.page.threadSendTarget, isNotNull);

      thread.closeThread();
      expect(ctx.page.threadSendTarget, isNull);

      // A later channel attachment is a plain channel message again.
      final echo = IsmChatThreadCoordinator.stampThreadTarget(
        mediaEcho(sentAt: 7300),
        ctx.page.threadSendTarget,
      );
      ctx.page.addLocalOutgoingRow(echo);
      expect(ctx.page.messages.map((e) => e.sentAt), contains(7300));
      expect(echo.threadRootId, isNull);
    }, setUpApi: (api) => api.registerSendDefaults());
  });

  group('thread panel rendering', () {
    chatTestWidgets(
        'a media reply renders with the SDK message widgets, text stays plain',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      await tester.runAsync(() => seedConversation(ctx));

      await pumpSdkScreen(
        tester,
        child: Scaffold(
          body: Column(
            children: [
              IsmChatThreadMessageTile(
                message: threadReply(body: 'just text'),
              ),
              IsmChatThreadMessageTile(
                message: message(
                  body: '',
                  customType: IsmChatCustomMessageType.file,
                  messageType: IsmChatMessageType.reply,
                  // Local-looking URLs: a VM widget test must not fetch.
                  attachments: [
                    attachment(IsmChatMediaType.file)
                        .copyWith(thumbnailUrl: '', mediaUrl: ''),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('just text'), findsOneWidget);
      // The document reply is rendered by the real message widget, not by the
      // "Document" fallback label.
      expect(find.byType(IsmChatMessageWrapper), findsOneWidget);
      expect(find.text('Document'), findsNothing);
    }, setUpApi: (api) => api.registerSendDefaults());

  });

  test('usesMediaTapBehavior is true for attachment replies only', () {
    configureChatSdk();
    addTearDown(() => resetChatSdk());
    expect(
      IsmChatThreadMessageTile.usesMediaTapBehavior(
        threadReply(body: 'hello'),
      ),
      isFalse,
    );
    expect(
      IsmChatThreadMessageTile.usesMediaTapBehavior(
        message(
          body: IsmChatStrings.image,
          customType: IsmChatCustomMessageType.reply,
          messageType: IsmChatMessageType.reply,
          attachments: [attachment(IsmChatMediaType.image)],
        ),
      ),
      isTrue,
    );
  });

  test('threadPanelBubbleType resolves AttachmentMessage:Reply + image attachment',
      () {
    configureChatSdk();
    addTearDown(() => resetChatSdk());
    final replyFromApi = message(
      body: IsmChatStrings.image,
      customType: IsmChatCustomMessageType.reply,
      messageType: IsmChatMessageType.reply,
      threadRootId: 'root-1',
      attachments: [attachment(IsmChatMediaType.image)],
    );
    expect(replyFromApi.threadPanelBubbleType, IsmChatCustomMessageType.image);
  });

  group('channel badge after thread', () {
    chatTestWidgets(
        'text reply bumps footer count; close + DB reload keeps badge',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      final root = threadRoot(messageId: 'root-1', replyCount: 0);
      await tester.runAsync(
        () => seedConversation(ctx, messages: {'1000': root}),
      );
      ctx.page.messages = [root];
      ctx.api.on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
      final thread = putThreadController(ctx);
      await drive(
        tester,
        () => thread.openThread(root: root, conversation: ctx.page.conversation),
      );
      thread.replyController.text = 'hello';
      await drive(tester, () => thread.sendReply());
      expect(
        ctx.page.messages
            .firstWhere((e) => e.messageId == 'root-1')
            .replyCount,
        1,
      );
      thread.closeThread();
      await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));
      expect(
        ctx.page.messages
            .firstWhere((e) => e.messageId == 'root-1')
            .replyCount,
        1,
      );
    }, setUpApi: (api) => api.registerSendDefaults());
  });

  group('focus menu', () {
    chatTestWidgets('"Reply in thread" appears only while threads are on',
        (tester, ctx) async {
      await tester.runAsync(() => seedConversation(ctx));
      final root = threadRoot();

      IsmChatConfig.threadsEnabled = false;
      expect(
        root.focusMenuList,
        isNot(contains(IsmChatFocusMenuType.replyInThread)),
      );
      // Inline quoting is untouched by threading.
      expect(root.focusMenuList, contains(IsmChatFocusMenuType.reply));

      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      expect(
        root.focusMenuList,
        contains(IsmChatFocusMenuType.replyInThread),
      );
      expect(root.focusMenuList, contains(IsmChatFocusMenuType.reply));

      // A row that cannot root a thread never offers the action.
      expect(
        message(messageId: '').focusMenuList,
        isNot(contains(IsmChatFocusMenuType.replyInThread)),
      );

      final alsoSent = threadReply(alsoSentToChannel: true);
      expect(
        alsoSent.focusMenuLabel(IsmChatFocusMenuType.replyInThread),
        IsmChatStrings.viewThread,
      );
      expect(
        root.focusMenuLabel(IsmChatFocusMenuType.replyInThread),
        IsmChatStrings.replyInThread,
      );
    }, setUpApi: (api) => api.registerSendDefaults());
  });

  group('IsmChat.i threads surface', () {
    chatTestWidgets('setThreadsEnabled flips the flag and re-reads the chat',
        (tester, ctx) async {
      await tester.runAsync(() => seedConversation(ctx));
      ctx.api.on(
        'GET',
        '/chat/messages',
        FakeResponse.json({'messages': [messageJson()]}),
      );
      addTearDown(() => IsmChatConfig.threadsEnabled = false);

      expect(IsmChat.i.threadsEnabled, isFalse);
      await drive(tester, () => IsmChat.i.setThreadsEnabled(true));
      await settle(tester);

      expect(IsmChat.i.threadsEnabled, isTrue);
      expect(IsmChatConfig.threadsEnabled, isTrue);
      // The timeline was re-fetched with the threaded filter.
      expect(
        ctx.api
            .requestsTo('/chat/messages')
            .last
            .url
            .queryParameters['feedType'],
        'main',
      );
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets('headless reads and sends are inert while threads are off',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = false;
      await tester.runAsync(() => seedConversation(ctx));

      expect(
        await drive(
          tester,
          () => IsmChat.i.getThreadReplies(
            conversationId: kDirectConversationId,
            threadRootId: 'root-1',
          ),
        ),
        isEmpty,
      );
      expect(
        await drive(
          tester,
          () => IsmChat.i.getThreadReplyCount(
            conversationId: kDirectConversationId,
            threadRootId: 'root-1',
          ),
        ),
        isNull,
      );
      expect(
        await drive(
          tester,
          () => IsmChat.i.sendThreadReply(
            parent: threadRoot(),
            text: 'nope',
          ),
        ),
        isFalse,
      );
      expect(ctx.api.requestsForPath('/chat/message', method: 'POST'), isEmpty);
    }, setUpApi: (api) => api.registerSendDefaults());

    chatTestWidgets('headless sendThreadReply posts a thread reply when on',
        (tester, ctx) async {
      IsmChatConfig.threadsEnabled = true;
      addTearDown(() => IsmChatConfig.threadsEnabled = false);
      await tester.runAsync(() => seedConversation(ctx));
      ctx.api
        ..on('GET', '/chat/messages', FakeResponse.json({'messages': []}))
        ..on(
          'POST',
          '/chat/message',
          FakeResponse.json(const {'messageId': 'server-reply'}),
        );
      putThreadController(ctx);

      final sent = await drive(
        tester,
        () => IsmChat.i.sendThreadReply(
          parent: threadRoot(),
          text: 'from the host app',
          alsoSendToChannel: true,
        ),
      );

      expect(sent, isTrue);
      final body = ctx.api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['messageType'], 2);
      expect(body['parentMessageId'], 'root-1');
      expect(body['showInConversation'], isTrue);
      expect(body['body'], 'from the host app');
    }, setUpApi: (api) => api.registerSendDefaults());
  });
}
