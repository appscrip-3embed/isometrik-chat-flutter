import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// Widget-level cover for the thread surfaces: the "N replies" footer, the
/// thread panel and the on/off switch. The footer assertions are the ones that
/// guarantee nothing changes in the chat bubble while threads are off.
void main() {
  late FakeChatApi api;

  setUp(() {
    configureChatSdk();
    api = FakeChatApi();
    IsmChatConfig.threadsEnabled = false;
    IsmChatProperties.chatPageProperties = IsmChatPageProperties();
    IsmChatProperties.threadProperties = IsmChatThreadProperties.defaults;
  });

  tearDown(() async {
    IsmChatConfig.threadsEnabled = false;
    IsmChatProperties.chatPageProperties = IsmChatPageProperties();
    IsmChatProperties.threadProperties = IsmChatThreadProperties.defaults;
    await resetChatSdk();
  });

  group('IsmChatThreadChannelContext', () {
    testWidgets('shows replied-to line with parent media type',
        (tester) async {
      IsmChatConfig.threadsEnabled = true;
      final api = FakeChatApi();
      final page = Get.put(
        IsmChatPageController(
          IsmChatPageViewModel(
            IsmChatPageRepository(apiWrapper: api.wrapper()),
          ),
        ),
        tag: IsmChat.i.chatPageTag,
      );
      final img = message(
        messageId: 'img-1',
        body: '',
        customType: IsmChatCustomMessageType.image,
        attachments: [
          attachment(IsmChatMediaType.image).copyWith(name: 'image (1).png'),
        ],
      );
      final shared = threadReply(
        alsoSentToChannel: true,
        parentMessageId: 'img-1',
        body: 'amaing',
      );
      page.messages = [img, shared];
      await pumpChatHost(
        tester,
        child: IsmChatThreadChannelContext(message: shared),
      );
      expect(
        find.byKey(const Key('ism-thread-channel-context')),
        findsOneWidget,
      );
      expect(find.textContaining(IsmChatStrings.image), findsOneWidget);
      expect(find.textContaining('replied to a thread'), findsOneWidget);
      await Get.delete<IsmChatPageController>(tag: IsmChat.i.chatPageTag);
    });
  });

  group('IsmChatThreadFooter', () {
    testWidgets('renders "3 replies" for a root with replies', (tester) async {
      IsmChatConfig.threadsEnabled = true;
      await pumpChatHost(
        tester,
        child: IsmChatThreadFooter(message: threadRoot(replyCount: 3)),
      );
      expect(find.text('3 replies'), findsOneWidget);
      expect(find.byKey(const Key('ism-thread-footer')), findsOneWidget);
    });

    testWidgets('uses the singular noun for one reply', (tester) async {
      IsmChatConfig.threadsEnabled = true;
      await pumpChatHost(
        tester,
        child: IsmChatThreadFooter(message: threadRoot(replyCount: 1)),
      );
      expect(find.text('1 reply'), findsOneWidget);
    });

    testWidgets('renders nothing for a root without replies', (tester) async {
      IsmChatConfig.threadsEnabled = true;
      await pumpChatHost(
        tester,
        child: IsmChatThreadFooter(message: threadRoot(replyCount: 0)),
      );
      expect(find.byKey(const Key('ism-thread-footer')), findsNothing);
    });

    testWidgets('calls the host tap handler instead of opening the panel',
        (tester) async {
      IsmChatConfig.threadsEnabled = true;
      var taps = 0;
      await pumpChatHost(
        tester,
        child: IsmChatThreadFooter(
          message: threadRoot(replyCount: 2),
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.byKey(const Key('ism-thread-footer')));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a host builder can replace the row', (tester) async {
      IsmChatConfig.threadsEnabled = true;
      IsmChatProperties.threadProperties = IsmChatThreadProperties(
        replyFooterBuilder: (_, __, count) => Text('custom $count'),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadFooter(message: threadRoot(replyCount: 5)),
      );
      expect(find.text('custom 5'), findsOneWidget);
      expect(find.byKey(const Key('ism-thread-footer')), findsNothing);
    });
  });

  group('IsmChatThreadMessageTile', () {
    testWidgets('shows sender, body and the "also sent to channel" hint',
        (tester) async {
      await pumpChatHost(
        tester,
        child: Column(
          children: [
            IsmChatThreadMessageTile(
              message: threadRoot(sentByMe: false),
              isRoot: true,
            ),
            IsmChatThreadMessageTile(
              message: threadReply(body: 'thread only'),
            ),
            IsmChatThreadMessageTile(
              message: threadReply(
                messageId: 'shared',
                body: 'shared with channel',
                alsoSentToChannel: true,
              ),
            ),
          ],
        ),
      );
      expect(find.text('root message'), findsOneWidget);
      expect(find.text('thread only'), findsOneWidget);
      expect(find.text('shared with channel'), findsOneWidget);
      expect(find.text(kOpponentName), findsWidgets);
      // The hint only shows on the "also sent to channel" reply.
      expect(
        find.text(IsmChatStrings.threadAlsoSendToChannel),
        findsOneWidget,
      );
    });

    testWidgets('labels non-text replies by kind', (tester) async {
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(
          message: message(
            body: '',
            customType: IsmChatCustomMessageType.image,
            messageType: IsmChatMessageType.reply,
          ),
        ),
      );
      expect(find.text(IsmChatStrings.image), findsOneWidget);
    });

    test('contact bubbles need the channel-style tap wrapper', () {
      expect(
        IsmChatThreadMessageTile.threadPanelBubbleNeedsMessageCardTap(
          IsmChatCustomMessageType.contact,
        ),
        isTrue,
      );
      expect(
        IsmChatThreadMessageTile.threadPanelBubbleNeedsMessageCardTap(
          IsmChatCustomMessageType.image,
        ),
        isFalse,
      );
    });

    chatTestWidgets('tapping a thread contact row opens contact info',
        (tester, ctx) async {
      final contactMsg = message(
        body: IsmChatStrings.contact,
        customType: IsmChatCustomMessageType.contact,
        messageType: IsmChatMessageType.reply,
        metaData: IsmChatMetaData(
          contacts: [
            IsmChatContactMetaDatModel(
              contactName: 'Alice',
              contactIdentifier: '+15550001',
            ),
          ],
        ),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(message: contactMsg),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IsmChatContactMessage), findsOneWidget);
      await tester.tap(find.textContaining('View'));
      await tester.pumpAndSettle();
      expect(find.byType(IsmChatContactsInfoView), findsOneWidget);
    }, setUpApi: (api) => api.registerSendDefaults());

    testWidgets('a host builder can replace a reply row', (tester) async {
      IsmChatProperties.threadProperties = IsmChatThreadProperties(
        replyTileBuilder: (_, reply) => Text('host:${reply.messageId}'),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(message: threadReply(messageId: 'r9')),
      );
      expect(find.text('host:r9'), findsOneWidget);
    });
  });

  group('IsmChatThreadsToggleTile', () {
    testWidgets('reflects and flips IsmChatConfig.threadsEnabled',
        (tester) async {
      final observed = <bool>[];
      await pumpChatHost(
        tester,
        child: IsmChatThreadsToggleTile(onChanged: observed.add),
      );

      final toggle = find.byKey(const Key('ism-threads-toggle'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(find.text(IsmChatStrings.threadsLabel), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(IsmChatConfig.threadsEnabled, isTrue);
      expect(observed, [true]);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(IsmChatConfig.threadsEnabled, isFalse);
      expect(observed, [true, false]);
    });
  });

  group('IsmChatThreadView', () {
    Future<void> pumpThreadView(
      WidgetTester tester, {
      required List<Map<String, dynamic>> replies,
      int rootReplyCount = 2,
    }) async {
      IsmChatConfig.threadsEnabled = true;
      api
        ..on('GET', '/chat/messages', FakeResponse.json({'messages': replies}))
        ..on(
          'POST',
          '/chat/message',
          FakeResponse.json(const {'messageId': 'server-reply'}),
        );
      Get.put(
        IsmChatThreadController(
          IsmChatThreadViewModel(
            IsmChatThreadRepository(apiWrapper: api.wrapper()),
          ),
        ),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadView(
          rootMessage: threadRoot(replyCount: rootReplyCount),
          conversation: directConversation(),
        ),
      );
      await settle(tester);
    }

    testWidgets('shows the root, the reply count and the replies',
        (tester) async {
      await pumpThreadView(tester, replies: [
        threadReplyJson(messageId: 'r1', body: 'first reply', sentAt: 2000),
        threadReplyJson(messageId: 'r2', body: 'second reply', sentAt: 3000),
      ]);

      expect(find.text('root message'), findsOneWidget);
      expect(find.text('first reply'), findsOneWidget);
      expect(find.text('second reply'), findsOneWidget);
      expect(find.byKey(const Key('ism-thread-reply-count')), findsOneWidget);
      expect(find.text(IsmChatStrings.threadTitle), findsOneWidget);
    });

    testWidgets('shows the empty state for a thread with no replies',
        (tester) async {
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);
      expect(find.byKey(const Key('ism-thread-empty')), findsOneWidget);
      expect(find.text(IsmChatStrings.threadNoReplies), findsOneWidget);
    });

    testWidgets('HTTP 404 on load shows empty placeholder, not retry',
        (tester) async {
      IsmChatConfig.threadsEnabled = true;
      api.on(
        'GET',
        '/chat/messages',
        const FakeResponse('{"error":"Not found"}', status: 404),
      );
      Get.put(
        IsmChatThreadController(
          IsmChatThreadViewModel(
            IsmChatThreadRepository(apiWrapper: api.wrapper()),
          ),
        ),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadView(
          rootMessage: threadRoot(replyCount: 0),
          conversation: directConversation(),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('ism-thread-empty')), findsOneWidget);
      expect(find.byKey(const Key('ism-thread-retry')), findsNothing);
    });

    testWidgets('offers a retry when the thread fails to load',
        (tester) async {
      IsmChatConfig.threadsEnabled = true;
      api.on('GET', '/chat/messages', const FakeResponse('{}', status: 500));
      Get.put(
        IsmChatThreadController(
          IsmChatThreadViewModel(
            IsmChatThreadRepository(apiWrapper: api.wrapper()),
          ),
        ),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadView(
          rootMessage: threadRoot(),
          conversation: directConversation(),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('ism-thread-retry')), findsOneWidget);
      expect(find.text(IsmChatStrings.threadLoadFailed), findsOneWidget);
    });

    testWidgets('composer sends a thread-only reply', (tester) async {
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);

      await tester.enterText(
        find.byKey(const Key('ism-thread-composer-field')),
        'typed in the panel',
      );
      await tester.tap(find.byKey(const Key('ism-thread-send-button')));
      await settle(tester);

      final body = api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['body'], 'typed in the panel');
      expect(body['messageType'], 2);
      expect(body['parentMessageId'], 'root-1');
      expect(body['showInConversation'], isFalse);
      expect(find.text('typed in the panel'), findsOneWidget);
    });

    testWidgets('the "also send to channel" checkbox flips showInConversation',
        (tester) async {
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);

      await tester.tap(find.byKey(const Key('ism-thread-also-send-toggle')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('ism-thread-composer-field')),
        'everyone sees this',
      );
      await tester.tap(find.byKey(const Key('ism-thread-send-button')));
      await settle(tester);

      final body = api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['showInConversation'], isTrue);
    });

    testWidgets('tapping a reply targets it for a nested reply',
        (tester) async {
      await pumpThreadView(tester, replies: [
        threadReplyJson(messageId: 'r1', body: 'first reply', sentAt: 2000),
      ]);

      await tester.tap(find.text('first reply'));
      await tester.pump();
      expect(
        find.byKey(const Key('ism-thread-reply-to-chip')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('ism-thread-composer-field')),
        'answering r1',
      );
      await tester.tap(find.byKey(const Key('ism-thread-send-button')));
      await settle(tester);

      final body = api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['parentMessageId'], 'r1');
      expect(find.byKey(const Key('ism-thread-reply-to-chip')), findsNothing);
    });

    testWidgets('the composer offers the channel attachment sheet',
        (tester) async {
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);
      expect(
        find.byKey(const Key('ism-thread-attach-button')),
        findsOneWidget,
      );
    });

    testWidgets('shows mic on the composer when audio is enabled', (tester) async {
      IsmChatProperties.chatPageProperties = IsmChatPageProperties(
        features: [IsmChatFeature.audioMessage],
      );
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('emoji button toggles the thread emoji board', (tester) async {
      IsmChatProperties.chatPageProperties = IsmChatPageProperties(
        features: [IsmChatFeature.emojiIcon],
      );
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);
      final threadController = Get.find<IsmChatThreadController>();
      expect(find.byKey(const Key('ism-thread-emoji-button')), findsOneWidget);
      expect(threadController.showEmojiBoard, isFalse);
      await tester.tap(find.byKey(const Key('ism-thread-emoji-button')));
      await tester.pump();
      expect(threadController.showEmojiBoard, isTrue);
    });

    testWidgets('attachments can be switched off for threads', (tester) async {
      IsmChatProperties.threadProperties = const IsmChatThreadProperties(
        showAttachments: false,
      );
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);
      expect(find.byKey(const Key('ism-thread-attach-button')), findsNothing);
      // Text replies still work.
      expect(
        find.byKey(const Key('ism-thread-composer-field')),
        findsOneWidget,
      );
    });

    testWidgets('hiding the checkbox keeps every reply thread-only',
        (tester) async {
      IsmChatProperties.threadProperties = const IsmChatThreadProperties(
        showAlsoSendToChannel: false,
      );
      await pumpThreadView(tester, replies: [], rootReplyCount: 0);
      expect(
        find.byKey(const Key('ism-thread-also-send-toggle')),
        findsNothing,
      );
    });
  });
}
