import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

void main() {
  chatTestWidgets('IsmChatConversationCard shows opponent name and handles tap',
      (tester, ctx) async {
    var tapped = false;
    final conv = directConversation();
    await pumpSdkScreen(
      tester,
      child: IsmChatConversationCard(
        conv,
        profileImageBuilder: testConversationProfileImage,
        onTap: () => tapped = true,
      ),
    );
    expect(find.textContaining(kOpponentName), findsWidgets);
    await tester.tap(find.byType(IsmChatConversationCard));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('group card shows conversation title', (tester, ctx) async {
    await pumpSdkScreen(
      tester,
      child: IsmChatConversationCard(
        groupConversation(title: 'My Group'),
        profileImageBuilder: testConversationProfileImage,
      ),
    );
    expect(find.text('My Group'), findsOneWidget);
  }, setUpApi: (api) => api.registerSendDefaults());
}
