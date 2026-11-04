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
