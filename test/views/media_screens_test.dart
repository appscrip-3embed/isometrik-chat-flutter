import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

/// Local-only attachment so tiles render the SDK placeholder (no network).
IsmChatMessageModel _media(IsmChatCustomMessageType type, int sentAt) =>
    message(
      customType: type,
      sentAt: sentAt,
      attachments: [
        AttachmentModel(
          attachmentType: type == IsmChatCustomMessageType.video
              ? IsmChatMediaType.video
              : IsmChatMediaType.image,
          mediaUrl: '',
          thumbnailUrl: '',
          name: 'shot.png',
          size: 2048,
        ),
      ],
    );

IsmChatMessageModel _doc(int sentAt) => message(
      customType: IsmChatCustomMessageType.file,
      sentAt: sentAt,
      attachments: [
        AttachmentModel(
          attachmentType: IsmChatMediaType.file,
          mediaUrl: '',
          name: 'Quarterly report.pdf',
          extension: 'pdf',
          size: 1024 * 1024,
        ),
      ],
    );

final _day = DateTime(2024, 3, 9, 10).millisecondsSinceEpoch;

/// 1×1 transparent PNG.
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// Image message backed by a real file so PhotoView can decode it.
Future<IsmChatMessageModel> _viewerImage(WidgetTester tester) async {
  final path = await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('ism-viewer');
    final file = File('${dir.path}/pixel.png');
    await file.writeAsBytes(_png);
    return file.path;
  });
  return message(
    customType: IsmChatCustomMessageType.image,
    sentAt: _day,
    attachments: [
      AttachmentModel(
        attachmentType: IsmChatMediaType.image,
        mediaUrl: path,
        name: 'pixel.png',
      ),
    ],
  );
}

void main() {
  chatTestWidgets('media tabs show friendly empty states', (tester, ctx) async {
    await pumpSdkScreen(
      tester,
      child: const IsmMedia(
        mediaList: [],
        mediaListLinks: [],
        mediaListDocs: [],
      ),
    );

    expect(find.text(IsmChatStrings.noMedia), findsOneWidget);
    expect(find.text(IsmChatStrings.mediaEmptyHint), findsOneWidget);

    await tester.tap(find.text(IsmChatStrings.links));
    await settle(tester);
    expect(find.text(IsmChatStrings.noLinks), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  chatTestWidgets('media grid renders sections and tiles without overflow',
      (tester, ctx) async {
    await pumpSdkScreen(
      tester,
      child: IsmMedia(
        mediaList: [
          _media(IsmChatCustomMessageType.image, _day),
          _media(IsmChatCustomMessageType.video, _day + 1000),
          _media(IsmChatCustomMessageType.image, _day + 2000),
        ],
        mediaListLinks: const [],
        mediaListDocs: const [],
      ),
    );

    expect(find.byType(ConversationMediaWidget), findsNWidgets(3));
    // Video tile carries a play badge.
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byType(IsmChatMediaSectionHeader), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  chatTestWidgets('docs tab lists documents with type and size',
      (tester, ctx) async {
    await pumpSdkScreen(
      tester,
      child: IsmMedia(
        mediaList: const [],
        mediaListLinks: const [],
        mediaListDocs: [_doc(_day)],
      ),
    );
    expect(
      IsmChatProperties.chatPageProperties.attachments
          .contains(IsmChatAttachmentType.document),
      isTrue,
      reason: 'docs tab is shown when documents are allowed (SDK default)',
    );

    await tester.tap(find.text(IsmChatStrings.docs));
    await settle(tester);
    expect(find.text('Quarterly report.pdf'), findsOneWidget);
    expect(find.textContaining('PDF · '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  chatTestWidgets('viewer uses chat screen background by default',
      (tester, ctx) async {
    final image = await _viewerImage(tester);
    await pumpSdkScreen(
      tester,
      child: IsmMediaPreview(
        messageData: [image],
        mediaIndex: 0,
        mediaUserName: 'Opponent',
        initiated: false,
        mediaTime: _day,
      ),
    );

    final element = tester.element(find.byType(Scaffold).first);
    final expectedBg = IsmChatMediaTheme.chatScreenBackground(
      IsmChatDesignTokens.of(element),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, expectedBg);
    final share = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
    expect(share.color, IsmChatDesignTokens.foregroundFor(expectedBg));
  });

  chatTestWidgets('viewer keeps a host media theme verbatim',
      (tester, ctx) async {
    const hostBackground = Color(0xFFF7F3EE);
    const hostIcon = Color(0xFF332211);
    final hostTheme = IsmChatMediaTheme.light().copyWith(
      previewBackgroundColor: hostBackground,
      appBarIconColor: hostIcon,
    );
    final image = await _viewerImage(tester);
    IsmChatConfig.chatBrightness = Brightness.light;
    IsmChatConfig.chatLightTheme = IsmChatThemeData(
      chatPageTheme: IsmChatPageTheme(mediaTheme: hostTheme),
    );
    try {
      await pumpSdkScreen(
        tester,
        child: IsmMediaPreview(
          messageData: [image],
          mediaIndex: 0,
          mediaUserName: 'Opponent',
          initiated: false,
          mediaTime: _day,
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, hostBackground);
      final share = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
      expect(share.color, hostIcon);
    } finally {
      IsmChatConfig.chatLightTheme = IsmChatThemeData.light();
      IsmChatConfig.chatBrightness = null;
    }
  });
}
