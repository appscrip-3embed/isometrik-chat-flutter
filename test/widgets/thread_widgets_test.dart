import 'dart:typed_data';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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

    testWidgets('shows reaction chips when the chat page is mounted',
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
      page.reactions = [const Emoji('👍', 'Thumbs Up')];
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(
          message: threadRoot().copyWith(
            reactions: [
              MessageReactionModel(emojiKey: 'yes', userIds: [kMeId]),
            ],
          ),
          isRoot: true,
        ),
      );
      expect(find.byType(IsmChatThreadReactionRow), findsOneWidget);
      await Get.delete<IsmChatPageController>(tag: IsmChat.i.chatPageTag);
    });

  /// Media captions use [IsmChatThreadTheme.bodyStyle], not bubble colors.
    Future<void> putChatPageForThreadTile(FakeChatApi api) async {
      IsmChatConfig.threadsEnabled = true;
      Get.put(
        IsmChatPageController(
          IsmChatPageViewModel(
            IsmChatPageRepository(apiWrapper: api.wrapper()),
          ),
        ),
        tag: IsmChat.i.chatPageTag,
      );
    }

    /// Local-only attachment row: avoids bogus [AttachmentModel.bytes] in tests.
    AttachmentModel threadTileImageAttachment() =>
        attachment(IsmChatMediaType.image).copyWith(
          mediaUrl: '',
          thumbnailUrl: '',
          bytes: Uint8List(0),
        );

    testWidgets('shows media caption from metadata with thread body style',
        (tester) async {
      await putChatPageForThreadTile(api);
      const caption = 'Sunset at the lake';
      final imageReply = message(
        body: caption,
        customType: IsmChatCustomMessageType.reply,
        messageType: IsmChatMessageType.reply,
        sentByMe: true,
        attachments: [threadTileImageAttachment()],
        metaData: IsmChatMetaData(caption: caption),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(message: imageReply),
      );
      await tester.pump();
      expect(find.text(caption), findsOneWidget);
      final captionText = tester.widget<Text>(find.text(caption));
      expect(captionText.style?.color, isNot(IsmChatColors.whiteColor));
      await Get.delete<IsmChatPageController>(tag: IsmChat.i.chatPageTag);
    });

    testWidgets('shows media caption from body when metadata is empty',
        (tester) async {
      await putChatPageForThreadTile(api);
      const caption = 'Caption only in body';
      final imageReply = message(
        body: caption,
        customType: IsmChatCustomMessageType.reply,
        messageType: IsmChatMessageType.reply,
        attachments: [threadTileImageAttachment()],
        metaData: IsmChatMetaData(),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(message: imageReply),
      );
      await tester.pump();
      expect(find.text(caption), findsOneWidget);
      await Get.delete<IsmChatPageController>(tag: IsmChat.i.chatPageTag);
    });

    testWidgets('does not treat attachment placeholder body as a caption',
        (tester) async {
      await putChatPageForThreadTile(api);
      final imageReply = message(
        body: IsmChatStrings.image,
        customType: IsmChatCustomMessageType.reply,
        messageType: IsmChatMessageType.reply,
        attachments: [threadTileImageAttachment()],
        metaData: IsmChatMetaData(),
      );
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(message: imageReply),
      );
      await tester.pump();
      expect(find.byType(IsmChatImageMessage), findsOneWidget);
      expect(find.text(IsmChatStrings.image), findsNothing);
      await Get.delete<IsmChatPageController>(tag: IsmChat.i.chatPageTag);
    });

    testWidgets('short text replies do not show Show more', (tester) async {
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(
          message: threadReply(body: 'Hello thread'),
        ),
      );
      await tester.pump();
      expect(find.text('Hello thread'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('root starting with @mention keeps body text color',
        (tester) async {
      final root = threadRoot(sentByMe: false)
          .copyWith(body: '@Opponent please check this');
      await pumpChatHost(
        tester,
        child: IsmChatThreadMessageTile(message: root, isRoot: true),
      );
      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere(
            (w) => w.text.toPlainText() == '@Opponent please check this',
          );
      final rootStyle = (rich.text as TextSpan).style;
      expect(rootStyle?.color, isNotNull);
      expect(rootStyle?.color, isNot(IsmChatColors.whiteColor));
    });

    testWidgets('long text replies can expand and collapse', (tester) async {
      // 20 lines exceeds collapsedMaxLines (15). Host in a scroll view like the
      // real thread SliverList so expanding past the 800px test viewport does
      // not RenderFlex-overflow the Scaffold body.
      final longBody =
          List.generate(20, (i) => 'Thread paragraph line $i.').join('\n');
      await pumpChatHost(
        tester,
        child: SingleChildScrollView(
          child: IsmChatThreadMessageTile(
            message: threadReply(body: longBody),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Show more'), findsOneWidget);
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(find.textContaining('Thread paragraph line 19'), findsOneWidget);
      await tester.ensureVisible(find.text('Show less'));
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Show more'), findsOneWidget);
    });

    testWidgets('long media captions offer Show more', (tester) async {
      await putChatPageForThreadTile(api);
      const longCaption =
          'A very long caption that should wrap across multiple lines in the '
          'thread panel when the row is only as wide as the message column '
          'beside the avatar.';
      final imageReply = message(
        body: longCaption,
        customType: IsmChatCustomMessageType.reply,
        messageType: IsmChatMessageType.reply,
        attachments: [threadTileImageAttachment()],
        metaData: IsmChatMetaData(caption: longCaption),
      );
      await pumpChatHost(
        tester,
        child: SizedBox(
          width: 320,
          child: IsmChatThreadMessageTile(message: imageReply),
        ),
      );
      await tester.pump();
      expect(find.text('Show more'), findsOneWidget);
      await Get.delete<IsmChatPageController>(tag: IsmChat.i.chatPageTag);
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
      expect(body['messageType'], 4);
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

    testWidgets('tapping a reply does not start a nested reply',
        (tester) async {
      await pumpThreadView(tester, replies: [
        threadReplyJson(messageId: 'r1', body: 'first reply', sentAt: 2000),
      ]);

      await tester.tap(find.text('first reply'));
      await tester.pump();
      expect(find.byKey(const Key('ism-thread-reply-to-chip')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('ism-thread-composer-field')),
        'answering the thread',
      );
      await tester.tap(find.byKey(const Key('ism-thread-send-button')));
      await settle(tester);

      final body = api
          .requestsForPath('/chat/message', method: 'POST')
          .last
          .json as Map<String, dynamic>;
      expect(body['parentMessageId'], isNot('r1'));
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
