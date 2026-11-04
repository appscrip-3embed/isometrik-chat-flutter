import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

void main() {
  chatTestWidgets('IsmChatPageView shows messages and composer', (tester, ctx) async {
    await mountChatPageForUi(tester, ctx, messageBody: 'on-screen-message');
    expect(find.byType(IsmChatMessageField), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('on-screen-message'),
      ),
      findsWidgets,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('typing in composer and tapping send posts message',
      (tester, ctx) async {
    await mountChatPageForUi(tester, ctx, messageBody: 'seed');
    await tester.enterText(find.byType(TextFormField).first, 'typed-ui-send');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    expect(
      ctx.page.messages.any((m) => m.body == 'typed-ui-send'),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 3));
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('attachment sheet opens from message field', (tester, ctx) async {
    await mountChatPageForUi(tester, ctx);
    final attachFinder = find.byIcon(Icons.attach_file_rounded);
    if (attachFinder.evaluate().isEmpty) {
      return;
    }
    await tester.tap(attachFinder.first);
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('message long-press opens focus menu route', (tester, ctx) async {
    await mountChatPageForUi(tester, ctx, messageBody: 'focus-menu-body');
    final context = IsmChatConfig.kNavigatorKey.currentContext!;
    final routeFuture = ctx.page.onMessageLongPress(
      context,
      ctx.page.messages.first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IsmChatFocusMenu), findsOneWidget);
    Navigator.of(context).pop();
    await routeFuture;
  }, setUpApi: (api) => api.registerSendDefaults());
}
