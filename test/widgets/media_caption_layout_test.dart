import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  testWidgets('caption wraps at the media width', (tester) async {
    const captionKey = Key('caption');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: IsmChatMediaCaptionLayout(
            media: const SizedBox(width: 120, height: 80),
            caption: Text(
              'word ' * 6,
              key: captionKey,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
    );
    final layout = tester.getSize(find.byType(IsmChatMediaCaptionLayout));
    final caption = tester.getSize(find.byKey(captionKey));
    expect(layout.width, 120);
    expect(caption.width, lessThanOrEqualTo(120));
    expect(layout.height, 80 + caption.height);
    expect(tester.getTopLeft(find.byKey(captionKey)).dy, 80);
  });

  testWidgets('no caption sizes to media', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: IsmChatMediaCaptionLayout(
            media: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(IsmChatMediaCaptionLayout)),
      const Size(120, 80),
    );
  });
}
