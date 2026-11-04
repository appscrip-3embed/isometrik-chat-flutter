import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

void main() {
  chatTestWidgets('IsmChatConversations shows conversation titles from controller',
      (tester, ctx) async {
    seedConversationListForUi(ctx.conversations);
    await pumpSdkScreen(
      tester,
      child: const IsmChatConversations(),
    );
    await pumpUntil(
      tester,
      () => find.textContaining(kOpponentName).evaluate().isNotEmpty,
    );
    expect(find.text('Group UI Test'), findsOneWidget);
  }, setUpApi: (api) {
    api.registerSendDefaults();
    registerConversationListApi(api);
  });

  chatTestWidgets('IsmChatConversationList renders seeded rows', (tester, ctx) async {
    seedConversationListForUi(ctx.conversations);
    await pumpSdkScreen(
      tester,
      child: const Scaffold(
        body: IsmChatConversationList(),
      ),
    );
    await pumpUntil(
      tester,
      () => find.byType(IsmChatConversationCard).evaluate().length >= 2,
    );
    expect(find.byType(IsmChatConversationCard), findsNWidgets(2));
  }, setUpApi: (api) => api.registerSendDefaults());
}
