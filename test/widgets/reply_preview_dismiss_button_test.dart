import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/views/chat_page/widget/messages/reply_message.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  testWidgets('ReplyPreviewDismissButton shows white circular close', (tester) async {
    var tapped = false;
    await pumpChatHost(
      tester,
      child: ReplyPreviewDismissButton(onTap: () => tapped = true),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(ReplyPreviewDismissButton),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, IsmChatColors.whiteColor);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byType(ReplyPreviewDismissButton));
    expect(tapped, isTrue);
  });
}