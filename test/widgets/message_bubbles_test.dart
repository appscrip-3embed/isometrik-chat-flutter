// Widget tests for message bubbles and [MessageBubble].
// Skips camera / gallery / video player / Giphy (platform-heavy; see test/README.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

void main() {
  chatTestWidgets('MessageBubble renders text body', (tester, ctx) async {
    seedChatPageForUi(
      ctx.page,
      messages: [message(body: 'bubble-via-wrapper')],
    );
    await pumpSdkScreen(
      tester,
      child: MessageBubble(message: ctx.page.messages.first),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('bubble-via-wrapper'),
      ),
      findsWidgets,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('attachment message types construct MessageBubble widgets',
      (tester, ctx) async {
    final msgs = attachmentMessages();
    seedChatPageForUi(ctx.page, messages: msgs.values.toList());
    for (final m in msgs.values) {
      expect(MessageBubble(message: m), isA<Widget>());
    }
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('reply quote strip matches reply body width', (tester, ctx) async {
    final replyMsg = message(
      customType: IsmChatCustomMessageType.reply,
      body: 'Much longer reply text here',
      parentMessageId: 'parent-1',
      metaData: IsmChatMetaData(
        replyMessage: IsmChatReplyMessageModel(
          parentMessageBody: 'hey',
          forMessageType: IsmChatCustomMessageType.text,
        ),
      ),
    );
    seedChatPageForUi(ctx.page, messages: [replyMsg]);
    await pumpSdkScreen(
      tester,
      child: MessageBubble(message: replyMsg),
    );

    final quoteClip = find.descendant(
      of: find.byType(IsmChatReplyMessage),
      matching: find.byType(ClipRRect),
    );
    final textBody = find.descendant(
      of: find.byType(IsmChatReplyMessage),
      matching: find.byType(IsmChatTextMessage),
    );
    expect(quoteClip, findsOneWidget);
    expect(textBody, findsOneWidget);

    final quoteWidth = tester.getSize(quoteClip).width;
    final bodyWidth = tester.getSize(textBody).width;
    expect(quoteWidth, closeTo(bodyWidth, 1));
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('short reply bubble stays content-sized', (tester, ctx) async {
    const surface = Size(400, 800);

    final replyMsg = message(
      customType: IsmChatCustomMessageType.reply,
      body: 'Hey',
      parentMessageId: 'parent-1',
      metaData: IsmChatMetaData(
        replyMessage: IsmChatReplyMessageModel(
          parentMessageBody: 'Hey',
          forMessageType: IsmChatCustomMessageType.text,
        ),
      ),
    );
    seedChatPageForUi(ctx.page, messages: [replyMsg]);
    await pumpSdkScreen(
      tester,
      size: surface,
      child: MessageBubble(message: replyMsg),
    );

    final replyWidth = tester.getSize(find.byType(IsmChatReplyMessage)).width;
    // Content-sized (quote + body), not stretched toward bubble maxWidth.
    expect(replyWidth, lessThan(surface.width * 0.35));
  }, setUpApi: (api) => api.registerSendDefaults());

  Finder messageBubbleShell() => find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius != null,
        ),
      );

  chatTestWidgets(
      'short reply ignores theme minWidth unlike plain text',
      (tester, ctx) async {
    const surface = Size(400, 800);
    // Use a large min so short quote chrome stays below the theme floor.
    final themeMinWidth = surface.width * 0.5;

    IsmChatConfig.chatLightTheme = IsmChatThemeData(
      chatPageTheme: IsmChatPageTheme(
        messageConstraints: IsmChatMessageConstraints(
          messageConstraints: BoxConstraints(
            maxWidth: surface.width * 0.8,
            minWidth: themeMinWidth,
          ),
        ),
      ),
    );

    final replyMsg = message(
      customType: IsmChatCustomMessageType.reply,
      body: 'I',
      parentMessageId: 'parent-1',
      metaData: IsmChatMetaData(
        replyMessage: IsmChatReplyMessageModel(
          parentMessageBody: 'J',
          forMessageType: IsmChatCustomMessageType.text,
        ),
      ),
    );
    final textMsg = message(body: 'I');

    seedChatPageForUi(ctx.page, messages: [replyMsg]);
    await pumpSdkScreen(
      tester,
      size: surface,
      child: MessageBubble(message: replyMsg),
    );

    final replyContentWidth =
        tester.getSize(find.byType(IsmChatReplyMessage)).width;
    final replyShellWidth = tester.getSize(messageBubbleShell()).width;
    // Shell adds bubble padding (~12px) around the reply column.
    expect(replyShellWidth, lessThan(themeMinWidth - 1));
    expect(replyShellWidth - replyContentWidth, lessThan(20));

    seedChatPageForUi(ctx.page, messages: [textMsg]);
    await pumpSdkScreen(
      tester,
      size: surface,
      child: MessageBubble(message: textMsg),
    );

    final textShellWidth = tester.getSize(messageBubbleShell()).width;
    expect(textShellWidth, greaterThanOrEqualTo(themeMinWidth - 1));
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('long quote with short reply keeps quote strip full width',
      (tester, ctx) async {
    final replyMsg = message(
      customType: IsmChatCustomMessageType.reply,
      body: 'Ok',
      parentMessageId: 'parent-1',
      metaData: IsmChatMetaData(
        replyMessage: IsmChatReplyMessageModel(
          parentMessageBody: 'Long message bzbbz long message bzbbz',
          forMessageType: IsmChatCustomMessageType.text,
        ),
      ),
    );
    seedChatPageForUi(ctx.page, messages: [replyMsg]);
    await pumpSdkScreen(
      tester,
      child: MessageBubble(message: replyMsg),
    );

    final replyBubble = find.byType(IsmChatReplyMessage);
    final quoteClip = find.descendant(
      of: replyBubble,
      matching: find.byType(ClipRRect),
    );
    final bubbleWidth = tester.getSize(replyBubble).width;
    final quoteWidth = tester.getSize(quoteClip).width;
    expect(quoteWidth, closeTo(bubbleWidth, 1));
    expect(bubbleWidth, greaterThan(120));
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets(
      'short parent quote still spans the reply bubble width',
      (tester, ctx) async {
    final replyMsg = message(
      customType: IsmChatCustomMessageType.reply,
      body: 'Hey',
      parentMessageId: 'parent-1',
      metaData: IsmChatMetaData(
        replyMessage: IsmChatReplyMessageModel(
          parentMessageBody: 'Hey',
          forMessageType: IsmChatCustomMessageType.text,
        ),
      ),
    );
    seedChatPageForUi(ctx.page, messages: [replyMsg]);
    await pumpSdkScreen(
      tester,
      child: MessageBubble(message: replyMsg),
    );

    final replyBubble = find.byType(IsmChatReplyMessage);
    final quoteClip = find.descendant(
      of: replyBubble,
      matching: find.byType(ClipRRect),
    );
    expect(quoteClip, findsOneWidget);

    final bubbleWidth = tester.getSize(replyBubble).width;
    final quoteWidth = tester.getSize(quoteClip).width;
    expect(quoteWidth, closeTo(bubbleWidth, 1));
  }, setUpApi: (api) => api.registerSendDefaults());

  testWidgets('IsmChatDateMessage shows the date label', (tester) async {
    configureChatSdk();
    addTearDown(resetChatSdk);
    await pumpChatHost(
      tester,
      child: IsmChatDateMessage(message(body: 'March 1, 2026')),
    );
    expect(find.text('March 1, 2026'), findsOneWidget);
  });
}
