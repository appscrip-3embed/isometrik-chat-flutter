import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

/// A read / delivered list entry (the API's `users[]` shape).
UserDetails acked(String id, String name, int timestamp) => UserDetails(
      userProfileImageUrl: '',
      userName: name,
      userIdentifier: '$id@test.com',
      userId: id,
      timestamp: timestamp,
    );

final _readAt = DateTime(2024, 3, 9, 10, 14).millisecondsSinceEpoch;
final _deliveredAt = DateTime(2024, 3, 9, 9, 25).millisecondsSinceEpoch;

Future<void> _mountInfo(
  WidgetTester tester,
  ChatTestContext ctx, {
  required bool isGroup,
  List<UserDetails> read = const [],
  List<UserDetails> delivered = const [],
}) async {
  ctx.page
    ..conversation = isGroup ? groupConversation() : directConversation()
    ..readMessageMembers = read
    ..deliverdMessageMembers = delivered;
  await pumpSdkScreen(
    tester,
    child: IsmChatMessageInfo(
      message: message(
        body: 'info-body',
        conversationId: isGroup ? kGroupConversationId : kDirectConversationId,
        isGroup: isGroup,
      ),
      isGroup: isGroup,
    ),
  );
}

void main() {
  chatTestWidgets('group: read by lists readers, delivered to only the rest',
      (tester, ctx) async {
    await _mountInfo(
      tester,
      ctx,
      isGroup: true,
      read: [acked(kOpponentId, 'Reader One', _readAt)],
      delivered: [
        acked(kOpponentId, 'Reader One', _deliveredAt),
        acked('user-third', 'Waiting Third', _deliveredAt),
      ],
    );

    expect(find.text(IsmChatStrings.readby.toUpperCase()), findsOneWidget);
    expect(find.text(IsmChatStrings.deliveredTo.toUpperCase()), findsOneWidget);
    expect(find.text('Reader One'), findsOneWidget);
    expect(find.text('Waiting Third'), findsOneWidget);
    expect(find.text('09/03/24'), findsWidgets);
  });

  chatTestWidgets('group: delivered to is hidden once everyone has read',
      (tester, ctx) async {
    await _mountInfo(
      tester,
      ctx,
      isGroup: true,
      read: [
        acked(kOpponentId, 'Reader One', _readAt),
        acked('user-third', 'Reader Two', _readAt),
      ],
      delivered: [
        acked(kOpponentId, 'Reader One', _deliveredAt),
        acked('user-third', 'Reader Two', _deliveredAt),
      ],
    );

    expect(find.text(IsmChatStrings.readby.toUpperCase()), findsOneWidget);
    expect(find.text(IsmChatStrings.deliveredTo.toUpperCase()), findsNothing);
  });

  chatTestWidgets('group: empty read by shows the placeholder card',
      (tester, ctx) async {
    await _mountInfo(
      tester,
      ctx,
      isGroup: true,
      delivered: [acked('user-third', 'Waiting Third', _deliveredAt)],
    );

    expect(find.text(IsmChatStrings.readby.toUpperCase()), findsOneWidget);
    expect(find.text('Waiting Third'), findsOneWidget);
    // Three hollow circles stand in for the empty list.
    expect(
      find.byWidgetPredicate((w) {
        if (w is! Container || w.decoration is! BoxDecoration) return false;
        final d = w.decoration! as BoxDecoration;
        return d.shape == BoxShape.circle && d.color == null && d.border != null;
      }),
      findsNWidgets(3),
    );
  });

  chatTestWidgets('group: tapping a reader shows read and delivered times',
      (tester, ctx) async {
    await _mountInfo(
      tester,
      ctx,
      isGroup: true,
      read: [acked(kOpponentId, 'Reader One', _readAt)],
      delivered: [acked(kOpponentId, 'Reader One', _deliveredAt)],
    );

    expect(find.text(IsmChatStrings.delivered), findsNothing);
    await tester.tap(find.text('Reader One'));
    await settle(tester, rounds: 2);
    expect(find.text(IsmChatStrings.read), findsOneWidget);
    expect(find.text(IsmChatStrings.delivered), findsOneWidget);
  });

  chatTestWidgets('1:1: read and delivered rows, dash when unknown',
      (tester, ctx) async {
    await _mountInfo(
      tester,
      ctx,
      isGroup: false,
      delivered: [acked(kOpponentId, kOpponentName, _deliveredAt)],
    );

    expect(find.text(IsmChatStrings.read), findsOneWidget);
    expect(find.text(IsmChatStrings.delivered), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text(IsmChatStrings.readby.toUpperCase()), findsNothing);
  });
}
