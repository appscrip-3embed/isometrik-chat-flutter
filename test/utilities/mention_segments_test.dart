import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Regression tests for @mention span parsing ([ismChatMentionSegmentsForBody]).
///
/// Reuse [UserDetails] + [wordCount]/[order] the same way the send path and API do.
UserDetails _mentionedUser({
  required String id,
  required String userName,
  String? firstName,
  String? lastName,
  required int wordCount,
  required int order,
}) =>
    UserDetails(
      userProfileImageUrl: '',
      userName: userName,
      userIdentifier: '$id@test.com',
      userId: id,
      wordCount: wordCount,
      order: order,
      metaData: IsmChatMetaData(firstName: firstName, lastName: lastName),
    );

void main() {
  group('ismChatMentionSegmentsForBody', () {
    test('covers full three-word display label when wordCount is 3', () {
      final mentioned = _mentionedUser(
        id: 'u1',
        userName: 'adv_handle',
        firstName: 'Adv.',
        lastName: 'rounit signha',
        wordCount: 3,
        order: 0,
      );
      const body = '@Adv. rounit signha hello';
      final segments = ismChatMentionSegmentsForBody(body, [mentioned]);
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@Adv. rounit signha']);
    });

    test('highlights two multi-word mentions in one message', () {
      final first = _mentionedUser(
        id: 'u1',
        userName: 'user_one',
        firstName: 'User',
        lastName: 'One',
        wordCount: 2,
        order: 0,
      );
      final second = _mentionedUser(
        id: 'u2',
        userName: 'user_two',
        firstName: 'User',
        lastName: 'Two',
        wordCount: 2,
        order: 1,
      );
      const body = '@User One and @User Two';
      final segments = ismChatMentionSegmentsForBody(body, [first, second]);
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@User One', '@User Two']);
    });

    test('matches inserted display label even when userName differs', () {
      final mentioned = _mentionedUser(
        id: 'u1',
        userName: 'short',
        firstName: 'Adv.',
        lastName: 'rounit signha',
        wordCount: 3,
        order: 0,
      );
      const body = '@Adv. rounit signha';
      final segments = ismChatMentionSegmentsForBody(body, [mentioned]);
      final mentionText = segments
          .firstWhere((s) => s.isLink && s.text.startsWith('@'))
          .text;

      expect(mentionText, '@Adv. rounit signha');
    });
  });
}