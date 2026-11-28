import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

/// [pumpSdkScreen] uses a 400-wide screen, so the mobile frame is
/// 400 × 3/4 − 30 = 270 wide and at most 270 × 4/3 = 360 tall (3:4).
const double _frameWidth =
    400 * .75 - IsmChatMediaGridLayout.mobileMediaWidthReduction;
const double _maxHeight = _frameWidth * 4 / 3;

IsmChatMessageModel _video({
  int? mediaWidth,
  int? mediaHeight,
  String thumbnailUrl = '',
}) =>
    IsmChatMessageModel(
      body: '',
      sentAt: 1,
      sentByMe: true,
      customType: IsmChatCustomMessageType.video,
      attachments: [
        AttachmentModel(
          attachmentType: IsmChatMediaType.video,
          thumbnailUrl: thumbnailUrl,
          mediaWidth: mediaWidth,
          mediaHeight: mediaHeight,
        ),
      ],
    );

Future<Size> _frameOf(WidgetTester tester, IsmChatMessageModel message) async {
  await pumpSdkScreen(
    tester,
    child: Scaffold(body: Center(child: IsmChatVideoMessage(message))),
  );
  return _currentFrame(tester);
}

Size _currentFrame(WidgetTester tester) => tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.play_circle),
            matching: find.byType(Stack),
          )
          .first,
    );

void main() {
  chatTestWidgets('portrait video uses the media width and is capped at 3:4',
      (tester, ctx) async {
    final size = await _frameOf(tester, _video(mediaWidth: 720, mediaHeight: 1280));
    expect(size.width, _frameWidth);
    expect(size.height, closeTo(_maxHeight, 0.01));
  });

  chatTestWidgets('landscape video keeps its 16:9 shape', (tester, ctx) async {
    final size = await _frameOf(tester, _video(mediaWidth: 1280, mediaHeight: 720));
    expect(size.width, _frameWidth);
    expect(size.height, closeTo(_frameWidth * 9 / 16, 0.01));
  });

  chatTestWidgets('no metadata: shape comes from the local thumbnail',
      (tester, ctx) async {
    // 4:3 → 225 tall: differs from the square fallback and is under the cap.
    final thumb = Uint8List.fromList(
      img.encodePng(img.Image(width: 400, height: 300)),
    );
    // Square until the thumbnail is read, then the thumbnail's shape.
    await _frameOf(tester, _video(thumbnailUrl: thumb.toString()));
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200),
        ));
    await tester.pump();
    final after = _currentFrame(tester);
    expect(after.width, _frameWidth);
    expect(after.height, closeTo(_frameWidth * 3 / 4, 0.01));
  });
}
