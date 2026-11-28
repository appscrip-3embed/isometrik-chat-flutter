import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';

UserDetails _member(String id, String userName,
        {String? firstName, String? lastName}) =>
    UserDetails(
      userProfileImageUrl: '',
      userName: userName,
      userIdentifier: '$id@test.com',
      userId: id,
      metaData: IsmChatMetaData(firstName: firstName, lastName: lastName),
    );

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  final members = [
    _member('u1', 'ajay', firstName: 'Mr.', lastName: 'Ajay'),
    _member('u2', 'bob'),
  ];

  group('composerMentionRanges', () {
    test('finds completed member mentions only', () {
      const text = 'hi @Mr. Ajay and @bob, also @Opp';
      final ranges = composerMentionRanges(text, members);
      expect(
        ranges.map((r) => text.substring(r.start, r.end)),
        ['@Mr. Ajay', '@bob'],
      );
    });

    test('ignores email addresses', () {
      expect(composerMentionRanges('mail me at x@bob.com', members), isEmpty);
    });
  });

  testWidgets('composer paints mentions with the bubble mention style',
      (tester) async {
    final controller = IsmChatMentionTextEditingController(
      membersProvider: () => members,
      text: 'hey @Mr. Ajay how are you',
    );
    late TextSpan span;
    await pumpChatHost(
      tester,
      child: Builder(
        builder: (context) {
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(fontSize: 14, color: Colors.black),
            withComposing: false,
          );
          return const SizedBox();
        },
      ),
    );

    expect(span.toPlainText(), controller.text);
    final parts = span.children!.cast<TextSpan>();
    final mention = parts.firstWhere((e) => e.text == '@Mr. Ajay');
    expect(mention.style?.color, IsmChatConfig.chatTheme.mentionColor);
    expect(mention.style?.fontWeight, FontWeight.bold);
    final plain = parts.firstWhere((e) => e.text == ' how are you');
    expect(plain.style?.color, Colors.black);
  });
}
