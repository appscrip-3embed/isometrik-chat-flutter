// Widget tests for message bubbles and [MessageBubble].
// Skips camera / gallery / video player / Giphy (platform-heavy; see test/README.md).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

/// 1×1 transparent PNG so sticker [Image.memory] can decode in widget tests.
final Uint8List _kStickerPngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

AttachmentModel _stickerAttachment() => attachment(IsmChatMediaType.sticker)
    .copyWith(bytes: _kStickerPngBytes, mediaUrl: '');

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

  /// Sent/received sticker time uses [IsmChatStickerTimeCapsule] with bubble
  /// theme colors (not the bottom-right overlay used by text/media bubbles).
  chatTestWidgets(
      'sticker time capsule uses sender and receiver bubble colors',
      (tester, ctx) async {
    const senderBubble = Color(0xFFD9FDD3);
    const receiverBubble = Color(0xFFFFFFFF);

    const senderBorder = Color(0xFFB7E0B0);
    const receiverBorder = Color(0xFFE0E0E0);

    IsmChatConfig.chatBrightness = Brightness.light;
    IsmChatConfig.chatLightTheme = IsmChatThemeData(
      chatPageTheme: IsmChatPageTheme(
        selfMessageTheme: IsmChatMessageTheme(
          backgroundColor: senderBubble,
          borderColor: senderBorder,
          timeStyle: const TextStyle(color: Color(0xFF667781), fontSize: 11),
        ),
        opponentMessageTheme: IsmChatMessageTheme(
          backgroundColor: receiverBubble,
          borderColor: receiverBorder,
          timeStyle: const TextStyle(color: Color(0xFF667781), fontSize: 11),
        ),
      ),
    );
    addTearDown(() {
      IsmChatConfig.chatLightTheme = IsmChatThemeData.light();
      IsmChatConfig.chatBrightness = null;
    });

    final sentSticker = message(
      customType: IsmChatCustomMessageType.image,
      body: IsmChatStrings.sticker,
      attachments: [_stickerAttachment()],
      sentByMe: true,
      sentAt: 1700000000000,
      messageId: 'sticker-sent',
    );
    final receivedSticker = message(
      customType: IsmChatCustomMessageType.image,
      body: IsmChatStrings.sticker,
      attachments: [_stickerAttachment()],
      sentByMe: false,
      sentAt: 1700000060000,
      messageId: 'sticker-received',
    );

    seedChatPageForUi(ctx.page, messages: [sentSticker]);
    await pumpSdkScreen(
      tester,
      child: MessageBubble(message: sentSticker),
    );
    await tester.pump();

    expect(find.byType(IsmChatStickerTimeCapsule), findsOneWidget);
    // Time lives inside the capsule (under-sticker path), not a free overlay.
    expect(
      find.descendant(
        of: find.byType(IsmChatStickerTimeCapsule),
        matching: find.byType(IsmChatMessageTimeStatusRow),
      ),
      findsOneWidget,
    );

    final sentCapsule = tester.widget<Container>(
      find.descendant(
        of: find.byType(IsmChatStickerTimeCapsule),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius != null,
        ),
      ),
    );
    final sentDecoration = sentCapsule.decoration! as BoxDecoration;
    expect(sentDecoration.color, senderBubble);
    expect(sentDecoration.border?.top.color, senderBorder);
    expect(sentDecoration.borderRadius, isNotNull);
    // Sent: sticker + capsule share a shrink-wrapped end-aligned column.
    final sentColumn = tester.widget<Column>(
      find
          .descendant(
            of: find.byType(MessageBubble),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Column &&
                  w.crossAxisAlignment == CrossAxisAlignment.end &&
                  w.mainAxisSize == MainAxisSize.min,
            ),
          )
          .first,
    );
    expect(sentColumn.crossAxisAlignment, CrossAxisAlignment.end);
    final sentStickerRight = tester.getTopRight(find.byType(IsmChatImageMessage));
    final sentCapsuleRight =
        tester.getTopRight(find.byType(IsmChatStickerTimeCapsule));
    expect(sentCapsuleRight.dx, closeTo(sentStickerRight.dx, 1));
    expect(
      tester.getTopLeft(find.byType(IsmChatStickerTimeCapsule)).dy,
      greaterThan(tester.getBottomLeft(find.byType(IsmChatImageMessage)).dy),
    );

    seedChatPageForUi(ctx.page, messages: [receivedSticker]);
    await pumpSdkScreen(
      tester,
      child: MessageBubble(message: receivedSticker),
    );
    await tester.pump();

    expect(find.byType(IsmChatStickerTimeCapsule), findsOneWidget);
    final receivedCapsule = tester.widget<Container>(
      find.descendant(
        of: find.byType(IsmChatStickerTimeCapsule),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius != null,
        ),
      ),
    );
    final receivedDecoration = receivedCapsule.decoration! as BoxDecoration;
    expect(receivedDecoration.color, receiverBubble);
    expect(receivedDecoration.border?.top.color, receiverBorder);
    final receivedColumn = tester.widget<Column>(
      find
          .descendant(
            of: find.byType(MessageBubble),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Column &&
                  w.crossAxisAlignment == CrossAxisAlignment.start &&
                  w.mainAxisSize == MainAxisSize.min,
            ),
          )
          .first,
    );
    expect(receivedColumn.crossAxisAlignment, CrossAxisAlignment.start);
    final receivedStickerLeft =
        tester.getTopLeft(find.byType(IsmChatImageMessage));
    final receivedCapsuleLeft =
        tester.getTopLeft(find.byType(IsmChatStickerTimeCapsule));
    expect(receivedCapsuleLeft.dx, closeTo(receivedStickerLeft.dx, 1));
  }, setUpApi: (api) => api.registerSendDefaults());
}
