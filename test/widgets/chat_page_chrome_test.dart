import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  testWidgets('IsmChatDeletedMessage shows deleted copy for sender',
      (tester) async {
    await pumpChatHost(
      tester,
      child: IsmChatDeletedMessage(message(sentByMe: true)),
    );
    expect(find.text(IsmChatStrings.deletedMessage), findsOneWidget);
  });

  chatTestWidgets('IsmChatPageHeader shows 1-to-1 chat name', (tester, ctx) async {
    seedChatPageForUi(ctx.page);
    await pumpSdkScreen(
      tester,
      child: Scaffold(
        appBar: IsmChatPageHeader(),
      ),
    );
    expect(find.textContaining(kOpponentName), findsWidgets);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('IsmChatListHeader renders custom title', (tester, ctx) async {
    seedConversationListForUi(ctx.conversations);
    await pumpSdkScreen(
      tester,
      size: const Size(900, 800),
      child: Scaffold(
        appBar: IsmChatListHeader(
          title: 'Messages UI',
          onSearchTap: (_, __, ___) {},
        ),
      ),
    );
    expect(find.text('Messages UI'), findsOneWidget);
  }, setUpApi: (api) => api.registerSendDefaults());
}
